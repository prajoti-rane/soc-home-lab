# Step 6: Wazuh Agent Deployment

Deploy Wazuh agents on `victim-windows` and `kali-attacker`, register them with the manager, and verify events flow into Kibana.

**Prerequisites:** Step 4 (Wazuh manager running) and Step 5 (Sysmon installed on Windows) must be complete.

**Estimated time:** 20 minutes

---

## 6.1 — Windows Agent (victim-windows · 192.168.64.20)

### Download the agent MSI

Connect to victim-windows via RDP. Open **Administrator PowerShell**.

```powershell
# [windows] Check the Wazuh site for the latest 4.x MSI
# The URL format is: https://packages.wazuh.com/4.x/windows/wazuh-agent-VERSION-1.msi
# Find the current version:
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/" -UseBasicParsing |
  Select-Object -ExpandProperty Content | Select-String -Pattern "wazuh-agent.*\.msi" -AllMatches |
  ForEach-Object { $_.Matches.Value } | Select-Object -First 5
```

Download the latest MSI:

```powershell
# [windows] Example — adjust version number to latest shown above
$WAZUH_VER = "4.9.0"   # <-- update to current version
Invoke-WebRequest `
  -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent-${WAZUH_VER}-1.msi" `
  -OutFile "C:\Tools\wazuh-agent.msi"

# Verify download
Get-Item "C:\Tools\wazuh-agent.msi" | Select-Object Length
# Expected: ~20–30 MB
```

### Install with manager IP

```powershell
# [windows] Silent install — sets manager IP and agent name at install time
msiexec.exe /i C:\Tools\wazuh-agent.msi /q `
  WAZUH_MANAGER="192.168.64.10" `
  WAZUH_AGENT_NAME="victim-windows" `
  WAZUH_REGISTRATION_SERVER="192.168.64.10"

# Wait for msiexec to finish (30–60 seconds, no output)
# Then start the agent service
NET START WazuhSvc
```

Expected: `The WazuhSvc service was started successfully.`

### Verify agent registered on manager

```bash
# [manager]
sudo /var/ossec/bin/agent_control -l
```

Expected output:

```
Wazuh agent_control. List of available agents:
   ID: 000, Name: wazuh-manager, IP: 127.0.0.1, Active/Local
   ID: 001, Name: victim-windows, IP: 192.168.64.20, Active
```

If you see `Disconnected` instead of `Active`, wait 30 seconds and check again — enrollment can take a moment.

```bash
# [manager] Check the enrollment log if agent doesn't appear
sudo tail -50 /var/ossec/logs/ossec.log | grep -i "agent\|enroll\|register"
```

---

## 6.2 — Linux Agent (kali-attacker · 192.168.64.30) — Optional

Deploying a Wazuh agent on Kali lets you monitor attacker-side activity (what Kali executed during attack scenarios). This is optional but adds detection coverage.

```bash
# [kali]
# Add Wazuh apt repo
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | \
  sudo gpg --dearmor -o /usr/share/keyrings/wazuh.gpg

echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] \
  https://packages.wazuh.com/4.x/apt/ stable main" | \
  sudo tee /etc/apt/sources.list.d/wazuh.list

sudo apt update
sudo apt install -y wazuh-agent
```

```bash
# [kali] Set manager IP
sudo sed -i 's/MANAGER_IP/192.168.64.10/' /var/ossec/etc/ossec.conf

# Register with the manager
sudo /var/ossec/bin/agent-auth -m 192.168.64.10 -n kali-attacker

# Start agent
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
sudo systemctl status wazuh-agent
```

```bash
# [manager] Verify Kali agent appeared
sudo /var/ossec/bin/agent_control -l
# Expected: ID 002, Name: kali-attacker, Active
```

---

## 6.3 — Configure Windows Event Channel Monitoring

The Wazuh manager needs to know which Windows event channels to collect from the agent. Verify these channels are configured:

```bash
# [manager] Check what channels are monitored
sudo grep -B2 -A4 "localfile" /var/ossec/etc/ossec.conf | grep -A3 "eventchannel"
```

You need these channels monitored:

```xml
<!-- These should be in ossec.conf — add any that are missing -->
<localfile>
  <location>Application</location>
  <log_format>eventchannel</log_format>
</localfile>

<localfile>
  <location>Security</location>
  <log_format>eventchannel</log_format>
</localfile>

<localfile>
  <location>System</location>
  <log_format>eventchannel</log_format>
</localfile>

<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>

<localfile>
  <location>Microsoft-Windows-Windows Defender/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

If any channel is missing:

```bash
# [manager] Edit ossec.conf and add the missing <localfile> blocks
sudo nano /var/ossec/etc/ossec.conf
# Add the missing blocks inside <ossec_config> but outside any <ruleset> block

# Restart to apply
sudo systemctl restart wazuh-manager
```

---

## 6.4 — Verify Events Are Flowing

### From the manager CLI

```bash
# [manager] Watch live alerts for 30 seconds
sudo tail -f /var/ossec/logs/alerts/alerts.json | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        a = json.loads(line.strip())
        if a.get('agent', {}).get('name') == 'victim-windows':
            print(f\"{a['timestamp']} | Rule {a['rule']['id']} ({a['rule']['level']}) | {a['rule']['description'][:70]}\")
    except: pass
"
```

Now do something on the Windows VM (open a program, browse a folder) — you should see events print within a few seconds.

Press `Ctrl+C` to stop.

### From Kibana

```bash
# [host] Open in browser
open https://192.168.64.10
```

1. Log in → navigate to **Wazuh → Agents**
2. Both `victim-windows` and `kali-attacker` should show **Active** status (green dot)
3. Click `victim-windows` → **Events** tab
4. You should see recent Sysmon events. If not, check the time filter (set to "Last 15 minutes")
5. Filter by: `agent.name: victim-windows` + `data.win.system.channel: Microsoft-Windows-Sysmon/Operational`

If events are missing, go to the troubleshooting section.

---

## 6.5 — Test Alert: Trigger a Known Detection

Generate a real Wazuh alert to confirm the full pipeline works end-to-end:

```powershell
# [windows] Trigger a suspicious PowerShell detection (Rule 100006/100007)
# This runs a base64-encoded command — benign content, suspicious form
powershell.exe -EncodedCommand "V3JpdGUtSG9zdCAiSGVsbG8gZnJvbSBlbmNvZGVkIFBTIg=="
# (Decodes to: Write-Host "Hello from encoded PS")
```

Wait 5–10 seconds, then check Kibana → Wazuh → Security Events. You should see an alert from rule 100006 or 100007 (suspicious PowerShell).

```bash
# [manager] Alternatively, check alert log directly
sudo tail -20 /var/ossec/logs/alerts/alerts.json | \
  python3 -c "
import sys, json
for line in sys.stdin:
    try:
        a = json.loads(line)
        if '100007' in str(a.get('rule', {}).get('id', '')):
            print('RULE 100007 FIRED:', a['rule']['description'])
    except: pass
"
```

---

## 6.6 — Add Agent to Kibana Dashboard (If Not Auto-Added)

Wazuh agents usually appear automatically in the dashboard. If they don't:

1. Wazuh Dashboard → **Agents** → click **Deploy new agent**
2. Select: OS = Windows
3. Copy the install command shown → run it on victim-windows via PowerShell
4. Return to Wazuh → Agents and wait for the agent to show Active

---

## Troubleshooting

**Agent shows "Disconnected" in Wazuh after install**

Check firewall on Windows:
```powershell
# [windows] Windows Firewall may be blocking outbound 1514
Test-NetConnection -ComputerName 192.168.64.10 -Port 1514
# Expected: TcpTestSucceeded : True
# If False: add firewall rule:
New-NetFirewallRule -DisplayName "Wazuh Agent Outbound" `
  -Protocol TCP -RemotePort 1514,1515 -Direction Outbound -Action Allow
```

Check agent log on Windows:
```powershell
# [windows]
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 30
# Look for "Error" lines
```

---

**Agent registered but no Sysmon events in Kibana**

The Sysmon channel must be in ossec.conf on the manager (Step 6.3). Also verify it's enabled in Windows:

```powershell
# [windows]
wevtutil gl "Microsoft-Windows-Sysmon/Operational"
# Look for: enabled: true
# If false: wevtutil sl "Microsoft-Windows-Sysmon/Operational" /e:true
```

---

**`msiexec` returns exit code 1603 (generic install failure)**

```powershell
# [windows] Run with verbose logging to see the real error
msiexec.exe /i C:\Tools\wazuh-agent.msi /qn /l*v C:\Tools\wazuh-install.log `
  WAZUH_MANAGER="192.168.64.10" `
  WAZUH_AGENT_NAME="victim-windows"
Get-Content C:\Tools\wazuh-install.log | Select-String -Pattern "Error|error|FAILED" | Select-Object -Last 20
```

---

**`agent-auth` on Kali fails: "ERROR: Unable to connect to 192.168.64.10:1515"**

Port 1515 handles agent enrollment. Verify it's listening:
```bash
# [manager]
ss -tlnp | grep 1515
# If not showing: sudo systemctl restart wazuh-manager
```

---

## Checklist — Step 6 Complete When:

- [ ] `agent_control -l` on manager shows `victim-windows` as **Active**
- [ ] Kibana → Wazuh → Agents shows victim-windows with green Active status
- [ ] Sysmon events visible in Kibana (filter: Sysmon/Operational channel)
- [ ] Rule 100006 or 100007 fires in response to encoded PowerShell test
- [ ] (Optional) kali-attacker agent shows Active in Wazuh

**Next step → [07-kali-setup.md](07-kali-setup.md)** (if not done already)  
**Then → [08-attack-simulation.md](08-attack-simulation.md)** once Steps 6 + 7 are both complete
