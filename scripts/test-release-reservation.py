"""Verify that persistent release ownership survives the stage's flock lifetime."""
import os
import pathlib
import subprocess
import tempfile

root=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='release-reservation-') as directory:
    env=dict(os.environ,DEPLOY_DIR=directory,BUILD_ID='101',SOURCE_COMMIT='a'*40,
             IMAGE_TAG='test')
    command=['bash','-c','source scripts/lib-postgresql.sh; reserve_release']
    other=dict(env,BUILD_ID='102')
    holding=subprocess.Popen(['bash','-c','source scripts/lib-postgresql.sh; reserve_release; echo reserved; read -r token'],
                             cwd=root,env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
    assert holding.stdout.readline().strip() == 'reserved'
    assert subprocess.run(command,cwd=root,env=other,capture_output=True).returncode != 0
    holding.communicate('release\n',timeout=10)
    assert holding.returncode == 0
    # The first stage ended (flock released), but build 102 still cannot mutate the release.
    assert subprocess.run(command,cwd=root,env=other,capture_output=True).returncode != 0
    subprocess.run(command,cwd=root,env=env,check=True)
    subprocess.run(['bash','-c','source scripts/lib-postgresql.sh; release_reservation'],cwd=root,env=env,check=True)
    subprocess.run(command,cwd=root,env=other,check=True)
print('PASS: second build blocked across stages; owner retry and explicit release verified.')
