#!/bin/sh
set -e

# Registers on first run only.
# config.toml persists in a named volume,
#   and registering again adds a second runner entry for the same host.
#
# --docker-network-mode host puts job containers in dind's network namespace rather than their own,
#   so a job resolves and routes exactly as dind does and reaches gitlab.<domain> and registry.<domain> the same way.
if [ ! -f /etc/gitlab-runner/config.toml ]; then
  gitlab-runner register \
    --non-interactive \
    --url                 "${GITLAB_INTERNAL_URL}" \
    --token               "${GITLAB_RUNNER_TOKEN}" \
    --executor            "docker" \
    --docker-image        "docker:24.0.5-cli" \
    --docker-host         "tcp://dind:2376" \
    --docker-network-mode "host" \
    --env                 "DOCKER_HOST=tcp://dind:2376" \
    --env                 "DOCKER_TLS_VERIFY=1" \
    --env                 "DOCKER_CERT_PATH=/certs/client" \
    --docker-volumes      "/certs/client:/certs/client:ro"
fi

exec gitlab-runner run
