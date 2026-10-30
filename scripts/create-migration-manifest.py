"""Write the ordered EF Core migration IDs declared by this source tree."""
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
MIGRATION_ATTRIBUTE = re.compile(r'\[Migration\("([^"]+)"\)\]')


def main():
    migration_files = sorted((ROOT / 'backend' / 'Migrations').glob('*.Designer.cs'))
    migrations = []
    for source in migration_files:
        matches = MIGRATION_ATTRIBUTE.findall(source.read_text(encoding='utf-8'))
        if len(matches) != 1:
            raise SystemExit(f'Expected one EF migration ID in {source.name}, found {len(matches)}.')
        migrations.append(matches[0])

    migrations.sort()
    if not migrations:
        raise SystemExit('No EF Core migrations were found.')
    if len(migrations) != len(set(migrations)):
        raise SystemExit('EF Core migration IDs must be unique.')

    manifest = {
        'migrations': migrations,
        'latestMigration': migrations[-1],
    }
    rendered = json.dumps(manifest, indent=2) + '\n'
    if len(sys.argv) > 1:
        output = Path(sys.argv[1])
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rendered, encoding='utf-8')
    else:
        sys.stdout.write(rendered)


if __name__ == '__main__':
    main()
