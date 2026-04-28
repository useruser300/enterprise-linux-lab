# 11 – Internal Nginx Service (srv-app-01)

## Goal

Introduce a simple internal web service on `srv-app-01` using Nginx.

This phase turns `srv-app-01` from a prepared application server into a server that actually hosts a service inside the company LAN.

The service provides:

- A real HTTP endpoint for internal access
- A target for monitoring checks
- Log files for operational analysis
- A service surface for Fail2Ban testing
- A foundation for later high availability and backup phases

---

## Scope

Included:

- Installing Nginx on `srv-app-01`
- Enabling and starting the Nginx service
- Creating a simple internal HTML page
- Verifying that Nginx listens on port `80`
- Verifying HTTP access from inside the LAN
- Confirming that access and error logs are generated

Not included:

- Public internet exposure
- HTTPS / TLS
- Reverse proxy configuration
- Load balancing
- High availability
- Application deployment beyond a static test page

---

## Target Server

- `srv-app-01`
- IP: `10.10.10.40`
- Network: Internal LAN only
- Gateway: `srv-edge-01` (`10.10.10.20`)

---

## Design Context

Before this phase, `srv-app-01` was prepared as an application server foundation:

- Ubuntu baseline installed
- SSH access configured
- SSH hardening applied
- LAN-only networking configured
- Bastion-based access enforced

However, the server did not yet have a documented application service.

After this phase, `srv-app-01` hosts an internal Nginx service that can be:

- Accessed from internal systems
- Monitored by `srv-ops-01`
- Protected by Fail2Ban
- Used for log analysis
- Extended later into a highly available service

---

## Why Nginx Exists in This Lab

Nginx is not installed only as a web server.

In this lab, Nginx represents a simple internal business service.

It gives the infrastructure something real to operate.

Without a service:

- Monitoring only checks servers, not application availability
- Logs are less meaningful
- Fail2Ban has no realistic service logs to analyze
- Backup has no application configuration to protect
- High availability has no service to make redundant

With Nginx:

- `srv-app-01` becomes a real application host
- HTTP checks become meaningful
- Security and operations phases have a real target

---

## Architecture Placement

```text
                 Internet
                    |
              srv-edge-01
        Gateway / Firewall / Bastion
                    |
              10.10.10.0/24 LAN
                    |
              srv-app-01
             10.10.10.40
              Nginx HTTP
```

The service is internal-only.

It is not exposed directly to the public internet.

---

## Installation

### Step 1 – Update Package Index

Run on `srv-app-01`:

```bash
sudo apt update
```

---

### Step 2 – Install Nginx

```bash
sudo apt install -y nginx
```

---

### Step 3 – Enable and Start Nginx

```bash
sudo systemctl enable nginx
sudo systemctl start nginx
```

Verify:

```bash
systemctl status nginx
```

Expected:

```text
active (running)
```

---

## Create Internal Service Page

Replace the default page with a simple internal service page:

```bash
cat <<'EOF' | sudo tee /var/www/html/index.html
<!DOCTYPE html>
<html>
  <head>
    <title>Company Internal Service</title>
  </head>
  <body>
    <h1>srv-app-01 — Nginx OK</h1>
    <p>Internal LAN service</p>
  </body>
</html>
EOF
```

This page confirms that the request reached the internal application server.

---

## Verify Web Root

Check the web root:

```bash
ls -l /var/www/html
```

Expected files may include:

```text
index.html
index.nginx-debian.html
```

The custom service page is:

```text
/var/www/html/index.html
```

Verify content:

```bash
cat /var/www/html/index.html
```

Expected content includes:

```text
srv-app-01 — Nginx OK
Internal LAN service
```

---

## Verify Nginx Configuration

Check Nginx syntax:

```bash
sudo nginx -t
```

Expected:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

Show the active configuration:

```bash
sudo nginx -T | head -n 80
```

Important configuration behavior:

```text
include /etc/nginx/sites-enabled/*;
```

This means Nginx loads enabled site definitions from:

```text
/etc/nginx/sites-enabled/
```

---

## Verify Listening Ports

Check that Nginx listens on HTTP port `80`:

```bash
sudo ss -tulpen | grep ':80'
```

Or:

```bash
sudo ss -tulpn | grep nginx
```

Expected:

```text
0.0.0.0:80
[::]:80
```

Meaning:

- `0.0.0.0:80` = Nginx listens on all IPv4 interfaces
- `[::]:80` = Nginx listens on IPv6
- The service is active and accepting HTTP connections

---

## Verify HTTP Access

### Local Test on srv-app-01

```bash
curl http://localhost
```

Expected output includes:

```html
<h1>srv-app-01 — Nginx OK</h1>
<p>Internal LAN service</p>
```

---

### Internal LAN Test

From another internal server, for example `srv-ops-01`:

```bash
curl http://10.10.10.40
```

Or by hostname if `/etc/hosts` is configured:

```bash
curl http://srv-app-01
```

Expected:

```text
srv-app-01 — Nginx OK
Internal LAN service
```

---

## Firewall Considerations

Because internal servers use UFW with default deny inbound, HTTP access must be explicitly allowed where required.

For internal HTTP access from the operations server:

```bash
sudo ufw allow from 10.10.10.30 to any port 80 proto tcp
sudo ufw reload
```

For HTTP access through the VPN path, traffic may appear to originate from the edge server due to NAT.

In that case, allow the edge server:

```bash
sudo ufw allow from 10.10.10.20 to any port 80 proto tcp
sudo ufw reload
```

Do not expose port `80` directly to the WAN.

---

## Log Verification

Nginx writes logs to:

```text
/var/log/nginx/access.log
/var/log/nginx/error.log
```

Check access logs:

```bash
sudo tail -n 50 /var/log/nginx/access.log
```

Check error logs:

```bash
sudo tail -n 50 /var/log/nginx/error.log
```

Generate a test request:

```bash
curl http://localhost
```

Then verify that the request appears in:

```bash
sudo tail -n 20 /var/log/nginx/access.log
```

---

## systemd Verification

Check Nginx service logs through journald:

```bash
journalctl -u nginx --since today
```

This confirms that Nginx is managed by systemd and that service-level events are visible through the system journal.

---

## Relationship to Later Phases

### Fail2Ban

Fail2Ban uses Nginx logs to detect abusive behavior and automatically ban suspicious clients.

This phase provides the service and logs that Fail2Ban protects.

---

### Local Logs

The operations logging phase uses Nginx access and error logs to demonstrate:

- Log inspection
- Basic log analysis
- Persistent journald usage
- logrotate verification

---

### Nagios Monitoring

Nagios monitors the HTTP service on `srv-app-01`.

The HTTP check confirms that the application service is reachable, not only that the server is powered on.

---

### Backup

Later backup phases can include:

```text
/etc/nginx
/var/www/html
```

This protects both the service configuration and the internal web content.

---

### High Availability

This service can later be extended by adding:

```text
srv-app-02
```

and placing a load balancer in front of both application servers.

---

## Verification Checklist

- Nginx is installed
- Nginx service is enabled
- Nginx service is running
- Port `80` is listening
- Custom `index.html` exists
- Internal HTTP access works
- Access logs are generated
- Error logs are available
- Nginx configuration syntax is valid

---

## Design Rationale

This phase introduces a real internal service only after the core infrastructure, access model, and firewall baseline are already in place.

This follows the lab design principle:

- Build infrastructure first
- Secure access paths
- Apply firewall controls
- Then introduce services
- Then monitor, protect, back up, and scale them

Nginx is intentionally simple here.

The goal is not to build a complex web application.

The goal is to create a real service target that makes the following phases meaningful:

- Security hardening
- Log operations
- Monitoring
- Backup
- High availability