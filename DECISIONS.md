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

---

## Decision 12: One XML File Per Detection Topic (Not a Single local_rules.xml)

**Date:** 2026-05-11
**Status:** Final

**Decision:** Store each detection topic in its own XML file (`100001-brute-force-ssh.xml`, etc.) rather than a single `local_rules.xml`.

**Alternatives considered:**

| Option | Pros | Cons |
|--------|------|------|
| **Per-topic XML files** (chosen) | Git diff is scoped to one technique; easy to enable/disable individual rules; clear PR scope | Requires copying multiple files to `/var/ossec/etc/rules/` |
| Single local_rules.xml | Matches Wazuh default layout; one file to deploy | All rules in one diff; harder to review; disabling one rule risks breaking adjacent rules |

**Rationale:** Detection engineering benefits from atomic, reviewable units. A PR adding a brute-force rule should not touch credential-dumping rules. Per-file structure also enables `ansible copy` to selectively deploy rule subsets per environment.

---

## Decision 13: Compound Rules (Base → Threshold → Critical) Within Each File

**Date:** 2026-05-11
**Status:** Final

**Decision:** Use a 2–3 rule chain within each XML file: a base classifier rule (level 6), a threshold rule that fires after N matches (level 10–12), and optionally a compound critical rule (level 14) for kill-chain correlation.

**Rationale:** Wazuh's `if_matched_sid` + `frequency` + `timeframe` mechanism requires a parent rule to count against. A single monolithic rule at level 14 would either fire on every event (no threshold) or require complex external state. The 3-level chain provides graduated alert severity that maps to SIEM triage workflows: level 6 → informational, 10–12 → medium/high priority, 14 → critical / auto-page.

---

## Decision 14: pcre2 for Field Matching, not Plain String Match

**Date:** 2026-05-11
**Status:** Final

**Decision:** Use `type="pcre2"` on all `<field>` elements in custom Wazuh rules.

**Rationale:** Wazuh's default field match is case-sensitive substring. Windows paths and process names are case-inconsistent (e.g., `powershell.exe` vs `PowerShell.exe`). Using `pcre2` with `(?i)` flag enables case-insensitive matching without maintaining multiple rule variants. The `negate="yes"` attribute on `<field>` enables allowlist exclusions without requiring a separate rule group.

---

## Decision 15: Sigma Rules as Parallel Documentation, Not Primary Detection

**Date:** 2026-05-11
**Status:** Final

**Decision:** Sigma rules in `detections/sigma/` are documentation and portability artifacts. The Wazuh XML rules in `detections/wazuh-rules/` are the deployed detection mechanism.

**Rationale:** No Sigma-to-Wazuh converter produces valid XML that passes `wazuh-logtest` without manual adjustment. Writing both formats ensures: (1) detection logic can be exported to any SIEM platform for interviews or future employer environments; (2) detection engineering methodology is visible in the portfolio even if the reviewer is unfamiliar with Wazuh XML syntax. Sigma rules follow v1 spec with `pySigma` compatibility.

---

## Decision 16: Test Cases in YAML Format with Inline Log Samples

**Date:** 2026-05-11
**Status:** Final

**Decision:** Test case files are YAML (not Markdown) and include inline JSON log sample payloads that can be directly piped to `wazuh-logtest`.

**Rationale:** YAML test files are machine-parseable by `validate-detections.sh`, enabling automated validation without a running Wazuh agent. Inline log samples eliminate the need to search for sample events; a reviewer can paste the JSON directly into wazuh-logtest and see the rule fire. This is more valuable for portfolio demonstration than narrative-only test case documents.

---

## Decision 17: Sliver over Metasploit as Primary C2 Framework

**Date:** 2026-05-11
**Status:** Final

**Decision:** Use Sliver C2 for all attack simulation content, not Metasploit/Meterpreter.

**Rationale:** Meterpreter is so heavily signatured by AV and EDR tools that detections built against it are nearly useless for validating production-grade security controls. Sliver generates realistic mTLS/HTTPS/DNS C2 traffic used by real APTs (documented in CISA AA23-025A 2023). Detections that catch Sliver traffic are directly operationally relevant. Additionally, Sliver ships native ARM64 Windows implants, which is a hard requirement for our Windows 11 ARM64 victim VM — Metasploit's Windows payloads do not have ARM64-native builds.

---

## Decision 18: Attack Scenarios as Standalone Markdown (Not Scripts)

**Date:** 2026-05-11
**Status:** Final

**Decision:** Write attack scenarios as step-by-step Markdown documents rather than fully automated shell scripts.

**Alternatives considered:**

| Option | Pros | Cons |
|--------|------|------|
| **Markdown step-by-step** (chosen) | Reviewer can read and understand each step; operator must consciously execute each command; no accidental automation; good for interview walk-through | Slower to execute than a script |
| Fully automated attack script | Fast to run; reproducible | Dangerous — a single script could chain destructive commands; bad for portfolio (looks like an attack tool rather than a security engineering demo) |
| Ansible playbook | Idempotent; modular | Unnecessary complexity for one-time scenarios; attack playbooks feel jarring alongside provisioning playbooks |

**Rationale:** In a security engineering interview, the ability to explain each step of the kill chain matters more than automation speed. Markdown scenarios are readable artifacts that demonstrate depth of understanding. They also enforce the safety requirement that each step requires conscious operator action.

---

## Decision 19: runner.ps1 Extension (Not runner.sh)

**Date:** 2026-05-11
**Status:** Final

**Decision:** The Atomic Red Team runner is saved as `runner.ps1` (PowerShell), not `runner.sh` (Bash).

**Rationale:** The task specification described "runner.sh" but stated it was a "PowerShell script that runs on Windows victim." PowerShell scripts use the `.ps1` extension; running a `.sh` file on Windows requires WSL or Cygwin, adding unnecessary complexity. The `.ps1` extension makes the script directly executable via `.\runner.ps1` in any Windows PowerShell session. This naming is consistent with ART's own PowerShell module conventions.

---

## Decision 20: ISO SHA256 Hashes as Placeholders in download-isos.sh

**Date:** 2026-05-11
**Status:** Final

**Decision:** The `scripts/download-isos.sh` script uses placeholder SHA256 values for the ISO checksums rather than hardcoding the current release hashes.

**Rationale:** ISO checksums change with every new release (Ubuntu 24.04.1 → 24.04.2 → etc.). Hardcoding a specific hash that becomes outdated on the next point release would cause false verification failures and confuse users. The script prominently documents where to obtain the current hash (official Ubuntu and Kali release pages) and warns users to verify before use. This follows the same pattern as Ansible's package installation (which always installs "latest") — the code stays correct over time while the user verifies currency at execution time.

---

## Decision 21: Sysmon Config — SwiftOnSecurity Base + Lab Customizations

**Date:** 2026-05-11
**Status:** Final

**Decision:** Use SwiftOnSecurity's `sysmonconfig-export.xml` as the base configuration, with lab-specific customizations added programmatically by `generate-sysmon-config.sh`.

**Alternatives considered:**

| Option | Pros | Cons |
|--------|------|------|
| **SwiftOnSecurity + custom script** (chosen) | Industry-standard base; maintained by community; lab additions are traceable in git diff | Requires re-running script after SwiftOnSecurity updates |
| Olaf Hartong's Sysmon Modular | More granular per-technique control | Heavier config; harder to explain in an interview |
| Fully custom config | Total control | Maintenance burden; likely to miss important event types |

**Rationale:** SwiftOnSecurity's config is the most widely-recognized Sysmon configuration in the security community and is referenced in countless detection engineering guides. Using it as a base signals familiarity with community standards. The script approach (rather than committing a static file) means the config can be regenerated with the latest SwiftOnSecurity version at any time, keeping the lab current with newly discovered attacker techniques.

---

## Decision 22: Incident Reports Written as Real Analyst Documents (Not Templates)

**Date:** 2026-05-11
**Status:** Final

**Decision:** The three example incident reports are fully written with realistic synthetic data — UTC timestamps, MITRE technique coverage, specific Sysmon field values, Kibana queries, and action items — rather than as annotated templates with placeholder text.

**Rationale:** Placeholder-filled examples ("insert your timeline here") have low portfolio value because they show only that the analyst knows a template exists. Fully written reports show that the analyst can: (1) reconstruct a timeline from log sources, (2) extract and classify IOCs, (3) map observations to ATT&CK techniques with supporting evidence, (4) identify detection gaps, and (5) communicate findings at both executive and technical levels. These are exactly the competencies evaluated in FAANG security engineering interviews. All data is synthetic but internally consistent and plausible.

---

## Decision 23: Report Numbering IR-YYYY-NNN (Not Per-Quarter or Per-Severity)

**Date:** 2026-05-11
**Status:** Final

**Decision:** Incident reports are numbered sequentially within the year (`IR-2026-001`, `IR-2026-002`, etc.) regardless of severity or scenario type.

**Rationale:** Year-sequential numbering is the most widely used convention in enterprise IR teams (used at Google, Microsoft, and most MSSPs). Per-quarter numbering (`IR-2026-Q2-001`) adds information that becomes stale as the quarter ends and confuses cross-quarter searches. Per-severity numbering (`IR-CRIT-001`) leaks internal severity assessments in external communications. The year-sequential format is immediately recognizable to any security engineer reviewing the portfolio.

---

## Decision 24: Corrected Rule IDs in Incident Reports vs. Task Specification

**Date:** 2026-05-11
**Status:** Final

**Decision:** Used correct Wazuh rule IDs from Phase 3 in the incident reports rather than the rule IDs listed in the Phase 5 task specification, which contained two errors.

**Errors in task specification:**
- IR-2026-001 (credential dumping): task said "Wazuh Rule 100003 fired" — 100003 is the RDP brute force rule. Correct rule is **100005** (LSASS ProcessAccess, T1003.001).
- IR-2026-002 (C2 beaconing): task said "Wazuh Rule 100005 fired" — 100005 is the LSASS rule. Correct rules are **100009/100010/100011** (network connection frequency, T1071.001).

**Rationale:** Incident reports are the most publicly visible artifact in this portfolio — they will be read by security engineers who know Wazuh and MITRE. Using incorrect rule IDs would undermine credibility. The correct rule IDs are derived from the authoritative source: Phase 3 Wazuh XML files in `detections/wazuh-rules/`.

---

## Decision 25: Detection Gap Sections Written Honestly (Including SIEM Compromise Gap)

**Date:** 2026-05-11
**Status:** Final

**Decision:** Detection gaps in incident reports are documented candidly, including the case where the SIEM itself was compromised (IR-2026-003) and the attacker read active alert data.

**Rationale:** Deliberately revealing architectural weaknesses (e.g., "the SIEM was reachable via password-auth SSH and had world-readable config files") might seem counterproductive in a portfolio. However, security engineering interviews at FAANG specifically probe for this analytical honesty — the ability to identify and articulate your own blind spots is a sign of mature security thinking. A report that only documents successful detections and omits gaps would look incomplete to any experienced reviewer. The action items section shows that gaps are not just acknowledged but addressed.
