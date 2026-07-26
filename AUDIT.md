# Homelab Security Audit

**Date:** 2026-06-25  
**Branch:** feat/gitlab-runner  
**Scope:** All stacks under `stacks/` — compose files, env examples, scripts, nginx configs, prometheus config  
**Updated:** 2026-07-26 — added H2 for the new `pelican` stack

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

### H2 — Pelican: root-equivalent Docker socket, plus the first inbound ports that bypass Cloudflare

**Files:** `stacks/pelican/docker-compose.yml`, router configuration

Adding the pelican stack introduces two exposures at once, both structural rather than misconfigurations — the panel cannot do its job without them.

**Read-write Docker socket in `wings`.** Same class as H1, but with a wider blast radius: where H1 is reachable by anyone who can run a CI job, this is reachable by anyone who can create a server in the panel. Wings mounts `/var/run/docker.sock` read-write by design — creating game server containers *is* the product. `tecnativa/docker-socket-proxy` is not a fix here the way it is for H1; wings legitimately needs container create/start/stop/exec, which is most of what the proxy exists to block.

- Keep panel registration closed and the admin account small. Treat "can create a server" as equivalent to "has root on the host".
- The `no-new-privileges` flag on the wings container is close to cosmetic — it constrains the wings process, not the containers wings asks the daemon to create.

**Game ports forwarded past the tunnel.** Every service to date reaches the internet through cloudflared, which means no inbound ports and fail2ban banning at the Cloudflare edge. Game protocols cannot use that path: Cloudflare Tunnel carries HTTP/HTTPS, and most titles are UDP (Valheim, Rust, CS2, Palworld). So game allocations are forwarded at the router straight to the host, and:

- The home IP is directly exposed on those ports rather than fronted by Cloudflare.
- **No jail can protect them.** The fail2ban deployment from L2 bans via the Cloudflare API; this traffic never touches Cloudflare, so there is nothing to ban. This is the same gap M9 describes for GitLab's published ports, arrived at by a different route.
- The exposed surface is game server software plus community mods — historically not a hardened target.

**Mitigations:**
- Forward only the specific allocations created in the panel, never a range.
- Keep SFTP (`WINGS_SFTP_BIND`) on `127.0.0.1` unless remote file access is genuinely needed; it defaults to loopback for that reason.
- Set per-server memory/disk caps and a node allocation limit in the panel — the compose-level `deploy.resources.limits` constrain only the wings binary, not the game servers, which are sibling containers of the host daemon.
- If iptables-based banning for these ports is wanted, it needs the second `network_mode: host` fail2ban with `NET_ADMIN` already floated under M9.

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

### L2 — fail2ban ✓ implemented (2026-07-26)

The original finding said "config files exist in `stacks/proxy/fail2ban/`". They did not — the directory was absent and nothing had been staged. Built from scratch:

- `fail2ban` service in `stacks/proxy/docker-compose.yml`, 5 jails, full docs in `stacks/proxy/fail2ban/README.md`
- Bans apply as **Cloudflare IP Access Rules**, not iptables. Behind the tunnel every packet reaches the kernel with cloudflared's address as its source, so a local firewall rule has nothing to match on; the real client IP exists only in `CF-Connecting-IP`, which `nginx.conf` already promotes via `real_ip_header`.
- The container gets **no `NET_ADMIN`** — unusual for fail2ban, and possible only because the ban action makes HTTPS calls rather than writing firewall rules. A process parsing attacker-controlled log lines stays unprivileged.

Filters were validated against real logs rather than assumed: `npm-botsearch` produced 0 false positives across 4285 live access-log lines, and the git-protocol exclusion in `npm-auth` correctly ignored 66 legitimate `401`s.

**Deployed and verified 2026-07-27.** Container healthy, 4 jails active, ban path confirmed by a live round trip against reserved documentation addresses (correct IPv4/IPv6 target selection, rule creation, restore-on-restart, clean deletion).

Two defects were found only by running it against live data, both of which passed every static check:

- **UTC vs local time.** GitLab and Grafana log in UTC; the container runs Europe/Oslo. The filters' `datepattern` omitted the timezone, so entries parsed 2h in the past and, with `findtime=10m`, `gitlab-auth` could never have banned anyone. Also `%f` does not match Grafana's 9-digit nanosecond timestamps — `(?:\.\d+)?%z` handles both.
- **fail2ban strips shell after a whitespace-preceded semicolon.** Inline `case ... ;; ... esac` in the ban action reached `sh` truncated, so every ban failed — while `fail2ban-client -t` still reported the config valid. Logic moved to `fail2ban/bin/cloudflare.sh`; the action file must stay free of semicolons.

The lesson worth carrying: for this component, config validation and `fail2ban-regex` prove nothing about whether a ban actually happens. Only the round trip does.

**Correction (2026-07-27):** this entry originally specified a token scoped to `Zone → Firewall Services → Edit`. No such permission group exists. The IP Access Rules endpoint requires [`Account Firewall Access Rules Write`](https://developers.cloudflare.com/api/resources/firewall/subresources/access_rules/methods/create/), which is **account-scoped** — the token cannot be restricted to a single zone, contrary to what was claimed here. The ban action now targets the account-level endpoint so its scope matches the permission, and it inspects the API response: Cloudflare returns HTTP 200 with `"success":false` for an expired token or a missing permission, which the original action discarded, making a no-op ban indistinguishable from a real one in the logs.

---

### M8 — GitLab logged the reverse proxy as the client ✓ fixed (2026-07-26)

**File:** `stacks/gitlab/docker-compose.yml`

`gitlab_rails['trusted_proxies']` was unset, so Rails treated nginx as the originating client and recorded `"remote_ip":"172.21.0.2"` on every request — despite `CF-Connecting-IP` and `cf_ipcountry` reaching GitLab intact.

This silently degraded everything keyed on client identity: per-IP rate limiting, the abuse dashboard, and audit events all attributed every request in the instance to a single internal address. It would also have made the new `gitlab-auth` jail actively dangerous — five failed logins from anywhere would have banned nginx at the Cloudflare edge, taking every hostname on the zone offline at once.

**Fix applied:** `gitlab_rails['trusted_proxies'] = ['172.21.0.0/16']`.

Same class of bug to watch for elsewhere: Grafana has no equivalent setting, which is why the `grafana-auth` jail ships disabled pending verification.

---

### M9 — GitLab's published ports bypass Cloudflare, and therefore fail2ban

**File:** `stacks/gitlab/docker-compose.yml`

```yaml
ports:
  - "${GITLAB_SSH_PORT}:22"
  - "${GITLAB_HTTP_PORT:-8080}:80"
  - "${GITLAB_REGISTRY_PORT:-5050}:5050"
```

Unlike NPM's admin UI (`127.0.0.1:81`) and Home Assistant (`127.0.0.1:8123`), these bind to all interfaces. Traffic reaching them never passes through Cloudflare, so **no edge ban applies** — the fail2ban deployment above cannot protect them. If the router forwards the SSH port, GitLab SSH is an unprotected brute-force target.

**Fix options:**
- Rebind 8080 and 5050 to `127.0.0.1` — both are already reachable through NPM, so nothing should depend on the host binding.
- For SSH, either accept the exposure, move it behind the tunnel / a VPN overlay (see P1), or run a second fail2ban with `network_mode: host` and `NET_ADMIN` for iptables bans — noting that this reintroduces the privilege the main deployment deliberately avoids.

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
