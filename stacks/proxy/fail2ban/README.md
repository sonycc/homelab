# fail2ban

Bans abusive clients across every public-facing service in the homelab.

## Why bans go to Cloudflare, not iptables

All public traffic arrives `cloudflared → nginx → service`. By the time a packet
reaches the host kernel its source address is the cloudflared container
(`172.21.0.14`); the real client address survives only in the `CF-Connecting-IP`
header, which `../nginx.conf` promotes to `$remote_addr` via `real_ip_header`.

A local firewall rule therefore has nothing useful to match on. Bans are written
as **Cloudflare IP Access Rules** instead, which blocks the client at the edge —
before the tunnel, and before it costs any bandwidth.

The consequence to keep in mind: **an edge ban applies to the whole zone.** One
false positive blocks `gitlab`, `monitoring`, `ha`, `wud` and `registry`
simultaneously. Ways back in:

- LAN: NPM admin UI on `127.0.0.1:81`, Home Assistant on `127.0.0.1:8123`
- Cloudflare dashboard → Security → WAF → Tools → IP Access Rules (delete the rule)
- `docker exec fail2ban fail2ban-client unban <ip>`

## Setup

1. Create a Cloudflare API token — Manage Account → API Tokens → Create Token:
   - Permissions: **Account → Firewall Access Rules → Edit**
   - Resources: Include → your account

   The documented permission for the IP Access Rules endpoint is
   [`Account Firewall Access Rules Write`](https://developers.cloudflare.com/api/resources/firewall/subresources/access_rules/methods/create/),
   which is **account-scoped**. There is no zone-scoped equivalent — no
   `Firewall Services` group exists — so this token cannot be narrowed to one
   zone, and the ban action uses the account-level endpoint to match. Account
   rules apply across every zone in the account, which for a single-domain
   homelab is the same practical effect.

   The token still cannot read DNS, touch the tunnel, or see traffic. It is a
   different token from `CLOUDFLARE_TUNNEL_TOKEN`.

2. Add to `../.env` (see `../.env.example`):

   ```
   CLOUDFLARE_API_TOKEN=...
   CLOUDFLARE_ACCOUNT_ID=...
   ```

   Both are required — the proxy stack refuses to start without them rather than
   silently running with a ban action that cannot ban.

   **Set no expiry and no client-IP filtering.** Both were measured to be
   actively harmful here: this homelab's egress address rotates (see the hairpin
   section below), so an IP-filtered token starts returning
   `code 10000 Authentication error` the moment the address changes. An expiring
   token fails the same way on its own schedule. In both cases the failure is
   only visible in `docker logs fail2ban` — the action checks Cloudflare's
   response and logs `FAILED` with the API's own error text, but nothing pages
   you about it.

3. The `gitlab` and `monitoring` stacks own log volumes mounted here, so bring
   them up first:

   ```bash
   docker compose -f ../../gitlab/docker-compose.yml up -d && docker compose -f ../../monitoring/docker-compose.yml up -d && docker compose -f ../docker-compose.yml up -d
   ```

## Jails

| Jail | Source | Enabled | Notes |
|---|---|---|---|
| `npm-auth` | NPM access logs | yes | 401/403 across all proxied hosts; catches Grafana and WUD implicitly |
| `npm-botsearch` | NPM access logs | yes | Scanner paths; verified against 4285 real log lines with zero false positives |
| `gitlab-auth` | `production_json.log`, `application_json.log` | yes | Requires `gitlab_rails['trusted_proxies']` — see below |
| `homeassistant-auth` | `home-assistant.log` | yes | Complements HA's own `ip_ban_enabled` |
| `grafana-auth` | `grafana.log` | **no** | Filter unverified against a real failure — see below |

## The two traps this config is built around

**1. Proxy addresses in application logs.** GitLab logged
`"remote_ip":"172.21.0.2"` — nginx — on every request, because
`gitlab_rails['trusted_proxies']` was unset. A jail keyed on that would have
banned the reverse proxy at the Cloudflare edge and taken the entire homelab
offline. The setting was added to `../../gitlab/docker-compose.yml`. Verify it
took effect before trusting the jail:

```bash
docker exec gitlab grep -c trusted_proxies /etc/gitlab/gitlab.rb
```

Then confirm a real client address appears in the logs:

```bash
docker exec gitlab tail -1 /var/log/gitlab/gitlab-rails/production_json.log
```

The same hazard is why `grafana-auth` ships disabled: Grafana has no
trusted-proxy setting and derives `remote_addr` from `X-Real-IP` /
`X-Forwarded-For`, which is untested here.

**2. The hairpin.** Internal clients reach the public hostnames through the
tunnel and come back in carrying the household's WAN address — the CI runner
already appears in NPM's logs as a public IP. A jail firing on that bans
everyone, not an attacker. Two defences are in place:

- `npm-auth` ignores git-protocol 401s (git *always* 401s on the first
  `/info/refs` before retrying with credentials — 66 such lines in the current
  logs)
- `gitlab-auth` ignores `/api/v4/jobs/request` and `/api/v4/runners/verify`

Adding the WAN address to `ignoreip` is **not** a usable third defence here — it
rotates. Measured: `84.215.23.113` on 2026-07-26, `88.90.1.16` on 2026-07-27. For
the same reason, do not enable client-IP filtering on the Cloudflare API token;
a rotation silently breaks every ban until someone reads `docker logs fail2ban`.

## Layout

```
action.d/cloudflare-api.conf   thin wrapper — no shell logic, see below
bin/cloudflare.sh              the actual ban/unban/verify logic
filter.d/                      log-line matchers
jail.d/homelab.conf            jails, thresholds, ignoreip
```

**Do not move the shell back into the action file.** fail2ban's config parser
treats a semicolon *preceded by whitespace* as an inline comment and strips the
rest of the line, so an inline
`case "<ip>" in *:*) target=ip6 ;; *) target=ip ;; esac` reaches `sh` as
`case "1.2.3.4" in *:*) target=ip6` — an unterminated case statement and a
guaranteed ban failure. `fail2ban-client -t` reports the configuration valid
anyway, because the truncation happens at parse time and nothing type-checks the
resulting shell. This cost a full ban/unban round trip to find.

The script is testable on its own:

```bash
docker exec fail2ban sh /data/bin/cloudflare.sh verify
```

## End-to-end ban test

Config tests and `fail2ban-regex` cannot prove the ban path works — only a real
round trip does. `192.0.2.1` (RFC 5737) and `2001:db8::1` (RFC 3849) are reserved
for documentation and routed to nobody, so banning them is harmless:

```bash
docker exec fail2ban fail2ban-client set npm-botsearch banip 2001:db8::1
```

Confirm the rule appears under Security → WAF → Tools → IP Access Rules with
target `ip6` (not `ip` — a family mismatch is rejected by Cloudflare), then:

```bash
docker exec fail2ban fail2ban-client set npm-botsearch unbanip 2001:db8::1
```

Cloudflare stores IPv6 in expanded form (`2001:0db8:0000:...:0001`) but matches
the compressed form on lookup, so the unban does find and delete it. Verified —
but re-check if that lookup ever changes, because a missed id would silently
leave the rule in place forever.

## Verifying a filter

Filters are matched against real log format, not guessed. Re-check after any
edit, or when enabling `grafana-auth`:

```bash
docker exec fail2ban fail2ban-regex /var/log/grafana/grafana.log /data/filter.d/grafana-auth.conf --print-all-matched
```

Useful runtime commands:

```bash
docker exec fail2ban fail2ban-client status
```

```bash
docker exec fail2ban fail2ban-client status npm-botsearch
```

## Known gap

GitLab publishes `${GITLAB_SSH_PORT}:22`, `8080:80` and `5050:5050` on
`0.0.0.0`, bypassing Cloudflare entirely. Traffic to those ports never reaches
an edge rule, so **no jail here protects them**. Closing that gap means either
rebinding those ports to `127.0.0.1` or running a second fail2ban with host
networking and `NET_ADMIN`. See the entry in `../../../AUDIT.md`.
