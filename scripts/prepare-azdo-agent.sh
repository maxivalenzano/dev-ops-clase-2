#!/usr/bin/env bash
# Download the official agent; registration still requires the Environment script.
set -euo pipefail
agent_dir=/opt/azdo-agent
agent_version=5.281.1
agent_sha256=c9579f76fd71a013e3b9010155454e20592d935134e4fcd04adc5283a820167e
sudo install -d -m 0700 -o "$(id -un)" -g "$(id -gn)" "$agent_dir"
cd "$agent_dir"
if [[ -f .agent ]]; then
  echo 'An agent is already registered here; leaving it unchanged.'
  exit 0
fi
if [[ ! -x bin/Agent.Listener ]]; then
  archive="$(mktemp /tmp/azdo-agent.XXXXXXXX.tar.gz)"
  trap 'rm -f -- "$archive"' EXIT
  curl -fsSL "https://download.agent.dev.azure.com/agent/$agent_version/vsts-agent-linux-x64-$agent_version.tar.gz" -o "$archive"
  printf '%s  %s\n' "$agent_sha256" "$archive" | sha256sum --check
  tar xzf "$archive"
fi
./bin/Agent.Listener --version
echo 'Agent files ready in /opt/azdo-agent; registration and systemd service pending.'
