# Extending the Lab

Ideas and guidance for expanding the SOC lab beyond its initial scope.

## Phase 8+ Extensions

### Add a Vulnerable Active Directory Domain

Add two more VMs:
- `dc-01` (Windows Server 2022 ARM64, 192.168.64.40) — Domain Controller
- `workstation-02` (Windows 11 ARM64, 192.168.64.21) — Domain-joined endpoint

New attack techniques unlocked:
- T1558.003 (Kerberoasting) — detected via EventID 4769 + Wazuh rule
- T1550.002 (Pass-the-Hash) — Sysmon EventID 10 + EventID 4624 type 3
- T1087.002 (Domain Account Enumeration) — EventID 4661, BloodHound detection
- T1484.001 (Group Policy Modification) — EventID 5136

### Add MISP Threat Intelligence

- `misp-server` (Ubuntu 22.04 ARM64, 192.168.64.50)
- Integrate Wazuh → MISP: alerts auto-query MISP for IOC enrichment
- Import threat feeds: CIRCL OSINT, VirusTotal
- Enables correlation of lab IOCs against real-world threat data

### Add Network IDS (Zeek / Suricata)

Deploy Zeek or Suricata on the wazuh-manager in "monitor" mode with a mirrored interface:
- Zeek: protocol analysis, JA3 TLS fingerprinting for C2 detection
- Suricata: signature-based detection of known attack traffic (Sliver HTTPS, Cobalt Strike JA3)
- Feed alerts into Wazuh via Filebeat

### Add a Proxy for HTTP/S Inspection

Mitmproxy on Kali for transparent SSL inspection:
- Decrypt Sliver HTTPS C2 traffic (in lab — cert pinning disabled on implant)
- Log HTTP downloads that trigger alert chain
- Export decrypted traffic to Wireshark for packet-level analysis

### Cloud Mirror

Mirror the lab architecture to AWS/GCP for comparison:
- AWS: EC2 Graviton3 (ARM64) instances for VMs
- Terraform for provisioning, same Ansible roles for configuration
- Compare cloud SIEM costs (AWS Security Hub, GuardDuty) vs. self-hosted Wazuh

## Resource Budget for Extensions

| Extension | Additional vCPU | Additional RAM | Additional Disk |
|-----------|-----------------|---------------|----------------|
| AD Domain (2 VMs) | 4 cores | 6 GB | 80 GB |
| MISP | 4 cores | 4 GB | 20 GB |
| Zeek/Suricata | 2 cores | 2 GB | 10 GB |

**Extended total:** ~24 cores, ~32 GB RAM, ~250 GB disk  
**Recommended Mac:** M2 Pro 32 GB / M3 Max

## Skills Unlocked by Extensions

| Extension | New Skills Demonstrated |
|-----------|------------------------|
| AD Domain | Kerberos attacks, AD enumeration, GPO abuse, domain trust exploitation |
| MISP | Threat intelligence, IOC correlation, CTI workflow |
| Zeek | Network forensics, JA3 fingerprinting, protocol anomaly detection |
| Cloud mirror | Cloud security architecture, IaC at scale, hybrid SIEM |
