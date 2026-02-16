# 05 – Access Model (SSH ProxyJump via Bastion)

## Goal
Implement a realistic enterprise access model where:
- Internal servers are not directly reachable from the admin workstation
- Administrative access is centralized through a single bastion host
- No port forwarding is used to expose internal systems

This phase establishes secure access to LAN-only servers via `srv-edge-01`.

---

## Scope
Included:
- Bastion (jump host) pattern using `srv-edge-01`
- SSH ProxyJump configuration on the admin workstation (macOS)
- Permissions and testing for SSH client configuration
- Required SSH server setting to support ProxyJump routing

Not included:
- VPN access (introduced later as an optional advanced phase)
- Firewall policy changes (documented in firewall phases)

---

## Target Systems

Bastion host:
- `srv-edge-01` (WAN + LAN)

Internal servers (LAN-only):
- `srv-id-01`
- `srv-ops-01`
- `srv-app-01`

Admin workstation:
- macOS

---

## Background

After DMZ/LAN segmentation, internal servers have no WAN interface.
This is intentional.

As a result:
- Direct SSH from the admin workstation to internal servers is not possible
- Access must traverse the edge server

This reflects production environments where:
- Bastion hosts are the only externally reachable entry point
- Internal systems are isolated by default

---

## SSH ProxyJump Design

Access path:

```
Admin workstation (macOS)
  -> SSH to srv-edge-01 (bastion)
    -> SSH to internal servers (LAN)
```

This provides:
- Centralized access control
- Reduced attack surface
- A clean audit point for future enhancements

---

## Commands and Configuration

### 1) Create SSH Client Configuration (macOS)

```bash
mkdir -p ~/.ssh
vim ~/.ssh/config
```

Add the following content:

```text
Host edge
  HostName 192.168.64.9
  User ali-admin
  IdentityFile ~/.ssh/id_ed25519

Host srv-id-01
  HostName 10.10.10.10
  User ali-admin
  ProxyJump edge
  IdentityFile ~/.ssh/id_ed25519

Host srv-ops-01
  HostName 10.10.10.30
  User ali-admin
  ProxyJump edge
  IdentityFile ~/.ssh/id_ed25519

Host srv-app-01
  HostName 10.10.10.40
  User ali-admin
  ProxyJump edge
  IdentityFile ~/.ssh/id_ed25519
```

Notes:
- Replace `192.168.64.9` if the WAN IP of `srv-edge-01` differs
- Keep naming consistent for clean usage (`ssh srv-id-01`, etc.)

---

### 2) Fix SSH Client Config Permissions (macOS)

```bash
chmod 600 ~/.ssh/config
```

Purpose:
- Required by SSH for secure config handling

---

### 3) Required SSH Server Setting on Bastion Host

Edit on `srv-edge-01`:

```bash
sudo vim /etc/ssh/sshd_config
```

Set:

```text
AllowTcpForwarding yes
```

Validate and restart SSH:

```bash
sudo sshd -t
sudo systemctl restart ssh
```

Important:
- Earlier SSH hardening disabled forwarding by default
- This phase re-enables it on the bastion host because it is required for ProxyJump

---

## Verification

### 1) Validate Bastion Access (macOS)

```bash
ssh edge
```

Expected:
- SSH login succeeds using keys

Exit:

```bash
exit
```

---

### 2) Validate Internal Access via ProxyJump (macOS)

```bash
ssh srv-id-01
```

Expected:
- SSH login succeeds without direct WAN access to the internal server

Repeat:

```bash
ssh srv-ops-01
ssh srv-app-01
```

Expected:
- All internal servers are reachable only through the bastion host

---

## Operational Notes

- Port forwarding is not used for exposing services
- VPN is introduced later as the enterprise-friendly option for browser-based access and internal web tools
- The bastion pattern is intentionally simple, secure, and realistic

---

## Outputs

- Secure and centralized administrative access through `srv-edge-01`
- Internal servers remain unreachable directly from WAN
- A production-style bastion host model using SSH ProxyJump
