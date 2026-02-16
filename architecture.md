# Architecture – Enterprise Linux Lab

This document describes the architectural design of the Enterprise Linux Lab.
It focuses on structure, responsibilities, and design rationale rather than
implementation details or command-level execution.

The goal is to model a realistic small-to-medium company infrastructure
using Ubuntu Server, following production-style system design principles.

---

## Architectural Vision

The lab represents a company environment that includes:

- Dedicated servers with clear responsibilities
- Centralized access control
- A segmented and controlled network
- Security enforced at multiple layers
- Internal services with restricted exposure
- Operational visibility and monitoring
- A foundation for backup and continuity

The architecture is intentionally built in layers, where each layer
supports and enables the next.

---

## Capability Model

The lab is organized around capabilities rather than tools.
Each capability represents something a real company must have.

### 1. Infrastructure
- Ubuntu Server as the base operating system
- Virtual machines with defined roles
- Static hostnames and predictable layout
- Time synchronization and base system readiness

This layer provides the foundation on which everything else depends.

---

### 2. Identity and Access
- Local users and groups
- Role-based access control
- Sudo policies based on least privilege
- SSH access policies using key-based authentication

Identity is treated as a first-class concern and is kept explicit
instead of abstracted away early.

---

### 3. Security
- Perimeter firewall at the network edge
- Host-based firewalls on internal servers
- Logging of denied and suspicious traffic
- Intrusion prevention mechanisms

Security is applied both at the network level and at the host level
to reduce blast radius and lateral movement.

---

### 4. Services
- Internal services hosted on dedicated servers
- Controlled exposure through the network
- Clear separation between infrastructure and applications

Services are introduced only after the environment is ready
to protect and operate them.

---

### 5. Operations
- Centralized monitoring
- Log inspection and rotation
- Health checks and alerting
- Operational visibility without exposing services publicly

Operations is treated as an active responsibility, not an afterthought.

---

### 6. Continuity
- Dedicated storage for backups
- Restore testing
- Preparation for disaster recovery scenarios

Continuity ensures that the environment can recover from failure,
not just run during normal operation.

---

## Server Roles

The architecture is based on strict role separation.

### srv-id-01 – Identity Server
Responsible for:
- Users and groups
- Sudo policies
- SSH access control
- Identity-related configuration

This server represents the question:
Who are you, and what are you allowed to do?

---

### srv-edge-01 – Edge and Gateway Server
Responsible for:
- Network gateway and routing
- Perimeter firewall
- Internet ingress and egress control
- Bastion (jump host) access

This server represents:
What enters and leaves the company network?

---

### srv-ops-01 – Operations Server
Responsible for:
- Monitoring
- Log analysis
- Backup storage
- Operational tooling

This server represents:
Is the company running correctly?

---

### srv-app-01 – Application Server
Responsible for:
- Hosting internal services
- Generating real traffic and logs
- Acting as the primary target for security and monitoring

This server represents:
Where the actual business services run.

---

## Network Architecture

### Logical Network Design

- Internal company network (LAN): 10.10.10.0/24
- Central gateway with routing and firewall responsibilities
- Internal servers do not have direct internet access

All traffic entering or leaving the LAN passes through the edge server.

---

### Evolution of the Network Design

The network architecture evolves in two stages:

#### Initial Stage – Simple NAT
- All servers have direct internet access
- Firewall rules apply only locally
- Suitable for early setup and learning

#### Final Stage – DMZ and LAN
- A single gateway controls all ingress and egress
- Internal servers are isolated from direct internet access
- Security and monitoring become enforceable at the network level

The final architecture reflects how real companies structure
their internal networks.

---

## Access Model

Administrative access follows a bastion host model.

- Direct SSH access to internal servers is not allowed
- All administrative access passes through the edge server
- VPN access is introduced later for secure remote access
- No port forwarding is used

This approach centralizes access, simplifies auditing,
and reduces attack surface.

---

## Design Decisions and Rationale

### Local Identity Before Central Identity
Local users and groups are implemented before introducing LDAP or FreeIPA.

This ensures:
- Clear understanding of access control
- Reduced dependency on central services
- Better recovery options in failure scenarios

---

### Services After Security Baseline
Services are introduced only after:
- Network segmentation is complete
- Firewalls are active
- Access paths are well defined

This prevents building services on insecure foundations.

---

### Manual First, Automation Later
All components are built manually before automation is introduced.

Automation is treated as a multiplier of understanding,
not a substitute for it.

---

## Design Boundaries and Out of Scope

The following are intentionally not part of the initial architecture:

- Central identity services (LDAP / FreeIPA)
- Full DNS infrastructure
- Public-facing services
- TLS interception or deep packet inspection
- Heavy service orchestration

These elements may be added later as controlled extensions,
not as baseline requirements.

---

## Summary

This architecture models a real company environment where:

- Responsibilities are clearly separated
- Access is controlled and auditable
- Security is layered and intentional
- Services exist to be operated, monitored, and protected
- The system is designed to evolve over time

The architecture prioritizes clarity, realism, and long-term maintainability.
