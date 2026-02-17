# 08 – Internal Firewall (UFW on Internal Servers)

## Goal
Apply a host-based firewall baseline on internal servers to:
- Prevent lateral movement inside the LAN
- Allow only the minimum required inbound traffic
- Preserve the bastion (jump host) access model
- Add lightweight logging for blocked attempts

This phase complements the perimeter firewall on the edge gateway.
It is not a replacement.

---

## Scope
Included:
- UFW installation (if not already present)
- Default deny inbound policy
- Explicit SSH allowlist rules (restricted source)
- Lightweight firewall logging
- Verification tests

Not included:
- Edge gateway firewall rules (handled with iptables)
- Service-specific inbound rules (added later as services are introduced)

---

## Target Servers
Internal servers only:
- `srv-id-01`
- `srv-ops-01`
- `srv-app-01`

Not applied here:
- `srv-edge-01` (gateway uses iptables and handles routing/NAT)

---

## Design Rationale

### Why an Internal Firewall is Needed

A perimeter firewall protects the network boundary.
An internal firewall protects each server itself.

Without internal firewalling:
- Any compromised internal system can probe and attack other internal servers
- Lateral movement becomes easy

With internal firewalling:
- Each server only accepts expected inbound traffic
- Blast radius is reduced if any internal host is compromised

---

## Policy

### Default Policies
- Incoming: deny
- Outgoing: allow

### Allowed Inbound Traffic
- SSH only from the edge gateway (bastion host)
  - Source: `10.10.10.20`
  - Port: `22/tcp`

### Logging
- Enabled in low mode to avoid excessive noise

---

## Commands

### Step 1) Install UFW (if required)

Run on each internal server:

```bash
sudo apt update
sudo apt install -y ufw
```

Verify:

```bash
ufw version
```

---

### Step 2) Set Default Policies

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

---

### Step 3) Allow SSH Only from the Bastion Host

```bash
sudo ufw allow from 10.10.10.20 to any port 22 proto tcp
```

Important:
- Do not use `ufw allow ssh` because it opens SSH from any source

---

### Step 4) Enable UFW

```bash
sudo ufw enable
```

If prompted:
- Confirm with `y`

---

### Step 5) Enable Lightweight Logging

```bash
sudo ufw logging low
```

---

## Verification

### 1) Verify UFW Status

```bash
sudo ufw status verbose
```

Expected:
- Default: deny (incoming), allow (outgoing)
- Rule allowing SSH from `10.10.10.20`
- Logging: on (low)

---

### 2) Confirm SSH Works Through the Bastion (macOS)

```bash
ssh srv-id-01
ssh srv-ops-01
ssh srv-app-01
```

Expected:
- All connections succeed via ProxyJump

---

### 3) Confirm SSH Works from the Bastion Host

From `srv-edge-01`:

```bash
ssh srv-id-01
ssh srv-ops-01
ssh srv-app-01
```

Expected:
- Connections succeed

---

### 4) Confirm Lateral SSH is Blocked (Internal to Internal)

From an internal server (example: `srv-ops-01`):

```bash
ssh srv-id-01

```

Expected:
- Connection attempt fails or hangs (DROP behavior)
- This confirms lateral movement is blocked

---

### 5) Verify Firewall Logs

UFW logs:

```bash
sudo tail -f /var/log/ufw.log
```

Or via journald:

```bash
sudo journalctl -u ufw --since "10 minutes ago"
```

Expected:
- Block entries appear for denied inbound attempts

---

## Outputs

- Internal servers are protected even inside the LAN
- Bastion-only administrative access remains intact
- Lateral movement is reduced by default
- Lightweight logging provides visibility without excessive noise
