# Only what genuinely differs between instances is a variable. Node, datastore,
# subnets and the firewall shape are hardcoded in main.tf — they are facts about
# this homelab, not configuration, and a second VPS must not be able to get a laxer
# rule set than the first.

variable "name" {
  description = "Hostname, e.g. vps-nawth. Becomes the Ansible group with hyphens swapped for underscores."
  type        = string
}

variable "vm_id" {
  description = "Proxmox VMID. Convention here: 1xx VMs, 2xx VPSes."
  type        = number
}

variable "octet" {
  description = "Last octet, used on both bridges. VPSes live in 10.0.1.14x; see vps.tf."
  type        = number
}

variable "template_file_id" {
  description = "vztmpl file id, shared across instances so they cannot drift onto different base images."
  type        = string
}

variable "ssh_public_key" {
  description = "Admin key placed on root — see the user_account block in main.tf."
  type        = string
}

variable "data_size" {
  description = "Data volume size, and the quota. Growable online with `pct resize`; Proxmox will not shrink it, so treat it as a floor."
  type        = string
  default     = "20G"
}

variable "data_path" {
  description = "Where the data volume mounts inside the container."
  type        = string
  default     = "/srv/data"
}

# cores and memory are cgroup limits, not reservations: nothing is set aside and an
# idle container costs the host nothing. They bound a guest workload rather than buy
# it capacity.

variable "cores" {
  description = "Caps concurrent CPUs. Does not pin or reserve one. sshd and one transfer need one."
  type        = number
  default     = 1
}

# rsync's memory scales with the file count in a tree, not its size, and it is the
# reason for this ceiling — sftp-server holds one file at a time and never approaches
# it. A large tree mid-sync is the realistic way to reach the cap, and the symptom —
# an OOM kill partway through a transfer — reads as a network fault. Headroom is free
# unused.
variable "memory" {
  description = "MB ceiling. Exceeding it OOM-kills inside the container rather than pressuring the host."
  type        = number
  default     = 1024
}

# Proxmox default is 100. Lower means the homelab's own services win when the CPU is
# scarce, which is the right priority for a box belonging to someone else.
variable "cpu_units" {
  description = "cpuunits weight. Irrelevant when nothing competes."
  type        = number
  default     = 50
}
