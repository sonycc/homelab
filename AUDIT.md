# Homelab Security Audit

**Date:** 2026-06-25  
**Branch:** feat/gitlab-runner  
**Scope:** All stacks under `stacks/` — compose files, env examples, scripts, nginx configs, prometheus config  
**Updated:** 2026-07-27 — fail2ban deployed (L2); added M8–M15 and L9–L16 from the fail2ban and Home Assistant reviews  
**Updated:** 2026-07-31 — postgres backups repaired and a restore proven; added M16–M17 for what that left open  
**Updated:** 2026-08-06 — GitLab migrated to Proxmox; added M18, found while taking the migration backup  
**Updated:** 2026-09-22 — Valheim replaced pelican and moved off-estate; dropped H2 with the pelican stack, added M19  
**Updated:** 2026-09-24 — Valheim reached via a bastion rather than directly; M19 revised, backup credentials scoped  
**Updated:** 2026-09-24 — resolved findings moved out of Open Findings into their own section

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

### M18 — `gitlab-backup create` omits the database and reports success

**Files:** `stacks/gitlab/docker-compose.yml`, `stacks/postgres/docker-compose.yml`

GitLab's omnibus image bundles pg_dump 17.8; the shared postgres stack runs 18.4. pg_dump refuses to dump a server newer than itself, so the database phase fails — and the rake task carries on through repositories, uploads, artifacts and the registry, builds the archive, and ends with `Backup <id> is done.`

The result passes every check short of opening it:

- The archive is 12.5 GB and `tar tf` lists a full component set, including `db/database.sql.gz`.
- That member is **20 bytes** — the gzip header for an empty stream.
- `backup_information.yml` records `:skipped: ''`, because the database was not skipped. It failed. Nothing in the metadata distinguishes the two.
- The command's own closing line claims success.

So a size check passes, a listing passes, and the archive restores everything except the thing that gives it meaning. Discovered only because the error scrolled past during a migration; a `2026-08-05` backup taken the same way had already been recorded in the migration plan as verified, on the strength of exactly those checks.

This is not a one-off. It recurs on every `gitlab-backup create` until GitLab's bundled client catches up with the server, and it will return whenever postgres is upgraded ahead of GitLab again.

**Fix:** take the database separately with a client that matches the server — `pg_dump` from inside the postgres container — and restore in two parts: `pg_restore` the database, then `gitlab-backup restore SKIP=db` for everything else. Quiesce GitLab (`gitlab-ctl stop puma sidekiq`) across both so the two halves agree.

**Detector worth having:** any backup whose `db/database.sql.gz` is under a few hundred bytes is empty. That is a one-line check and the only cheap way to catch this class.

Same family as M14 and M17 — a correct-looking success from a process that did nothing — and the sharpest instance so far, because here the failure is sealed inside an artifact that looks right from the outside.

---

### M19 — The Valheim world lives on hardware outside this estate

**Files:** `stacks/valheim/`, `infra/ansible/games.yml`, `infra/ansible/roles/game_backup/`, `infra/ansible/inventory.external.ini`

The server moved off vm-core onto a machine this repo does not provision and nobody here administers. Three things sit on it now:

- **The world.** The world directory — `_main.<gen>.db2`, its `.fwl2` and every chunk — plus every hourly archive the image writes, in a Docker volume on someone else's disk.
- **A live playit.gg agent secret.** That secret *is* the tunnel, not merely a credential for it: whoever holds it can stand up an agent claiming the same public endpoint.
- **A Docker daemon** running a public image, on a host whose patch level, other workloads and physical access are all unknown.

It is also no longer reached directly. The game host sits on a private address behind a bastion that is likewise not ours, so the path now crosses two machines outside this estate, and vm-core holds a key to the first of them.

tofu cannot render that host into `inventory.ini`, because it did not create it, so it comes from a separate `inventory.external.ini` and is deliberately kept out of the `homelab` group. `common.yml` and `docker.yml` therefore never target it. That is correct — you should not push an sshd config onto a box you do not own — and it equally means none of this estate's hardening applies there.

**What keeps the exposure one-directional:**
- `games.yml` runs `become: false` with the stack under `$HOME`, so the deploy needs no root on that host and no sudo credential is held for it.
- vm-core's two keys are scoped, not copies of the estate key. The game-host key is pinned `restrict,command="rrsync -ro …"`, so it can read that one directory and run nothing; the bastion key is pinned `restrict,permitopen="…:22"`, so it forwards to the game host and gives no shell. A compromise of vm-core is worth the pull and nothing more.
- `game_backup` **pulls**. The game host is never given a key into this network and cannot reach, overwrite or delete what has already been copied. A push, including into a `mode: "0730"` drop-box on one of the VPSes, would not be equivalent: write permission on a directory permits unlink, and `rrsync -no-del` blocks `--delete` but not an SFTP remove, so no share-account mode available here is append-only.

**What remains open:**
- **The pull puts `homelab_infra` on vm-core.** That key opens root on every VPS container and the admin account on every VM, and until now it lived only on the control node. A compromise of vm-core previously did not reach the VPSes; with the key at `/root/.ssh/homelab_infra` it does. The game host's `authorized_keys` entry should be pinned — `restrict,command="rrsync -ro ..."` — but that only bounds what the key does *there*, not what it opens across the estate. A key issued for this one job would close it properly.
- The playit secret and `SERVER_PASS` are in a `.env` on that host, readable by anyone with root on it. `SERVER_PASS` is the only access control on the game itself. Rotating the playit secret means a new agent, and a new public address unless the account has a reserved one.
- A compromise of that host is not visible from here. The only signal is the nightly pull failing, which reports *unreachable*, not *owned*.
- The homelab copy is daily. The hourly archives are the intra-day layer and they die with the host, so up to a day of progress is lost in the case this entry is about.

**Fix:** none available while the host belongs to someone else. Recorded so the trade is deliberate rather than forgotten. If the server ever comes back in-estate, this entry and `inventory.external.ini` are removed together.

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

Read-only, so this is materially weaker than H1 — no container creation, no `exec`. But read access to the daemon still exposes every container's full configuration, including the **environment variables of every service on the host**: database passwords, the Grafana admin password, the GitLab runner token, the Cloudflare tokens.

WUD is publicly exposed at `wud.<domain>`, gated by GitLab OIDC. A pre-auth vulnerability in WUD would read every secret in the homelab.

**Fix:** `tecnativa/docker-socket-proxy` genuinely fits here, unlike H1 — WUD needs only `CONTAINERS` and `IMAGES` read endpoints, which is exactly what the proxy is designed to permit while blocking everything else.

---

### L16 — cadvisor runs with broad host access

**File:** `stacks/monitoring/docker-compose.yml`

`cadvisor` mounts `/`, `/var/run`, `/sys`, `/var/lib/docker` and `/dev/disk`, adds `SYS_PTRACE`, and takes `/dev/kmsg`. This is what cadvisor requires to do its job, and the mounts are read-only, so there is no clean fix — but it is a large host-visibility grant sitting on the same flat network as everything else (M7), and it is worth counting when reasoning about lateral movement.

**Consider:** whether per-container metrics are worth this surface, given `node-exporter` already covers host-level metrics at far lower privilege.

---

## Resolved

Kept for the reasoning, not the history. Anything still outstanding from one of these is an open finding above.

### L2 — fail2ban ✓ deployed and verified 2026-07-27

5 jails in `stacks/proxy/docker-compose.yml`, documented in `stacks/proxy/fail2ban/README.md`.

Bans apply as **Cloudflare IP Access Rules**, not iptables: behind the tunnel every packet reaches the kernel with cloudflared's address as its source, and the real client IP exists only in `CF-Connecting-IP`. That is also why the container needs **no `NET_ADMIN`** — a process parsing attacker-controlled log lines stays unprivileged.

The permission is account-scoped (`Account Firewall Access Rules Write`); it cannot be narrowed to one zone, which is what L12 is about.

Two defects survived every static check and were found only by a live round trip:

- **Timezone.** GitLab and Grafana log in UTC, the container runs Europe/Oslo. A `datepattern` without a timezone parsed entries 2h in the past, so `gitlab-auth` could never have banned anyone inside its `findtime`.
- **fail2ban truncates shell at a whitespace-preceded semicolon.** An inline `case … ;; … esac` reached `sh` cut short and every ban silently failed, while `fail2ban-client -t` still called the config valid. Logic lives in `fail2ban/bin/cloudflare.sh`; the action file must stay free of semicolons.

The lesson: for this component, config validation and `fail2ban-regex` prove nothing about whether a ban happens. Only the round trip does. The action now also inspects the response body, since Cloudflare returns HTTP 200 with `"success":false` for an expired token.

---

### M8 — GitLab logged the reverse proxy as the client ✓ fixed 2026-07-26

`gitlab_rails['trusted_proxies']` was unset, so every request recorded nginx's address. That degraded per-IP rate limiting, the abuse dashboard and audit events, and would have made `gitlab-auth` dangerous — five failed logins from anywhere would have banned nginx at the edge, taking the whole zone offline.

Fixed with `gitlab_rails['trusted_proxies'] = ['172.21.0.0/16']`. Grafana has no equivalent setting, which is why L11 ships disabled.

---

### L3 — `uptime` stack ✓ built

Kuma plus AutoKuma, with the monitors in `stacks/uptime/monitors/` as the source of truth. The original suggestion to host it off-estate is unaddressed: it still cannot report on an outage that takes vm-core with it.

---

### L8 — Image freshness ✓ resolved by WUD

`stacks/wud/` replaces the original Diun recommendation. Still open from the intent: images are pinned but nothing *acts* on a report, and the dashboard item in `TODO.md` is unbuilt. WUD also watches only vm-core's local socket, so the Valheim image tag (M19) is unwatched.

---

### P2 — GitLab container registry ✓ configured

Enabled in `GITLAB_OMNIBUS_CONFIG` with `registry_external_url` on port 5050. The NPM proxy host and the Cloudflare public hostname are UI-only and already applied; both are documented as comments in `stacks/proxy/docker-compose.yml`.

---

## Planned Improvements

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
