# Homelab Security Audit

**Date:** 2026-06-25  
**Branch:** feat/gitlab-runner  
**Scope:** All stacks under `stacks/` — compose files, env examples, scripts, nginx configs, prometheus config

---

## Open Findings

### H1 — Docker socket mounted in `gitlab-runner`

**File:** `stacks/gitlab/docker-compose.yml`

```yaml
- /var/run/docker.sock:/var/run/docker.sock
```

Mounting the Docker daemon socket gives any CI job that runs on this runner **full root access to the host**. A malicious or compromised pipeline job can start containers with `--privileged`, mount the host filesystem, read secrets from other containers' environments, or install a backdoor.

**Fix options (pick one):**
- **`tecnativa/docker-socket-proxy`** — filtered TCP proxy in front of the socket; blocks `EXEC`, `COMMIT`, `SECRETS`, `SWARM` API calls while keeping CI working. Runner uses `DOCKER_HOST=tcp://socket-proxy:2375` instead of the socket mount.
- **Rootless Docker / `userns_remap`** — configure the Docker daemon so container root doesn't map to host root. Host-level change.

---

### M7 — No network segmentation — all services on a single flat network

Every service shares the `homelab` network. A compromised container has direct network access to the database and all other services.

**Recommended segmentation:**

| Network      | Members                                          |
|--------------|--------------------------------------------------|
| `proxy`      | cloudflared, nginx                               |
| `app`        | nginx, gitlab, grafana                           |
| `data`       | postgres, postgres-backup, gitlab, grafana       |
| `monitoring` | prometheus, cadvisor, node-exporter, grafana     |

---

### L2 — fail2ban not implemented

Config files exist in `stacks/proxy/fail2ban/` but the service is not in the compose file. Without it, brute-force attacks against GitLab login and Grafana go unblocked. Requires `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ZONE_ID` in proxy `.env`.

---

### L3 — `uptime` stack is empty

`stacks/uptime/docker-compose.yml` exists but is blank. Consider uptime-kuma on a separate host so it can alert when the homelab itself is down.

---

### L7 — `test.local` proxy host missing exploit-blocking include

`stacks/proxy/data/nginx/proxy_host/1.conf` does not include `conf.d/include/block-exploits.conf`, unlike the `gitlab.<domain>` proxy host. Either add the include or confirm this host is not reachable externally.

---

### L8 — No image freshness tracking

No mechanism surfaces when a running container image has a newer upstream release. Pinned tags go stale silently.

**Fix:** Add **Diun** (Docker Image Update Notifier) to the monitoring stack — lightweight, read-only, sends notifications when a new digest is published for a tag.

---

## Planned Improvements

### P2 — GitLab container registry ✓ configured

The GitLab built-in container registry is now enabled. Changes made:

- `stacks/gitlab/docker-compose.yml` — added `registry_external_url`, `registry_nginx['listen_port'] = 5050`, `registry_nginx['listen_https'] = false` to `GITLAB_OMNIBUS_CONFIG`; added port `${GITLAB_REGISTRY_PORT:-5050}:5050`
- `stacks/gitlab/.env.example` — added `GITLAB_REGISTRY_PORT=5050`

**Remaining manual steps (UI-only, cannot be automated):**
1. **NPM:** Add proxy host `registry.<domain> → http://gitlab:5050` in the Nginx Proxy Manager UI (http://localhost:81)
2. **Cloudflare:** Add public hostname `registry.<domain> → http://nginx:80` in the Zero Trust dashboard

Both steps are documented as comments in `stacks/proxy/docker-compose.yml`.

---

### P1 — Enable SSH-based git push/pull for GitLab

Cloudflare tunnels do not proxy raw TCP/SSH. Options:
- **Cloudflare Tunnel `ssh` service** — configure a public hostname of type `SSH` in Zero Trust pointing to `gitlab:22`.
- **Direct port forwarding** — expose `GITLAB_SSH_PORT` through the router (bypasses Cloudflare).
- **Tailscale / WireGuard** — route SSH through a VPN overlay.

The compose file already maps `${GITLAB_SSH_PORT}:22` and sets `gitlab_rails['gitlab_shell_ssh_port']` — the gap is the ingress path.

---

## Gitignore Notes

- `stacks/proxy/data/keys.json` — RSA private key (NPM JWT signing key). Correctly gitignored via `data/`. Never manually stage it.
- `.env` files excluded via `.env` / `.env.*` with `!.env.example` whitelist.
- `*.pem`, `*.key`, `*.crt` excluded as a safety net.
