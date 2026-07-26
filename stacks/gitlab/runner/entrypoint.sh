#!/bin/sh
set -e

# --docker-network-mode host: job containers share dind's network namespace (dind
# is on the homelab network), so they resolve the NPM split-horizon aliases
# (gitlab.<domain> / registry.<domain> → NPM) and reach GitLab over internal HTTPS.
# Not a leftover workaround — required for the shared-dind architecture.
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
