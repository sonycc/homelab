# Uptime Kuma + AutoKuma

`monitors/` is the source of truth.
One `.toml` or `.json` per monitor; **the filename minus its extension is the AutoKuma ID**, so renaming a file orphans the old monitor and creates a new one.

```toml
type = "http"
name = "GitLab"
url = "https://gitlab.example.com"
interval = 60
max_retries = 3
```

## Monitors

| ID | Type | Target |
|---|---|---|
| `gitlab` | http | `https://gitlab.<domain>` |
| `monitoring` | http | `https://monitoring.<domain>` |
| `registry` | http | `https://registry.<domain>` |
| `ha` | http | `https://ha.<domain>` |
| `wud` | http | `https://wud.<domain>` |
| `proxmox` | ping | `10.0.1.2` |
| `vm-core` | ping | `10.0.1.20` |
| `vm-ci` | ping | `10.0.1.30` |
| `postgres` | port | `postgres:5432` |
| `old-host` | ping | old host LAN address |
| `postgres-backup` | push | called from `stacks/postgres/backup.sh` (AUDIT M17) |

The http monitors survive a tunnel flip untouched.
The ping monitors are what needs revisiting at decommissioning.

## Setup

| | |
|---|---|
| Bootstrap | Kuma's admin account must exist before AutoKuma can log in. Deploy → wizard at `http://10.0.1.20:3001` → credentials into `.env` → redeploy. Auth failures on first run are expected. |
| Domain | `.j2` rendered by Ansible from `homelab_domain` in `group_vars/all.yml`, which is gitignored. AutoKuma only ever sees a finished file. |
| `stack_templates` | every file in `monitors/` is a template and must be listed there, not in `stack_paths` |
| Push monitor | create it here first to get its URL, then add the `curl` to `backup.sh` |
