# Step 2: UTM VM Creation

Create three VMs in the UTM GUI. All VMs use ARM64 architecture and UTM Shared Network.

> **This step is GUI-only.** See [MANUAL_STEPS.md](MANUAL_STEPS.md) for detailed click-by-click instructions with screenshots.

## VM 1: wazuh-manager

| Setting | Value |
|---------|-------|
| Name | `wazuh-manager` |
| Architecture | ARM64 (AArch64) |
| Machine | QEMU 7.x (virt) |
| Boot ISO | ubuntu-24.04-live-server-arm64.iso |
| CPU | 4 cores |
| RAM | 8192 MB |
| Disk | 60 GB (virtio-blk) |
| Network | Shared Network |
| Display | Console |

**During Ubuntu install:**
- Hostname: `wazuh-manager`
- Username: `ubuntu`
- Enable OpenSSH server: **Yes**
- Import SSH key from GitHub: paste your public key

## VM 2: victim-windows

| Setting | Value |
|---------|-------|
| Name | `victim-windows` |
| Architecture | ARM64 (AArch64) |
| Machine | QEMU 7.x (virt) with UEFI + TPM |
| Boot image | Windows11_InsiderPreview_Client_ARM64.vhdx (import existing) |
| CPU | 4 cores |
| RAM | 4096 MB |
| Disk | 40 GB (from VHDX import) |
| Network | Shared Network |
| Display | VGA / SPICE |

**During Windows setup:**
- Use a local account (not Microsoft account) to avoid telemetry
- Disable BitLocker to simplify disk access
- Install VirtIO network drivers from ISO during setup (UTM provides these)

## VM 3: kali-attacker

| Setting | Value |
|---------|-------|
| Name | `kali-attacker` |
| Architecture | ARM64 (AArch64) |
| Machine | QEMU 7.x (virt) |
| Boot ISO | kali-linux-2024.x-installer-arm64.iso |
| CPU | 4 cores |
| RAM | 4096 MB |
| Disk | 40 GB (virtio-blk) |
| Network | Shared Network |
| Display | VGA / SPICE |

**During Kali install:**
- Hostname: `kali-attacker`
- Username: `kali`
- Install desktop environment: **Yes** (Xfce recommended for ARM performance)
- Enable SSH server: **Yes**

## Post-Creation Verification

After all three VMs boot for the first time:

```bash
# [host] Verify SSH reachability (after IP assignment in Step 3)
ssh ubuntu@192.168.64.10   # wazuh-manager
ssh kali@192.168.64.30     # kali-attacker
```

Windows: connect via RDP from Mac (`open rdp://192.168.64.20` or use Microsoft Remote Desktop app).
