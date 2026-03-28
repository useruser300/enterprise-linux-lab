# 17 – Storage & LVM (srv-ops-01)

## Goal

Introduce dedicated storage for backups and operational data using LVM on `srv-ops-01`.

This phase enables:

* Separation of OS disk and data disk
* Flexible storage management using LVM
* Safe expansion in future phases
* Proper location for backups and restore testing

---

## Design Overview

### Why LVM

LVM (Logical Volume Manager) allows:

* Flexible resizing of volumes
* Separation between physical disk and logical usage
* Easier future expansion without downtime

This matches real-world infrastructure practices.

---

## Storage Design

* Disk: /dev/vdb (new disk, 20GB)
* Volume Group: vg_data
* Logical Volume: lv_backups (10GB)
* Mount point: /srv/backups

Remaining space is intentionally left free for future expansion.

---

## Step 1 – Add Disk (UTM)

On the VM:

* Open VM settings for `srv-ops-01`
* Add new storage disk
* Size: 20GB
* Interface: default or VirtIO
* Start VM

Important:
Do not format or partition the disk in UTM.

---

## Step 2 – Verify Disk

```bash
lsblk
```

Expected:

* Existing OS disk (vda)
* New disk (vdb) with no partitions

Example:

```text
vda   40G
└─vda1 40G /

vdb   20G   (empty)
```

---

## Step 3 – Confirm Disk is Empty

```bash
sudo wipefs -n /dev/vdb
```

Expected:
No filesystem signatures detected.

---

## Step 4 – Create Physical Volume (PV)

```bash
sudo pvcreate /dev/vdb
```

Verify:

```bash
sudo pvs
```

---

## Step 5 – Create Volume Group (VG)

```bash
sudo vgcreate vg_data /dev/vdb
```

Verify:

```bash
sudo vgs
```

---

## Step 6 – Create Logical Volume (LV)

```bash
sudo lvcreate -L 10G -n lv_backups vg_data
```

Verify:

```bash
sudo lvs
```

Design note:

* Only half of the disk is allocated
* Remaining space is reserved for future use

---

## Step 7 – Create Filesystem

```bash
sudo mkfs.ext4 /dev/vg_data/lv_backups
```

---

## Step 8 – Create Mount Point

```bash
sudo mkdir -p /srv/backups
```

---

## Step 9 – Mount (Temporary Test)

```bash
sudo mount /dev/vg_data/lv_backups /srv/backups
```

Verify:

```bash
df -h | grep backups
```

---

## Step 10 – Persistent Mount (fstab)

Get UUID:

```bash
sudo blkid /dev/vg_data/lv_backups
```

Edit fstab:

```bash
sudo vim /etc/fstab
```

Add:

```text
UUID=XXXX-XXXX  /srv/backups  ext4  defaults  0  2
```

Test:

```bash
sudo umount /srv/backups
sudo mount -a
```

---

## Verification

Check mount:

```bash
df -h
```

Check LVM:

```bash
sudo lvs
sudo vgs
sudo pvs
```

---

## Operational Notes

* Storage is isolated from OS disk
* LVM allows future extension without downtime
* Backup data will be stored under /srv/backups
* This volume will be used in later phases for:

  * Backup scripts
  * Restore testing
  * Disaster recovery scenarios

---

## Outcome

At this stage:

* A dedicated storage volume is available
* LVM is correctly configured
* Storage is persistent across reboots
* The system is ready for backup and recovery operations
