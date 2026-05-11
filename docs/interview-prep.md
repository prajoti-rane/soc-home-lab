# Interview Prep — SOC Lab Questions

Expected interview questions about this project, with answers grounded in what this lab actually demonstrates.

## Design Questions

**Q: Walk me through the architecture of your SOC lab.**

> I built a 3-VM environment on macOS Apple Silicon using UTM as the ARM64-native hypervisor. The wazuh-manager VM (Ubuntu 24.04, 192.168.64.10) runs Wazuh SIEM, Elasticsearch, Logstash, and Kibana. The victim-windows VM (Windows 11 ARM64, 192.168.64.20) has Sysmon with SwiftOnSecurity ruleset and a Wazuh agent that forwards events over OSSEC protocol (UDP 1514). The kali-attacker VM (Kali 2024.x, 192.168.64.30) has Sliver C2 and Atomic Red Team for simulating attacks. All VMs are on an isolated UTM shared network (192.168.64.0/24) — no lab traffic reaches the home LAN.

**Q: Why did you choose Wazuh over Splunk or Elastic SIEM?**

> Wazuh is free and open-source with native ARM64 packages for Ubuntu, which was essential since I'm running on Apple Silicon. Splunk's free tier has a 500 MB/day ingest limit and no native ARM64 package — it would run under Rosetta emulation. Wazuh also ships with 3,000+ built-in rules, a MITRE ATT&CK overlay in Kibana, and an official Ansible role. For a portfolio project targeting FAANG roles, it demonstrates the same concepts as Splunk at 1/10th the cost.

**Q: How does the log pipeline work end-to-end?**

> Sysmon on Windows generates structured XML events (EventIDs 1, 3, 7, 10, 11, 13, 22) into the Windows Event Log. The Wazuh agent reads those channels in real-time and forwards over OSSEC protocol (TLS-encrypted) to the Wazuh manager. The manager runs XML decoders to parse fields, then applies the rule engine. Alerts with level ≥ 3 are written to `wazuh-alerts-*` in Elasticsearch. In parallel, Filebeat ships the full event archive to Logstash, which enriches and normalizes before indexing to `wazuh-archives-*`. Kibana visualizes both indices.

---

## Detection Engineering Questions

**Q: How did you validate that your detection rules work?**

> I used Atomic Red Team — each rule is paired with a specific ART test that executes the technique, and I verify in Kibana that the alert fires within 15 seconds. I record the rule ID, level, and key fields for each test in a test-case document. I also measure false-positive rate by running a "benign baseline" — 30 minutes of normal Windows activity — and checking whether any high-severity rules fire incorrectly.

**Q: How would you reduce false positives in a production SIEM?**

> First, I'd baseline normal activity — what processes run daily, what parent-child relationships are common. Then I'd tune rules with exceptions for known-good activity (e.g., a rule that fires on processes spawned from Office can be scoped to exclude processes in `C:\Program Files`). In Wazuh, I add level-0 override rules for specific exceptions. Long-term, I'd implement a tiered alerting model: high-fidelity rules → immediate alert; medium-fidelity → queue for analyst triage; low-fidelity → aggregate and review weekly.

**Q: What's the MITRE ATT&CK technique you find hardest to detect?**

> T1055 (Process Injection) in its reflective DLL variant. Sysmon EventID 8 (CreateRemoteThread) catches the naive case, but reflective injection loads the DLL directly into memory without CreateRemoteThread. Detection requires either memory scanning (which Wazuh doesn't do natively) or behavioral heuristics — a process suddenly gaining new network connections after an unusual OpenProcess call (EventID 10). In this lab I'm focused on the EventID 10 path; for production, I'd layer EDR telemetry on top.

---

## Incident Response Questions

**Q: Walk me through the incident response process from a Sliver C2 session.**

> I start with the Kibana alert that fired — for example, rule 100200 (suspicious process in writable path). I click into the alert to get the full Sysmon EventID 1 data: process image, parent, command line, hash, user. I note the timestamp and search backwards for what preceded it — typically an EventID 11 (file create) showing the implant being dropped, and an EventID 3 (network connection) showing the download. Then I search forward for what followed — EventID 13 for persistence, EventID 10 if LSASS was accessed. This builds the timeline. I record all IOCs (file hash, registry key, C2 IP) and produce a structured incident report.

**Q: How would you contain a compromised endpoint?**

> In the lab, I suspend the UTM VM immediately — this preserves memory state for forensics. In production, I'd use network isolation first (pull it off the LAN via NAT rules or EDR agent kill-switch), then collect a memory dump and forensic disk image before any remediation. I'd also check for lateral movement — were any other hosts contacted from the compromised machine in the 24 hours before detection? The Wazuh agent should still be forwarding events even after isolation, so I can continue monitoring.

---

## Infrastructure / IaC Questions

**Q: How does your Ansible automation work?**

> I have a site.yml master playbook that applies four roles in sequence: common (base OS hardening, packages, UFW, fail2ban), wazuh (installs Wazuh manager, deploys ossec.conf template), elk (Elasticsearch + Logstash + Kibana with JVM heap tuning and ILM policy), and hardening (sshd lockdown, sysctl parameters). For Windows, a separate role uses the ansible.windows collection over WinRM to deploy Sysmon with the SwiftOnSecurity config. The inventory uses static IPs so there's no DNS dependency.

**Q: Why didn't you use Terraform?**

> There's no Terraform provider for UTM or local QEMU on macOS. Terraform is designed for cloud and API-driven infrastructure. UTM's VM lifecycle is GUI-only (or UTM's AppleScript API, which is limited). Ansible handles everything post-boot — it's the right tool for configuration management, not infrastructure provisioning in this case. If I were building this in the cloud (AWS/GCP), I'd use Terraform for the VM provisioning and Ansible for post-boot configuration.

---

## Behavioral / Situational Questions

**Q: What would you add if you had another month?**

> MISP (Malware Information Sharing Platform) for threat intelligence correlation — so Wazuh can cross-reference IOCs against the MISP database in real time. A VyOS ARM64 router VM for proper VLAN microsegmentation between the red-team and blue-team networks. And a vulnerable Active Directory domain (Bad Blood or similar) to practice Kerberoasting, Pass-the-Hash, and BloodHound enumeration — the techniques that come up most in FAANG security interviews.
