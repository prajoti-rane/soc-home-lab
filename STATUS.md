# Project Status

Last updated: 2026-05-12 (Phase 6 complete)

## Phase Overview

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1 | ✅ Complete | Repository Bootstrap + Architecture Documentation |
| Phase 2 | ✅ Complete | Ansible Automation |
| Phase 3 | ✅ Complete | Detection Rules |
| Phase 4 | ✅ Complete | Attack Simulation Scripts |
| Phase 5 | ✅ Complete | Incident Reports (3 forensic reports) |
| Phase 6 | ✅ Complete | Runbook (Human-Executable Steps) |
| Phase 7 | ⏳ Next | Documentation Polish + CI/CD |

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

## Phase 3: Detection Rules — ✅ COMPLETE

**Goal:** Custom Wazuh rules and Sigma signatures covering key MITRE ATT&CK techniques with validated test cases.

**Delivered:**
- [x] `detections/wazuh-rules/100001-brute-force-ssh.xml` — SSH brute-force + success compound (T1110.001)
- [x] `detections/wazuh-rules/100003-brute-force-rdp.xml` — RDP EventID 4625 brute-force + success (T1110.001, T1021.001)
- [x] `detections/wazuh-rules/100005-credential-dumping-lsass.xml` — Sysmon EID 10 LSASS access (T1003.001)
- [x] `detections/wazuh-rules/100006-suspicious-powershell.xml` — Encoded/bypass PowerShell, 3-level chain (T1059.001, T1027)
- [x] `detections/wazuh-rules/100009-c2-beaconing.xml` — Repeated outbound connections from writable-path binary (T1071.001)
- [x] `detections/wazuh-rules/100012-lateral-movement-psexec.xml` — PsExec service install + remote credential (T1021.002)
- [x] `detections/wazuh-rules/100015-defender-tampering.xml` — Registry Defender exclusion + Set-MpPreference (T1562.001)
- [x] `detections/wazuh-rules/100017-suspicious-scheduled-task.xml` — schtasks with scripting/encoded payload (T1053.005)
- [x] `detections/wazuh-rules/README.md` — Rule table, deployment instructions, correlation notes
- [x] 8 Sigma rules in `detections/sigma/` — portable format with logsource categories, aggregation conditions, UUIDs
- [x] `detections/sigma/README.md` — Sigma conversion instructions for Wazuh, Splunk, Sentinel, Elastic
- [x] 8 YAML test cases in `detections/test-cases/` — positive + negative tests with inline JSON log samples
- [x] `detections/test-cases/README.md` — Full kill-chain test sequence, ART commands, test file format
- [x] `scripts/validate-detections.sh` — Automated PASS/FAIL validation via wazuh-logtest over SSH
- [x] DECISIONS.md updated (decisions 12–16: per-file rules, compound chain, pcre2, Sigma as documentation, YAML test format)

---

## Phase 4: Attack Simulation Scripts — ✅ COMPLETE

**Goal:** Documented, repeatable attack scenarios with Sliver C2 and Atomic Red Team.

**Delivered:**
- [x] `attack-simulation/sliver/README.md` — Complete Sliver operator guide (ARM64-specific): server setup, HTTPS listener, implant generation, C2 operations (shell/upload/download/screenshot/LSASS), Kibana correlation table
- [x] `attack-simulation/sliver/setup-sliver.sh` — ARM64-aware installer: downloads server+client binaries, creates systemd service, initializes PKI, prints operator next-steps
- [x] `attack-simulation/atomic-red-team/README.md` — ART installation, per-technique execution guide, detection coverage map, expected alert latency table, Kibana correlation queries
- [x] `attack-simulation/atomic-red-team/runner.ps1` — PowerShell test runner with DryRun/TechniquesOnly/SkipCleanup params, per-test prereq checking, 30s Wazuh wait, Defender re-enable guard, results log
- [x] `attack-simulation/atomic-red-team/test-plan.md` — Full table: 8 rules × technique × test number × admin requirement × cleanup command; detailed per-test procedures; pass/fail criteria
- [x] `attack-simulation/attack-scenarios/01-initial-access-c2.md` — Sliver C2 implant delivery + beaconing (T1071.001, T1059.001)
- [x] `attack-simulation/attack-scenarios/02-credential-dumping.md` — LSASS dump via ART/Sliver/procdump (T1003.001)
- [x] `attack-simulation/attack-scenarios/03-lateral-movement.md` — SSH brute force + PsExec (T1110.001, T1021.002)
- [x] `attack-simulation/attack-scenarios/04-persistence.md` — Scheduled task + Defender tamper (T1053.005, T1562.001)
- [x] `attack-simulation/attack-scenarios/05-full-kill-chain.md` — Capstone: all 8 rule groups fire; interview demo scenario
- [x] `scripts/download-isos.sh` — Ubuntu + Kali ARM64 ISO downloader with SHA256 verify; Windows 11 UUPDump manual instructions
- [x] `scripts/generate-sysmon-config.sh` — Downloads SwiftOnSecurity config, applies lab customizations, validates XML, installs to ansible/roles/sysmon/files/
- [x] DECISIONS.md updated (D17–D21: Sliver rationale, Markdown scenarios, .ps1 extension, ISO placeholders, Sysmon config strategy)

---

## Phase 5: Incident Reports — ✅ COMPLETE

**Goal:** Professional incident reports documenting attack simulations as real SOC analyst investigations.

**Delivered:**
- [x] `incident-reports/TEMPLATE.md` — Full professional IR template (classification, exec summary, UTC timeline, IOCs, MITRE mapping, detection gaps, action items, appendix)
- [x] `incident-reports/IR-2026-001-credential-dumping.md` — Critical: LSASS dump via procdump (T1003.001); Rule 100005 fired in <1s; root cause: no PPL/Credential Guard; 5 action items
- [x] `incident-reports/IR-2026-002-c2-beaconing.md` — Critical: Sliver HTTPS implant (T1071.001); Rules 100009/100010/100011; 32 beacons; 16-min window before critical alert; beacon timing analysis
- [x] `incident-reports/IR-2026-003-brute-force-lateral-movement.md` — High: SSH brute force (487 attempts) + PsExec lateral movement (T1110.001 + T1021.002); SIEM compromise documented; 8 action items
- [x] `incident-reports/README.md` — Report index, naming convention, severity criteria, SOC workflow diagram, FAANG interview relevance guide
- [x] DECISIONS.md updated (D22–D25: real documents, sequential numbering, rule ID corrections, honest gap analysis)

---

## Phase 6: Runbook — ✅ COMPLETE

**Goal:** Complete click-by-click instructions for building the lab from scratch on a fresh Mac.

**Delivered:**
- [x] `runbook/README.md` — Overview: 6–8 hour estimate, prereq checklist, dependency graph, conventions, quick-start
- [x] `runbook/01-prerequisites.md` — Full prereq guide: UTM, Homebrew, tools, SSH keys, ISO downloads, verification checklist
- [x] `runbook/02-utm-vm-creation.md` — Click-by-click VM creation: full Ubuntu installer selections, Windows OOBE bypass, Kali installer, post-creation SSH verification
- [x] `runbook/03-network-setup.md` — UTM network modes explained, static IP config for all 3 VMs (netplan/PowerShell/nmcli), full mesh connectivity test, 7 troubleshooting scenarios
- [x] `runbook/04-wazuh-elk-install.md` — Option A (Wazuh all-in-one) + Option B (Ansible); expected output; custom rule deployment; troubleshooting
- [x] `runbook/05-sysmon-setup.md` — Sysmon ARM64 install, SwiftOnSecurity config, event ID reference, tamper protection, troubleshooting
- [x] `runbook/06-agent-deployment.md` — Windows + Linux agent install, ossec.conf event channel config, live event verification, Kibana validation
- [x] `runbook/07-kali-setup.md` — Sliver C2, ART dependencies, additional tools, WinRM setup, tool verification, network reachability
- [x] `runbook/08-attack-simulation.md` — Pre-flight checklist, quick-run commands for all 5 scenarios, real-time monitoring guide, screenshot guide, cleanup
- [x] `runbook/09-detection-validation.md` — validate-detections.sh, wazuh-logtest manual tests, 19-rule validation matrix, Kibana coverage review, Elasticsearch query, rule tuning
- [x] `runbook/MANUAL_STEPS.md` — Consolidated GUI reference: UTM VM creation, Ubuntu installer selections, Windows OOBE, VirtIO driver, static IP, Defender disable, UTM snapshots, Kibana dashboard setup
- [x] `scripts/check-prereqs.sh` — PASS/FAIL/WARN prerequisite check (architecture, UTM, tools, SSH keys, disk, RAM, repo, ISOs)
- [x] DECISIONS.md updated (D26–D30: installer choice, standalone prereq script, VM creation placement, troubleshooting sections, completion checklists)

---

## Phase 7: Documentation Polish + CI/CD — ⏳ NEXT

**Goal:** Production-quality documentation and passing CI badges.

**Planned work:**
- [ ] Fix all markdown-lint warnings
- [ ] Verify ansible-lint passes on all playbooks
- [ ] Add truffleHog pre-commit hook to prevent secret commits
- [ ] Add MITRE ATT&CK navigator layer JSON to `detections/`
- [ ] Add architecture diagrams as rendered PNG exports
- [ ] `docs/resume-bullets.md` — finalized bullets per role type
- [ ] `docs/interview-prep.md` — expected interview questions + answers
