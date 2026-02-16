# 03 – SSH Hardening

## Goal
Harden SSH access across all servers to:
- Eliminate password-based authentication
- Prevent direct root login
- Reduce the SSH attack surface
- Enforce consistent, enterprise-grade SSH policies

This phase builds on the existing SSH key access established earlier.

---

## Scope
Included:
- SSH configuration backup
- Key-only authentication
- Root login disabled
- Reduced SSH features and tighter limits
- Validation before applying changes

Not included:
- Network-level access restrictions (handled by firewalls)
- Bastion / ProxyJump configuration (handled in the Access phase)

---

## Target Servers
Applied identically on:
- `srv-id-01`
- `srv-edge-01`
- `srv-ops-01`
- `srv-app-01`

---

## Pre-Checks
Before applying changes:
- SSH access using keys must already work
- `ali-admin` must be able to log in remotely
- Changes are applied while an active SSH session is open

---

## Commands

### 1) Backup Current SSH Configuration
Run as `ali-admin`:

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
```

Purpose:
- Ensure immediate rollback is possible if needed

---

### 2) Edit SSH Configuration

Open the configuration file:

```bash
sudo vim /etc/ssh/sshd_config
```

Apply the following settings:

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
AuthenticationMethods publickey
PubkeyAuthentication yes
UsePAM yes

X11Forwarding no
AllowTcpForwarding no
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
```

---

## Configuration Rationale

- `PermitRootLogin no`  
  Prevents direct root access

- `PasswordAuthentication no`  
  Eliminates password-based brute-force attacks

- `AuthenticationMethods publickey`  
  Enforces key-only authentication

- `UsePAM yes`  
  Keeps account, session, and policy handling consistent

- `X11Forwarding no` and `AllowTcpForwarding no`  
  Reduces unused SSH features and attack surface

- Connection limits  
  Reduce the impact of failed or abusive login attempts

---

### 3) Validate Configuration

Before restarting SSH:

```bash
sudo sshd -t
```

Expected result:
- No output (syntax is valid)

---

### 4) Restart SSH Service

```bash
sudo systemctl restart ssh
```

---

## Verification

### Remote Login Test

From the admin workstation (macOS):

```bash
ssh ali-admin@<SERVER>
```

Expected:
- Login succeeds using SSH keys
- No password prompt appears

---

### Root Login Test

```bash
ssh root@<SERVER>
```

Expected:
- Connection refused or denied

---

### Password Authentication Test

Attempt to force password login:

```bash
ssh -o PreferredAuthentications=password ali-admin@<SERVER>
```

Expected:
- Authentication fails

---

## Design Notes

- SSH is hardened before network segmentation to reduce risk early
- Feature restrictions are applied consistently across all servers
- More permissive SSH behavior (such as TCP forwarding) is intentionally disabled
  and only re-enabled later where explicitly required

---

## Outputs

- SSH access restricted to key-based authentication
- Root login disabled
- Reduced attack surface on all servers
- Stable and secure baseline for network and access model changes
