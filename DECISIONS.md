# Architecture Decision Log

This file records non-obvious architectural decisions made during the design and build of this SOC home lab. Each entry explains what was chosen, what alternatives were considered, and why.

---

## Decision 1: UTM over Proxmox / VirtualBox

**Date:** 2026-05-11  
**Status:** Final

**Decision:** Use UTM (QEMU-based) as the hypervisor on macOS Apple Silicon.

**Alternatives considered:**

| Option | Pros | Cons |
|--------|------|------|
| **UTM** (chosen) | Native ARM64; free; macOS-native UI; no emulation; supports Windows ARM UEFI + TPM | No programmatic VM lifecycle API; GUI-only creation |
| Proxmox on external machine | Full REST API; production-grade clustering; LXC containers | Requires dedicated x86 hardware; adds cost; not portable |
| VirtualBox | Cross-platform; API available | ARM64 support is experimental and slow on Apple Silicon; poor Windows ARM performance |
| Parallels Desktop | Best macOS integration; fast Windows ARM | Paid ($100+/year); closed source; not appropriate for portfolio |
| VMware Fusion | Good ARM64 support | Free tier has limitations; acquired by Broadcom (uncertain future) |

**Rationale:** UTM runs QEMU natively on Apple Silicon with full ARM64 hardware virtualization (HVF acceleration). No emulation layer means near-native performance for all three VMs. It is free and open-source, appropriate for a public portfolio project.

---

## Decision 2: UTM Shared Network over Bridged Networking

**Date:** 2026-05-11  
**Status:** Final

**Decision:** Use UTM's "Shared Network" mode (NAT) for all VMs, not Bridged.

**Alternatives considered:**

| Option | Pros | Cons |
|--------|------|------|
| **Shared Network / NAT** (chosen) | Isolated from home LAN; consistent IPs (192.168.64.0/24); no router dependency; UTM DHCP assigns predictable addresses | VMs cannot receive inbound connections from home LAN (acceptable for this lab) |
| Bridged | VMs appear as first-class LAN devices; can be accessed by other LAN hosts | IPs change with DHCP; lab traffic visible on home network; security risk if C2 traffic escapes |
| Host-Only | No internet access for VMs | Kali needs internet for package updates; Wazuh needs it for threat intel feeds |

**Rationale:** Lab isolation is a security requirement — Sliver C2 implants should never be able to call home over the real internet. Shared Network provides NAT with a fixed 192.168.64.0/24 subnet that is consistent across Mac reboots and router changes. The host can still reach VMs for Kibana (port 5601) and SSH.

---

## Decision 3: Ansible + Shell Scripts over Terraform

**Date:** 2026-05-11  
**Status:** Final

**Decision:** Use Ansible for all post-boot VM configuration. No Terraform.

**Alternatives considered:**

| Option | Pros | Cons |
|--------|------|------|
| **Ansible** (chosen) | Agentless; idempotent; large role ecosystem (Wazuh official Ansible role exists); YAML-native; familiar to security teams | Requires SSH connectivity before running; no VM lifecycle management |
| Terraform | Infrastructure + config in one tool; state management | **No Terraform provider for UTM exists**; would only manage cloud resources, not local VMs |
| Shell scripts only | Simple; no dependencies | Not idempotent; hard to maintain; no inventory management |
| Chef / Puppet | Mature config management | Requires agent installation; overkill for 3-VM lab; less common in security roles |

**Rationale:** Terraform has no provider for UTM or QEMU on macOS. VM creation must be done manually (GUI) or via UTM's scripting interface (limited). Ansible handles everything after first boot: package installation, Wazuh config, ELK stack deployment, Sysmon setup via WinRM. The Wazuh project provides an official Ansible role, reducing custom code.

**Implication:** VM creation remains a manual step documented in [runbook/02-utm-vm-creation.md](runbook/02-utm-vm-creation.md) and [runbook/MANUAL_STEPS.md](runbook/MANUAL_STEPS.md).

---

## Decision 4: Network Segmentation — UTM Isolation vs. Dedicated Firewall VM

**Date:** 2026-05-11  
**Status:** Final

**Decision:** Rely on UTM Shared Network isolation rather than adding a dedicated firewall VM.

**Alternatives considered:**

| Option | Pros | Cons |
|--------|------|------|
| **UTM isolation** (chosen) | No extra VM; no extra RAM; simpler; UTM NAT prevents lab traffic reaching home LAN | No intra-lab microsegmentation; all 3 VMs can talk to each other unrestricted |
| VyOS ARM64 | Full routing/firewall control; VLAN support; enterprise-realistic | 1 GB+ RAM overhead; complex UTM multi-NIC setup; VyOS ARM64 images require manual build from source |
| OPNsense (FreeBSD ARM) | Production-grade firewall; good UI | FreeBSD ARM64 on UTM has significant compatibility issues; requires emulation for some drivers; not worth the complexity for phase 1 |
| iptables on Kali/Ubuntu VMs | No extra VM; granular control | Attacker-controlled (Kali) shouldn't be the firewall; management complexity |

**Rationale:** For phase 1, the threat model accepts that all lab VMs can communicate freely. The important boundary is lab ↔ home LAN, which UTM Shared Network enforces via NAT. Adding a firewall VM would consume 1–2 GB of the already-constrained 16 GB Mac RAM budget.

**Future consideration:** If extending the lab with MISP (threat intel) or a vulnerable AD domain (Phase 8+), revisit VyOS ARM64 to add VLAN-based microsegmentation between red-team and blue-team segments.

---

## Decision 5: Wazuh 4.x + ELK 8.x over OpenSearch / Splunk Free

**Date:** 2026-05-11  
**Status:** Final

**Decision:** Use the Wazuh + Elasticsearch/Kibana 8.x stack, not OpenSearch or Splunk.

**Alternatives considered:**

| Option | Pros | Cons |
|--------|------|------|
| **Wazuh + ELK 8.x** (chosen) | Wazuh is industry-standard open-source SIEM; ELK has massive adoption; Wazuh has official Ansible role and ARM64 packages | ELK 8.x requires X-Pack licensing for some features (alerting) — though basic tier is free |
| Wazuh + OpenSearch | Fully open-source (Apache 2.0); AWS-backed | Wazuh's official integration is Elasticsearch; OpenSearch compatibility requires manual config; fewer tutorials |
| Splunk Enterprise (free tier) | Industry standard; most FAANG use Splunk | 500 MB/day ingest limit; x86 only (no ARM64 native package); defeats purpose on Apple Silicon |
| Graylog | Good UI; lower RAM than ELK | Less common in enterprise security; smaller community |
| Security Onion | All-in-one; includes Zeek, Suricata | Heavy (requires 16 GB RAM for the platform alone); ARM64 support is experimental |

**Rationale:** Wazuh + ELK is the most recognizable stack for FAANG security engineering interviews. Elasticsearch 8.x has official ARM64 packages for Ubuntu. The Wazuh project ships ARM64 `.deb` packages for Ubuntu 24.04.

---

## Decision 6: Sliver C2 over Cobalt Strike / Metasploit for Red Team

**Date:** 2026-05-11  
**Status:** Final

**Decision:** Use Sliver as the primary C2 framework for attack simulation.

**Alternatives considered:**

| Option | Pros | Cons |
|--------|------|------|
| **Sliver** (chosen) | Free, open-source, actively maintained; realistic enterprise C2 behavior; ARM64 implant support; mTLS + HTTP/DNS C2 channels; good detection evasion for realistic detections | Newer; less widely known than Cobalt Strike |
| Cobalt Strike | Industry standard; most realistic; what red teams actually use | $3,500/year license; cannot use in a public portfolio lab; licensing prohibits redistribution |
| Metasploit | Free; widely known | Meterpreter is heavily signatured; doesn't test realistic detection scenarios |
| Havoc C2 | Modern; good evasion | Less mature; ARM64 implant support is inconsistent |

**Rationale:** Sliver provides realistic C2 behavior (mTLS, HTTP/2, DNS) that generates the same kind of detectable traffic as commercial C2 frameworks, without licensing restrictions. ARM64 native implants work on Windows 11 ARM64. Sliver is increasingly used by real threat actors (CISA advisory 2023), making detections developed against it directly applicable.

---

## Decision 7: Public GitHub Repo

**Date:** 2026-05-11  
**Status:** Final

**Decision:** Make the repository public.

**Rationale:** This is a portfolio project. Public visibility allows FAANG security hiring managers and recruiters to review the work directly. All credentials, keys, and sensitive configuration are excluded via `.gitignore` and Ansible vault. No real infrastructure IPs or credentials are committed. The attack simulation tools (Sliver, ART) are documented as references, not deployed binaries.

**Risk mitigation:** Pre-commit hooks (to be added in Phase 7) will scan for accidental secret commits using `truffleHog` or `git-secrets`.

---

## Decision 8: Role Variable Naming — Semantic Prefix over Role Prefix

**Date:** 2026-05-11  
**Status:** Final

**Decision:** Use semantically meaningful variable prefixes (`elasticsearch_`, `kibana_`, `logstash_`) within the `elk` role rather than the role-name prefix (`elk_elasticsearch_`, `elk_kibana_`).

**Rationale:** The ansible-lint `var-naming[no-role-prefix]` rule requires role variables to be prefixed with the role name. However, `elk_elasticsearch_heap_size` is redundant — the `elasticsearch_` prefix already scopes the variable. The Ansible community convention for widely-adopted roles (e.g., `geerlingguy.elasticsearch`) uses the service name as prefix. This rule is suppressed in `.ansible-lint` with a `skip_list` entry.

---

## Decision 9: ansible-lint `name[play]` Suppressed for `import_playbook`

**Date:** 2026-05-11  
**Status:** Final

**Decision:** Suppress `name[play]` in `.ansible-lint`.

**Rationale:** The `site.yml` master playbook uses `import_playbook` directives which cannot carry a `name:` attribute — they inherit names from the imported playbooks. ansible-lint 26.x incorrectly flags these as unnamed plays. The rule is skipped globally since all actual plays within the imported playbooks are named.

---

## Decision 10: Windows Sysmon Binary — Sysmon64a.exe (ARM64 Native)

**Date:** 2026-05-11  
**Status:** Final

**Decision:** Use `Sysmon64a.exe` (ARM64-native) instead of `Sysmon64.exe` (x86_64) on the Windows 11 ARM64 victim VM.

**Alternatives considered:**

| Option | Pros | Cons |
|--------|------|------|
| `Sysmon64a.exe` (chosen) | Native ARM64 — runs at hardware speed; no emulation | Requires ARM64 Sysmon (ships in the same zip as of Sysmon 14+) |
| `Sysmon64.exe` (x86_64) | Works via WOW64 emulation on ARM64 | ~10–20% CPU overhead; potential event volume impact |

**Rationale:** Since the entire lab is ARM64-native, using the native Sysmon binary reduces CPU overhead. The Sysinternals `Sysmon.zip` includes both `Sysmon64.exe` (x64) and `Sysmon64a.exe` (ARM64) as of Sysmon 14.x. The service name for the ARM64 binary is `Sysmon64a` (not `Sysmon64`).

---

## Decision 11: Filebeat on Windows — x86_64 Binary under WOW64

**Date:** 2026-05-11  
**Status:** Final

**Decision:** Use Filebeat x86_64 Windows binary on the ARM64 Windows victim VM (no native ARM64 Filebeat binary for Windows exists).

**Rationale:** Elastic does not ship a native ARM64 Filebeat binary for Windows as of Filebeat 8.x. The x86_64 binary runs under Windows 11 ARM64's built-in WOW64 (Windows on Windows 64-bit) x86_64 emulation layer, which is hardware-accelerated on Apple Silicon. Performance impact is acceptable for the low event volume of a single-VM lab.

**Future:** If Elastic ships native ARM64 Windows binaries, update `filebeat_windows_download_url` in `ansible/roles/filebeat/defaults/main.yml`.
