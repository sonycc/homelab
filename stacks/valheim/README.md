# Valheim

Dedicated server on [`community-valheim-tools/valheim-server`](https://github.com/community-valheim-tools/valheim-server-docker), reached over WAN through a [playit.gg](https://playit.gg) tunnel.
The image wraps SteamCMD, so game patches are handled inside the container and do not need a new image.

It runs on a host this repo does not provision, deployed by `infra/ansible/games.yml` off `inventory.external.ini`.
WUD reads vm-core's local Docker socket, so it does not watch this image tag: bumping it is manual.

## Why a tunnel

Every other service here reaches the internet through cloudflared, which carries HTTP — and Valheim is UDP.
The alternative is a router port forward straight to the host, exposing the WAN address with no jail able to see the traffic.
playit moves the public endpoint to its edge and the agent dials out, so the router stays closed.

## Setup

| | |
|---|---|
| 1 | Generate an agent secret at [playit.gg](https://playit.gg/account/setup/wizard/new-account/docker/docker-name) |
| 2 | `PLAYIT_SECRET_KEY` and `SERVER_PASS` into `.env` |
| 3 | Deploy — first boot spends several minutes on the SteamCMD download before the healthcheck passes |
| 4 | In the playit dashboard, add a **UDP** tunnel to local `127.0.0.1:2456` |

The agent takes its tunnel definitions from the playit account, not from a config file, so step 4 needs no redeploy.

## Joining

The server is **not** in the browser list — `SERVER_PUBLIC=false`, because behind the tunnel it would advertise an address only reachable inside its own network namespace.
Players use **Join IP** with the public address from the playit dashboard, port included.

That port is assigned at random unless the account has a reserved one, and changes if the tunnel is recreated.
Worth pinning if people are saving it.

LAN players can skip the tunnel: set `VALHEIM_BIND` to the host's LAN address and connect to `<host>:2456`.

## Backups

Two layers, for two different failures.

| | On the game host | On the homelab |
|---|---|---|
| Covers | a bad save, a wiped world | the host being gone |
| Taken by | the image's own backup loop | `infra/ansible/roles/game_backup`, pulled nightly |
| Frequency | hourly, whether or not anyone is connected | daily, the newest archive |
| Kept | `BACKUPS_MAX_AGE` / `BACKUPS_MAX_COUNT` | `game_backup_keep` days |

The homelab pulls rather than being pushed to, so the game host holds no credential into this network and cannot reach or delete the copies (AUDIT M19).
Its key is pinned to a read-only `rrsync` of the backups directory, which is why the pull lists files with rsync rather than `ls`.
Each archive is verified to hold at least one world whose `.db2`, `.fwl2` and `.ok` share a generation, and a `MANIFEST` is written beside it with the restore procedure.

The pull needs `VALHEIM_BACKUP_DIR` bind-mounted: archives inside the named volume sit under `/var/lib/docker` and are unreadable without root.

vm-core generates its own keys — not copies of the estate key — and each is pinned in the far end's `authorized_keys`, so a compromise of vm-core is worth the pull and nothing else:

```
# game host, for the stack's own account
restrict,command="rrsync -ro /home/<user>/homelab/valheim/backups" ssh-ed25519 AAAA...

# bastion, forwarding only
restrict,permitopen="<game-host>:<port>" ssh-ed25519 AAAA...
```

`restrict` disables everything; `command=` allows only a read-only rsync of that one directory, and `permitopen=` only a forward to that one host and port. Neither grants a shell. `game_backup` refuses to deploy if either private key is missing.

The values come from `ssh -G <alias>` on the control node, which is where the connection is defined — not from this file.

### Restoring

Pick the cheapest source that covers the damage.

| Source | Where | Covers |
|---|---|---|
| `<world>_backup_auto-<stamp>/` | beside the live world in the volume | one bad save, minutes old |
| `worlds-<stamp>.zip` | `/config/backups` on the game host | `BACKUPS_MAX_AGE` days, hourly |
| `<stamp>/` with its `MANIFEST` | `/var/backups/games/valheim` on vm-core | `game_backup_keep` days; the only one left if the host is gone |

A world is a directory — `_main.<gen>.db2`, `_main.<gen>.fwl2`, `_main.<gen>.ok` and one file per chunk, all sharing `<gen>`.
Restore it whole; mixing generations corrupts it. No `.ok` means that save never finished — take an older one.

**1. Stop the server.** Never unpack over a running one.

```bash
ssh game-server "cd ~/homelab/valheim && docker compose stop valheim"
```

**2. List what is there.**

```bash
ssh game-server "docker exec valheim ls /config/backups"
```

**3. Unpack.** Paths inside the archive start at `config/`, so extract from `/`.
The archives live on the host, not in the volume, so mount that directory too — with only the volume mounted, `/config/backups` is the stale copy the bind mount shadows.

```bash
ssh game-server "docker run --rm -v valheim_valheim_config:/config -v ~/homelab/valheim/backups:/restore:ro -w / alpine unzip -o /restore/<archive>.zip"
```

**4. Start, and watch it load.**

```bash
ssh game-server "cd ~/homelab/valheim && docker compose up -d && docker logs -f valheim"
```

`Server config is … world: <name>` with no `Generating locations` means it came back.
A fresh map means `WORLD_NAME` matches no directory under `worlds_local`.

Restoring from vm-core instead: the `MANIFEST` beside each archive names the host it came from and carries this same procedure.

## Operational notes

| Symptom | Cause | Check |
|---|---|---|
| Healthy, but never updates, backs up or restarts | `PUID`/`PGID` is not 0, so busybox `crontab` refused the schedules and `valheim-bootstrap` exited 0 regardless | `docker exec valheim crontab -l` — three entries, or this regressed |
| Players get `incompatible version` | SteamCMD stuck on `state is 0x6`, serving the stale binary while logging that it is current | `docker logs valheim \| grep "Valheim version"` against the client's |
| Tunnel dead, server fine | `docker restart valheim` left playit in a namespace that no longer exists | `docker logs valheim-playit` — `tunnel_count=1` expected |
| World damaged after a crash | An OOM kill landed mid-save, which `stop_grace_period` cannot help with | Keep `VALHEIM_MEM_LIMIT` at 4g for an explored map |
| Fresh map after a restore or an `.env` edit | `WORLD_NAME` matches no directory under `worlds_local`, which generates rather than fails | `docker exec valheim ls /config/worlds_local` |
| Backup monitor green, nobody can join | Nothing watches the server itself | By hand — `STATUS_HTTP` serves `/status.json` only for browser-listed servers, which this is not |

A stuck update and a stuck download are the same fix: recreate the container.
`/opt/valheim` is not a volume, so `docker compose up -d --force-recreate` refetches the server clean, at ~2GB.

**Crossplay is a second WAN path, not a setting.**
`CROSSPLAY=true` routes players through Valheim's PlayFab relay, which needs neither the tunnel nor a port forward.
Running both is redundant rather than harmful, but then two things can break a join and only one is visible from here.
