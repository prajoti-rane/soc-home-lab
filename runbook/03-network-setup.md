# Step 3: Network Setup

Configure static IPs on all three VMs so agent → manager connectivity never breaks due to DHCP renewal.

**Estimated time:** 20 minutes

**Target network layout:**

```
macOS Host
    │
    │  192.168.64.0/24  (UTM Shared Network — NAT)
    │
    ├── 192.168.64.1   UTM gateway (DNS + NAT — don't modify)
    ├── 192.168.64.10  wazuh-manager  (Ubuntu 24.04)
    ├── 192.168.64.20  victim-windows (Windows 11 ARM64)
    └── 192.168.64.30  kali-attacker  (Kali Linux ARM64)
```

---

## Understanding UTM Network Modes

UTM offers three network modes. This lab uses **Shared Network** exclusively.

| Mode | Description | Use case |
|------|-------------|---------|
| **Shared Network** (recommended) | VMs get 192.168.64.x IPs via UTM's built-in DHCP. UTM NATs them to the internet through your Mac. VMs can talk to each other and the internet. | This lab |
| **Bridged Network** | VMs get IPs on your home LAN from your router. VMs appear as real devices on your network. | If you need VMs reachable from other home devices |
| **Host Only** | VMs can only talk to your Mac, not to each other or the internet. | Isolated testing; blocks Wazuh → internet |
| **None** | No network adapter. | Fully air-gapped VMs |

> **Why Shared Network?** It provides consistent 192.168.64.x addresses that never conflict with your home LAN, and it keeps all attack traffic contained inside UTM. A Sliver C2 running on 192.168.64.30 cannot accidentally reach your home router.

Verify each VM's network mode: **UTM → right-click VM → Edit → Network → Network Mode: Shared Network**. Change any that aren't set correctly.

---

## 3.1 — wazuh-manager Static IP (Ubuntu 24.04)

Ubuntu 24.04 uses `netplan` for network configuration.

```bash
# [manager — via SSH or UTM console]
# First find your interface name (may differ from enp0s1)
ip link show
# Look for the interface that shows a 192.168.64.x address — that's the right one.
# Common names: enp0s1, ens3, eth0, enp0s3
```

```bash
# [manager] View the current netplan config
cat /etc/netplan/00-installer-config.yaml
# This file currently has dhcp4: true — we're replacing it
```

```bash
# [manager] Edit the netplan config
sudo nano /etc/netplan/00-installer-config.yaml
```

Replace the entire file contents with (substitute `enp0s1` if your interface name is different):

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s1:
      dhcp4: false
      addresses:
        - 192.168.64.10/24
      nameservers:
        addresses:
          - 192.168.64.1
          - 8.8.8.8
      routes:
        - to: default
          via: 192.168.64.1
```

Save (Ctrl+O → Enter) and exit (Ctrl+X).

```bash
# [manager] Apply the config
sudo netplan apply

# Verify the new address is assigned
ip addr show enp0s1
# Expected: inet 192.168.64.10/24
# (The old 192.168.64.x DHCP address disappears)

# Test gateway connectivity
ping -c 3 192.168.64.1
# Expected: 0% packet loss

# Test internet
ping -c 3 8.8.8.8
# Expected: 0% packet loss
```

Your SSH session may drop when you apply the new IP. Reconnect from your Mac:

```bash
# [host]
ssh ubuntu@192.168.64.10
```

---

## 3.2 — victim-windows Static IP (Windows 11 ARM64)

**Method A: PowerShell (run as Administrator)**

Open PowerShell as Administrator on Windows (right-click Start → Terminal (Admin)):

```powershell
# [windows] Find the interface index
Get-NetAdapter | Select-Object Name, InterfaceIndex, Status
# Note the InterfaceIndex of the adapter showing "Up"

# [windows] Set static IP (replace 3 with your actual InterfaceIndex)
$idx = (Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1).InterfaceIndex
New-NetIPAddress -InterfaceIndex $idx -IPAddress 192.168.64.20 -PrefixLength 24 -DefaultGateway 192.168.64.1
Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses 192.168.64.1, 8.8.8.8

# Verify
ipconfig
# Expected: IPv4 Address: 192.168.64.20
#           Default Gateway: 192.168.64.1
```

**Method B: Settings GUI** (if PowerShell gives errors — see [MANUAL_STEPS.md](MANUAL_STEPS.md#windows-static-ip))

Test connectivity after setting:

```powershell
# [windows]
ping 192.168.64.1
ping 192.168.64.10
# Both should reply with TTL values and <1ms latency
```

---

## 3.3 — kali-attacker Static IP (Kali Linux)

Kali with Xfce desktop uses NetworkManager. Use either method:

**Method A: nmcli (command-line)**

```bash
# [kali] Find connection name
nmcli connection show
# Note the NAME column — typically "Wired connection 1" or "eth0"

# [kali] Set static IP
nmcli connection modify "Wired connection 1" \
  ipv4.method manual \
  ipv4.addresses 192.168.64.30/24 \
  ipv4.gateway 192.168.64.1 \
  ipv4.dns "192.168.64.1,8.8.8.8"

# Apply
nmcli connection up "Wired connection 1"

# Verify
ip addr show
# Expected: inet 192.168.64.30/24
```

**Method B: /etc/network/interfaces** (if NetworkManager is not running)

```bash
# [kali]
sudo nano /etc/network/interfaces
```

Add or replace:

```
auto eth0
iface eth0 inet static
    address 192.168.64.30
    netmask 255.255.255.0
    gateway 192.168.64.1
    dns-nameservers 192.168.64.1 8.8.8.8
```

```bash
# [kali] Apply
sudo ifdown eth0 && sudo ifup eth0
# Or: sudo systemctl restart networking
```

Test:

```bash
# [kali]
ping -c 2 192.168.64.1
ping -c 2 192.168.64.10
```

---

## 3.4 — Full Connectivity Test

After all static IPs are set, verify the entire mesh from each machine:

```bash
# [host — your Mac] All three VMs should respond
ping -c 2 192.168.64.10   # wazuh-manager
ping -c 2 192.168.64.20   # victim-windows
ping -c 2 192.168.64.30   # kali-attacker

# [host] SSH should work to both Linux VMs
ssh ubuntu@192.168.64.10 "hostname && ip addr show enp0s1 | grep inet"
ssh kali@192.168.64.30   "hostname && ip addr show | grep 192.168"
```

```bash
# [manager — via SSH] Test from wazuh-manager
ping -c 2 192.168.64.20
ping -c 2 192.168.64.30
ping -c 2 8.8.8.8
```

```bash
# [kali] Test from kali-attacker
ping -c 2 192.168.64.10
ping -c 2 192.168.64.20
```

```powershell
# [windows] Test from victim-windows
Test-NetConnection -ComputerName 192.168.64.10 -Port 22   # SSH to manager
Test-NetConnection -ComputerName 192.168.64.30 -Port 22   # SSH to Kali
```

**All pings must succeed before proceeding.** If any fail, use the troubleshooting section below.

---

## 3.5 — Copy SSH Public Key to VMs

Once network is working, copy your Mac's SSH public key to the Linux VMs for passwordless login:

```bash
# [host] Copy key to wazuh-manager
ssh-copy-id -i ~/.ssh/soc-lab.pub ubuntu@192.168.64.10
# Enter password when prompted — you won't need it again after this

# [host] Copy key to kali-attacker
ssh-copy-id -i ~/.ssh/soc-lab.pub kali@192.168.64.30
# Enter password when prompted

# [host] Verify passwordless login works
ssh ubuntu@192.168.64.10 "echo 'SSH key auth working'"
ssh kali@192.168.64.30   "echo 'SSH key auth working'"
```

---

## Troubleshooting

**"Can't ping VM from Mac after setting static IP"**

Check 1: Is the IP actually set?
```bash
# [manager] or [kali]
ip addr show
# Should show 192.168.64.10/24 or 192.168.64.30/24
```

Check 2: Is the interface up?
```bash
ip link show
# Should show "state UP" for your interface
```

Check 3: Is the UTM network mode correct?
- UTM → right-click VM → Edit → Network → confirm **Shared Network**

Check 4: Flush DNS cache on Mac:
```bash
# [host]
sudo dscacheutil -flushcache
```

---

**"VMs can't ping each other but can ping 192.168.64.1"**

This means each VM can reach UTM's gateway but not each other. Most likely the Windows firewall is blocking ICMP.

```powershell
# [windows] Temporarily allow ICMP (ping)
New-NetFirewallRule -DisplayName "Allow ICMPv4" -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Allow
```

Wazuh agent communication uses TCP ports 1514 and 1515 — also verify Windows firewall allows these:

```powershell
# [windows] Allow Wazuh ports
New-NetFirewallRule -DisplayName "Wazuh Agent" -Protocol TCP -LocalPort 1514,1515 -Direction Outbound -Action Allow
```

---

**"netplan apply breaks SSH connection"**

When you change the IP via netplan, your existing SSH session (using the old DHCP IP) drops. This is expected. Reconnect:

```bash
# [host] After netplan apply disconnects your session
ssh ubuntu@192.168.64.10
```

If you get "Connection refused", wait 10 seconds — sshd may be restarting. If you get "No route to host", the IP didn't apply correctly. Connect via UTM console (direct VM window) to debug.

---

**"Kali nmcli says 'connection not found'"**

Find the exact connection name first:
```bash
nmcli con show
# Copy the NAME exactly, including spaces
nmcli con modify "YOUR EXACT NAME HERE" ipv4.method manual ...
```

---

**"Windows `ipconfig` still shows old DHCP address"**

After setting static IP in PowerShell, release the old DHCP lease:

```powershell
ipconfig /release
ipconfig /renew
ipconfig
# Should now show 192.168.64.20
```

If it still shows DHCP, reboot the Windows VM: the static IP will apply after reboot.

---

**"No internet in VM after static IP change"**

The gateway must be `192.168.64.1`. Check:

```bash
# [manager]
ip route show
# Should include: default via 192.168.64.1 dev enp0s1
```

If the default route is missing:

```bash
# [manager]
sudo ip route add default via 192.168.64.1
# Test: ping 8.8.8.8
# Make permanent by re-running netplan apply after verifying your yaml has the routes block
```

---

## Checklist — Step 3 Complete When:

- [ ] wazuh-manager: `ip addr` shows `192.168.64.10/24`, can ping internet
- [ ] victim-windows: `ipconfig` shows `192.168.64.20`, can ping 192.168.64.10
- [ ] kali-attacker: `ip addr` shows `192.168.64.30/24`, can ping all other VMs
- [ ] Mac can ping all 3 VMs by IP
- [ ] Mac can SSH to ubuntu@192.168.64.10 without password
- [ ] Mac can SSH to kali@192.168.64.30 without password

**Next steps (can be done in any order):**
- **→ [04-wazuh-elk-install.md](04-wazuh-elk-install.md)** — install SIEM on wazuh-manager
- **→ [05-sysmon-setup.md](05-sysmon-setup.md)** — install Sysmon on victim-windows
- **→ [07-kali-setup.md](07-kali-setup.md)** — install attack tools on kali-attacker
