# 04 – DMZ and LAN Network Segmentation

## Goal
Transform the lab from a simple network where every server has direct internet access
into a realistic company-style architecture with:
- A single internet gateway
- An isolated internal LAN
- Central routing and egress control points for future security layers (firewall, proxy, VPN)

This phase converts the environment into a network design that can enforce policies
at the company perimeter rather than only on individual hosts.

---

## Design Intent

### Before: Simple NAT (Baseline)

In the initial baseline, each server can reach the internet directly.

```
srv-id-01   --\
srv-edge-01 --- Internet
srv-ops-01  --/
```

Characteristics:
- Each server has direct internet access
- Firewall and proxy controls are host-based only
- Centralized egress control is not enforceable

---

### After: DMZ and LAN

After segmentation, only the edge server has WAN access.
All internal servers are LAN-only and must route through the edge.

```
                 Internet
                    |
             (UTM Shared NAT)
                    |
              srv-edge-01
            WAN: 192.168.64.x
            LAN: 10.10.10.20
                    |
        ---------------------------------------------------
        |                              |                   |
   srv-id-01                      srv-ops-01           srv-app-01
  10.10.10.10                    10.10.10.30           10.10.10.40
```

Characteristics:
- `srv-edge-01` becomes the gateway, router, and control point
- Internal servers have no direct internet interface
- All egress policies can be centralized on the edge server
- Future layers (firewall, proxy, VPN) become meaningful and enforceable

---

## Scope

Included:
- Disabling cloud-init network management
- Custom netplan configuration
- Static IP addressing
- IP forwarding on the edge server
- NAT for LAN-to-internet access

Not included:
- Firewall policy design (handled in firewall phases)
- Proxy or VPN services (handled later)

---

## Target Servers

- `srv-edge-01`  
  Gateway with WAN and LAN interfaces

- `srv-id-01`  
  Internal server (LAN only)

- `srv-ops-01`  
  Internal server (LAN only)

- `srv-app-01`  
  Internal server (LAN only)

---

## Network Inventory

### Logical Networks
- Internal company network (LAN): `10.10.10.0/24`
- Central gateway: `srv-edge-01` routes between LAN and WAN

### Static IP Assignment
- `srv-id-01`  → `10.10.10.10`
- `srv-edge-01` → `10.10.10.20`
- `srv-ops-01` → `10.10.10.30`
- `srv-app-01` → `10.10.10.40`

Only the edge server has direct WAN access.

---

## VM Platform Network Configuration (UTM)

### WAN Network
- Type: Shared Network
- DHCP: Provided by UTM
- Internet: Yes

### LAN Network
- Type: Host Only
- Name: company-lan
- DHCP: No
- Internet: No

---

## Commands and Configuration

### 1) Disable cloud-init Network Management

Run on all servers:

```bash
sudo mkdir -p /etc/cloud/cloud.cfg.d
echo "network: {config: disabled}" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
```

Purpose:
- Prevent cloud-init from overwriting custom netplan settings

---

### 2) Netplan Configuration – Edge Server (WAN + LAN)

On `srv-edge-01`:

```bash
sudo vim /etc/netplan/01-company-network.yaml
```

Configuration:

```yaml
network:
  version: 2
  ethernets:
    enp0s1:   # WAN
      dhcp4: true

    enp0s2:   # LAN
      dhcp4: no
      addresses:
        - 10.10.10.20/24
```

Apply configuration:

```bash
sudo rm -f /etc/netplan/50-cloud-init.yaml    #optinal 
sudo netplan try
sudo netplan apply
```

---

### 3) Netplan Configuration – Internal Servers (LAN Only)

#### srv-id-01

```yaml
network:
  version: 2
  ethernets:
    enp0s1:
      dhcp4: no
      addresses:
        - 10.10.10.10/24
      gateway4: 10.10.10.20
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
```

#### srv-ops-01

```yaml
network:
  version: 2
  ethernets:
    enp0s1:
      dhcp4: no
      addresses:
        - 10.10.10.30/24
      gateway4: 10.10.10.20
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
```

#### srv-app-01

```yaml
network:
  version: 2
  ethernets:
    enp0s1:
      dhcp4: no
      addresses:
        - 10.10.10.40/24
      gateway4: 10.10.10.20
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
```

Apply on each server:

```bash
sudo rm -f /etc/netplan/50-cloud-init.yaml
sudo netplan try
sudo netplan apply
```

---

### 4) Enable IP Forwarding on Edge Server

On `srv-edge-01`:

Enable immediately:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

Persist across reboots:

```bash
echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-ipforward.conf
sudo sysctl --system
```

Verify:

```bash
sysctl net.ipv4.ip_forward
```

---

### 5) Configure NAT on Edge Server

```bash
sudo iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o enp0s1 -j MASQUERADE
sudo iptables -A FORWARD -i enp0s2 -o enp0s1 -j ACCEPT
sudo iptables -A FORWARD -i enp0s1 -o enp0s2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```

Quick check:

```bash
sudo iptables -t nat -L -n -v
sudo iptables -L FORWARD -n -v
```


Persist rules:

```bash
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
sudo netfilter-persistent reload
```

---

## Verification

On internal servers:

```bash
ping 10.10.10.20
ping 8.8.8.8
apt update
```

Expected:
- LAN connectivity to the edge server works
- Internet access works through the gateway
- Internal servers remain LAN-only

---

## Outputs

- Segmented network with a controlled gateway
- A realistic enterprise-style DMZ and LAN layout
- Stable foundation for access control, firewall policies, proxy, and VPN
