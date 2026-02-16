# 02 – Identity and Access (Users, Groups, Sudo)

## Goal
Establish a clear and consistent identity and access model across all servers:
- Create users and groups with real roles
- Apply least-privilege sudo policies
- Ensure identical identity structure on every server

This phase makes access control explicit and realistic before introducing
centralized identity solutions.

---

## Scope
Included:
- Local users and groups
- Group-based access model
- Limited sudo policies
- Verification of effective permissions

Not included:
- Central identity services (LDAP / FreeIPA)
- SSH hardening options (handled in the SSH Hardening phase)

---

## Target Servers
Applied identically on:
- `srv-id-01`
- `srv-edge-01`
- `srv-ops-01`
- `srv-app-01`

Each server is treated as an independent system.

---

## Identity Model

### Users
- `ali-admin`  
  Full administrative user (already present)

- `it-user`  
  Technical operations user with limited sudo access

- `acc-user`  
  Accounting role user

- `sup-user`  
  Support role user

---

### Groups
- `it`  
  Technical users

- `accounting`  
  Accounting department

- `support`  
  Support department

- `sudo-limited`  
  Group with restricted sudo permissions

---

## Commands

### 1) Create Groups
Run as `ali-admin`:

```bash
sudo groupadd it
sudo groupadd accounting
sudo groupadd support
sudo groupadd sudo-limited
```

Verify:

```bash
getent group it accounting support sudo-limited
```

---

### 2) Create Users

```bash
sudo adduser it-user
sudo adduser acc-user
sudo adduser sup-user
```

---

### 3) Assign Group Memberships

```bash
sudo usermod -aG it it-user
sudo usermod -aG sudo-limited it-user

sudo usermod -aG accounting acc-user
sudo usermod -aG support sup-user
```

Verify:

```bash
id it-user
id acc-user
id sup-user
```

---

### 4) Configure Limited Sudo Policy

Create a dedicated sudoers file:

```bash
sudo visudo -f /etc/sudoers.d/sudo-limited
```

Add the following content:

```text
%sudo-limited ALL=(ALL) NOPASSWD: \
/bin/systemctl status *, \
/bin/systemctl restart *, \
/bin/systemctl reload *, \
/bin/systemctl daemon-reexec, \
/bin/journalctl, \
/usr/bin/less, \
/bin/cat
```

Purpose:
- Allow service inspection and control
- Prevent privilege escalation
- Enforce least-privilege administration

---

## Verification

### Test Limited Sudo Access

Switch to the IT user:

```bash
su - it-user
```

Allowed command:

```bash
sudo systemctl status ssh
```

Expected:
- Command succeeds

Disallowed command:

```bash
sudo useradd testuser
```

Expected:
- Permission denied

Exit:

```bash
exit
```

---

### Verify Admin Context

```bash
sudo whoami
```

Expected output:

```text
root
```

---

## Design Rationale

### Why Identity Is Local on Each Server

Each Linux server maintains its own:
- `/etc/passwd`
- `/etc/group`
- `/etc/sudoers`

Even with identical usernames, servers are not linked by default.
This provides:
- Isolation
- Reduced blast radius
- Clear failure boundaries

This reflects real-world environments where:
- Central identity may not exist
- Or is intentionally limited in scope

---

### Why Central Identity Is Not Introduced Yet

Central identity is a solution, not a starting point.

Implementing local identity first ensures:
- Understanding of access mechanics
- Visibility into security implications
- Safe recovery options if central services fail

Central identity can later be added as an architectural enhancement.

---

## Outputs

- Consistent users and groups across all servers
- Clear role separation
- Enforced least-privilege sudo access
- A stable foundation for SSH hardening and security policies
