# 14 – Operations: Monitoring with Nagios Core

## Goal

Transform the lab from “servers running” into an operable infrastructure by introducing centralized monitoring on `srv-ops-01`.

This phase establishes:

- Central visibility of all company servers
- Host-level and service-level health checks
- Secure access to monitoring tools
- Early detection of operational issues
- Alerting capabilities

Monitoring marks the transition from infrastructure building to real operations.

---

## Design Overview

### Monitoring Location

Nagios Core runs exclusively on:

- `srv-ops-01` (10.10.10.30)

This server represents the Operations layer in the architecture.

---

### Monitoring Scope

| Host         | Role                 | IP           |
|--------------|----------------------|--------------|
| srv-edge-01 | Gateway / Bastion    | 10.10.10.20  |
| srv-id-01   | Identity             | 10.10.10.10  |
| srv-ops-01  | Monitoring / Ops     | 10.10.10.30  |
| srv-app-01  | Application (Nginx)  | 10.10.10.40  |

Initial service checks:

- PING (host reachability)
- SSH (administrative access)
- HTTP (application availability)
- Disk usage
- Load average

---

### Access Model

Nagios UI is not exposed externally.

Access method:

- SSH tunnel from admin workstation
- No public port exposure
- No firewall exceptions on WAN

Operations tools remain internal-only.

---

# Installation

## 1) Base Preparation (srv-ops-01)

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget vim git net-tools ca-certificates
```

---

## 2) Install Dependencies

```bash
sudo apt install -y apache2 php libapache2-mod-php \
  build-essential unzip wget \
  libgd-dev libssl-dev daemon autoconf gcc make \
  mailutils postfix
```

Postfix configuration:
- Local only

---

## 3) Create Nagios User

```bash
sudo useradd nagios
sudo usermod -aG nagios <username>
```

---

## 4) Download and Build Nagios Core

```bash
cd /usr/src
sudo wget -O nagios.tar.gz https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.5.1.tar.gz
sudo tar xzf nagios.tar.gz
cd nagios-4.5.1

sudo ./configure --with-httpd-conf=/etc/apache2/sites-enabled
sudo make all
sudo make install
sudo make install-init
sudo make install-commandmode
sudo make install-config
```

---

## 5) Install Plugins

```bash
cd /usr/src
sudo wget -O plugins.tar.gz https://nagios-plugins.org/download/nagios-plugins-2.4.9.tar.gz
sudo tar xzf plugins.tar.gz
cd nagios-plugins-2.4.9

sudo ./configure
sudo make
sudo make install
```

---

## 6) Enable Web Interface

```bash
cd /usr/src/nagios-4.5.1
sudo make install-webconf
sudo a2enmod rewrite cgi
sudo systemctl restart apache2
```

Create UI user:

```bash
sudo htpasswd -c /usr/local/nagios/etc/htpasswd.users nagiosadmin
```

Enable and start:

```bash
sudo systemctl enable nagios
sudo systemctl start nagios
```

---

# SSH Tunnel Access

## Problem

SSH hardening disabled port forwarding:

```
AllowTcpForwarding no
```

As a result, SSH tunnels failed.

---

## Controlled Exception (srv-ops-01 only)

Edit `/etc/ssh/sshd_config`:

```
Match User ali-admin
    AllowTcpForwarding yes
    PermitTunnel yes
```

Validate and restart:

```bash
sudo sshd -t
sudo systemctl restart ssh
```

---

## Access Nagios UI from macOS

```bash
ssh -L 8080:localhost:80 ali-admin@srv-ops-01
```

Open in browser:

```
http://localhost:8080/nagios
```

This maintains internal-only exposure.

---

# Clean Configuration Isolation

Configuration path:

```
/usr/local/nagios/etc
```

Create dedicated directory:

```bash
sudo mkdir /usr/local/nagios/etc/objects/company
```

Edit:

```bash
sudo vim /usr/local/nagios/etc/nagios.cfg
```

Add:

```
cfg_dir=/usr/local/nagios/etc/objects/company
```

This isolates all lab-specific definitions.

---

# Host Definitions

File:

```
/usr/local/nagios/etc/objects/company/hosts.cfg
```

Example:

```
define host {
    use         linux-server
    host_name   srv-edge-01
    alias       Edge Gateway
    address     10.10.10.20
}

define host {
    use         linux-server
    host_name   srv-id-01
    alias       Identity Server
    address     10.10.10.10
}

define host {
    use         linux-server
    host_name   srv-ops-01
    alias       Operations Server
    address     10.10.10.30
}

define host {
    use         linux-server
    host_name   srv-app-01
    alias       Application Server
    address     10.10.10.40
}
```

---

# Firewall Adjustment for SSH Monitoring

Previously:
- Internal firewall (UFW) allowed SSH only from `srv-edge-01`
- `srv-ops-01` was not permitted
- SSH checks showed CRITICAL despite healthy servers

Monitoring is not human access.
Internal servers (srv-id-01 and srv-app-01) must allow SSH from `srv-ops-01`.

Example on `srv-id-01`:

```bash
sudo ufw allow from 10.10.10.30 to any port 22 proto tcp
sudo ufw reload
```

This preserves the bastion model while enabling monitoring.

---

# Service Checks

## PING

Purpose:
- First validation layer
- Confirms network reachability

```
define service {
    use                     generic-service
    host_name               srv-edge-01,srv-id-01,srv-ops-01,srv-app-01
    service_description     PING
    check_command           check_ping!100.0,20%!500.0,60%
}
```

---

## SSH

Purpose:
- Confirms administrative access
- Detects firewall or daemon issues

```
define service {
    use                     generic-service
    host_name               srv-edge-01,srv-id-01,srv-ops-01,srv-app-01
    service_description     SSH
    check_command           check_ssh
}
```

---

## HTTP (Application)

Only on `srv-app-01`.

Purpose:
- Validate real service availability
- Detect application-level failure

```
define service {
    use                     generic-service
    host_name               srv-app-01
    service_description     HTTP
    check_command           check_http
}
```

---

## Disk Usage

Purpose:
- Prevent outages due to full disk

```
define service {
    use                     generic-service
    host_name               srv-edge-01,srv-id-01,srv-ops-01,srv-app-01
    service_description     Disk Usage /
    check_command           check_local_disk!20%!10%!/
}
```

---

## Load Average

Purpose:
- Detect CPU overload conditions

```
define service {
    use                     generic-service
    host_name               srv-edge-01,srv-id-01,srv-ops-01,srv-app-01
    service_description     Load Average
    check_command           check_local_load!5.0,4.0,3.0!10.0,6.0,4.0
}
```

---

# Validation

Always validate configuration before restart:

```bash
sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
```

Expected:

```
Total Errors:   0
Total Warnings: 0
```

Restart:

```bash
sudo systemctl restart nagios
```

---

# Alerting (Email)

Configure contact email in:

```
/usr/local/nagios/etc/objects/contacts.cfg
```

Example:

```
define contact {
    contact_name    nagiosadmin
    use             generic-contact
    alias           Nagios Admin
    email           your-email@example.com
}
```

Ensure notifications are enabled in templates:

```
define service {
    name                    generic-service
    notifications_enabled   1
    notification_interval   30
    notification_period     24x7
    notification_options    w,u,c,r
}
```

---

# Test Alerting

Stop Nginx:

```bash
sudo systemctl stop nginx
```

Expected:
- HTTP check becomes CRITICAL
- Email notification triggered

Restart:

```bash
sudo systemctl start nginx
```

Recovery notification expected.

---

# Monitoring Dashboard Snapshot

The following screenshot shows the Nagios service overview after full configuration and firewall alignment.

All hosts are reachable and all configured service checks are operational.

![Nagios Monitoring Overview](/assets/nagios-overview.png)

---

## Observations

- All hosts: UP
- PING: OK across all systems
- SSH: OK (after allowing monitoring source on internal firewall)
- HTTP: OK on srv-app-01
- Disk Usage: within defined thresholds
- Load Average: normal values

This confirms:
- Network segmentation is correct
- Firewall adjustments for monitoring are correct
- Bastion model remains intact
- Service-level visibility is operational

---

# Operational Outcome

At this stage:
- Central monitoring is operational
- Service-level visibility exists
- Alerts are functional
- UI is secure and internal-only
- Configuration is clean and isolated

The lab is now operable, not just deployed.
