"""Verify the demo stack, including shared Redis data and optional restarts."""
import argparse
import concurrent.futures
import json
import os
import pathlib
import subprocess
import time
import urllib.request
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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--resilience', action='store_true',
                        help='Also restart Redis, recreate a backend and test failover.')
    args = parser.parse_args()
    directory = pathlib.Path(os.environ.get('DEPLOY_DIR', '/opt/devops-lab'))
    compose = ['docker', 'compose', '--env-file', str(directory / '.env'),
               '-f', str(directory / 'compose.yaml'), '-p', 'devops-lab']
    expected = {'nginx', 'redis', 'portainer',
                *[f'backend-{i}' for i in range(1, 4)],
                *[f'frontend-{i}' for i in range(1, 4)]}
    backends = [f'backend-{i}' for i in range(1, 4)]

    def ready():
        running = set(run(*compose, 'ps', '--status', 'running', '--services').splitlines())
        assert running == expected, f'Running services: {sorted(running)}'
        assert run('docker', 'exec', 'lab-redis', 'redis-cli', 'ping') == 'PONG'
        for service in backends:
            assert internal(service, '/api/health')['status'] == 'UP'
        for path in ['/', '/frontend-info', '/api/info', '/api/health', '/api/tasks']:
            request(path)

    wait_for(ready)
    print('PASS: nine running services, Redis PONG and all HTTP endpoints.')
    task_id = None
    stopped = False
    try:
        title = 'ec2-verification-' + uuid.uuid4().hex[:12]
        task = request('/api/tasks', 'POST', {'title': title})
        task_id = task['id']

        def shared():
            saved = json.loads(run('docker', 'exec', 'lab-redis', 'redis-cli',
                                   '--raw', 'HGET', 'tasks', task_id))
            assert saved['title'] == title, 'Task missing from Redis hash'
            for service in backends:
                assert internal(service, '/api/tasks/' + task_id)['title'] == title

        wait_for(shared)
        print('PASS: task persisted in Redis and read through all three backends.')
        if args.resilience:
            # AOF fsync is every second; wait before deliberately restarting Redis.
            time.sleep(2)
            run(*compose, 'restart', 'redis')
            wait_for(lambda: run('docker', 'exec', 'lab-redis', 'redis-cli', 'ping') == 'PONG'
                     or (_ for _ in ()).throw(AssertionError('Redis not ready')))
            wait_for(shared)
            run(*compose, 'up', '-d', '--no-build', '--force-recreate', 'backend-1')
            run(*compose, 'up', '-d', '--no-build', '--force-recreate', 'nginx')
            wait_for(ready)
            wait_for(shared)
            print('PASS: data survived Redis restart and backend recreation.')
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

        assert request('/api/tasks/' + task_id + '/toggle', 'PUT')['isCompleted']
        request('/api/tasks/' + task_id, 'DELETE')
        assert run('docker', 'exec', 'lab-redis', 'redis-cli', 'HEXISTS', 'tasks', task_id) == '0'
        task_id = None
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            nodes = list(pool.map(lambda _: request('/api/info')['instance'], range(30)))
        assert set(nodes) == {f'backend-dotnet-{i}' for i in range(1, 4)}, nodes
        print('PASS: toggle/delete and 30 requests balanced across all three backends.')
        print(run('docker', 'stats', '--no-stream', '--format', '{{.Name}} {{.MemUsage}} {{.CPUPerc}}'))
    finally:
        if stopped:
            run(*compose, 'start', 'backend-1', 'frontend-1')
            run(*compose, 'up', '-d', '--no-build', '--force-recreate', 'nginx')
        if task_id:
            request('/api/tasks/' + task_id, 'DELETE')


if __name__ == '__main__':
    main()
