# Step 3: Network Setup

Configure static IPs on all three VMs so Wazuh agent → manager connectivity is never broken by DHCP renewal.

**Target IPs:**
- wazuh-manager: `192.168.64.10`
- victim-windows: `192.168.64.20`
- kali-attacker: `192.168.64.30`
- Gateway: `192.168.64.1` (UTM's NAT gateway)
- DNS: `192.168.64.1` (UTM DNS relay)

---

## wazuh-manager (Ubuntu 24.04)

```bash
# [manager] Edit netplan config
sudo nano /etc/netplan/00-installer-config.yaml
```

Replace contents with:

```yaml
network:
  version: 2
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

```bash
# [manager] Apply and verify
sudo netplan apply
ip addr show enp0s1
ping -c 3 192.168.64.1
```

> **Note:** The interface name may be `enp0s1`, `ens3`, or `eth0` depending on UTM version. Run `ip link` to confirm.

---

## victim-windows (Windows 11 ARM64)

In Windows Settings (GUI required):

1. Settings → Network & Internet → Ethernet
2. Click the connected adapter → Edit (next to IP assignment)
3. Switch from "Automatic (DHCP)" to "Manual"
4. Enter:
   - IP: `192.168.64.20`
   - Subnet prefix: `24`
   - Gateway: `192.168.64.1`
   - DNS: `192.168.64.1`

Or via PowerShell (run as Administrator):

```powershell
# [windows] Set static IP via PowerShell
$adapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress 192.168.64.20 -PrefixLength 24 -DefaultGateway 192.168.64.1
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses 192.168.64.1
```

---

## kali-attacker (Kali Linux)

```bash
# [kali] Edit interfaces
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
sudo systemctl restart networking
ip addr show eth0
```

> If using NetworkManager (Kali with desktop): use `nmcli` or the network settings GUI.

---

## Connectivity Test

Run these from each VM to confirm full mesh connectivity:

```bash
# [manager] Test from wazuh-manager
ping -c 2 192.168.64.20   # victim-windows
ping -c 2 192.168.64.30   # kali-attacker
ping -c 2 8.8.8.8          # internet

# [kali] Test from kali-attacker
ping -c 2 192.168.64.10   # wazuh-manager
ping -c 2 192.168.64.20   # victim-windows

# [host] Test from macOS host
ping -c 2 192.168.64.10   # wazuh-manager
ssh ubuntu@192.168.64.10  # SSH to manager
```

All pings should succeed before proceeding to Step 4.
