# Project Status

Last updated: 2026-05-11

## Phase Overview

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1 | ✅ Complete | Repository Bootstrap + Architecture Documentation |
| Phase 2 | ✅ Complete | Ansible Automation |
| Phase 3 | ⏳ Next | Detection Rules |
| Phase 4 | 🔜 Planned | Attack Simulation Scripts |
| Phase 5 | 🔜 Planned | Incident Report Templates |
| Phase 6 | 🔜 Planned | Runbook (Human-Executable Steps) |
| Phase 7 | 🔜 Planned | Documentation Polish + CI/CD |

---

## Phase 1: Repository Bootstrap + Architecture — ✅ COMPLETE

- [x] GitHub repository created (public)
- [x] Full directory structure scaffolded
- [x] `.gitignore` (macOS, Python, Ansible, secrets, ISOs)
- [x] MIT LICENSE
- [x] `architecture/network-diagram.md` — Mermaid topology diagram
- [x] `architecture/data-flow.md` — Log pipeline with Mermaid + stage detail
- [x] `architecture/threat-model.md` — Full STRIDE analysis (6 categories, 20+ threats)
- [x] `architecture/vm-specs.md` — VM inventory table + host requirements
- [x] `README.md` — FAANG-portfolio hero README with badges, diagrams, resume bullets
- [x] `DECISIONS.md` — 7 architecture decision entries
- [x] `STATUS.md` — This file
- [x] Runbook stubs (all 11 files)
- [x] Ansible skeleton (inventory, cfg, requirements, playbooks, roles)
- [x] Detection, attack-sim, incident, dashboard, scripts, docs stubs
- [x] GitHub Actions workflow stubs (ansible-lint, yaml-lint, markdown-lint)
- [x] Initial commit pushed to `origin/main`

---

## Phase 2: Ansible Automation — ✅ COMPLETE

**Goal:** Fully automated provisioning of wazuh-manager, victim-windows, and kali-attacker VMs from a single `ansible-playbook site.yml` command.

**Delivered:**
- [x] `ansible/inventory.yml` — 3 hosts (siem, victims, attackers groups), WinRM for Windows
- [x] `ansible/ansible.cfg` — optimized settings (pipelining, fact caching, yaml callback)
- [x] `ansible/requirements.yml` — ansible.windows, ansible.posix, community.general
- [x] `ansible/.ansible-lint` — basic profile config, skip list for non-actionable rules
- [x] `roles/common` — apt update, base packages (jq, chrony NTP, fail2ban, auditd), hostname, /etc/hosts, UFW
- [x] `roles/wazuh` — GPG key (dearmored), apt repo, wazuh-manager install, `ossec.conf.j2` template, `local_rules.xml` placeholder, UFW ports 1514/1515/55000, service verify
- [x] `roles/elk` — Elasticsearch 8.x (2g heap, xpack.security=false), Logstash pipeline (`logstash-pipeline.conf.j2`), Kibana, UFW ports, ES health check
- [x] `roles/sysmon` — Windows ARM64 via WinRM, `Sysmon64a.exe` (native ARM64), SwiftOnSecurity `sysmonconfig-export.xml`, event log size increase
- [x] `roles/filebeat` — OS-conditional (Linux: apt + Wazuh pipeline; Windows: x64 WOW64 binary), templates `filebeat-linux.yml.j2` + `filebeat-windows.yml.j2`
- [x] `roles/hardening` — sshd 8-parameter lockdown, fail2ban, sysctl 8 parameters, USB storage disable option
- [x] `playbooks/site.yml` — import_playbook orchestration (wazuh-manager → windows-victim → kali-attacker)
- [x] `playbooks/kali-attacker.yml` — Sliver C2 installer, ART clone, 12 offensive tools, pip3 libs
- [x] Templates: `ossec.conf.j2`, `elasticsearch.yml.j2`, `kibana.yml.j2`, `logstash-pipeline.conf.j2`, `filebeat-linux.yml.j2`, `filebeat-windows.yml.j2`
- [x] **ansible-lint passes: 0 failures, production profile** (run: `cd ansible && ansible-lint playbooks/ roles/`)
- [x] DECISIONS.md updated (decisions 8–11)

---

## Phase 3: Detection Rules — ⏳ NEXT

**Goal:** Custom Wazuh rules and Sigma signatures covering the 10 MITRE ATT&CK techniques listed in the README, with validated true-positive rates.

**Planned work:**
- [ ] Custom Wazuh XML rules for Sliver C2 IOCs
- [ ] Sysmon EventID 10 rule (LSASS access)
- [ ] PowerShell obfuscated command detection
- [ ] Sigma rules (portable format, convertible to Splunk/QRadar/Sentinel)
- [ ] Test case documents pairing each rule with an ART test ID

---

## Phase 4: Attack Simulation Scripts — 🔜 PLANNED

**Goal:** Documented, repeatable attack scenarios with Sliver C2 and Atomic Red Team.

**Planned work:**
- [ ] Sliver listener + implant generation guide
- [ ] Atomic Red Team test selection (T1059, T1055, T1003, T1070, T1547)
- [ ] Full kill chain scenario: recon → initial access → persistence → credential access → lateral movement → C2 → defense evasion
- [ ] Expected alert list for each attack step

---

## Phase 5: Incident Report Templates — 🔜 PLANNED

**Goal:** One complete incident report from a Sliver C2 kill chain execution.

**Planned work:**
- [ ] Fill in `incident-reports/TEMPLATE.md` with real data from a Sliver session
- [ ] Timeline reconstruction from Kibana
- [ ] IOC extraction (hashes, IPs, registry keys)
- [ ] MITRE ATT&CK navigator layer export

---

## Phase 6: Runbook — 🔜 PLANNED

**Goal:** Complete click-by-click instructions for building the lab from scratch on a fresh Mac.

**Planned work:**
- [ ] Fill in all 9 runbook step files with exact commands + screenshots
- [ ] Test end-to-end on a fresh UTM environment
- [ ] Document all UTM GUI interactions in `MANUAL_STEPS.md`

---

## Phase 7: Documentation Polish + CI/CD — 🔜 PLANNED

**Goal:** Production-quality documentation and passing CI badges.

**Planned work:**
- [ ] Fix all markdown-lint warnings
- [ ] Verify ansible-lint passes on all playbooks
- [ ] Add truffleHog pre-commit hook to prevent secret commits
- [ ] Add MITRE ATT&CK navigator layer JSON to `detections/`
- [ ] Add architecture diagrams as rendered PNG exports
- [ ] `docs/resume-bullets.md` — finalized bullets per role type
- [ ] `docs/interview-prep.md` — expected interview questions + answers
