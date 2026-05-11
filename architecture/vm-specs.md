# VM Specifications

## Virtual Machine Inventory

| VM Name | OS | Architecture | vCPU | RAM | Disk | IP Address | Role |
|---------|----|----|------|-----|------|------------|------|
| wazuh-manager | Ubuntu 24.04 LTS | ARM64 | 4 cores | 8 GB | 60 GB | 192.168.64.10 | SIEM + ELK Stack |
| victim-windows | Windows 11 ARM | ARM64 | 4 cores | 4 GB | 40 GB | 192.168.64.20 | Target endpoint |
| kali-attacker | Kali Linux 2024.x | ARM64 | 4 cores | 4 GB | 40 GB | 192.168.64.30 | Red team / attacker |

**Total resources required:** 12 vCPU · 16 GB RAM · 140 GB disk

---

## Detailed Specifications

### wazuh-manager · 192.168.64.10

| Property | Value |
|----------|-------|
| OS | Ubuntu 24.04 LTS Server (ARM64) |
| ISO | ubuntu-24.04-live-server-arm64.iso |
| vCPU | 4 (ARM64 cores) |
| RAM | 8 GB |
| Disk | 60 GB (virtio-blk) |
| Network | UTM Shared Network (virtio-net) |
| Display | Console only (headless after setup) |
| UTM machine type | QEMU (virt) |

**Installed software:**

| Component | Version | Port |
|-----------|---------|------|
| Wazuh Manager | 4.x (latest stable) | 1514/UDP, 1515/TCP |
| Wazuh API | 4.x | 55000/TCP |
| Elasticsearch | 8.x | 9200/TCP (loopback) |
| Logstash | 8.x | 5044/TCP |
| Kibana | 8.x | 5601/TCP |
| Filebeat (indexer) | 8.x | — |

**Resource rationale:** Elasticsearch requires minimum 4 GB JVM heap; 8 GB RAM total allows 4 GB for ES + 2 GB for Wazuh manager + 2 GB OS overhead.

---

### victim-windows · 192.168.64.20

| Property | Value |
|----------|-------|
| OS | Windows 11 ARM64 (Insider / VHDX) |
| Image source | Windows 11 on ARM — VHDX from Microsoft (MSDN) |
| vCPU | 4 (ARM64 cores) |
| RAM | 4 GB |
| Disk | 40 GB (virtio-blk or IDE for Windows compatibility) |
| Network | UTM Shared Network (virtio-net with Windows driver) |
| Display | VGA/SPICE (required for Windows setup) |
| UTM machine type | QEMU (virt) with UEFI + TPM 2.0 emulation |

**Installed software:**

| Component | Version | Purpose |
|-----------|---------|---------|
| Sysmon | 15.x | Kernel-level endpoint telemetry |
| Sysmon config | SwiftOnSecurity ruleset | Noise-reduced event collection |
| Wazuh Agent | 4.x | Log forwarding to manager |
| Filebeat | 8.x | Supplemental log shipping |
| .NET Framework | 4.x+ | Atomic Red Team prerequisite |
| PowerShell | 7.x | ART execution engine |

**Notes:**
- Windows 11 ARM64 requires UEFI boot in UTM
- virtio network driver must be installed from ISO during setup
- Static IP configured via `netsh interface ip set address` or Settings UI

---

### kali-attacker · 192.168.64.30

| Property | Value |
|----------|-------|
| OS | Kali Linux 2024.x (ARM64) |
| ISO | kali-linux-2024.x-installer-arm64.iso |
| vCPU | 4 (ARM64 cores) |
| RAM | 4 GB |
| Disk | 40 GB (virtio-blk) |
| Network | UTM Shared Network (virtio-net) |
| Display | VGA/SPICE (for GUI tools) |
| UTM machine type | QEMU (virt) |

**Installed software:**

| Tool | Purpose | Key commands |
|------|---------|-------------|
| Sliver C2 | Command-and-control framework | `sliver-server`, `sliver` client |
| Atomic Red Team | MITRE ATT&CK technique simulation | `Invoke-AtomicTest T1059.001` |
| Nmap | Network reconnaissance | `nmap -sV -sC` |
| Metasploit | Exploit framework | `msfconsole` |
| Impacket | SMB/Kerberos attacks | `psexec.py`, `secretsdump.py` |
| CrackMapExec | Network pentesting | `cme smb`, `cme winrm` |
| Responder | LLMNR/NBT-NS poisoning | `responder -I eth0` |
| BloodHound | AD enumeration | `bloodhound-python` |

---

## Host Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| Mac model | Apple M1 (any) | Apple M2 Pro / M3 Pro |
| macOS | 13 Ventura | 14 Sonoma / 15 Sequoia |
| RAM | 16 GB | 24 GB or 32 GB |
| Free disk | 160 GB | 250 GB (SSD) |
| UTM version | 4.x | Latest stable |

**Important:** Running all 3 VMs simultaneously requires ~16 GB RAM for VMs alone. On a 16 GB Mac, macOS itself needs ~4–6 GB, making simultaneous operation difficult. Recommendation: use 24 GB+ Mac, or run only 2 VMs at a time (wazuh-manager is always on; alternate between victim and kali).

---

## VM Boot Order

For normal operation:

1. **wazuh-manager** — start first, wait ~3 min for all services to come online
2. **victim-windows** — start second; Wazuh agent auto-connects to manager
3. **kali-attacker** — start last when ready to run attack simulations

To verify connectivity after boot:

```bash
# From kali-attacker
ping 192.168.64.10   # wazuh-manager
ping 192.168.64.20   # victim-windows
nmap -p 5601 192.168.64.10  # Kibana
```

## IP Assignment (Static Configuration)

All VMs use static IPs to ensure Wazuh agent → manager connectivity is never broken by DHCP renewal.

| VM | Method | Config location |
|----|--------|----------------|
| wazuh-manager (Ubuntu) | `/etc/netplan/00-installer-config.yaml` | See runbook/03-network-setup.md |
| victim-windows | Windows Settings → Network → IPv4 manual | See runbook/03-network-setup.md |
| kali-attacker | `/etc/network/interfaces` or NetworkManager | See runbook/03-network-setup.md |
