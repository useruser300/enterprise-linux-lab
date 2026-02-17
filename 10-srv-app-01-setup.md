# 10 – srv-app-01 Setup (Application Server Foundation)

## Goal
Prepare `srv-app-01` as the dedicated application server by:
- Installing a clean Ubuntu baseline
- Applying SSH hardening consistent with other servers
- Configuring LAN-only networking
- Enforcing bastion-based administrative access

This server will later host application services such as Nginx.

---

## Scope
Included:
- Base system update
- Essential administration packages
- SSH key-based access
- SSH hardening configuration
- LAN-only netplan configuration
- Access via ProxyJump (bastion model)

Not included:
- Application services (covered in next phase)
- Reverse proxy configuration
- HTTPS
- Monitoring agents

---

## Role in Architecture

Server: `srv-app-01`  
IP: `10.10.10.40`  
Network: LAN only  
Gateway: `10.10.10.20` (srv-edge-01)

Design principle:
- No direct WAN access
- No direct SSH from outside
- Reachable only via the bastion (edge server)

---

## Base System Setup

### Step 1) Update System

```bash
sudo apt update && sudo apt upgrade -y
```

---

### Step 2) Install Essential Tools

```bash
sudo apt install -y curl wget vim git net-tools ca-certificates
```

Purpose:
- Ensure troubleshooting and administration tools are available
- Align with baseline of other servers

---

## SSH Access & Hardening

### 1) SSH Key Access

Ensure SSH key from the admin workstation is installed:

```bash
ssh-copy-id ali-admin@10.10.10.40
```

Access should work via the bastion model:

```bash
ssh srv-app-01
```

---

### 2) Backup SSH Configuration

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
```

---

### 3) Apply Enterprise SSH Hardening

Edit:

```bash
sudo vim /etc/ssh/sshd_config
```

Ensure the following settings:

```
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

### 4) Validate and Restart SSH

```bash
sudo sshd -t
sudo systemctl restart ssh
```

Expected:
- No syntax errors
- SSH service running normally

---

## Network Configuration (LAN Only)

### 1) Disable cloud-init Network Control

```bash
sudo mkdir -p /etc/cloud/cloud.cfg.d
echo "network: {config: disabled}" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
```

---

### 2) Configure Netplan

Create:

```bash
sudo vim /etc/netplan/01-company-network.yaml
```

Content:

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

Apply:

```bash
sudo netplan apply
```

---

### 3) Verify Network Configuration

```bash
ip a
ip r
```

Expected:
- Static IP: 10.10.10.40
- Default route via 10.10.10.20
- No WAN interface

---

## Access Model

### Admin Access Pattern

From macOS:

```bash
ssh srv-app-01
```

Internally resolved via:
- ProxyJump through `srv-edge-01`
- No direct SSH from outside

This enforces the bastion host model consistently across the environment.

---

## Verification Checklist

- SSH login works via bastion
- Password login disabled
- Root login disabled
- Static IP correctly assigned
- Default route points to edge gateway
- Internet access works via NAT on `srv-edge-01`

---

## Outputs

- Dedicated application server prepared
- LAN-only exposure enforced
- SSH hardened consistently
- Clean foundation for application services
