# 12 – Security Hardening: Fail2Ban (Nginx Protection)

## Goal
Enhance service-level security on `srv-app-01` by:
- Monitoring Nginx logs for abusive behavior
- Automatically banning suspicious clients
- Integrating dynamic firewall rules
- Demonstrating practical intrusion prevention

This phase turns static firewall rules into dynamic, log-driven protection.

---

## Scope
Included:
- Fail2Ban installation
- Nginx-related jails
- Custom jail for controlled testing
- Ban verification and unban procedure

Not included:
- Advanced IPS/IDS systems
- Centralized log correlation
- SSL/TLS hardening

---

## Target Server
- `srv-app-01`

---

## Design Context

Before this phase:
- Firewall rules were static
- Nginx generated logs but no automated response existed

After this phase:
- Logs trigger automatic bans
- Abusive patterns are blocked dynamically
- Service security becomes behavior-aware

---

## Installation

### Step 1) Install Fail2Ban

```bash
sudo apt install -y fail2ban
```

Enable and start:

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

Verify:

```bash
sudo systemctl status fail2ban
```

---

## Configure Local Jail

### Step 2) Create Local Configuration

```bash
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

Edit:

```bash
sudo vim /etc/fail2ban/jail.local
```

---

## Enable Nginx Jails

Add or ensure the following sections are enabled:

```text
[nginx-http-auth]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 5


[nginx-botsearch]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/access.log
maxretry = 2
```

Restart Fail2Ban:

```bash
sudo systemctl restart fail2ban
```

Verify:

```bash
sudo fail2ban-client status
sudo fail2ban-client status nginx-http-auth
sudo fail2ban-client status nginx-botsearch
```

Expected:
- nginx-http-auth listed
- nginx-botsearch listed

---

## Verify Firewall Integration

```bash
sudo iptables -L -n | grep f2b
```

Expected:
- Chains created by Fail2Ban
- Dynamic rules inserted automatically when bans occur

---

## Custom Jail (Controlled Test)

This jail bans repeated HTTP 404 requests.

### Step 1) Create Custom Filter

```bash
sudo vim /etc/fail2ban/filter.d/nginx-404.conf
```

Content:

```text
[Definition]
failregex = ^<HOST> .* "GET .* HTTP/.*" 404
ignoreregex =
```

---

### Step 2) Add Custom Jail

```bash
sudo vim /etc/fail2ban/jail.local
```

Append:

```text
[nginx-404-test]
enabled  = true
port     = http
filter   = nginx-404
logpath  = /var/log/nginx/access.log
maxretry = 3
findtime = 60
bantime  = 300
```

Restart:

```bash
sudo systemctl restart fail2ban
```

Verify:

```bash
sudo fail2ban-client status
```

Expected:
- nginx-404-test listed

---

## Trigger Test Ban

From another internal server:

```bash
for i in {1..5}; do curl http://10.10.10.40/notfound; done
```

Monitor Fail2Ban logs:

```bash
sudo tail -f /var/log/fail2ban.log
```

Expected:
- IP detected
- Ban applied

---

## Confirm Ban

From the same client:

```bash
curl http://10.10.10.40
```

Expected:
- Request blocked

Check jail status:

```bash
sudo fail2ban-client status nginx-404-test
```

---

## Unban Example

```bash
sudo fail2ban-client set nginx-404-test unbanip 10.10.10.10
```

---

## Outputs

- Dynamic service protection enabled
- Log-driven banning operational
- Verified integration with firewall
- Custom rule capability demonstrated
- Foundation for advanced hardening complete
