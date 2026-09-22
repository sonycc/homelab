# Valheim

Dedicated server on [`community-valheim-tools/valheim-server`](https://github.com/community-valheim-tools/valheim-server-docker), reached over WAN through a [playit.gg](https://playit.gg) tunnel.

The image is the maintained continuation of `lloesche/valheim-server-docker`, which its author handed over.
It wraps SteamCMD, so game patches are handled inside the container and do not need a new image.

It runs on a host this repo does not provision, deployed by `infra/ansible/games.yml` off `inventory.external.ini`.
WUD reads vm-core's local Docker socket, so it does not watch this image tag: bumping it is manual.

## Why a tunnel

Every other service here reaches the internet through cloudflared, which means no inbound ports and fail2ban banning at the Cloudflare edge.
Valheim cannot use that path: Cloudflare Tunnel carries HTTP, and Valheim is UDP.

The alternative is a router port forward straight to the host, which exposes the WAN address on those ports with no jail able to see the traffic.
playit moves the public endpoint to its edge instead, and the agent dials out — so the router stays closed.

## Setup

| | |
|---|---|
| 1 | Generate an agent secret at [playit.gg/account/setup/wizard/new-account/docker/docker-name](https://playit.gg/account/setup/wizard/new-account/docker/docker-name) |
| 2 | `PLAYIT_SECRET_KEY` and `SERVER_PASS` into `.env` |
| 3 | Deploy — first boot spends several minutes on the SteamCMD download before the healthcheck passes |
| 4 | In the playit dashboard, add a **UDP** tunnel to local `127.0.0.1:2456` and note the public address it returns |

The agent takes its tunnel definitions from the playit account, not from a config file, so step 4 needs no redeploy.

## Joining

The server is **not** in the browser list — `SERVER_PUBLIC=false`, because behind the tunnel it would advertise an address only reachable inside its own network namespace.

Players use **Join IP** with the public address from the playit dashboard, including the port:

```
foo-bar.gl.joinmc.link:41234
```

playit assigns that port at random unless the account has a reserved one, and it can change if the tunnel is recreated.
Worth pinning if people are saving it.

If a direct join fails at the handshake, add a second UDP tunnel for `127.0.0.1:2457` — some clients probe the query port before connecting.

LAN players can skip the tunnel entirely: set `VALHEIM_BIND` to the host's LAN address and connect to `<host>:2456`.

## Backups

The image's own, running under the same supervisord that starts the server, writing to `/config/backups` beside the worlds.

| | |
|---|---|
| Schedule | hourly, whether or not anyone is connected |
| Retention | `BACKUPS_MAX_AGE` days or `BACKUPS_MAX_COUNT` archives, whichever trips first |
| Contents | the `.db` and `.fwl` pair zipped together |

Both files must be restored from the **same** archive.
A `.db` from one timestamp with a `.fwl` from another corrupts the world, which is the reason they are archived as a pair rather than swept individually.

Valheim also keeps `World.db.old` — the last save before the current one — inside `/config/worlds_local`.
That covers a single bad save without touching the archives.

To restore:

```bash
docker compose stop valheim
docker run --rm -v valheim_valheim_config:/config -w /config/worlds_local alpine \
  unzip -o /config/backups/<archive>.zip
docker compose start valheim
```

Never unpack over a running server.

## Operational notes

**`PUID`/`PGID` must stay 0.**
The update, backup and restart schedules are crontab entries that `kill -HUP` the updater and backup loops, installed by `valheim-bootstrap` with busybox `crontab`.
That refuses to run as non-root — `crontab: must be suid to work properly` — then exits 0.
The result is a container that reports healthy while never updating, never backing up and never restarting.
`docker exec valheim crontab -l` should list three entries; an empty list means this regressed.

**`docker restart valheim` breaks the tunnel.**
The playit container uses `network_mode: service:valheim` and lives in the server's network namespace.
Restarting the server container alone leaves the agent attached to a namespace that no longer exists.
Use `docker compose up -d` or `docker compose restart`, which recreate both.

**Memory is the real constraint.**
4g is right for an explored map; 2g carries a fresh world with a few players.
An OOM kill lands mid-save, which is exactly the corruption case `stop_grace_period: 2m` exists to prevent — so trimming `VALHEIM_MEM_LIMIT` to fit a crowded host trades a working server for a damaged world.

**Crossplay is a second WAN path, not a setting.**
`CROSSPLAY=true` routes players through Valheim's PlayFab relay, which does its own NAT traversal and needs neither the tunnel nor a port forward — players join by a code instead of an address.
It is the simpler route if it works for your group.
Running both is redundant rather than harmful, but then two things can break a join and only one of them is visible from here.

**No Uptime Kuma monitor.**
`STATUS_HTTP` serves `/status.json` only for servers listed in the browser, which this one is not.
A push monitor driven from a container healthcheck is the way in, if it is wanted later.
