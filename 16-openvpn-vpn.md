# 16 – OpenVPN (Remote Access into the Company Network)

## Goal

Provide secure remote access to the internal company LAN using OpenVPN on `srv-edge-01`.

This phase enables:

- Remote administration without port forwarding
- Access to internal LAN services from the admin workstation
- A realistic enterprise access pattern (VPN into internal network)
- Controlled exposure (VPN port only)

Target outcome:
From the admin workstation, open internal services such as:

- `http://10.10.10.30/nagios`
- SSH to internal servers using LAN IPs

---

## Design Overview

### Placement

OpenVPN runs on:

- `srv-edge-01` (WAN + LAN)
- WAN side receives VPN connections
- LAN side forwards traffic into `10.10.10.0/24`

`srv-edge-01` is the correct termination point because it already acts as:

- Gateway / Router (NAT)
- Firewall (iptables)
- Central enforcement point

---

## Network Model

- Company LAN: `10.10.10.0/24`
- VPN Client subnet: `10.8.0.0/24`
- Edge LAN IP: `10.10.10.20`
- Edge WAN IP: `192.168.64.9` (example)

VPN provides routing into LAN only.
No full-tunnel internet redirect is used.

---

## Installation (srv-edge-01)

```bash
sudo apt update
sudo apt install -y openvpn easy-rsa
```

---

## PKI Setup (CA + Server + Client)

Create PKI directory:

```bash
make-cadir ~/openvpn-ca
cd ~/openvpn-ca
```

Initialize PKI:

```bash
./easyrsa init-pki
```

Build CA (prompts for CA password and name):

```bash
./easyrsa build-ca
```

Create server certificate:

```bash
./easyrsa gen-req server nopass
./easyrsa sign-req server server
```

Create client certificate (example: `ali-mac`):

```bash
./easyrsa gen-req ali-mac nopass
./easyrsa sign-req client ali-mac
```

Generate DH:

```bash
./easyrsa gen-dh
```

Generate TLS auth key:

```bash
openvpn --genkey secret ta.key
```

---

## Deploy Certificates to OpenVPN

```bash
sudo cp pki/ca.crt /etc/openvpn/
sudo cp pki/issued/server.crt /etc/openvpn/
sudo cp pki/private/server.key /etc/openvpn/
sudo cp pki/dh.pem /etc/openvpn/
sudo cp ta.key /etc/openvpn/
```

---

## OpenVPN Server Configuration

Create:

```bash
sudo vim /etc/openvpn/server.conf
```

Content:

```text
port 1194
proto udp
dev tun

user nobody
group nogroup

persist-key
persist-tun

ca   /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key  /etc/openvpn/server.key
dh   /etc/openvpn/dh.pem

tls-auth /etc/openvpn/ta.key 0
key-direction 0

topology subnet
server 10.8.0.0 255.255.255.0

# Push company LAN route only
push "route 10.10.10.0 255.255.255.0"

keepalive 10 120

cipher AES-256-GCM
auth SHA256

verb 3

status /var/log/openvpn-status.log
log-append /var/log/openvpn.log
```

Note:  
No `redirect-gateway` is used.  
The goal is LAN access, not routing client internet through the VPN.

---

## Enable IP Forwarding (srv-edge-01)

Check:

```bash
cat /proc/sys/net/ipv4/ip_forward
```

If not `1`, enable permanently:

```bash
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-openvpn.conf
sudo sysctl --system
```

---

## Firewall Rules (iptables on srv-edge-01)

Assumptions:
- WAN interface: `enp0s1`
- LAN interface: `enp0s2`

### 1) Allow VPN connections on WAN

```bash
sudo iptables -A INPUT -i enp0s1 -p udp --dport 1194 -j ACCEPT
```

### 2) Allow VPN clients to reach LAN

```bash
sudo iptables -A FORWARD -i tun0 -o enp0s2 -s 10.8.0.0/24 -d 10.10.10.0/24 -j ACCEPT
sudo iptables -A FORWARD -i enp0s2 -o tun0 -s 10.10.10.0/24 -d 10.8.0.0/24 -j ACCEPT
```

### 3) NAT VPN clients toward LAN (critical)

```bash
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o enp0s2 -j MASQUERADE
```

Persist rules:

```bash
sudo netfilter-persistent save
```

Why this NAT matters:  
Internal servers do not need routes back to `10.8.0.0/24`.  
Replies work immediately because traffic appears to originate from the edge LAN IP.

---

## Start OpenVPN

On Ubuntu 22.04:

```bash
sudo systemctl enable --now openvpn@server
sudo systemctl status openvpn@server --no-pager
```

If the unit name differs:

```bash
systemctl list-unit-files | grep openvpn
```

---

## Client Setup (macOS)

Create workspace:

```bash
cd ~/Desktop
mkdir -p vpn
cd vpn
```

Required client files:

- `~/openvpn-ca/pki/ca.crt`
- `~/openvpn-ca/pki/issued/ali-mac.crt`
- `~/openvpn-ca/pki/private/ali-mac.key`
- `/etc/openvpn/ta.key`

Because `ta.key` is owned by root, copy it first:

```bash
sudo cp /etc/openvpn/ta.key /home/ali-admin/
sudo chown ali-admin:ali-admin /home/ali-admin/ta.key
```

Copy files to macOS (run from macOS):

```bash
scp ali-admin@192.168.64.9:~/openvpn-ca/pki/ca.crt .
scp ali-admin@192.168.64.9:~/openvpn-ca/pki/issued/ali-mac.crt .
scp ali-admin@192.168.64.9:~/openvpn-ca/pki/private/ali-mac.key .
scp ali-admin@192.168.64.9:~/ta.key .
```

---

## Client Profile (`ali-mac.ovpn`)

Create `ali-mac.ovpn` on macOS:

```text
client
dev tun
proto udp

remote 192.168.64.9 1194
nobind

persist-key
persist-tun

remote-cert-tls server

cipher AES-256-GCM
auth SHA256
verb 3

key-direction 1

<ca>
-----BEGIN CERTIFICATE-----
PASTE ca.crt CONTENT HERE
-----END CERTIFICATE-----
</ca>

<cert>
-----BEGIN CERTIFICATE-----
PASTE ali-mac.crt CONTENT HERE
-----END CERTIFICATE-----
</cert>

<key>
-----BEGIN PRIVATE KEY-----
PASTE ali-mac.key CONTENT HERE
-----END PRIVATE KEY-----
</key>

<tls-auth>
-----BEGIN OpenVPN Static key V1-----
PASTE ta.key CONTENT HERE
-----END OpenVPN Static key V1-----
</tls-auth>
```

Recommended client on macOS:
- Tunnelblick (or OpenVPN Connect)

---

## Tunnelblick Setup (macOS)

### 1. Install Tunnelblick
- Search for "Tunnelblick"
- Install normally

### 2. Import profile
- Open Tunnelblick
- Add Configuration
- Import `ali-mac.ovpn`

### 3. Connect
- Approve macOS network/VPN permission prompts

---

## Verification After اتصال VPN

Confirm `tun` interface exists:

```bash
ifconfig | grep tun
```

Confirm VPN IP in `10.8.0.x`.

Test reachability:

```bash
ping 10.10.10.20
ping 10.10.10.10
ping 10.10.10.30
```

Test SSH:

```bash
ssh ali-admin@10.10.10.10
```

---

## Final Target: Access Nagios from Browser (No SSH Tunnel)

Open:
- `http://10.10.10.30/nagios`

Test via curl:

```bash
curl -I http://10.10.10.30/nagios
```

Expected:
- `HTTP/1.1 401 Unauthorized`

This is correct and proves:
- Request reached Apache
- Nagios is running
- Authentication is required

---

## Why UFW Rules Based on `10.8.0.0/24` Did Not Work

Because VPN traffic is NATed on the edge:

```bash
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o enp0s2 -j MASQUERADE
```

Internal servers see the traffic source as:
- `10.10.10.20` (`srv-edge-01`)

Not:
- `10.8.0.x`

Therefore, the correct UFW rule for allowing HTTP to `srv-ops-01` is:

```bash
sudo ufw allow from 10.10.10.20 to any port 80 proto tcp
```

This keeps services internal while permitting VPN access via the edge.

---

## Open Nagios from macOS Browser via VPN (No SSH, No ProxyJump)

Final target:

- `http://10.10.10.30/nagios`

Requirements:

- Access from macOS browser
- Without SSH tunnel
- Without ProxyJump
- Through the OpenVPN connection only

---

## Stage 1: Before VPN (Why It Did Not Work)

Before VPN:

- The Mac was not part of the company network
- Internal servers were reachable only through:
  - ProxyJump (SSH)
- HTTP / Nagios was not reachable from the Mac
- `srv-ops-01` had Apache running, but firewall rules were strict

Result:  
No direct web access from macOS to internal services.

---

## Stage 2: VPN Gateway Was Built (Key Step)

On `srv-edge-01`, the following was implemented:

### 1) OpenVPN Server
- Listening on UDP `1194`
- Assigning client IPs from `10.8.0.0/24`

### 2) Routing
- Pushing the internal LAN route to clients:
  - `10.10.10.0/24`

### 3) IP Forwarding
- Enabled:
  - `net.ipv4.ip_forward=1`

This makes `srv-edge-01` a router between VPN and LAN.

---

## Stage 3: NAT on the Edge (Critical Detail)

On `srv-edge-01`, VPN client traffic is NATed toward the LAN:

```bash
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o enp0s2 -j MASQUERADE
```

Effect:
- Internal servers do not see the VPN client IP (`10.8.0.x`)
- They see the source as the edge LAN IP:
  - `10.10.10.20` (`srv-edge-01`)

This is why UFW rules based on `10.8.0.0/24` did not work.

---

## Stage 4: macOS Joined the Network

On macOS:
- Tunnelblick connected successfully
- The Mac received a VPN IP:
  - `10.8.0.2` (example)
- A route was installed:
  - `10.10.10.0/24` via `10.8.0.1`

Result:  
The Mac became logically part of the company network.

---

## Stage 5: Final Blocker (Firewall on `srv-ops-01`)

On `srv-ops-01`, UFW policy was strict:
- SSH allowed only from `10.10.10.20`
- Everything else dropped

This caused:
- HTTP access from VPN clients to be blocked
- HTTP access from any source to be blocked

Result:  
Nagios UI could not load from the Mac.

---

## Stage 6: Correct Fix (Allow HTTP from the Edge Only)

Because of NAT, `srv-ops-01` sees requests coming from `10.10.10.20`.

Fix on `srv-ops-01`:

```bash
sudo ufw allow from 10.10.10.20 to any port 80 proto tcp
```

Meaning:  
Allow HTTP access only when the traffic comes through the edge gateway.  
No broad LAN exposure is introduced.

---

## Stage 7: Final Validation (Success)

From macOS:

```bash
curl -I http://10.10.10.30/nagios
```

Expected result:
- `HTTP/1.1 401 Unauthorized`

This is correct and indicates:
- The request reached Apache
- Nagios is running
- Networking and VPN path are correct
- Authentication is required (normal)

Then open in browser:
- `http://10.10.10.30/nagios`

Result:  
Nagios UI loads successfully.

---

## Fast Rollback (If Something Breaks)

Stop VPN service:

```bash
sudo systemctl stop openvpn@server
```

Remove iptables rules safely using line numbers:

```bash
sudo iptables -L INPUT --line-numbers
sudo iptables -L FORWARD --line-numbers
sudo iptables -t nat -L POSTROUTING --line-numbers
```

Delete specific rule numbers:

```bash
sudo iptables -D INPUT <NUM>
sudo iptables -D FORWARD <NUM>
sudo iptables -t nat -D POSTROUTING <NUM>
```

Persist:

```bash
sudo netfilter-persistent save
```

---

## Operational Outcome

At this stage:
- VPN termination is implemented correctly on the edge server
- VPN clients receive an IP from `10.8.0.0/24`
- Clients receive a route to `10.10.10.0/24`
- Admin workstation can access internal services via browser
- No port forwarding is required