# 15 – Squid Proxy (Enterprise Internet Governance)

## Goal

Introduce a centralized web proxy on `srv-edge-01` to provide controlled and auditable internet access for internal systems.

This phase enables:

- Centralized outbound internet governance (egress control)
- Proxy authentication tied to users
- Policy enforcement (domains, file types, safe ports/methods)
- Bandwidth shaping (delay pools)
- HTTP-level logging for audit and troubleshooting

Note:
Direct internet access via NAT still exists at this stage.
Squid is deployed and ready, but outbound enforcement (proxy-only) can be introduced later as a hardening step.

---

## Why Squid Exists in This Lab

Squid is not installed “because it exists”.
It is installed to support a real enterprise scenario.

### Operational Goal
- Internal servers should not have uncontrolled outbound browsing
- A single egress control point simplifies troubleshooting
- Internet issues can be investigated in one place

### Security Goal
- Reduce risks such as malware downloads and data exfiltration
- Gain visibility into “who accessed what, when”
- Enable authentication and audit-friendly logs
- Prepare for future integration (SIEM / auditing)

### Governance / Policy Goal
- Enable organization-level policies such as:
  - IT has broad access
  - Accounting restricted from social media
  - Support has limited bandwidth
  - Block risky file downloads

### What Squid is Not Used For
- Reverse proxy (handled by Nginx)
- Heavy caching (not the focus)

---

## Placement and Architecture

### Location

Squid runs on:

- `srv-edge-01` (LAN IP: `10.10.10.20`)
- Proxy port: `3128/tcp`

This is the correct enforcement point because `srv-edge-01` is already:

- Gateway (routing/NAT)
- Firewall (iptables)
- Central choke point for outbound traffic

### Architecture

```
                 Internet
                    |
             (UTM Shared NAT)
                    |
              srv-edge-01
        WAN: 192.168.64.x
        LAN: 10.10.10.20
        Roles:
          - Gateway
          - Router (NAT)
          - Firewall (iptables)
          - Proxy (Squid)
                    |
        ------------------------------------
        |               |                |
   srv-id-01        srv-ops-01        srv-app-01
  10.10.10.10       10.10.10.30       10.10.10.40
```

### Current State (Before vs After)

Before Squid:
- Internet access goes out via NAT only
- No authentication
- No filtering policies
- Logs only show low-level NAT traffic

After Squid:
- Proxy is available and configured
- Authentication is required when using the proxy
- Policies apply only to proxied traffic
- HTTP logs become detailed and usable
- Direct NAT access may still work unless enforcement is added later

---

## Installation (srv-edge-01)

### 1) Install packages

```bash
sudo apt update
sudo apt install -y squid apache2-utils
```

---

### 2) Backup default config

```bash
sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.bak
```

---

## Proxy Authentication

Create a password file and a user:

```bash
sudo htpasswd -c /etc/squid/passwd it-user
```

Notes:
- `-c` creates the file (use only once)
- Add more users later without `-c`

---

## Squid Configuration

Main file:
- `/etc/squid/squid.conf`

Edit:

```bash
sudo vim /etc/squid/squid.conf
```

Configuration (active build version):

```
############################################
# Squid Proxy – Enterprise Configuration
# Host: srv-edge-01
# Role: Gateway / Firewall / Proxy
############################################

############################
# Basic settings
############################
http_port 3128
visible_hostname srv-edge-01

############################
# Authentication (Basic)
############################
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm Company Secure Proxy
auth_param basic credentialsttl 2 hours
acl authenticated proxy_auth REQUIRED

############################
# Network definitions
############################
acl company_lan src 10.10.10.0/24

############################
# Safe ports & methods
############################
acl SSL_ports port 443
acl Safe_ports port 80 443 21
acl CONNECT method CONNECT

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports

############################
# Blocked domains (policy)
############################
acl blocked_sites dstdomain \
    .facebook.com \
    .tiktok.com \
    .youtube.com

############################
# Blocked file types
############################
acl blocked_files url_regex -i \
    \.exe$ \
    \.msi$ \
    \.bat$ \
    \.cmd$ \
    \.ps1$ \
    \.zip$ \
    \.rar$ \
    \.torrent$

############################
# Bandwidth control (Delay Pools)
############################
delay_pools 1
delay_class 1 2
delay_access 1 allow company_lan

delay_parameters 1 125000/125000 32000/32000

############################
# Access rules (ORDER MATTERS)
############################
http_access deny blocked_sites
http_access deny blocked_files

http_access allow authenticated company_lan

http_access deny all

############################
# Logging
############################
access_log /var/log/squid/access.log squid
cache_log  /var/log/squid/cache.log

logfile_rotate 7

############################
# Cache (minimal – not focus)
############################
cache_mem 64 MB
maximum_object_size_in_memory 512 KB
maximum_object_size 5 MB
cache_dir ufs /var/spool/squid 100 16 256
```

---

## Validate and Start

### 1) Validate Squid config syntax

```bash
sudo squid -k parse
```

Expected:
- No errors

---

### 2) Restart and enable Squid

```bash
sudo systemctl restart squid
sudo systemctl enable squid
```

---

## Firewall Rule (srv-edge-01)

Allow Squid access only from LAN:

```bash
sudo iptables -A INPUT -p tcp -s 10.10.10.0/24 --dport 3128 -j ACCEPT
```

Persist:

```bash
sudo netfilter-persistent save
```

Notes:
- Squid listens on the edge server itself, so this is an INPUT rule
- Do not allow 3128 from WAN

---

## Client Testing (Internal Servers)

### Method 1: Explicit curl with proxy and credentials (recommended)

HTTP:

```bash
curl -I -x http://10.10.10.20:3128 -U it-user http://example.com
```

HTTPS:

```bash
curl -I -x http://10.10.10.20:3128 -U it-user https://example.com
```

Tip:
- You can use `-U it-user:PASSWORD` for non-interactive testing

---

### Method 2: Export proxy environment variables

```bash
export http_proxy="http://it-user@10.10.10.20:3128"
export https_proxy="http://it-user@10.10.10.20:3128"
curl -I http://example.com
```

If authentication fails, use Method 1 with `-U`.

---

## Log Verification

Tail Squid access log on `srv-edge-01`:

```bash
sudo tail -f /var/log/squid/access.log
```

Success indicators in logs:
- For HTTPS: `TCP_TUNNEL/200`
- For HTTP: `TCP_MISS/200` or `TCP_HIT/200`

A denied / auth failure may show:
- `TCP_DENIED/407`

---

## Important Clarification: NAT vs Proxy (What Actually Happens)

### Case A: Without Proxy (direct NAT)

If an internal server runs:

```bash
curl http://example.com
```

Flow:
- Client goes directly out via routing/NAT
- Squid is not involved
- No proxy authentication
- No Squid policy enforcement
- No Squid logging for that request

---

### Case B: With Proxy (Squid path)

If an internal server runs:

```bash
curl -x http://10.10.10.20:3128 -U it-user http://example.com
```

Flow:
- Request goes to Squid on `srv-edge-01`
- Authentication is required
- Policies apply (blocked sites/files)
- Request is logged in Squid `access.log`
- Governance becomes enforceable

---

## Operational Outcome

At this stage:
- Squid is deployed on the correct enforcement point (`srv-edge-01`)
- Proxy authentication is functional
- Policies are active for proxied traffic (domains, file types, safe ports, methods)
- Bandwidth shaping is configured
- Logging is available for audit and troubleshooting

NAT-based direct internet still exists until enforcement is introduced later.
