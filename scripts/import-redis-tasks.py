"""Export frozen Redis tasks and import idempotently, rejecting invalid/conflicting rows."""
import datetime
import json
import pathlib
import subprocess
import sys
import uuid

destination = pathlib.Path(sys.argv[1])
raw = subprocess.check_output(['docker', 'exec', 'lab-redis', 'redis-cli', '--json', 'HGETALL', 'tasks'], text=True)
entries = json.loads(raw)
if isinstance(entries, list):
    entries = dict(zip(entries[::2], entries[1::2], strict=True))
tasks = []
for key, value in entries.items():
    item = json.loads(value)
    if str(uuid.UUID(item['id'])) != key.lower():
        raise SystemExit('Redis ID/key mismatch; import stopped without writing.')
    if not isinstance(item['title'], str) or not item['title'].strip():
        raise SystemExit('Redis title invalid; import stopped without writing.')
    if not isinstance(item['isCompleted'], bool) or not isinstance(item['createdByNode'], str):
        raise SystemExit('Redis field type invalid; import stopped without writing.')
    stamp = datetime.datetime.fromisoformat(item['createdAt'].replace('Z', '+00:00'))
    if stamp.tzinfo is None:
        raise SystemExit('Redis timestamp has no timezone; import stopped without writing.')
    tasks.append({'id':key, 'title':item['title'], 'is_completed':item['isCompleted'],
                  'created_by_node':item['createdByNode'], 'created_at':stamp.isoformat()})
destination.write_text(json.dumps(tasks), encoding='utf-8')
encoded = json.dumps(tasks).encode().hex()
statement = f"""
BEGIN;
CREATE TEMP TABLE imported_tasks (id uuid PRIMARY KEY, title text NOT NULL, is_completed boolean NOT NULL, created_by_node text NOT NULL, created_at timestamptz NOT NULL);
INSERT INTO imported_tasks SELECT * FROM jsonb_to_recordset(convert_from(decode('{encoded}','hex'),'UTF8')::jsonb)
  AS r(id uuid,title text,is_completed boolean,created_by_node text,created_at timestamptz);
INSERT INTO tasks(id,title,is_completed,created_by_node,created_at) SELECT * FROM imported_tasks ON CONFLICT(id) DO NOTHING;
DO $$ BEGIN IF EXISTS(SELECT FROM imported_tasks i JOIN tasks t USING(id)
 WHERE (t.title,t.is_completed,t.created_by_node,t.created_at) IS DISTINCT FROM (i.title,i.is_completed,i.created_by_node,i.created_at))
 THEN RAISE EXCEPTION 'Redis/PostgreSQL records conflict'; END IF; END $$;
COMMIT;
"""
subprocess.run(['docker','exec','-i','lab-postgres','bash','-c',
    'export PGPASSWORD="$(cat /run/secrets/postgres_password)"; exec psql -X -q -v ON_ERROR_STOP=1 -h127.0.0.1 -U postgres -d devops'],
    input=statement, text=True, check=True, stdout=subprocess.DEVNULL)
print(f'Imported/validated {len(tasks)} Redis records; export stored with restricted permissions.')
