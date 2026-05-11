# Step 6: Wazuh Agent Deployment

Deploy and register Wazuh agents on `victim-windows` and optionally on `kali-attacker`.

---

## Windows Agent (victim-windows · 192.168.64.20)

### Download

```powershell
# [windows] Download Wazuh Windows agent (ARM64 compatible MSI)
Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.x.x-1.msi" `
  -OutFile C:\Tools\wazuh-agent.msi
```

> Check [packages.wazuh.com](https://packages.wazuh.com/4.x/windows/) for the latest ARM64-compatible MSI version.

### Install (silent)

```powershell
# [windows] Install with manager IP and agent name (run as Administrator)
msiexec /i C:\Tools\wazuh-agent.msi /q `
  WAZUH_MANAGER="192.168.64.10" `
  WAZUH_AGENT_NAME="victim-windows" `
  WAZUH_REGISTRATION_SERVER="192.168.64.10"

# Start the agent service
NET START WazuhSvc
```

### Verify registration

```bash
# [manager] Confirm agent appeared on manager side
sudo /var/ossec/bin/agent_control -l
# Expected: Agent 001 victim-windows 192.168.64.20 Active
```

---

## Linux Agent (optional — kali-attacker · 192.168.64.30)

```bash
# [kali] Add Wazuh repo
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list
sudo apt update && sudo apt install -y wazuh-agent

# [kali] Configure manager IP
sudo sed -i 's/MANAGER_IP/192.168.64.10/' /var/ossec/etc/ossec.conf

# [kali] Register and start
sudo /var/ossec/bin/agent-auth -m 192.168.64.10 -n kali-attacker
sudo systemctl enable --now wazuh-agent
```

---

## Configure ossec.conf (Windows Event Log Monitoring)

On the `wazuh-manager`, verify that the Windows event channels are monitored. The default config already includes Security and Sysmon:

```bash
# [manager]
sudo grep -A5 "localfile" /var/ossec/etc/ossec.conf | grep -i "windows\|sysmon" | head -20
```

If Sysmon channel is missing, add it via the Wazuh dashboard or directly:

```bash
# [manager] Add Sysmon channel to ossec.conf
sudo nano /var/ossec/etc/ossec.conf
```

Add inside `<ossec_config>`:

```xml
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

```bash
# [manager] Restart to apply
sudo systemctl restart wazuh-manager
```

---

## Verify Events Flowing

```bash
# [manager] Watch live events from victim-windows
sudo tail -f /var/ossec/logs/alerts/alerts.json | python3 -m json.tool | grep -i "agent\|rule\|data" | head -50
```

Open Kibana → Wazuh → Agents → victim-windows → Events. You should see Sysmon events within 30 seconds of any activity on the Windows VM.

---

## Agent Status in Kibana

1. Open `https://192.168.64.10:5601`
2. Navigate to: Wazuh → Agents
3. Both agents should show status: **Active**
4. Click an agent → Overview → Recent alerts
