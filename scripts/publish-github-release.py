"""Publish optional GitHub metadata after the EC2 deployment has passed checks."""
import json
import os
import urllib.error
import urllib.request


def api(path, body=None):
    request = urllib.request.Request(
        'https://api.github.com/repos/maxivalenzano/dev-ops-clase-2' + path,
        data=json.dumps(body).encode() if body is not None else None,
        headers={'Authorization': 'Bearer ' + os.environ['GITHUB_RELEASE_TOKEN'],
                 'Accept': 'application/vnd.github+json',
                 'Content-Type': 'application/json', 'User-Agent': 'DevOps-EC2-Pipeline',
                 'X-GitHub-Api-Version': '2022-11-28'})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def main():
    tag = 'v' + os.environ['SEMVER_TAG']
    commit = os.environ['SOURCE_COMMIT']
    app_url = os.environ['APP_URL']
    try:
        api('/releases/tags/' + tag)
        print(f'Release {tag} already exists; preserving it.')
    except urllib.error.HTTPError as exc:
        if exc.code != 404:
            raise
        api('/releases', {
            'tag_name': tag, 'target_commitish': commit, 'name': 'Release ' + tag,
            'body': f'Application: {app_url}\n\nAWS EC2 / Docker Compose\n\n'
                    f'Commit: {commit}\nImages: {os.environ["IMAGE_TAG"]}',
            'draft': False, 'prerelease': '-' in os.environ['SEMVER_TAG'],
            'generate_release_notes': True})
    deployment = api('/deployments', {
        'ref': commit, 'environment': 'ec2-demo', 'auto_merge': False,
        'required_contexts': [], 'production_environment': False,
        'description': 'EC2 deployment ' + os.environ['IMAGE_TAG']})
    api(f'/deployments/{deployment["id"]}/statuses', {
        'state': 'success', 'environment_url': app_url,
        'description': 'Compose, readiness, HTTP and PostgreSQL verification passed.'})
    print(f'GitHub release/deployment metadata published for {tag}.')


if __name__ == '__main__':
    main()
