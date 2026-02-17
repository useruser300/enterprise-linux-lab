# 13 – Operations: Local Logs (journald and logrotate)

## Goal
Stabilize service operations on `srv-app-01` by:
- Ensuring persistent system logging
- Understanding Nginx access and error logs
- Preventing uncontrolled log growth
- Preparing for monitoring and troubleshooting

This phase focuses on operational hygiene at the source of the service.

---

## Scope
Included:
- Persistent journald configuration
- Basic journald operational commands
- Nginx log inspection
- logrotate verification and testing

Not included:
- Centralized log forwarding
- SIEM integration
- Advanced log parsing tools

---

## Target Server
- `srv-app-01`

---

## Design Context

Before this phase:
- Logs existed but were not verified for persistence
- No operational validation of log rotation
- Troubleshooting required manual inspection

After this phase:
- Logs survive reboots
- Disk usage is controlled
- Operators can quickly diagnose issues
- The system is prepared for monitoring integration

---

## journald Configuration

### Step 1) Ensure Persistent Logging

Create persistent journal directory:

```bash
sudo mkdir -p /var/log/journal
sudo systemctl restart systemd-journald
```

Verify disk usage:

```bash
journalctl --disk-usage
```

Expected:
- Journal storage located in `/var/log/journal`
- Logs survive reboot

---

## Useful journald Commands

Check Nginx logs (last hour):

```bash
journalctl -u nginx --since "1 hour ago"
```

Check SSH logs (today):

```bash
journalctl -u ssh --since today
```

Show high-severity logs:

```bash
journalctl -p err..alert --since today
```

These commands reduce dependency on raw file browsing.

---

## Nginx Log Inspection

### Access Log

```bash
sudo tail -n 20 /var/log/nginx/access.log
```

### Error Log

```bash
sudo tail -n 20 /var/log/nginx/error.log
```

---

## Basic Log Analysis Examples

### Top Client IPs

```bash
sudo awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -nr | head
```

### Top HTTP Status Codes

```bash
sudo awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -nr | head
```

These simple commands provide quick operational insight.

---

## logrotate Verification

Ubuntu installs logrotate by default.

### Step 1) Inspect Nginx Rotation Policy

```bash
cat /etc/logrotate.d/nginx
```

Review:
- Rotation frequency
- Number of rotated files kept
- Compression settings

---

### Step 2) Dry-Run Test (Safe)

```bash
sudo logrotate -d /etc/logrotate.conf
```

`-d` performs a simulation without modifying files.

---

### Step 3) Force Rotation (Optional Test)

```bash
sudo logrotate -f /etc/logrotate.conf
```

Verify:
- New rotated log files created
- Old logs compressed if configured

---

## Operational Verification Checklist

- journald persists across reboots
- Nginx logs update on new requests
- logrotate functions correctly
- Disk usage remains controlled
- No service interruption during rotation

---

## Outputs

- Persistent system logging enabled
- Operational visibility improved
- Nginx logs verified and managed
- Log growth controlled
- Foundation prepared for centralized monitoring
