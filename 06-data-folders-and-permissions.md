# 06 – Data Folders and Permissions

## Goal
Introduce a realistic data and permission model that:
- Separates data by department
- Enforces ownership and access boundaries
- Demonstrates correct Linux permission semantics
- Prepares the environment for services and real workloads

This phase focuses on filesystem design rather than services.

---

## Scope
Included:
- Creation of shared data directories
- Group-based ownership
- Permission modeling using standard UNIX permissions
- Validation of access behavior

Not included:
- Application-specific data layouts
- Backup configuration (handled later)
- Centralized storage (handled in the storage phase)

---

## Target Servers
Applied on:
- `srv-id-01` (initial modeling and validation)

The same model can later be replicated where needed.

---

## Design Context

In real environments, data does not live randomly.
It is:
- Owned by a department
- Accessed by specific roles
- Protected from other users by default

This phase introduces that concept explicitly.

---

## Directory Structure

Planned structure under `/data`:

```
/data
├── accounting
├── it
└── support
```

Each directory:
- Belongs to its department group
- Is not accessible by unrelated users
- Can be safely extended later by services

---

## Commands

### 1) Create Base Data Directory

```bash
sudo mkdir /data
```

---

### 2) Create Department Directories

```bash
sudo mkdir /data/accounting
sudo mkdir /data/it
sudo mkdir /data/support
```

---

### 3) Set Ownership

```bash
sudo chown root:accounting /data/accounting
sudo chown root:it /data/it
sudo chown root:support /data/support
```

Rationale:
- `root` retains ultimate control
- Groups define access boundaries

---

### 4) Set Permissions

```bash
sudo chmod 2770 /data/accounting
sudo chmod 2770 /data/it
sudo chmod 2770 /data/support
```

Explanation:
- `2` (setgid): new files inherit the group
- `7` (owner): full access for root
- `7` (group): full access for department members
- `0` (others): no access

---

## Verification

### Test Accounting Access

```bash
su - acc-user
```

Allowed:

```bash
cd /data/accounting
touch report.txt
ls -l
```

Expected:
- File creation succeeds
- Group ownership is `accounting`

Denied:

```bash
cd /data/it
```

Expected:
- Permission denied

---

### Test IT Access

```bash
su - it-user
cd /data/it
touch notes.txt
ls -l
exit
```

Expected:
- Files belong to group `it`
- Access is limited to the IT directory

---

## Design Notes

- Write permission does not imply read permission elsewhere
- Directory permissions control access more strictly than file permissions
- setgid ensures consistent group ownership in shared directories

This phase reinforces correct Linux permission mental models.

---

## Outputs

- Clear department-based data separation
- Correct ownership and permission behavior
- A safe foundation for services and shared data
