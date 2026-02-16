# Enterprise Linux Lab – Ubuntu Company Simulation

This repository documents a hands-on Enterprise Linux Lab that simulates
a small-to-medium company infrastructure using Ubuntu Server.

The lab is built iteratively, following real-world system administration
and DevOps practices. The focus is on understanding why each component
exists, not only how it is configured.

This is a continuously evolving project. The implementation reflects
real execution order, real constraints, and production-style decisions.

---

## Overview

The lab models a realistic company environment with:

- Multiple Linux servers with clearly defined roles
- Centralized access and identity policies
- A segmented network architecture (LAN and DMZ)
- Perimeter and internal firewalls
- Internal services
- Monitoring and operational visibility
- Backup and continuity planning

---

## Architecture Summary

The environment is composed of the following servers:

- srv-id-01: Identity and access management
- srv-edge-01: Edge gateway, firewall, and ingress/egress control
- srv-ops-01: Operations and monitoring
- srv-app-01: Application and service hosting

The network design evolves from a simple NAT-based setup to a structured
DMZ and LAN architecture with a single controlled gateway.

Detailed architectural decisions and design rationale are documented in:

architecture.md

---

## Build and Implementation

The actual implementation is documented step by step in the exact order
in which it was executed.

Each build phase documents:

- The goal of the phase
- The target server or servers
- Configuration files involved
- Commands used
- Verification and validation steps

The full build index is available at:

build/00-build-index.md

---

## Project Status

Completed:
- Infrastructure and base system setup
- Network segmentation and routing
- Secure access model using a jump host
- Identity, users, groups, and sudo policies
- Baseline and advanced security measures
- Internal services
- Monitoring and alerting

In progress or planned:
- Expanded operations workflows
- Centralized log aggregation
- Backup and disaster recovery
- Automation with Ansible
- Central identity services (LDAP / FreeIPA)

This repository will continue to evolve as additional phases are added.

---

## Purpose

This lab demonstrates:

- Realistic Linux system design
- Clear separation of responsibilities
- Security-first and least-privilege principles
- Operational and monitoring readiness
- Production-oriented access and network models

---

## Environment Notes

- Ubuntu Server 22.04 LTS
- Manual implementation before automation
- Focus on clarity, correctness, and realism

---

## License

This project is provided for educational and portfolio purposes.

