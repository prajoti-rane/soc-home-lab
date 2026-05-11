# Resume Bullets

Copy-paste ready resume bullets for different role types. Tailor to the specific job description.

## Security Engineer (Detection / SIEM focus)

- **Engineered enterprise SOC home lab** on macOS Apple Silicon (UTM/QEMU ARM64) with Wazuh 4.x SIEM, ELK Stack 8.x, and Kibana — end-to-end log pipeline from Sysmon telemetry to indexed alerts
- **Developed 10+ custom Wazuh detection rules and Sigma signatures** covering MITRE ATT&CK techniques T1059, T1055, T1003, T1070, T1547; validated against Atomic Red Team with documented true-positive confirmation
- **Built automated lab provisioning** with Ansible (6 roles: common, wazuh, elk, sysmon, filebeat, hardening) — reduced setup time from 6+ hours manual to ~45 min idempotent playbook run

## Security Engineer (Red Team / Offensive focus)

- **Executed full Sliver C2 kill chain** on Windows 11 ARM64 VM: implant delivery → persistence (registry run key) → credential access (LSASS dump) → C2 exfiltration — with complete Kibana-sourced incident report and IOC documentation
- **Ran MITRE ATT&CK technique simulations** using Atomic Red Team across 10 techniques (T1059, T1055, T1003, T1070, T1046, T1547, T1021, T1071, T1074, T1053) — validated corresponding Wazuh detection rules for each
- **Deployed Sliver C2 framework** (ARM64-native) on Kali Linux ARM64 with mTLS listener; generated Windows ARM64 implants and documented detection signatures for each C2 channel (HTTPS, DNS)

## Security Engineer (Infrastructure / Cloud focus)

- **Built Security Operations Center home lab** as infrastructure-as-code: Ansible playbooks provision Wazuh SIEM + ELK stack on Ubuntu 24.04 ARM64; CI/CD pipeline (GitHub Actions) enforces ansible-lint and yaml-lint on every commit
- **Architected STRIDE threat model** for lab environment — identified 6 critical/high threats across spoofing, tampering, information disclosure, and privilege escalation categories with corresponding detection rules and mitigations
- **Designed 3-tier network architecture** on macOS UTM hypervisor: SIEM node, victim endpoint, and attacker VM isolated in 192.168.64.0/24 with static IPs, documented network topology, and firewall hardening via UFW + fail2ban

## For LinkedIn "About" or Project Description

Built a fully automated, enterprise-grade SOC home lab on macOS Apple Silicon (UTM ARM64 hypervisor) featuring Wazuh SIEM, ELK Stack, Windows 11 ARM64 endpoint with Sysmon telemetry, and Kali Linux red team VM. The lab simulates realistic attack scenarios using Sliver C2 and Atomic Red Team, validates detection coverage across 10 MITRE ATT&CK techniques, and generates structured incident reports. Infrastructure provisioned via Ansible with GitHub Actions CI/CD. Full documentation at github.com/prajoti-rane/soc-home-lab.

## Skills Tags (for resume skills section)

`Wazuh` `ELK Stack` `Elasticsearch` `Kibana` `Sysmon` `MITRE ATT&CK` `Sigma` `Ansible` `Sliver C2` `Atomic Red Team` `Incident Response` `DFIR` `SIEM` `Threat Detection` `Python` `PowerShell` `Linux` `Windows` `UTM` `QEMU` `ARM64` `CI/CD` `GitHub Actions`
