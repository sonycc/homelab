# Homelab Security Audit

**Date:** 2026-06-25  
**Branch:** feat/gitlab-runner  
**Scope:** All stacks under `stacks/` — compose files, env examples, scripts, nginx configs, prometheus config  
**Updated:** 2026-07-26 — added H2 for the new `pelican` stack  
**Updated:** 2026-07-27 — fail2ban deployed (L2); added M8–M15 and L9–L16 from the fail2ban and Home Assistant reviews  
**Updated:** 2026-07-31 — postgres backups repaired and a restore proven; added M16–M17 for what that left open

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


### L8 — Image freshness tracking ✓ resolved by WUD

The Diun recommendation is superseded: `stacks/wud/` deploys **What's Up Docker**, which watches the local socket on a cron and batches update notifications to Discord. It also filters HA's floating tags (`wud.tag.include` on the Home Assistant service) so only real version bumps are reported.

Still open from the original intent: images are pinned but nothing *acts* on a report, and the dashboard item in `TODO.md` (show current vs available version for every image) is unbuilt.

---

### M10 — Home Assistant's `.storage` is backed up nowhere

**File:** `stacks/homeassistant/config/.storage/`, `.gitignore`

Recorder history lives in postgres and is covered by `stacks/postgres/backup/backup.sh`. `.storage` is not — and that is where the irreplaceable state actually is: the user database and password hashes (`auth`), every issued refresh token and long-lived access token (`auth_provider.homeassistant`, `http.auth`), and the device, entity and area registries. It is correctly gitignored (it holds secrets) but nothing else copies it anywhere.

Losing the host means re-onboarding Home Assistant from zero: recreating users, re-pairing both companion apps, re-authenticating every integration, and re-issuing any long-lived token — including the one the Prometheus scrape job would use. The recorder data that *is* backed up would be orphaned, since the entity registry that gives it meaning would be gone.

**Fix:** the `backup` integration is already loaded (`default_config`). It needs a schedule and an off-box destination. Aligning it with the existing postgres backup target is the least new machinery.

---

### M11 — Home Assistant brute-force protection is off

**File:** `stacks/homeassistant/config/configuration.yaml`

The `http:` block sets `use_x_forwarded_for` and `trusted_proxies` — the hard part, and correct — but not `ip_ban_enabled` or `login_attempts_threshold`. So HA resolves real client IPs and then does nothing with them, on a login page reachable from the internet.

The new `homeassistant-auth` fail2ban jail reduces but does not close this. The two are complementary and fail differently: fail2ban blocks at Cloudflare's edge and depends on the API token, the container running, and the log being parsed correctly; HA's own ban list blocks inside the process and keeps working when any of that breaks. Given how many ways the fail2ban path was found to fail silently (see L2), the in-process backstop is worth having.

**Fix:** add `ip_ban_enabled: true` and `login_attempts_threshold: 5` to the `http:` block.

---

### M12 — fail2ban can read Home Assistant's auth store

**File:** `stacks/proxy/docker-compose.yml`

```yaml
- ../homeassistant/config:/var/log/ha:ro
```

The `homeassistant-auth` jail needs `home-assistant.log`, but bind-mounting the single file breaks the moment HA rotates it and the inode changes, so the whole config directory is mounted instead. That directory contains `.storage/auth`.

The result: a container whose entire job is parsing attacker-controlled log lines has read access to Home Assistant's user database and tokens. The mount is read-only and fail2ban holds no `NET_ADMIN`, so this is a confidentiality exposure reachable only through a parser escape, not a direct privilege path — but it is a wider grant than the job requires.

**Fix options:**
- Point HA's logger at a dedicated directory (`logger:` → a `logs/` subdirectory) and mount only that.
- Or run a sidecar that tails the log into a separate volume, and mount that instead.

Accepted deliberately for now; documented here so it is a decision rather than an oversight.

---

### M13 — A single false positive locks out every service at once

**File:** `stacks/proxy/fail2ban/jail.d/homelab.conf`

Cloudflare IP Access Rules are account-wide. A ban triggered by one jail on one hostname blocks that address from `gitlab`, `monitoring`, `ha`, `wud`, `registry` and `panel` simultaneously. This is not a misconfiguration — it is inherent to banning at the edge, which is the only place a ban is meaningful behind the tunnel (see L2).

The blast radius is why thresholds in `jail.d/homelab.conf` are deliberately loose, why `ignoreip` lists the Docker subnet first, and why `grafana-auth` ships disabled.

**Ways back in, in order of convenience** — worth knowing *before* they are needed:
1. LAN: NPM admin UI on `127.0.0.1:81`, Home Assistant on `127.0.0.1:8123` — unaffected by edge bans.
2. `docker exec fail2ban fail2ban-client unban <ip>`.
3. Cloudflare dashboard → Security → WAF → Tools → IP Access Rules → delete the rule.

Note that path 3 is the only one available from off-site, and it requires Cloudflare dashboard access — not the homelab.

---

### M14 — Ban failures are only visible in container logs

**Files:** `stacks/proxy/fail2ban/bin/cloudflare.sh`, `stacks/wud/docker-compose.yml`

The ban script inspects Cloudflare's response and writes `FAILED` with the API's own error text to stderr, which reaches `docker logs fail2ban`. Nothing reads that. The failure modes are all quiet:

- Token revoked, deleted, or its permission changed
- Cloudflare API contract changes (see L13, L14)
- The 50,000-rule account cap reached
- Network egress broken while the rest of the stack looks healthy

In every case fail2ban keeps running, keeps reporting jails as active, and keeps its own "Currently banned" counters climbing, while nothing is actually blocked. This exact failure occurred during deployment and was invisible until the Cloudflare rule list was queried directly.

**Fix:** `stacks/wud/` already holds a working `DISCORD_WEBHOOK_URL`. Wiring the script's failure path to the same webhook turns a silent months-long degradation into a message. Small change, and the highest-value follow-up on this list.

---

### M15 — No identity layer in front of publicly exposed services

**Files:** `stacks/proxy/docker-compose.yml`, Cloudflare Zero Trust configuration

`gitlab`, `monitoring`, `ha`, `wud`, `registry` and `panel` are all reachable from the public internet, each defended only by its own application login. The tunnel provides transport and hides the origin IP; it authenticates nobody.

Cloudflare Access (Zero Trust) can place an identity gate in front of a hostname before the request ever reaches nginx, and is free for small user counts. It composes well with the fail2ban deployment: Access rejects unauthenticated requests at the edge, so brute-force traffic never reaches a login page and never needs banning.

**Caveats worth weighing:** it complicates the Home Assistant companion app and any non-browser client (the GitLab runner, `git` over HTTPS, `docker login` to the registry), which need service tokens or a bypass policy. Applying it to `monitoring` and `wud` first — browser-only, low client complexity — captures most of the value with none of that friction.

---

### M16 — Postgres backups sit on the same disk as the data they protect

**Files:** `stacks/postgres/.env.example`, `stacks/postgres/docker-compose.yml`

`BACKUP_HOST_DIR` defaults to `./backup`, which puts the archives on `E:` alongside the Docker volumes they exist to protect. That covers the failure mode where postgres corrupts its own data or a bad migration drops a table. It does not cover the disk failing, the machine being lost, or ransomware — in all of which the backups die with the original.

The dumps are also the only copy of the role definitions and their password hashes, so losing them means rebuilding every service's database credentials by hand.

**Fix:** point `BACKUP_HOST_DIR` at a NAS or second physical drive. A pull-based copy from elsewhere is better still, since a host compromise then cannot reach the archive.

Postponed deliberately — the backups exist and restore correctly, which is the larger half of the problem. This is the remaining half.

---

### M17 — A failing backup is visible but not announced

**Files:** `stacks/postgres/docker-compose.yml`, `stacks/postgres/backup.sh`, `stacks/wud/docker-compose.yml`

`postgres-backup` now reports unhealthy when no backup has succeeded within `BACKUP_MAX_AGE_SECONDS`, and `backup.sh` writes its errors to stderr. Both only help someone who is looking. Nothing polls the healthcheck and nothing reads `docker logs`, so a backup path that stops working stays quiet exactly as long as nobody checks.

This is the same shape as M14, arrived at from a different service: a correct failure signal with no delivery mechanism. The failure modes are quiet ones — credentials rotated, the postgres host renamed, `BACKUP_HOST_DIR` unmounted, the disk full.

**Fix:** `stacks/wud/.env` already holds a working `DISCORD_WEBHOOK_URL`. Wiring `backup.sh`'s failure path and M14's ban-failure path to the same webhook is one small change covering both, and is worth doing once rather than twice.

---

### L9 — Home Assistant recorder records everything

**File:** `stacks/homeassistant/config/configuration.yaml`

`recorder:` sets `purge_keep_days: 30` with no `exclude:` filters. Harmless at the current six entities; it becomes a steadily growing postgres table once real devices exist, and it shares the instance with GitLab, Grafana and NPM.

Cheaper to add filters before the device count grows than to prune afterwards.

---

### L10 — The homelab's egress address rotates

Measured directly: `84.215.23.113` on 2026-07-26, `88.90.1.16` on 2026-07-27 — same path, same container, roughly 24 hours apart. Dynamic lease or ISP-side NAT pool.

Consequences, all already accounted for but worth recording:

- **Cloudflare API tokens must not use client-IP filtering.** This was tried and failed immediately with `code 10000 Authentication error`.
- **The WAN address cannot be pinned in `ignoreip`.** A stale entry would protect an address the household no longer holds while leaving the current one bannable. The git-protocol exclusions in `npm-auth` and `gitlab-auth` are the real hairpin protection.
- **Ban escalation buys less than it appears.** `bantime.maxtime = 7d` assumes an attacker keeps one address; on rotating consumer addressing, both sides move. Not worth retuning without real ban data, but do not read the 7-day figure as 7 days of protection.

---

### L11 — `grafana-auth` jail is unverified and disabled

**File:** `stacks/proxy/fail2ban/filter.d/grafana-auth.conf`

Its `datepattern` is now fixed and verified. Its `failregex` has never been matched against a real failed Grafana login — the expressions are written from Grafana's documented logfmt output, not a captured sample.

Second, unresolved concern: Grafana has no trusted-proxy setting equivalent to GitLab's (see M8). It derives `remote_addr` from `X-Real-IP` / `X-Forwarded-For`, which NPM does set, but this was never confirmed against a real line. If it logs `172.21.0.2`, enabling the jail would ban nginx — the M8 failure mode, at the edge.

**Before enabling:** one deliberate bad login, then `fail2ban-regex` (command in `stacks/proxy/fail2ban/README.md`), and confirm the captured address is the client's. `npm-auth` catches Grafana brute-force via its 401s meanwhile, so the jail is a refinement rather than a gap.

---

### L12 — Long-lived, account-wide Cloudflare API token

The fail2ban token has **no expiry**, deliberately: an expiring token fails silently and unattended (see M14), which is worse than a long-lived one whose capability is narrow. It also **cannot be scoped to a single zone** — `Account Firewall Access Rules Write` is account-scoped and has no zone-level equivalent.

Net capability if leaked: create and delete IP block rules across the account. It cannot read DNS, alter the tunnel, read traffic, or reach any other Cloudflare product. An attacker holding it could unban themselves, or ban arbitrary addresses — a denial-of-service against the household, not a data breach.

**Mitigations:** rotate periodically; revoke instantly from the dashboard if suspected. It lives only in `stacks/proxy/.env`, which is gitignored.

---

### L13 — IPv6 unban depends on Cloudflare's lookup normalisation

**File:** `stacks/proxy/fail2ban/bin/cloudflare.sh`

Cloudflare stores IPv6 expanded (`2001:0db8:0000:...:0001`) while fail2ban hands over the compressed form. Unban looks the rule up by `configuration.value` in compressed form and Cloudflare matches it — verified by round trip.

If that normalisation ever changes, the lookup returns nothing, the script treats it as "already gone" and exits 0, and the rule stays in Cloudflare **permanently**. Given how IPv6-heavy this homelab's traffic is, that would accumulate quietly until the 50,000-rule cap.

**Cheap detector:** if the Cloudflare rule count keeps climbing while `fail2ban-client status` shows few current bans, this is why.

---

### L14 — IP Access Rules is the older of two Cloudflare mechanisms

Cloudflare [recommends WAF custom rules](https://developers.cloudflare.com/waf/tools/ip-access-rules/) over IP Access Rules for new work. IP Access Rules are **not** deprecated, carry no announced sunset, and remain available on all plans at 50,000 rules — and they are the better fit here, because fail2ban needs to add and remove individual entries cheaply, which the rules API does and a ruleset expression does not.

Recorded so that a future deprecation notice is recognised as affecting this deployment rather than coming as a surprise.

---

### L15 — WUD mounts the Docker socket

**File:** `stacks/wud/docker-compose.yml`

```yaml
- /var/run/docker.sock:/var/run/docker.sock:ro
```

Read-only, so this is materially weaker than H1 and H2 — no container creation, no `exec`. But read access to the daemon still exposes every container's full configuration, including the **environment variables of every service on the host**: database passwords, the Grafana admin password, the GitLab runner token, the Cloudflare tokens.

WUD is publicly exposed at `wud.<domain>`, gated by GitLab OIDC. A pre-auth vulnerability in WUD would read every secret in the homelab.

**Fix:** `tecnativa/docker-socket-proxy` genuinely fits here, unlike H2 — WUD needs only `CONTAINERS` and `IMAGES` read endpoints, which is exactly what the proxy is designed to permit while blocking everything else.

---

### L16 — cadvisor runs with broad host access

**File:** `stacks/monitoring/docker-compose.yml`

`cadvisor` mounts `/`, `/var/run`, `/sys`, `/var/lib/docker` and `/dev/disk`, adds `SYS_PTRACE`, and takes `/dev/kmsg`. This is what cadvisor requires to do its job, and the mounts are read-only, so there is no clean fix — but it is a large host-visibility grant sitting on the same flat network as everything else (M7), and it is worth counting when reasoning about lateral movement.

**Consider:** whether per-container metrics are worth this surface, given `node-exporter` already covers host-level metrics at far lower privilege.

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
