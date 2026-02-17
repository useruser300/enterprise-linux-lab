# 09 – Hosts Resolution (Using /etc/hosts)

## Goal
Provide simple and reliable hostname resolution for internal systems in order to:
- Use meaningful server names instead of IP addresses
- Simplify SSH access, scripts, and monitoring
- Avoid premature complexity (DNS infrastructure)

This phase introduces deterministic name resolution without adding new services.

---

## Scope
Included:
- Static hostname resolution using `/etc/hosts`
- Consistent host naming across servers
- Immediate verification

Not included:
- DNS server deployment
- Service discovery
- Dynamic or automated name management

---

## Target Systems
Applied on:
- `srv-edge-01`
- `srv-id-01`
- `srv-ops-01`
- `srv-app-01`

Optional:
- Admin workstation (macOS)

---

## Design Rationale

### Why /etc/hosts

At this stage, hostnames are used primarily for:
- Administrative access (SSH)
- Monitoring targets
- Internal references

There is no need yet for:
- DNS zones
- Service records
- High availability name resolution

Using `/etc/hosts` keeps the environment:
- Simple
- Predictable
- Easy to audit

This approach is commonly used on bastion hosts and in restricted environments.

---

## Canonical Host Mapping

The following mappings are used consistently:

```
10.10.10.10   srv-id-01
10.10.10.20   srv-edge-01
10.10.10.30   srv-ops-01
10.10.10.40   srv-app-01
```

WAN addresses are intentionally excluded.

---

## Commands

### Step 1) Edit /etc/hosts

Run on each target system:

```bash
sudo vim /etc/hosts
```

Append the following lines:

```text
# Company internal hosts
10.10.10.10   srv-id-01
10.10.10.20   srv-edge-01
10.10.10.30   srv-ops-01
10.10.10.40   srv-app-01
```

Save and exit.

---

### Step 2) Verify Name Resolution

From any server:

```bash
ping srv-id-01
ping srv-edge-01
ping srv-ops-01
ping srv-app-01
```

Expected:
- Hostnames resolve to the correct IPs
- ICMP replies succeed where allowed by firewall policy

---

### Step 3) Verify SSH by Hostname

```bash
ssh srv-id-01
ssh srv-ops-01
ssh srv-app-01
```

Expected:
- SSH works through the bastion model
- Hostnames resolve correctly without using IP addresses

---

## Notes

- `/etc/hosts` is static and must be updated manually
- This is acceptable and intentional at the current stage
- DNS can be introduced later when:
  - Multiple services are exposed
  - Monitoring and clients depend on names
  - Centralized management becomes necessary

---

## Outputs

- Clean and consistent hostname usage
- Reduced reliance on raw IP addresses
- No additional services or firewall changes required
