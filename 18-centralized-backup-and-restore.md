
# 18 – Backup and Restore (srv-ops-01)

## Goal

Introduce a practical backup and restore strategy for the Enterprise Linux Lab using the dedicated LVM storage on `srv-ops-01`.

This phase turns the backup storage prepared in the previous storage phase into an operational backup system.

This phase enables:

- Reliable data protection
- Centralized backup operations
- Automated backup execution
- File-level restore testing
- Snapshot-style backup history
- A foundation for disaster recovery practices

---

## Design Context

In the previous phase, dedicated backup storage was created on `srv-ops-01` using LVM.

The backup volume is mounted at:

```text
/srv/backups
```

At that point, the environment had dedicated storage, but no backup process yet.

This phase adds the missing operational layer:

```text
Dedicated storage
    ↓
Backup process
    ↓
Scheduled execution
    ↓
Snapshot-style backup history
    ↓
Restore validation
```

The goal is not only to create backup copies, but to prove that data can be restored when needed.

---

## Architecture Overview

`srv-ops-01` acts as the centralized backup node.

The important design point is that `srv-ops-01` runs the backup process.

It connects to each protected system over SSH, pulls selected directories using `rsync`, and stores the backup data locally under `/srv/backups`.

Protected systems:

```text
srv-id-01
srv-app-01
srv-edge-01
```

Backup direction:

```text
srv-ops-01  ---> connects to --->  srv-id-01
srv-ops-01  ---> connects to --->  srv-app-01
srv-ops-01  ---> connects to --->  srv-edge-01
```

The data is then stored locally on `srv-ops-01`:

```text
/srv/backups
```

---

## Backup Flow

### srv-id-01

```text
1. srv-ops-01 connects to srv-id-01 over SSH
2. srv-ops-01 pulls /etc, /home, /srv using rsync
3. srv-ops-01 stores the data under /srv/backups/srv-id-01/<DATE>
```

### srv-app-01

```text
4. srv-ops-01 connects to srv-app-01 over SSH
5. srv-ops-01 pulls /etc, /home, /srv using rsync
6. srv-ops-01 stores the data under /srv/backups/srv-app-01/<DATE>
```

### srv-edge-01

```text
7. srv-ops-01 connects to srv-edge-01 over SSH
8. srv-ops-01 pulls /etc, /home, /srv using rsync
9. srv-ops-01 stores the data under /srv/backups/srv-edge-01/<DATE>
```

---

## Centralized Backup Architecture

```text
                         pulls via SSH + rsync

┌────────────────────┐  <-------------------  ┌────────────────────┐
│ srv-id-01           │                       │                    │
│ Identity Server     │                       │                    │
│ /etc /home /srv     │                       │                    │
└────────────────────┘                       │                    │
                                             │                    │
┌────────────────────┐  <-------------------  │ srv-ops-01          │
│ srv-app-01          │   pulls via SSH+rsync │ Backup Node         │
│ Application Server  │                       │ /srv/backups        │
│ /etc /home /srv     │                       │                    │
└────────────────────┘                       │                    │
                                             │                    │
┌────────────────────┐  <-------------------  │                    │
│ srv-edge-01         │   pulls via SSH+rsync │                    │
│ Gateway / Bastion   │                       │                    │
│ /etc /home /srv     │                       └────────────────────┘
└────────────────────┘
```

The arrows point from the protected systems toward `srv-ops-01` because the data ends up on the backup node.

Operationally, however, the connection is initiated by `srv-ops-01`.

So the model is:

```text
srv-ops-01 connects outward
rsync pulls data back
/srv/backups stores the result
```

---

## Scope

Included:

- Using `/srv/backups` as the central backup location
- Documenting the initial local backup validation before centralized backups
- Pulling backups from remote servers using SSH and rsync
- Backing up selected system and service directories
- Creating date-based snapshot directories
- Maintaining a `current` symlink to the latest successful backup
- Using `--link-dest` for efficient snapshot-style backups
- Logging backup execution to `/var/log/backup.log`
- Running manual backup tests
- Scheduling backups with cron
- Performing file-level restore testing

Not included:

- SAN / iSCSI storage
- Cloud backup
- Encrypted offsite backup
- Full system image backup
- Database-aware backup
- High availability
- Ansible automation
- Enterprise backup products

These can be added later as controlled extensions.

---

## Backup Target

All backups are stored on:

```text
/srv/backups
```

This directory is backed by the LVM volume created on `srv-ops-01`.

Benefits:

- Backup data is separated from the operating system disk
- Storage can be expanded later using LVM
- Backup operations are centralized
- Restore testing can be performed from one location

Recommended permissions:

```bash
sudo chown root:root /srv/backups
sudo chmod 750 /srv/backups
```

For stricter access:

```bash
sudo chmod 700 /srv/backups
```

---

## Protected Systems

The initial protected systems are:

```text
srv-id-01
srv-app-01
srv-edge-01
```

Each system represents an important infrastructure role:

| Server | Role | Reason for Backup |
|---|---|---|
| `srv-id-01` | Identity server | Users, groups, sudo-related configuration |
| `srv-app-01` | Application server | Nginx service, web content, service configuration |
| `srv-edge-01` | Gateway / Bastion | Network, firewall, proxy, VPN-related configuration |

---

## Backup Sources

The backup process protects the following paths from each remote server:

```text
/etc
/home
/srv
```

### `/etc`

Contains system and service configuration.

Examples:

```text
/etc/ssh
/etc/nginx
/etc/hosts
/etc/netplan
/etc/ufw
/etc/squid
/etc/openvpn
```

### `/home`

Contains user-level files and SSH-related configuration.

Important note:

`/home` may contain sensitive data such as SSH keys or user files.  
Because of that, backup storage permissions must be restricted.

### `/srv`

Contains service data and lab-specific operational data.

Examples:

```text
/srv/company
/srv/backups
```

Important note:

When backing up `srv-ops-01` in the future, avoid recursively backing up `/srv/backups` into itself.

---

## Excluded Paths

The following pseudo-filesystems and temporary paths are excluded:

```text
/proc
/sys
/dev
/tmp
/run
```

These paths are not regular persistent data.

They are generated by the kernel or runtime environment and should not be included in file-level backups.

---

## Pre-Checks

Before running centralized backups, verify that:

- `/srv/backups` is mounted on `srv-ops-01`
- SSH name resolution works
- Passwordless SSH works from `srv-ops-01` to protected servers
- `rsync` is installed on all protected servers
- Remote sudo permissions allow `rsync` to read protected paths
- Internal firewall rules allow SSH from `srv-ops-01` to protected systems

Check backup storage:

```bash
df -h | grep /srv/backups
```

Check host resolution:

```bash
ping srv-id-01
ping srv-app-01
ping srv-edge-01
```

Check SSH access:

```bash
ssh srv-id-01 hostname
ssh srv-app-01 hostname
ssh srv-edge-01 hostname
```

---

## Phase 1 – Initial Local Backup Implementation

Before implementing centralized backups from multiple remote systems, a local backup workflow was tested directly on `srv-ops-01`.

This initial phase validated the basic backup and restore idea using:

- Local directories
- `rsync`
- Date-based backup folders
- A simple backup script
- Manual restore testing
- Optional archive separation

This was not the final backup architecture.

It was used as a first validation step before moving to the centralized model.

---

### Step 1 – Prepare Backup Directories

Create daily and archive backup directories:

```bash
sudo mkdir -p /srv/backups/daily
sudo mkdir -p /srv/backups/archive
```

Purpose:

- `/srv/backups/daily` stores regular local backup runs
- `/srv/backups/archive` can be used later for older backups

---

### Step 2 – Create Local Backup Script

Create the script:

```bash
sudo vim /usr/local/bin/backup.sh
```

Content:

```bash
#!/bin/bash

DATE=$(date +%F-%H%M)
DEST="/srv/backups/daily/backup-$DATE"

mkdir -p "$DEST"

rsync -av \
  /etc \
  /var/www \
  /srv/company \
  "$DEST"

echo "Backup completed: $DEST"
```

This script creates a timestamped local backup directory and copies selected local paths into it.

Backed up paths:

```text
/etc
/var/www
/srv/company
```

---

### Step 3 – Make the Script Executable

```bash
sudo chmod +x /usr/local/bin/backup.sh
```

Verify:

```bash
ls -l /usr/local/bin/backup.sh
```

---

### Step 4 – Run First Backup Manually

```bash
sudo /usr/local/bin/backup.sh
```

Verify that a backup directory was created:

```bash
ls /srv/backups/daily
```

Expected example:

```text
backup-2026-04-29-0200
```

---

### Step 5 – Automate Local Backup with Cron

Edit root crontab:

```bash
sudo crontab -e
```

Add:

```cron
0 2 * * * /usr/local/bin/backup.sh
```

Meaning:

```text
Run the local backup every day at 02:00.
```

Verify:

```bash
sudo crontab -l
```

---

### Step 6 – Optional Archive Handling

Older backup directories can be moved manually to the archive directory:

```bash
sudo mv /srv/backups/daily/backup-* /srv/backups/archive/
```

This was kept manual at this stage.

Automated archive and retention handling can be added later.

---

### Step 7 – Restore Test – File-Level Recovery

A basic restore scenario was validated by manually restoring a deleted file from the latest local backup.

Create a test file:

```bash
sudo mkdir -p /srv/company
echo "test" | sudo tee /srv/company/testfile.txt
```

Run the backup again:

```bash
sudo /usr/local/bin/backup.sh
```

Delete the original file:

```bash
sudo rm /srv/company/testfile.txt
```

Restore the file from the latest backup:

```bash
sudo cp /srv/backups/daily/<LATEST_BACKUP>/srv/company/testfile.txt /srv/company/
```

Verify:

```bash
cat /srv/company/testfile.txt
```

Expected:

```text
test
```

---

### Local Backup Outcome

This local backup phase proved that:

- `rsync` can copy selected directories successfully
- Backup directories are created under `/srv/backups/daily`
- The process can be scheduled with cron
- A deleted file can be restored manually
- Restore testing is required, not optional

After this local validation, the design was extended into the centralized backup model using SSH, remote `rsync`, snapshot directories, `current` symlinks, and `--link-dest`.

---

## SSH Key Setup

Generate an SSH key on `srv-ops-01` if it does not already exist:

```bash
ssh-keygen -t ed25519
```

Deploy the public key to protected systems:

```bash
ssh-copy-id ali-admin@srv-id-01
ssh-copy-id ali-admin@srv-app-01
ssh-copy-id ali-admin@srv-edge-01
```

Verify access:

```bash
ssh srv-id-01 hostname
ssh srv-app-01 hostname
ssh srv-edge-01 hostname
```

Expected result:

```text
srv-id-01
srv-app-01
srv-edge-01
```

---

## Remote Sudo Requirement

The backup process uses remote `rsync` with elevated permissions so that protected directories such as `/etc` can be read correctly.

The implementation uses:

```bash
--rsync-path="sudo rsync"
```

For automated execution, `ali-admin` must be allowed to run `rsync` with sudo without an interactive password prompt.

On each protected server, create a sudoers file:

```bash
sudo visudo -f /etc/sudoers.d/backup-rsync
```

Add:

```text
ali-admin ALL=(root) NOPASSWD: /usr/bin/rsync
```

Verify the correct rsync path if needed:

```bash
which rsync
```

Test from `srv-ops-01`:

```bash
ssh srv-app-01 "sudo rsync --version"
```

Expected:

```text
rsync version ...
```

---

## Backup Script Location

The centralized backup logic is implemented in a separate script:

```text
/usr/local/bin/backup_rsync.sh
```

The full script is documented separately to keep this phase focused on:

- Backup architecture
- Backup flow
- Restore process
- Verification
- Operational behavior

This file explains what the backup system does and why it exists.

The script file explains how the backup process is implemented.

---

## Script Permissions

Secure the backup script:

```bash
sudo chown root:root /usr/local/bin/backup_rsync.sh
sudo chmod 750 /usr/local/bin/backup_rsync.sh
```

Verify:

```bash
ls -l /usr/local/bin/backup_rsync.sh
```

Expected:

```text
-rwxr-x--- root root ... /usr/local/bin/backup_rsync.sh
```

---

## Manual Backup Execution

Run the first backup manually:

```bash
sudo /usr/local/bin/backup_rsync.sh
```

Check the log:

```bash
sudo tail -n 50 /var/log/backup.log
```

Expected log entries:

```text
Backup started
Starting backup for srv-id-01
Backing up srv-id-01:/etc
Backing up srv-id-01:/home
Backing up srv-id-01:/srv
Backup completed for srv-id-01
...
Backup completed successfully
```

---

## Snapshot Structure

After a successful run, the backup directory should look similar to:

```text
/srv/backups/
├── srv-id-01/
│   ├── 2026-04-29-020000/
│   └── current -> /srv/backups/srv-id-01/2026-04-29-020000
├── srv-app-01/
│   ├── 2026-04-29-020000/
│   └── current -> /srv/backups/srv-app-01/2026-04-29-020000
└── srv-edge-01/
    ├── 2026-04-29-020000/
    └── current -> /srv/backups/srv-edge-01/2026-04-29-020000
```

Verify:

```bash
ls -l /srv/backups
ls -l /srv/backups/srv-id-01
ls -l /srv/backups/srv-app-01
ls -l /srv/backups/srv-edge-01
```

Check the latest backup link:

```bash
ls -l /srv/backups/srv-app-01/current
```

---

## How `current` Works

Each server has a `current` symlink:

```text
/srv/backups/srv-app-01/current
```

This points to the latest successful snapshot.

Example:

```text
current -> /srv/backups/srv-app-01/2026-04-29-020000
```

Benefits:

- Easy access to the latest backup
- Simplifies restore operations
- Enables `--link-dest` for efficient future snapshots

---

## How `--link-dest` Works

The backup process uses:

```bash
--link-dest="$CURRENT_LINK$SRC"
```

This tells `rsync`:

- If a file did not change, hard-link it from the previous backup
- If a file changed, copy the new version
- If a file was deleted from the source, reflect that deletion in the new snapshot because `--delete` is used

This creates snapshot-style backups without copying every unchanged file again.

Result:

```text
Each backup looks complete.
Unchanged files do not consume full extra space.
```

---

## Cron Scheduling

Open root crontab:

```bash
sudo crontab -e
```

Add:

```cron
0 2 * * * /usr/local/bin/backup_rsync.sh
```

Meaning:

```text
Run the backup every day at 02:00.
```

Verify root crontab:

```bash
sudo crontab -l
```

---

## Log Verification

Backup logs are written to:

```text
/var/log/backup.log
```

Check latest log entries:

```bash
sudo tail -n 100 /var/log/backup.log
```

Search for errors:

```bash
sudo grep -i "error\|failed\|denied" /var/log/backup.log
```

Check if the backup completed successfully:

```bash
sudo tail -n 5 /var/log/backup.log
```

Expected:

```text
Backup completed successfully
```

---

## Restore Test

Backups are only useful if restore works.

This phase includes a file-level restore test.

### Example Restore Scenario

Create a test file on `srv-app-01`:

```bash
ssh srv-app-01
sudo mkdir -p /srv/company
echo "test" | sudo tee /srv/company/testfile.txt
exit
```

Run backup from `srv-ops-01`:

```bash
sudo /usr/local/bin/backup_rsync.sh
```

Delete the original file on `srv-app-01`:

```bash
ssh srv-app-01
sudo rm /srv/company/testfile.txt
exit
```

Restore the file from the latest backup:

```bash
sudo scp /srv/backups/srv-app-01/current/srv/company/testfile.txt \
  ali-admin@srv-app-01:/tmp/testfile.txt
```

Move it back to the original location:

```bash
ssh srv-app-01
sudo mv /tmp/testfile.txt /srv/company/testfile.txt
cat /srv/company/testfile.txt
exit
```

Expected:

```text
test
```

This confirms that:

- The file was backed up
- The file can be restored
- The restored content is correct

---

## Restore Nginx Web Content Example

Because `srv-app-01` hosts an internal Nginx service, `/var/www` is an important restore target.

This restore test simulates accidental damage to the Nginx web content and restores it from the latest backup.

### Step 1 – Confirm Current Web Page

On `srv-app-01`:

```bash
curl http://localhost
```

Expected output includes:

```text
srv-app-01 — Nginx OK
```

---

### Step 2 – Simulate Accidental Web Content Damage

Create a backup of the current file locally before testing:

```bash
sudo cp /var/www/html/index.html /var/www/html/index.html.before-restore-test
```

Now simulate a broken or overwritten page:

```bash
echo "BROKEN PAGE" | sudo tee /var/www/html/index.html
```

Verify the problem:

```bash
curl http://localhost
```

Expected output:

```text
BROKEN PAGE
```

---

### Step 3 – Restore Web Content from Backup

From `srv-ops-01`, copy the backed-up web content to a temporary location on `srv-app-01`:

```bash
sudo scp -r /srv/backups/srv-app-01/current/var/www/html \
  ali-admin@srv-app-01:/tmp/html-restore
```

On `srv-app-01`, restore the files:

```bash
sudo rsync -av /tmp/html-restore/ /var/www/html/
```

Validate Nginx configuration:

```bash
sudo nginx -t
```

Reload Nginx:

```bash
sudo systemctl reload nginx
```

Verify the restored page:

```bash
curl http://localhost
```

Expected output includes:

```text
srv-app-01 — Nginx OK
```

---

### Step 4 – Clean Up Temporary Restore Data

```bash
sudo rm -rf /tmp/html-restore
```

This confirms that:

- The Nginx web content was damaged intentionally
- The damaged content was restored from backup
- The service returned to the expected state

---

## Verification Checklist

- `/srv/backups` is mounted
- Backup script exists
- Backup script is executable
- SSH access from `srv-ops-01` to protected systems works
- Remote sudo rsync works
- Manual backup completes successfully
- `/var/log/backup.log` contains successful entries
- Snapshot directories are created
- `current` symlink points to the latest backup
- Restore test succeeds
- Restored file content is correct

---

## Operational Notes

- A backup is not valid until restore has been tested
- Review `/var/log/backup.log` after each run
- Monitor free space on `/srv/backups`
- Keep backup permissions restrictive
- Avoid backing up temporary or pseudo-filesystems
- Validate SSH connectivity before relying on scheduled backups
- Document restore steps clearly
- Do not assume backup success only because the cron job exists

---

## Retention Notes


Retention means deciding how long old backups should be kept.

Without retention, backup directories will continue growing until the backup volume becomes full.

Example policy:

```text
Keep daily backups for 14 days.
Delete backups older than 14 days.
```

At this stage, retention is documented but not automated.

This is intentional because deleting backups automatically can be dangerous if the logic is wrong.

At this stage, retention can be handled manually.

Example: list old backups:

```bash
find /srv/backups -mindepth 2 -maxdepth 2 -type d
```

Example future retention rule:

```bash
find /srv/backups/* -mindepth 1 -maxdepth 1 -type d -mtime +14 -exec rm -rf {} \;
```

Important:

Do not delete the directory currently referenced by `current`.

A safer retention script should check symlinks before deletion.

Automated retention is intentionally left as a future improvement.

---

## Security Considerations

Backup data may contain sensitive files, including:

- SSH configuration
- User files
- Service configuration
- VPN configuration
- Proxy configuration
- Firewall-related files

Therefore:

- Restrict access to `/srv/backups`
- Restrict access to `/var/log/backup.log`
- Avoid exposing backups through web services
- Do not store backups on public shares
- Treat backup data as sensitive infrastructure data

Recommended permissions:

```bash
sudo chown root:root /srv/backups
sudo chmod 750 /srv/backups

sudo chown root:adm /var/log/backup.log
sudo chmod 640 /var/log/backup.log
```

---

## Monitoring Ideas

This phase can later be connected to the monitoring system.

Possible checks:

- `/srv/backups` disk usage
- Existence of the latest backup directory
- Age of the latest backup
- Errors in `/var/log/backup.log`
- SSH connectivity to protected systems
- Cron execution status

Example manual check:

```bash
find /srv/backups/srv-app-01 -maxdepth 1 -type d -mtime -1
```

This can later become a Nagios plugin or scripted health check.

---

## Future Improvements

Planned improvements:

- Automated retention policy
- Backup health check script
- Nagios alert for failed backups
- Compression for archived backups
- Encrypted backups
- Remote/offsite backup target
- LVM snapshots
- Restic or BorgBackup
- Backup reports
- Ansible-managed backup deployment

---

## Outcome

At the end of this phase:

- `srv-ops-01` acts as the centralized backup node
- `/srv/backups` is used as the dedicated backup location
- Multiple servers are protected
- Backups are pulled over SSH using rsync
- Snapshot-style backups are created with `--link-dest`
- A `current` symlink points to the latest backup
- Backups can be scheduled using cron
- Backup logs are stored in `/var/log/backup.log`
- File-level restore was tested successfully
- The lab now has a practical disaster recovery foundation

---

## Commands Summary

```bash
# On srv-ops-01

df -h | grep /srv/backups

ssh-keygen -t ed25519

ssh-copy-id ali-admin@srv-id-01
ssh-copy-id ali-admin@srv-app-01
ssh-copy-id ali-admin@srv-edge-01

ssh srv-id-01 hostname
ssh srv-app-01 hostname
ssh srv-edge-01 hostname

sudo chown root:root /usr/local/bin/backup_rsync.sh
sudo chmod 750 /usr/local/bin/backup_rsync.sh

sudo /usr/local/bin/backup_rsync.sh

sudo tail -n 100 /var/log/backup.log

ls -l /srv/backups
ls -l /srv/backups/srv-app-01/current

sudo crontab -e
sudo crontab -l
```

```bash
# On each protected server, if sudo rsync needs passwordless execution

sudo visudo -f /etc/sudoers.d/backup-rsync
```

```text
ali-admin ALL=(root) NOPASSWD: /usr/bin/rsync
```

---

## Design Rationale

This phase follows the lab architecture principle that services must be operated, monitored, protected, and recoverable.

The system already has:

- Dedicated server roles
- Network segmentation
- Bastion-based access
- Internal firewalls
- Monitoring
- Dedicated LVM backup storage

This phase adds the missing continuity process.

The backup design is intentionally simple enough to understand, but realistic enough to represent infrastructure operations:

- Centralized backup node
- SSH-based access
- rsync file-level backup
- Snapshot-style history
- Restore validation

The result is a backup system that is practical, explainable, and extendable.
