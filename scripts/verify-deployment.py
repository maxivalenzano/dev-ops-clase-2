"""Verify the ten durable services and PostgreSQL persistence; resilience is opt-in."""
import argparse
import concurrent.futures
import json
import os
import pathlib
import subprocess
import time
import urllib.request
import urllib.error
import uuid


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT, timeout=90).strip()


def wait_for(action, timeout=90):
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        try:
            return action()
        except (AssertionError, OSError, ValueError, subprocess.SubprocessError) as exc:
            last = exc
            time.sleep(2)
    raise RuntimeError(f'Readiness check failed: {last}')


def request(path, method='GET', body=None):
    payload = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request('http://127.0.0.1' + path, data=payload,
                                 method=method, headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=20) as response:
        raw = response.read()
        return json.loads(raw) if raw and path != '/' else raw


def internal(service, path):
    return json.loads(run('docker', 'exec', 'lab-nginx', 'wget', '-qO-',
                          f'http://{service}:3000{path}'))


def sql(statement):
    return run('docker', 'exec', 'lab-postgres', 'bash', '-c',
               'export PGPASSWORD="$(cat /run/secrets/app_password)"; '
               'exec psql -X -qAt -v ON_ERROR_STOP=1 -h127.0.0.1 -U devops_app -d devops -c "$1"',
               'sql', statement)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--resilience', action='store_true',
                        help='Also interrupt/recreate PostgreSQL and recreate a backend (maintenance window).')
    args = parser.parse_args()
    directory = pathlib.Path(os.environ.get('DEPLOY_DIR', '/opt/devops-lab'))
    compose = ['docker', 'compose', '--env-file', str(directory / '.env'),
               '-f', str(directory / 'compose.yaml'), '-p', 'devops-lab']
    data_compose = ['docker', 'compose', '-p', 'devops-data',
                    '-f', str(directory / 'data' / 'compose.data.yaml')]
    expected = {'nginx', 'redis', 'portainer',
                *[f'backend-{i}' for i in range(1, 4)],
                *[f'frontend-{i}' for i in range(1, 4)]}
    backends = [f'backend-{i}' for i in range(1, 4)]

    def ready():
        running = set(run(*compose, 'ps', '--status', 'running', '--services').splitlines())
        assert running == expected, f'Running services: {sorted(running)}'
        assert set(run(*data_compose, 'ps', '--status', 'running', '--services').splitlines()) == {'postgres'}
        assert run('docker', 'inspect', 'lab-postgres', '--format', '{{.State.OOMKilled}}') == 'false'
        assert run('docker', 'exec', 'lab-redis', 'redis-cli', 'ping') == 'PONG'
        assert sql('SELECT current_database();') == 'devops'
        for service in backends:
            assert internal(service, '/api/health')['status'] == 'UP'
            assert internal(service, '/api/ready')['status'] == 'UP'
        for path in ['/', '/frontend-info', '/api/info', '/api/health', '/api/ready', '/api/tasks']:
            request(path)

    wait_for(ready)
    print('PASS: ten durable services, authenticated PostgreSQL and readiness on three backends.')
    task_id = None
    stopped = False
    database_stopped = False
    try:
        title = 'ec2-verification-' + uuid.uuid4().hex[:12]
        task = request('/api/tasks', 'POST', {'title': title})
        task_id = task['id']

        def shared():
            saved = json.loads(sql(f"SELECT row_to_json(t) FROM tasks t WHERE id='{uuid.UUID(task_id)}';"))
            assert saved['title'] == title, 'Task missing from PostgreSQL'
            for service in backends:
                assert internal(service, '/api/tasks/' + task_id)['title'] == title

        wait_for(shared)
        print('PASS: task persisted in PostgreSQL and read through all three backends.')
        if args.resilience:
            run(*data_compose, 'stop', 'postgres')
            database_stopped = True
            for path, method, body in [('/api/ready','GET',None),('/api/tasks','POST',{'title':'must-not-diverge'})]:
                try:
                    request(path, method, body)
                except urllib.error.HTTPError as exc:
                    assert exc.code == 503, exc.code
                else:
                    raise AssertionError('Database outage must return 503')
            run(*data_compose, 'up', '-d', '--force-recreate', '--wait', 'postgres')
            database_stopped = False
            wait_for(ready)
            wait_for(shared)
            run(*compose, 'up', '-d', '--no-build', '--force-recreate', 'backend-1')
            run(*compose, 'up', '-d', '--no-build', '--force-recreate', 'nginx')
            wait_for(ready)
            wait_for(shared)
            print('PASS: outage returned 503; data survived PostgreSQL and backend recreation.')
            stopped = True
            run(*compose, 'stop', 'backend-1', 'frontend-1')
            for _ in range(12):
                request('/')
                assert request('/api/health')['status'] == 'UP'
            run(*compose, 'start', 'backend-1', 'frontend-1')
            stopped = False
            run(*compose, 'up', '-d', '--no-build', '--force-recreate', 'nginx')
            wait_for(ready)
            print('PASS: gateway served traffic with one frontend and backend stopped.')

        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            list(pool.map(lambda _: request('/api/tasks/' + task_id + '/toggle', 'PUT'), range(10)))
        assert request('/api/tasks/' + task_id)['isCompleted'] is False
        assert request('/api/tasks/' + task_id + '/toggle', 'PUT')['isCompleted']
        request('/api/tasks/' + task_id, 'DELETE')
        assert sql(f"SELECT count(*) FROM tasks WHERE id='{uuid.UUID(task_id)}';") == '0'
        task_id = None
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            nodes = list(pool.map(lambda _: request('/api/info')['instance'], range(30)))
        assert set(nodes) == {f'backend-dotnet-{i}' for i in range(1, 4)}, nodes
        print('PASS: ten atomic concurrent toggles, delete and balance across three backends.')
        print(run('docker', 'stats', '--no-stream', '--format', '{{.Name}} {{.MemUsage}} {{.CPUPerc}}'))
    finally:
        if database_stopped:
            run(*data_compose, 'up', '-d', '--wait', 'postgres')
        if stopped:
            run(*compose, 'start', 'backend-1', 'frontend-1')
            run(*compose, 'up', '-d', '--no-build', '--force-recreate', 'nginx')
        if task_id:
            request('/api/tasks/' + task_id, 'DELETE')


if __name__ == '__main__':
    main()
