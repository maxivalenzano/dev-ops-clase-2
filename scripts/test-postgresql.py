"""Exercise the real release images and EF bundle against disposable PostgreSQL.

Run on a Linux Docker CI agent. No production services or volumes are used.
"""
import concurrent.futures
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import tempfile
import time
import urllib.error
import urllib.request
import uuid
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
RUN = 'ef-test-' + uuid.uuid4().hex[:10]
PG = RUN + '-pg'
NETWORK = RUN
CONTAINERS = []
RESULTS = []


def command(*args, data=None, check=True):
    result = subprocess.run(args, input=data, text=True, capture_output=True, cwd=ROOT)
    if check and result.returncode:
        # Test credentials are random and disposable; still keep command arguments out of logs.
        raise RuntimeError(result.stderr[-3000:] or result.stdout[-3000:])
    return result


def sql(statement, database='lab', user='postgres', check=True):
    return command('docker', 'exec', '-i', PG, 'psql', '-X', '-A', '-t',
                   '-v', 'ON_ERROR_STOP=1', '-U', user, '-d', database,
                   data=statement, check=check)


def wait(check, seconds=60):
    deadline = time.monotonic() + seconds
    last = None
    while time.monotonic() < deadline:
        try:
            return check()
        except Exception as exc:
            last = exc
            time.sleep(1)
    raise AssertionError('Timed out waiting for service') from last


def http(port, path='/api/ready', method='GET', body=None, status=200):
    started = time.monotonic()
    request = urllib.request.Request(
        f'http://127.0.0.1:{port}{path}', method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            code, payload = response.status, response.read()
    except urllib.error.HTTPError as exc:
        code, payload = exc.code, exc.read()
    assert code == status, (path, code, f'{time.monotonic() - started:.3f}s', payload[:500])
    return json.loads(payload) if payload else None


def record(name, check):
    started = time.monotonic()
    try:
        check()
        RESULTS.append((name, time.monotonic() - started, None))
        print('PASS:', name, flush=True)
    except Exception as exc:
        RESULTS.append((name, time.monotonic() - started, str(exc)))
        raise


def main():
    phases = json.loads((ROOT / 'backend/schema-compatibility.json').read_text())
    image = re.search(r'^    image: (postgres:[^\s]+)',
                      (ROOT / 'compose.data.yaml').read_text(), re.M).group(1)
    command('docker', 'network', 'create', NETWORK)
    with tempfile.TemporaryDirectory(prefix=RUN) as directory:
        work = Path(directory)
        work.chmod(0o755)  # Traversable by the non-root application UID inside Docker.
        password = secrets.token_hex(24)
        (work / 'postgres.env').write_text('POSTGRES_DB=lab\nPOSTGRES_PASSWORD=' + password)
        for name, user in [('migrator', 'lab_migrator'), ('app', 'lab_app')]:
            file = work / name
            file.write_text(f'Host=postgres;Database=lab;Username={user};Password={password};'
                            'Maximum Pool Size=5;Timeout=3;Command Timeout=10;'
                            'Options=-c lock_timeout=2000 -c statement_timeout=10000')
            file.chmod(0o444)
        command('docker', 'run', '-d', '--name', PG, '--network', NETWORK,
                '--network-alias', 'postgres', '--env-file', str(work / 'postgres.env'), image)
        CONTAINERS.append(PG)
        # initdb briefly runs a Unix-socket-only server; wait for the final TCP listener.
        wait(lambda: command('docker', 'exec', PG, 'pg_isready', '-h', '127.0.0.1',
                             '-U', 'postgres', '-d', 'lab'))
        wait(lambda: sql('SELECT 1'))
        sql(f"CREATE ROLE lab_migrator LOGIN PASSWORD '{password}';"
            f"CREATE ROLE lab_app LOGIN PASSWORD '{password}';"
            'ALTER SCHEMA public OWNER TO lab_migrator;'
            'REVOKE CREATE ON SCHEMA public FROM PUBLIC;'
            'GRANT USAGE ON SCHEMA public TO lab_app;'
            'ALTER DEFAULT PRIVILEGES FOR ROLE lab_migrator IN SCHEMA public '
            'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO lab_app;')

        def migrate(phase=None, target=None, check=True):
            return command('docker', 'run', '--rm', '--network', NETWORK,
                           '-v', f'{work / "migrator"}:/run/secrets/db_connection:ro',
                           '-e', 'DATABASE_CONNECTION_FILE=/run/secrets/db_connection',
                           'devops-migrator:test', target or phases[phase]['targetMigration'], check=check)

        def start_app(phase, index=1):
            name = RUN + '-' + phase.lower() + '-' + str(index)
            command('docker', 'run', '-d', '--name', name, '--network', NETWORK,
                    '-p', '127.0.0.1::3000', '-e', 'INSTANCE_NAME=' + name,
                    '-v', f'{work / "app"}:/run/secrets/db_connection:ro',
                    '-e', 'DATABASE_CONNECTION_FILE=/run/secrets/db_connection',
                    'devops-backend:test-' + phase)
            CONTAINERS.append(name)
            binding = json.loads(command('docker', 'inspect', name).stdout)[0]
            port = binding['NetworkSettings']['Ports']['3000/tcp'][0]['HostPort']
            wait(lambda: http(port))
            return name, port

        def history():
            return sql('SELECT "MigrationId" FROM "__EFMigrationsHistory" ORDER BY 1').stdout.strip()

        record('P1: migrate empty database using the final bundle image', lambda: migrate('P1'))
        _, p1 = start_app('P1')
        task = http(p1, '/api/tasks', 'POST', {'title': 'Existing P1 task'}, 201)
        marker = task['id']
        task = http(p1, '/api/tasks/' + marker)
        record('P2: additive migration preserves existing records', lambda: migrate('P2'))
        _, p2 = start_app('P2')
        assert http(p2, '/api/tasks/' + marker)['title'] == task['title']
        sql(f"UPDATE tasks SET priority = NULL WHERE id = '{marker}'")
        assert http(p2, '/api/tasks/' + marker)['priority'] == 2

        def failed_not_null():
            result = sql('ALTER TABLE tasks ALTER COLUMN priority SET NOT NULL', check=False)
            assert result.returncode != 0
            assert phases['P2']['targetMigration'] in history()
            assert phases['P3']['targetMigration'] not in history()
        record('Controlled failure: NOT NULL before backfill is rejected', failed_not_null)

        def ddl_timeout():
            blocker = subprocess.Popen(
                ['docker', 'exec', '-i', PG, 'psql', '-X', '-v', 'ON_ERROR_STOP=1',
                 '-U', 'postgres', '-d', 'lab'], stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, text=True)
            blocker.stdin.write('BEGIN; LOCK TABLE tasks IN ACCESS EXCLUSIVE MODE; SELECT pg_sleep(12); COMMIT;\n')
            blocker.stdin.close()
            try:
                def lock_acquired():
                    assert sql("SELECT count(*) FROM pg_locks WHERE relation='tasks'::regclass "
                               "AND mode='AccessExclusiveLock' AND granted").stdout.strip() == '1'
                wait(lock_acquired, 10)
                result = migrate('P3', check=False)
                assert result.returncode != 0, 'DDL must time out under a prolonged lock'
            finally:
                blocker.wait(timeout=30)
            assert phases['P3']['targetMigration'] not in history()
        record('DDL lock timeout prevents an indefinite deployment', ddl_timeout)
        record('P3: backfill then NOT NULL and CHECK preserve task identity', lambda: migrate('P3'))
        _, p3 = start_app('P3')
        upgraded = http(p3, '/api/tasks/' + marker)
        for key in ('id', 'title', 'isCompleted', 'createdAt', 'createdByNode'):
            assert upgraded[key] == task[key], key
        assert upgraded['priority'] == 2

        def idempotence():
            before = history()
            migrate('P3')
            assert history() == before
        record('Second bundle execution leaves history and data unchanged', idempotence)

        def constraints():
            for value in ('NULL', '0', '9'):
                assert sql(f"UPDATE tasks SET priority={value} WHERE id='{marker}'", check=False).returncode != 0
            for value in (0, 9):
                http(p3, '/api/tasks', 'POST', {'title': 'Invalid', 'priority': value}, 400)
            assert sql('CREATE TABLE forbidden(id int)', user='lab_app', check=False).returncode != 0
        record('Database constraints, API validation and DML-only app privileges', constraints)

        def old_image():
            http(p1)
            item = http(p1, '/api/tasks', 'POST', {'title': 'P1 on P3'}, 201)
            assert http(p3, '/api/tasks/' + item['id'])['priority'] == 2
            http(p1, '/api/tasks/' + item['id'] + '/toggle', 'PUT')
            http(p1, '/api/tasks/' + item['id'], 'DELETE', status=204)
        record('Actual P1 image supports CRUD on P3 schema (application rollback)', old_image)

        replicas = [p3] + [start_app('P3', i)[1] for i in (2, 3)]

        def concurrency():
            for port in replicas:
                assert http(port, '/api/tasks/' + marker)['id'] == marker
            with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
                list(pool.map(lambda i: http(replicas[i % 3], '/api/tasks/' + marker + '/toggle', 'PUT'), range(30)))
            assert http(p3, '/api/tasks/' + marker)['isCompleted'] is False
        record('Three replicas share data and 30 concurrent toggles lose no updates', concurrency)

        # Match the production gateway deadlines so a slow DB failure cannot turn 503 into 504.
        gateway = RUN + '-gateway'
        upstream = '\n'.join(f'server {RUN}-p3-{i}:3000 max_fails=2 fail_timeout=10s;' for i in (1, 2, 3))
        config = work / 'nginx.conf'
        config.write_text('upstream backends { ' + upstream + ' }\n'
                          'server { listen 8080; location / { proxy_pass http://backends; '
                          'proxy_connect_timeout 5s; proxy_read_timeout 5s; '
                          'proxy_next_upstream error timeout http_503; proxy_next_upstream_tries 3; } }')
        config.chmod(0o444)
        command('docker', 'run', '-d', '--name', gateway, '--network', NETWORK,
                '-p', '127.0.0.1::8080', '-v', f'{config}:/etc/nginx/conf.d/default.conf:ro', 'nginx:alpine')
        CONTAINERS.append(gateway)
        binding = json.loads(command('docker', 'inspect', gateway).stdout)[0]
        gateway_port = binding['NetworkSettings']['Ports']['8080/tcp'][0]['HostPort']
        wait(lambda: http(gateway_port))

        def persistence_and_outage():
            command('docker', 'stop', PG)
            try:
                http(p3, status=503)
                http(p3, '/api/tasks', 'POST', {'title': 'Must not use fallback'}, 503)
                http(gateway_port, status=503)
                http(gateway_port, '/api/tasks', 'POST', {'title': 'Must not use fallback'}, 503)
                http(p3, '/api/health')
            finally:
                command('docker', 'start', PG)
            wait(lambda: http(p3))
            assert http(p3, '/api/tasks/' + marker)['id'] == marker
            assert sql("SELECT count(*) FROM tasks WHERE title='Must not use fallback'").stdout.strip() == '0'
        record('Database outage returns 503 through Nginx; restart retains data and reconnects', persistence_and_outage)

        def restore_and_down():
            sql(f"UPDATE tasks SET priority=3 WHERE id='{marker}'")
            command('docker', 'exec', PG, 'pg_dump', '-U', 'postgres', '-d', 'lab', '-Fc', '-f', '/tmp/recovery.dump')
            expected = sql('SELECT row_to_json(t) FROM tasks t ORDER BY id').stdout
            command('docker', 'exec', PG, 'createdb', '-U', 'postgres', 'restore_test')
            command('docker', 'exec', PG, 'pg_restore', '-U', 'postgres', '-d', 'restore_test', '--exit-on-error', '/tmp/recovery.dump')
            assert sql('SELECT row_to_json(t) FROM tasks t ORDER BY id', 'restore_test').stdout == expected
            assert sql('SELECT "MigrationId" FROM "__EFMigrationsHistory" ORDER BY 1', 'restore_test').stdout.strip() == history()
            migrate('P1')  # Deliberate destructive Down only in this disposable database.
            migrate('P3')
            assert http(p3, '/api/tasks/' + marker)['priority'] == 2
            assert sql(f"SELECT priority FROM tasks WHERE id='{marker}'", 'restore_test').stdout.strip() == '3'
        record('Backup restores separately; Down cannot recover dropped priority values', restore_and_down)

        def sql_artifact():
            name = RUN + '-sql-artifact'
            command('docker', 'create', '--name', name, 'devops-migrator:test')
            try:
                command('docker', 'cp', name + ':/artifacts/forward.sql', str(work / 'forward.sql'))
            finally:
                command('docker', 'rm', name)
            sql('CREATE DATABASE freshsql OWNER lab_migrator', database='postgres')
            statement = (work / 'forward.sql').read_text(encoding='utf-8-sig')
            sql(statement, database='freshsql', user='lab_migrator')
            before = sql('SELECT "MigrationId" FROM "__EFMigrationsHistory" ORDER BY 1', 'freshsql').stdout
            sql(statement, database='freshsql', user='lab_migrator')
            assert sql('SELECT "MigrationId" FROM "__EFMigrationsHistory" ORDER BY 1', 'freshsql').stdout == before
            assert sql('SELECT count(*) FROM "__EFMigrationsHistory"', 'freshsql').stdout.strip() == '4'
        record('Published forward SQL executes twice on a separate empty database', sql_artifact)

        def fresh_to_latest():
            sql('CREATE DATABASE fresh OWNER lab_migrator', database='postgres')
            connection = work / 'migrator'
            connection.chmod(0o644)
            connection.write_text(connection.read_text().replace('Database=lab;', 'Database=fresh;'))
            connection.chmod(0o444)
            migrate('P3')
            assert sql('SELECT count(*) FROM "__EFMigrationsHistory"', 'fresh').stdout.strip() == '4'
        record('Empty database migrates directly to latest P3', fresh_to_latest)


if __name__ == '__main__':
    try:
        main()
    finally:
        if any(error is not None for _, _, error in RESULTS):
            for name in CONTAINERS:
                if '-p3-' in name or name.endswith('-gateway'):
                    logs = command('docker', 'logs', '--tail', '60', name, check=False)
                    print('Failure diagnostics:', name, logs.stdout, logs.stderr, flush=True)
        suite = ET.Element('testsuite', name='PostgreSQL migrations', tests=str(len(RESULTS)),
                           failures=str(sum(error is not None for _, _, error in RESULTS)))
        for name, elapsed, error in RESULTS:
            case = ET.SubElement(suite, 'testcase', name=name, time=f'{elapsed:.3f}')
            if error is not None:
                ET.SubElement(case, 'failure', message=error[:2000])
        output = ROOT / 'TestResults'
        output.mkdir(exist_ok=True)
        ET.ElementTree(suite).write(output / 'postgresql.xml', encoding='utf-8', xml_declaration=True)
        for name in reversed(CONTAINERS):
            command('docker', 'rm', '-f', '-v', name, check=False)
        command('docker', 'network', 'rm', NETWORK, check=False)
