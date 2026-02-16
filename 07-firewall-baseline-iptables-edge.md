# 07 – Firewall Baseline (iptables on Edge Gateway)

## Goal
Establish a perimeter firewall baseline on `srv-edge-01` that:
- Uses default deny (DROP) inbound and forwarding policies
- Preserves gateway responsibilities (routing and NAT)
- Allows only required traffic (SSH for bastion access, LAN forwarding)
- Adds rate-limited logging for dropped traffic
- Persists rules across reboots

This phase turns the edge server into a real company perimeter control point.

---

## Scope
Included:
- iptables baseline rules on `srv-edge-01`
- NAT preservation for LAN egress
- Minimal allowlist required for operations
- Logging of dropped traffic
- Persistence via `iptables-persistent`

Not included:
- Host-based firewalls on internal servers (handled in the next phase)
- Service-specific rules beyond baseline (added later as services appear)

---

## Target Server
- `srv-edge-01`

Interfaces and networks:
- WAN interface: `enp0s1`
- LAN interface: `enp0s2`
- LAN subnet: `10.10.10.0/24`

---

## Important Notes
- Apply rules while you still have a working SSH session to the edge server.
- This firewall must not break:
  - SSH access to the bastion (`srv-edge-01`)
  - LAN-to-internet routing via NAT

---

## Commands

### Step 1) Backup Current Rules

```bash
sudo iptables-save > /root/iptables.backup.$(date +%F-%H%M)
```

Rollback example:

```bash
sudo iptables-restore < /root/iptables.backup.*
```

---

### Step 2) Flush Existing Rules (Light Reset)

```bash
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -X
```

---

### Step 3) Allow Loopback

```bash
sudo iptables -A INPUT -i lo -j ACCEPT
```

---

### Step 4) Restore NAT (LAN -> WAN)

```bash
sudo iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o enp0s1 -j MASQUERADE
```

---

### Step 5) Allow Established and Related Traffic

```bash
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```

---

### Step 6) Allow SSH to the Edge (WAN -> Edge)

```bash
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
```

Purpose:
- Keep bastion access available from the admin workstation

---

### Step 6.5) Allow ICMP Ping from LAN to the Edge (Diagnostics)

```bash
sudo iptables -A INPUT -i enp0s2 -s 10.10.10.0/24 -p icmp --icmp-type echo-request -j ACCEPT
```

---

### Step 7) Allow LAN Forwarding to Internet (Forwarding)

```bash
sudo iptables -A FORWARD -i enp0s2 -o enp0s1 -j ACCEPT
```

---

### Step 8) Allow ICMP in Forwarding (Temporary Diagnostics)

```bash
sudo iptables -A FORWARD -p icmp -j ACCEPT
```

---

### Step 9) Allow DNS Forwarding from LAN

```bash
sudo iptables -A FORWARD -p udp --dport 53 -j ACCEPT
sudo iptables -A FORWARD -p tcp --dport 53 -j ACCEPT
```

---

### Step 10) Set Default Policies to DROP

```bash
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT
```

Rationale:
- INPUT and FORWARD are restricted by default
- OUTPUT remains open on the gateway for stability and manageability

---

### Step 11) Add Rate-Limited Logging for Drops

```bash
sudo iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "FW_INPUT_DROP: " --log-level 4
sudo iptables -A FORWARD -m limit --limit 5/min -j LOG --log-prefix "FW_FORWARD_DROP: " --log-level 4
```

Log review example:

```bash
sudo tail -f /var/log/syslog
```

---

### Step 12) Persist the Firewall Rules

```bash
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
sudo netfilter-persistent reload
```

---

## Verification

### 1) Confirm Bastion SSH Access (from macOS)

```bash
ssh edge
```

Expected:
- Works reliably

---

### 2) Confirm LAN Egress Still Works (from internal servers)

On `srv-id-01`, `srv-ops-01`, or `srv-app-01`:

```bash
ping 8.8.8.8
apt update
```

Expected:
- Internet access works via NAT through the edge

---

### 3) Confirm Unwanted Ports Are Blocked

From a system that can reach the edge WAN IP:

```bash
nc -zv 192.168.64.9 80
```

Expected:
- Connection fails (blocked)

---

## Outputs

- Edge gateway now enforces a perimeter firewall baseline
- Only SSH is exposed on the edge by default
- LAN traffic can reach the internet through controlled NAT
- Dropped traffic is logged in a rate-limited manner
- Rules persist across reboots
