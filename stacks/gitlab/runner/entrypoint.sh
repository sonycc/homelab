#!/bin/sh
set -e

CONFIG=/etc/gitlab-runner/config.toml

if ! grep -q 'token = "glrt-' "$CONFIG" 2>/dev/null; then
  echo "Registering GitLab Runner..."
  gitlab-runner register \
    --non-interactive \
    --url "${GITLAB_INTERNAL_URL:-http://gitlab:80}" \
    --token "${GITLAB_RUNNER_TOKEN}" \
    --executor "docker" \
    --docker-image "alpine:3.21" \
    --docker-network-mode "homelab" \
    --docker-pull-policy "if-not-present" \
    --docker-volumes "/cache" \
    --description "homelab-docker-runner"

  sed -i 's/^concurrent = .*/concurrent = 4/' "$CONFIG"
fi

# Ensure clone_url is always set so job containers clone via internal network
if ! grep -q 'clone_url' "$CONFIG" 2>/dev/null; then
  sed -i '/^\[\[runners\]\]/a\  clone_url = "http://gitlab:80"' "$CONFIG"
fi

exec gitlab-runner run --user=gitlab-runner --working-directory=/home/gitlab-runner
