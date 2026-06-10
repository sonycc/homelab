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
    --docker-image "alpine:latest" \
    --docker-network-mode "homelab" \
    --docker-pull-policy "if-not-present" \
    --docker-volumes "/cache" \
    --description "homelab-docker-runner"

  sed -i 's/^concurrent = .*/concurrent = 4/' "$CONFIG"
fi

exec gitlab-runner run --user=gitlab-runner --working-directory=/home/gitlab-runner
