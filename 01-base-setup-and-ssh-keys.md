# 01 – Base Setup and SSH Keys

## Goal
Prepare the initial Ubuntu Server baseline for administration and repeatability:
- Update the system and install core utilities
- Confirm hostname and network visibility
- Enable fast, secure administration access using SSH keys

This phase is executed first on `srv-id-01`, then repeated on the other servers.

---

## Scope
Included:
- System update and baseline packages
- Hostname and IP verification
- SSH key generation on the admin workstation (macOS)
- SSH key installation on the server using `ssh-copy-id`

Not included:
- SSH hardening policies (handled in the SSH Hardening phase)
- Network segmentation changes (handled in the DMZ + LAN phase)

---

## Target Servers
Primary:
- `srv-id-01`

Then repeated on:
- `srv-edge-01`
- `srv-ops-01`
- (later) `srv-app-01`

---

## Admin Workstation
- macOS (SSH client)

---

## Commands

### 1) Base System Update (on srv-id-01)
Run as `ali-admin`:

```bash
sudo apt update && sudo apt upgrade -y
```

---

### 2) Install Baseline Tools (on srv-id-01)

```bash
sudo apt install -y curl wget vim git net-tools ca-certificates
```

---

### 3) Confirm Hostname and IP (on srv-id-01)

```bash
hostnamectl
ip a
```

Purpose:
- Confirm the machine identity (hostname)
- Confirm the assigned IP address before configuring remote access

---

## SSH Keys (Admin Workstation to Server)

### 4) Generate SSH Key (on macOS)

```bash
ssh-keygen -t ed25519
```

Notes:
- Generates `~/.ssh/id_ed25519` (private key) and `~/.ssh/id_ed25519.pub` (public key)
- This key is used to access all lab servers consistently

---

### 5) Copy Public Key to Server (on macOS)

After identifying the server IP from `ip a`:

```bash
ssh-copy-id ali-admin@<SERVER_IP>
```

---

### 6) Verify SSH Login (on macOS)

```bash
ssh ali-admin@<SERVER_IP>
```

Expected result:
- Login succeeds without password prompts
- Administrative access is now fast and repeatable

---

## Verification Checklist

### On srv-id-01:
- `apt upgrade` completed successfully
- Baseline packages installed
- Hostname is correct via `hostnamectl`
- IP address visible via `ip a`

### On macOS:
- SSH key exists at `~/.ssh/id_ed25519`
- Key copied successfully using `ssh-copy-id`
- SSH login works using `ssh ali-admin@<SERVER_IP>`

---

## Repeatability Notes

This phase is repeated on each additional server as soon as it is created:

- Apply the same base packages
- Confirm hostname and IP
- Enable key-based SSH access from the admin workstation

This creates a consistent administrative baseline for all future phases.

---

## Outputs

- Admin workstation has a persistent SSH key for the lab
- Each server is reachable via SSH using `ali-admin` without passwords
- Systems are ready for identity policies, SSH hardening, and network segmentation

