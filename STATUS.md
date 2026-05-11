# Project Status

Last updated: 2026-05-11

## Phase Overview

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1 | ✅ Complete | Repository Bootstrap + Architecture Documentation |
| Phase 2 | ⏳ Next | Ansible Automation |
| Phase 3 | 🔜 Planned | Detection Rules |
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

## Phase 2: Ansible Automation — ⏳ NEXT

**Goal:** Fully automated provisioning of wazuh-manager, victim-windows, and kali-attacker VMs from a single `ansible-playbook site.yml` command.

**Planned work:**
- [ ] `roles/common` — base OS hardening, hostname, NTP, fail2ban
- [ ] `roles/wazuh` — Wazuh manager install + ossec.conf template
- [ ] `roles/elk` — Elasticsearch + Logstash + Kibana install + ILM policy
- [ ] `roles/sysmon` — WinRM-based Sysmon + SwiftOnSecurity config deploy
- [ ] `roles/filebeat` — Filebeat install + Wazuh pipeline config
- [ ] `roles/hardening` — UFW rules, sshd hardening, auditd
- [ ] `ansible/playbooks/site.yml` — orchestrates all roles in dependency order
- [ ] Ansible vault for credential management
- [ ] WinRM setup on Windows (required before Ansible can manage it)

**Estimated time:** 4–6 hours

---

## Phase 3: Detection Rules — 🔜 PLANNED

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
