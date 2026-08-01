# Proxmox user/role/token for OpenTofu

One-time setup in the Proxmox web UI (`https://<host>:8006`). Doc, not automation —
Proxmox has no unauthenticated bootstrap path, so this has to be done by hand once
before OpenTofu can authenticate at all.

## 1. Role

**Datacenter → Permissions → Roles → Add**

- Name: `TofuProvisioner`
- Privileges (Proxmox has no wildcards like `VM.Config.*` — each is ticked individually;
  see [User Management](https://pve.proxmox.com/wiki/User_Management) for the full list if this ever needs extending):
  - `VM.Allocate` — create/remove a VM. Needed to bring vm-core/vm-ci into existence (cloning still allocates a new VM ID).
  - `VM.Clone` — clone a VM. vm-core and vm-ci are both created by cloning template 9000, not built from scratch.
  - `VM.Config.CDROM` — change the CD-ROM/ide device. The cloud-init drive attaches as an ide2 device, which falls under this.
  - `VM.Config.CPU` — set core count/type. Needed to size each VM (4 vs 2 vCPU).
  - `VM.Config.Cloudinit` — set cloud-init parameters. Needed to inject the SSH key and static vmbr1 address at clone time.
  - `VM.Config.Disk` — resize/attach disks. Needed to set each VM's disk size on clone (250GB / 150GB).
  - `VM.Config.Memory` — set RAM. Needed to size each VM (10GB vs 4GB).
  - `VM.Config.Network` — add/modify network devices. Needed for the dual-NIC setup (vmbr0 + vmbr1) on both VMs.
  - `VM.Config.Options` — everything else in a VM's config (name, boot order, agent flag, etc.) that doesn't fall under a more specific `VM.Config.*` privilege above.
  - `VM.Audit` — read VM config. Needed for `plan`/`refresh` to see current state, not just write new state.
  - `VM.GuestAgent.Audit` — reads QEMU guest-agent state (e.g. the VM's IP once cloud-init assigns one). Not `VM.Monitor` — that privilege doesn't exist.
  - `VM.PowerMgmt` — start/stop/reset. A cloned VM is created powered off; this is what actually boots it.
  - `VM.Console` — console/VNC access. Included from the original privilege list, but honestly: nothing OpenTofu does for cloning/configuring/powering a VM opens a console. Left in rather than silently dropped, but it's a candidate to remove if you want the role tighter — flagging rather than asserting a need I can't back up.
  - `Datastore.AllocateSpace` — use space on a datastore. Needed every time a disk is sized on `local-lvm`.
  - `Datastore.Audit` — read datastore status. Needed to validate `local-lvm` has room before allocating.
  - `Datastore.Allocate` — create/modify/remove a datastore. Not needed just to *use* `local-lvm` for VM disks (that's `Datastore.AllocateSpace` above) — needed specifically to read or manage the storage pool's own definition, e.g. `proxmox_storage_lvmthin` in Terraform. Found the hard way: importing that resource with only `AllocateSpace`/`Audit` granted fails with a 403 on `/storage/local-lvm`.
  - `Sys.Audit` — read node status/config. Needed for the provider to resolve and validate `node_name`.
  - `SDN.Use` — attach to vnets/local bridges. Needed to attach network devices to `vmbr0` and `vmbr1`.

## 2. User

**Datacenter → Permissions → Users → Add**

- User name: `terraform`
- Realm: **Proxmox VE authentication server** (`pve`). not PAM, this isn't a real system login
- Password: leave blank, only the API token below will be used

## 3. Grant the role

**Datacenter → Permissions → Add → User Permission**

- Path: `/`
- User: `terraform@pve`
- Role: `TofuProvisioner`

## 4. API token

**Datacenter → Permissions → API Tokens → Add**

- User: `terraform@pve`
- Token ID: `tofu`
- **Privilege Separation: uncheck this.** It defaults to checked (Proxmox's own default for new tokens), which means the token's effective permissions are the *intersection* of the user's ACLs and the token's own — with no ACL granted to the token itself, that intersection is empty regardless of what the user can do. This is the single most common first failure with this provider.
- Add, and copy the secret shown — Proxmox displays it exactly once, at creation.

## Wiring it into Terraform

Proxmox shows the token as two pieces:

- **Token ID**: `terraform@pve!tofu`
- **Secret**: a UUID, shown once

`infra/tofu/providers.tf` takes these as two separate variables (`proxmox_token_id`, `proxmox_token_secret`) rather than one combined string, matching how the UI presents them, and joins them back into the `user@realm!tokenid=secret` form the provider actually expects via a `locals` block. Put the real values in `terraform.tfvars` (gitignored) — see `terraform.tfvars.example` for the shape.
