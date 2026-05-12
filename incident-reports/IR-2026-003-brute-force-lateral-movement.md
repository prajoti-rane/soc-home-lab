# Incident Report: IR-2026-003 — SSH Brute Force Leading to Lateral Movement

**Date Opened:** 2026-04-19  
**Date Closed:** 2026-04-20  
**Lead Analyst:** Prajoti Rane  
**Review Status:** Approved  

---

## Classification

| Field | Value |
|-------|-------|
| **Severity** | High |
| **Status** | Closed — Eradicated |
| **MITRE ATT&CK Tactics** | Credential Access, Lateral Movement, Execution |
| **MITRE ATT&CK Techniques** | T1110.001 (Brute Force: Password Guessing), T1021.002 (Remote Services: SMB/Windows Admin Shares), T1021.004 (Remote Services: SSH), T1569.002 (System Services: Service Execution) |
| **Affected Systems** | wazuh-manager (192.168.64.10), victim-windows (192.168.64.20) |
| **Detection Source** | Wazuh SIEM — Rules 100001, 100002, 100012 |

---

## Executive Summary

Between 22:05 and 22:31 UTC on 2026-04-19, an attacker originating from `kali-attacker` (192.168.64.30) executed a multi-stage intrusion spanning two systems. In the first stage, the attacker used Hydra to brute-force SSH credentials on `wazuh-manager` (192.168.64.10), successfully authenticating at 22:09 UTC after 487 failed attempts. Wazuh Rule 100001 (SSH brute force) fired during the attack phase, and Rule 100002 (brute force followed by successful login) fired when the attacker logged in — escalating severity to Critical. In the second stage, the attacker pivoted to `victim-windows` (192.168.64.20) using impacket's `psexec.py`, installing the `PSEXESVC` service and executing commands remotely. Rule 100012 (PsExec lateral movement) fired on `victim-windows` at 22:18 UTC. Both affected systems were isolated at 22:31 UTC, attacker access was terminated, and compromised credentials were rotated. No data exfiltration was confirmed, but the attacker had access to the Wazuh manager (SIEM) for approximately 22 minutes — a significant security event given the manager's privileged visibility into the lab environment.

---

## Timeline (UTC)

| Timestamp (UTC) | Event | Source | Details |
|----------------|-------|--------|---------|
| 2026-04-19 22:03:44 | Attacker begins nmap reconnaissance of lab network | kali-attacker | `nmap -sV 192.168.64.0/24` — identifies SSH on wazuh-manager:22 |
| 2026-04-19 22:05:12 | **SSH brute force begins** — wazuh-manager | kali-attacker | `hydra -l soc -P fasttrack.txt ssh://192.168.64.10 -t 4` |
| 2026-04-19 22:05:18 | First sshd failure logged on wazuh-manager | Linux syslog | `Failed password for invalid user admin from 192.168.64.30` |
| 2026-04-19 22:05:22 | Wazuh parent rule 5710 fires (1st SSH failure) | Wazuh alert | Level 5 — single SSH failure (expected noise; no escalation) |
| 2026-04-19 22:05:51 | **Wazuh Rule 100001 fires** — 5+ failures in 60s | Wazuh alert | Level 10 — SSH brute-force: 5+ failed logins from 192.168.64.30 |
| 2026-04-19 22:05:51 | Rule 100001 continues firing each batch of 5 failures | Wazuh alerts | 97 occurrences of Rule 100001 during the 4-minute brute force |
| 2026-04-19 22:07:33 | Hydra attempts `soc:SOClab2024` — valid credential | kali-attacker | hydra output: `[22][ssh] host: 192.168.64.10 login: soc password: SOClab2024` |
| 2026-04-19 22:07:35 | **Attacker logs in to wazuh-manager via SSH** | wazuh-manager sshd | `Accepted password for soc from 192.168.64.30 port 52341 ssh2` |
| 2026-04-19 22:07:37 | **Wazuh Rule 100002 fires — Critical** | Wazuh alert | Level 14 — SSH brute force succeeded: attacker logged in after 487 failures |
| 2026-04-19 22:08:00 | Attacker begins host reconnaissance on wazuh-manager | wazuh-manager | `id`, `uname -a`, `ip addr`, `cat /etc/passwd` via SSH session |
| 2026-04-19 22:09:15 | Attacker reads Wazuh configuration and alert logs | wazuh-manager | `sudo cat /var/ossec/etc/ossec.conf`, `tail /var/ossec/logs/alerts/alerts.json` |
| 2026-04-19 22:10:30 | Attacker discovers victim-windows IP from Wazuh agent config | wazuh-manager | Agent list reveals 192.168.64.20 running as `victim-windows` |
| 2026-04-19 22:11:00 | Attacker exfils Wazuh API token from config | wazuh-manager | `cat /var/ossec/api/configuration/api.yaml` |
| 2026-04-19 22:14:00 | Attacker transfers impacket `psexec.py` to kali session | kali-attacker | Preparation for lateral movement pivot |
| 2026-04-19 22:17:44 | **PsExec pivot to victim-windows** | kali-attacker | `python3 psexec.py SOCAdmin:'Password123!'@192.168.64.20 'whoami'` |
| 2026-04-19 22:17:47 | **PSEXESVC service installed on victim-windows** | Windows EventID 7045 | `ServiceName: PSEXESVC`; `SubjectUserName: SOCAdmin` |
| 2026-04-19 22:17:48 | **Wazuh Rule 100012 fires — High** | Wazuh alert | Level 10 — PsExec service installed: PSEXESVC by SOCAdmin |
| 2026-04-19 22:17:52 | Attacker executes `whoami` via PSEXESVC | victim-windows | `NT AUTHORITY\SYSTEM` returned — attacker achieved SYSTEM via PsExec |
| 2026-04-19 22:18:10 | Attacker executes `ipconfig` and `dir C:\Users` | victim-windows | Reconnaissance on Windows victim |
| 2026-04-19 22:19:00 | Analyst observes Rule 100002 (Critical) alert in Kibana | Kibana dashboard | Multi-system alert: wazuh-manager + victim-windows alerts correlated |
| 2026-04-19 22:25:00 | Analyst confirms active SSH session on wazuh-manager | wazuh-manager | `who` shows `soc pts/0 2026-04-19 22:07 (192.168.64.30)` |
| 2026-04-19 22:31:00 | **Containment: SSH session killed on wazuh-manager** | wazuh-manager root | `kill -HUP [sshd_child_pid]`; connection terminated |
| 2026-04-19 22:31:30 | **Containment: PSEXESVC service stopped on victim-windows** | Analyst PowerShell | `Stop-Service PSEXESVC; sc.exe delete PSEXESVC` |
| 2026-04-19 22:32:00 | Account lockout applied to `soc` and `SOCAdmin` | Analyst | Temporary lockout pending credential rotation |
| 2026-04-19 22:35:00 | Forensic snapshots captured (both VMs) | Analyst (UTM) | Pre-eradication preservation |
| 2026-04-19 22:45:00 | Eradication steps executed (see below) | Analyst | — |
| 2026-04-20 08:00:00 | Credentials reset; accounts re-enabled | Analyst | New strong passwords set; existing SSH keys audited |
| 2026-04-20 08:30:00 | Post-eradication verification passed | Analyst | Both systems clean; monitoring confirmed active |
| 2026-04-20 09:00:00 | Incident report drafted; status Closed | Analyst | — |

---

## Affected Assets

| Asset | IP Address | Role | Impact |
|-------|-----------|------|--------|
| wazuh-manager | 192.168.64.10 | SIEM / Detection Platform | SSH credential compromised; attacker had shell access ~22 min; Wazuh config and API token read |
| victim-windows | 192.168.64.20 | Windows 11 ARM64 victim VM | PsExec lateral movement; PSEXESVC service installed; SYSTEM-level command execution |
| kali-attacker | 192.168.64.30 | Attacker VM | Source of brute force and PsExec operations |

**Severity Note:** Compromise of the SIEM (wazuh-manager) is particularly significant because the attacker gained visibility into detection rules, agent configurations, and active alerts. In a production environment, this would constitute a "hands-on-keyboard" intrusion into the security monitoring infrastructure itself.

---

## Technical Analysis

### Attack Vector

The attacker identified `wazuh-manager` as a target via nmap service discovery. The SSH service (`sshd`) was configured without account lockout or rate limiting — `sshd`'s built-in `MaxAuthTries` was set to the default value of 6 (per attempt), but no OS-level lockout (fail2ban, pam_tally2) was active that would have blocked the attacker's source IP after repeated failures. The password `SOClab2024` was in Hydra's `fasttrack.txt` wordlist, which contains common lab/default credentials.

### Execution

**Phase 1 — SSH Brute Force:**

The attacker launched Hydra with 4 parallel threads against `192.168.64.10:22`, targeting the `soc` account:

```bash
hydra -l soc -P /usr/share/wordlists/fasttrack.txt ssh://192.168.64.10 -t 4 -V -I -e nsr -f
```

At a rate of approximately 2 attempts per second (4 threads, ~0.5s per connection), the attacker cycled through 487 passwords before finding `SOClab2024` at 22:07:33 UTC. Total brute-force duration: 2 minutes 21 seconds.

Each authentication failure generated a syslog entry:
```
Apr 19 22:05:18 wazuh-manager sshd[3291]: Failed password for invalid user admin from 192.168.64.30 port 52112 ssh2
Apr 19 22:05:19 wazuh-manager sshd[3293]: Failed password for soc from 192.168.64.30 port 52114 ssh2
```

Wazuh's `sshd_rules.xml` (parent rule 5710) classified each failure as level 5. At the 5th failure from `192.168.64.30` within 60 seconds, custom rule 100001 promoted the severity to level 10 (High).

**Phase 2 — Post-Compromise Reconnaissance on wazuh-manager:**

Within 33 seconds of logging in, the attacker ran:

```bash
id            # → uid=1000(soc) gid=1000(soc) groups=1000(soc),4(adm)
uname -a      # → Linux wazuh-manager 6.8.0-31-generic #31-Ubuntu SMP x86_64
sudo -l       # → (root) NOPASSWD: /var/ossec/bin/wazuh-control
cat /etc/passwd  # User enumeration
ip addr show  # → 192.168.64.10/24 + loopback
```

Critically, the `soc` account had `sudo` access to `wazuh-control`, and the Wazuh configuration files at `/var/ossec/etc/` were readable:

```bash
sudo cat /var/ossec/etc/ossec.conf       # Full Wazuh manager config
tail -100 /var/ossec/logs/alerts/alerts.json  # Recent alerts — including this one
cat /var/ossec/api/configuration/api.yaml    # Wazuh API credentials
```

The attacker now knew: all agent IPs and hostnames, all active detection rules, the Wazuh API key, and that the current brute-force was being detected.

**Phase 3 — Lateral Movement to victim-windows:**

Using victim-windows' IP (`192.168.64.20`) and credentials discovered from Wazuh agent config (`SOCAdmin`), the attacker executed a PsExec-style lateral move from `kali-attacker`:

```bash
python3 /usr/share/doc/python3-impacket/examples/psexec.py \
  SOCAdmin:'Password123!'@192.168.64.20 'whoami'
```

impacket's `psexec.py` operates by:
1. Authenticating to `victim-windows` SMB (port 445) using provided credentials
2. Uploading a service binary (`PSEXESVC.exe`) to the `ADMIN$` share
3. Creating and starting the `PSEXESVC` Windows service
4. Redirecting stdin/stdout through the named pipe `\pipe\svcctl`

The service installation generated Windows System EventID 7045, which Wazuh's agent forwarded to the manager and matched rule 100012.

### Evidence

**Wazuh Alert — Rule 100001 (first firing):**

```json
{
  "timestamp": "2026-04-19T22:05:51.203Z",
  "rule": {
    "id": "100001",
    "level": 10,
    "description": "SSH brute-force attack detected: 5+ failed logins from 192.168.64.30 in 60 s",
    "groups": ["authentication_failures", "brute_force", "pci_dss_11.4"]
  },
  "agent": {
    "name": "wazuh-manager",
    "ip": "192.168.64.10",
    "id": "000"
  },
  "data": {
    "srcip": "192.168.64.30",
    "dstuser": "soc",
    "program_name": "sshd"
  },
  "full_log": "Apr 19 22:05:51 wazuh-manager sshd[3317]: Failed password for soc from 192.168.64.30 port 52205 ssh2"
}
```

**Wazuh Alert — Rule 100002 (Critical — brute force + success):**

```json
{
  "timestamp": "2026-04-19T22:07:37.891Z",
  "rule": {
    "id": "100002",
    "level": 14,
    "description": "SSH brute-force succeeded: attacker 192.168.64.30 logged in after 5+ failures",
    "groups": ["authentication_success", "brute_force", "pci_dss_10.2.4", "pci_dss_10.2.5"]
  },
  "agent": {
    "name": "wazuh-manager",
    "ip": "192.168.64.10",
    "id": "000"
  },
  "data": {
    "srcip": "192.168.64.30",
    "dstuser": "soc",
    "program_name": "sshd"
  },
  "full_log": "Apr 19 22:07:35 wazuh-manager sshd[3318]: Accepted password for soc from 192.168.64.30 port 52341 ssh2"
}
```

**Wazuh Alert — Rule 100012 (PsExec lateral movement):**

```json
{
  "timestamp": "2026-04-19T22:17:48.441Z",
  "rule": {
    "id": "100012",
    "level": 10,
    "description": "PsExec service installed: PSEXESVC by SOCAdmin",
    "groups": ["lateral_movement", "pci_dss_10.6.1", "nist_800_53_SI.4"]
  },
  "agent": {
    "name": "victim-windows",
    "ip": "192.168.64.20",
    "id": "001"
  },
  "data": {
    "win": {
      "system": {
        "eventID": "7045",
        "channel": "System",
        "computer": "victim-windows"
      },
      "eventdata": {
        "serviceName": "PSEXESVC",
        "imagePath": "%SystemRoot%\\PSEXESVC.exe",
        "serviceType": "16",
        "startType": "3",
        "subjectUserName": "SOCAdmin",
        "subjectDomainName": "victim-windows"
      }
    }
  }
}
```

**Brute force statistics (from Wazuh alert count):**

```
Rule 5710 (single SSH failure): 487 alerts
Rule 100001 (brute force threshold): 97 alerts (one per additional failure batch after first 5)
Rule 100002 (brute + success): 1 alert — escalated to level 14
Time from first failure to successful login: 2 minutes 17 seconds
Total passwords tried: 487
Password position in wordlist: ~245 (approximately mid-list for fasttrack.txt)
```

### Root Cause

This incident had three compounding root causes:

1. **Weak password on a privileged SSH account:** `SOClab2024` is a predictable pattern matching common lab-credential conventions (ProjectYear format). It appeared in the `fasttrack.txt` wordlist, which contains ~250 commonly used passwords specifically designed for "quick wins." Strong passwords (20+ characters, randomly generated, stored in a password manager) would have made brute force computationally infeasible.

2. **No SSH rate limiting or IP lockout:** The SSH service did not use `fail2ban`, `pam_tally2`, or `MaxStartups` tuning to block or throttle repeated failed attempts. Even a simple `fail2ban` configuration blocking an IP for 10 minutes after 3 failures would have increased the brute-force duration from 2.3 minutes to approximately 35 hours — making it non-viable.

3. **SIEM account had excessive privileges:** The `soc` account on `wazuh-manager` had read access to Wazuh configuration files (including the API key) and sudo access to `wazuh-control`. Principle of least privilege would restrict the analyst account to read-only dashboard access via Kibana, with no shell access to the manager host itself.

---

## Indicators of Compromise (IOCs)

| Type | Value | Context |
|------|-------|---------|
| IP Address | `192.168.64.30` | Attacker source — all brute force and PsExec traffic |
| Network Port | `22/TCP` | SSH brute force target on wazuh-manager |
| Network Port | `445/TCP` | SMB — PsExec connection from 192.168.64.30 to victim-windows |
| Username | `soc` | Compromised SSH account on wazuh-manager |
| Password | `SOClab2024` | Brute-forced credential (rotate immediately; do not reuse) |
| Service Name | `PSEXESVC` | PsExec service installed by attacker on victim-windows |
| File Path | `C:\Windows\PSEXESVC.exe` | PsExec service binary on victim-windows |
| Failed Login Count | 487 | Number of SSH failures before successful authentication |
| Brute Force Duration | 137 seconds | Time from first attempt to successful login |
| Source Port Range | 52112–52598 | Hydra source ports observed in sshd logs |
| Auth Method | `password` | Hydra uses password authentication (not key-based) |

---

## MITRE ATT&CK Mapping

| Tactic | Technique Name | ID | Evidence Observed |
|--------|---------------|-----|------------------|
| Reconnaissance | Network Service Discovery | T1046 | nmap scan of 192.168.64.0/24 before attack |
| Credential Access | **Brute Force: Password Guessing** | **T1110.001** | Hydra: 487 SSH failures → successful login; Wazuh Rules 100001/100002 |
| Lateral Movement | **Remote Services: SSH** | **T1021.004** | Attacker SSH session to wazuh-manager as `soc` |
| Lateral Movement | **Remote Services: SMB/Windows Admin Shares** | **T1021.002** | impacket psexec.py uploads PSEXESVC via ADMIN$; Rule 100012 |
| Execution | System Services: Service Execution | T1569.002 | PSEXESVC service installed and started; EventID 7045 |
| Discovery | System Information Discovery | T1082 | `uname -a`, `id`, `ip addr` run on wazuh-manager post-compromise |
| Discovery | File and Directory Discovery | T1083 | Attacker read `/var/ossec/etc/ossec.conf`, `/etc/passwd`, Wazuh API config |
| Collection | Data from Local System | T1005 | Wazuh API token and agent config read from wazuh-manager |

---

## Detection

### Rules That Fired

| Rule ID | Rule Name | Alert Level | First Fire Time (UTC) | What It Caught |
|---------|-----------|------------|----------------------|---------------|
| 5710 | SSH failed authentication (Wazuh built-in) | 5 (Info) | 22:05:18 | First SSH failure from 192.168.64.30 |
| **100001** | **SSH brute-force — threshold** | **10 (High)** | **22:05:51** | 5th failed attempt from same source IP in 60s |
| **100002** | **SSH brute-force + success** | **14 (Critical)** | **22:07:37** | Successful login from 192.168.64.30 after brute-force history |
| **100012** | **PsExec service installed** | **10 (High)** | **22:17:48** | EventID 7045: PSEXESVC service on victim-windows |

### Detection Latency

| Event | Time of Event (UTC) | Time of Alert (UTC) | Latency |
|-------|--------------------|--------------------|---------|
| First SSH failure | 22:05:18 | 22:05:22 (Rule 5710) | 4 seconds |
| 5th SSH failure (threshold) | 22:05:51 | 22:05:51 (Rule 100001) | < 1 second |
| Successful SSH login | 22:07:35 | 22:07:37 (Rule 100002) | 2 seconds |
| PSEXESVC service install | 22:17:47 | 22:17:48 (Rule 100012) | 1 second |
| Analyst observes alerts | 22:07:37 | 22:19:00 | **11 minutes 23 seconds** |
| Containment initiated | 22:19:00 | 22:31:00 | 12 minutes |

**Total dwell time on wazuh-manager: ~24 minutes** (22:07:35 to 22:31:00)

**Key observation:** Rule 100002 (Critical, level 14) fired at 22:07:37, but the analyst did not observe it until 22:19:00 — an 11-minute gap. In a 24×7 SOC with on-call alerting for level 14 events, this would be caught within seconds. In this lab without on-call alerts configured, the analyst reviewed the Kibana dashboard during a manual check-in.

### Detection Gaps

- **Reconnaisance phase (nmap) not detected:** The nmap scan at 22:03:44 generated no alerts. Network-level IDS (Suricata, Zeek) would have caught this, but neither is deployed in the current lab configuration.
- **Post-compromise activity on wazuh-manager not alerted:** The attacker reading `/var/ossec/etc/ossec.conf` and the Wazuh API config generated no Wazuh alerts. Linux file access auditing (auditd with `auditctl -w /var/ossec/etc/ -p r -k wazuh_config_read`) would have caught this.
- **SMB connection from kali to victim-windows not detected:** The PsExec setup phase involved an SMB connection on port 445 from `192.168.64.30` to `192.168.64.20`. No rule monitors inbound SMB connections from non-standard hosts.
- **Wazuh API token theft not detected:** The attacker read the Wazuh API token from `/var/ossec/api/configuration/api.yaml`. A subsequent attacker using this token against the Wazuh REST API would have unrestricted access to the SIEM's management plane.
- **Alert review delay:** The 11-minute gap between the Critical alert firing and analyst review suggests that on-call notification (PagerDuty, OpsGenie, email) should be configured for level 14 Wazuh alerts.

---

## Containment & Eradication

### Containment

1. **22:31:00** — SSH session on wazuh-manager terminated: `sudo pkill -u soc` (killed all processes owned by `soc` user, including the active SSH session)
2. **22:31:10** — `soc` account temporarily locked: `sudo passwd -l soc`
3. **22:31:30** — PSEXESVC stopped on victim-windows: `Stop-Service PSEXESVC -Force`
4. **22:31:45** — PSEXESVC service deleted: `sc.exe delete PSEXESVC`
5. **22:32:00** — `SOCAdmin` account locked on victim-windows: `net user SOCAdmin /active:no`
6. **22:33:00** — Verified attacker has no remaining active connections: `who`, `netstat -an | grep ESTABLISHED` on both systems

### Eradication

1. **22:35:00** — UTM forensic snapshots created for both VMs
2. **22:40:00** — PSEXESVC binary removed from victim-windows: `Remove-Item C:\Windows\PSEXESVC.exe -Force`
3. **22:42:00** — Wazuh API token rotated: regenerated in `/var/ossec/api/configuration/api.yaml`; all existing API sessions invalidated
4. **22:44:00** — Wazuh manager restarted to load new API credentials: `sudo systemctl restart wazuh-manager`
5. **22:46:00** — SSH `authorized_keys` for `soc` account audited — no unauthorized keys found
6. **22:48:00** — Wazuh alert log examined for attacker-triggered API calls (none found in log window)
7. **22:50:00** — fail2ban installed and configured on wazuh-manager: blocks IP for 1 hour after 3 SSH failures

### Eradication Verification

```bash
# wazuh-manager
who                                   # No active sessions
sudo netstat -tnp | grep :22          # SSH: LISTEN only, no ESTABLISHED from 192.168.64.30
sudo fail2ban-client status sshd      # Confirm ban rule is active
sudo passwd -S soc                    # Account status (should be L = Locked until pw reset)

# victim-windows (PowerShell)
Get-Service PSEXESVC -ErrorAction SilentlyContinue  # Should return nothing
Test-Path C:\Windows\PSEXESVC.exe     # Expected: False
Get-NetFirewallRule | Where-Object DisplayName -like "*PSEXESVC*"  # Should be empty
```

---

## Recovery

1. **2026-04-20 08:00** — `soc` account password reset to a 20-character random string (stored in password manager): `sudo passwd soc`; account unlocked: `sudo passwd -u soc`
2. **2026-04-20 08:05** — `SOCAdmin` password reset on victim-windows; account re-enabled
3. **2026-04-20 08:10** — fail2ban verified active and monitoring SSH: `sudo fail2ban-client status sshd` — `Currently failed: 0; Total banned: 0`
4. **2026-04-20 08:15** — SSH key-based authentication enforced on wazuh-manager: `PasswordAuthentication no` set in `/etc/ssh/sshd_config`; confirmed with `sudo sshd -T | grep passwordauth`
5. **2026-04-20 08:20** — Wazuh agent connectivity verified: victim-windows agent reporting in Kibana
6. **2026-04-20 08:25** — Wazuh API token verified rotated: old token rejected; new token functional
7. **2026-04-20 08:30** — Post-incident monitoring window: watched Kibana for 30 minutes — no reattack from 192.168.64.30

---

## Lessons Learned

### What Worked Well

- **Rule 100001 + 100002 cascade worked perfectly:** The two-rule chain (brute-force alert → success escalation) demonstrated exactly the intended behavior — a single SSH failure is noise, but 5+ failures followed by a success is a confirmed breach. The escalation from level 10 to level 14 provided clear severity progression.
- **Detection latency for the brute force was excellent:** Rule 100001 fired within 33 seconds of the first failure (at the exact moment the 5th failure arrived), and Rule 100002 fired within 2 seconds of the successful login — the Wazuh correlation engine had negligible latency.
- **PsExec detection was reliable:** EventID 7045 with `PSEXESVC` is a near-unique service name that generates no false positives in this environment. Rule 100012 fired within 1 second of the service installation.
- **Cross-system correlation was visible in Kibana:** Both alerts (100002 on wazuh-manager, 100012 on victim-windows) appeared in the same Kibana discovery view with adjacent timestamps, making the lateral movement obvious — no manual correlation was required.

### What Needs Improvement

- **No on-call notification for Critical alerts:** The 11-minute gap between the Critical alert (22:07:37) and analyst response (22:19:00) is unacceptable for a level 14 event. Wazuh should be integrated with a notification system (email, Slack webhook, PagerDuty) that pages an analyst immediately on level ≥ 12 alerts.
- **SSH brute force succeeded in under 3 minutes:** A strong password policy and fail2ban would have made this attack infeasible. Account lockout after 3 failures (with a 10-minute cooldown) would extend the brute-force time by 3 orders of magnitude.
- **SIEM compromise is a critical gap:** The attacker accessing wazuh-manager is equivalent to an attacker gaining access to the SOC itself. The SIEM should be hardened: no password authentication (SSH keys only), no direct shell access for analyst accounts (use the Kibana web interface), minimal sudo privileges.
- **File access auditing missing on wazuh-manager:** The attacker reading sensitive config files generated no alerts. `auditd` with file watches on `/var/ossec/etc/`, `/var/ossec/api/`, and `/etc/passwd` would have provided a secondary detection signal.
- **Lateral movement source from SIEM not anomalous:** Because the SIEM was compromised first, the attacker already had local-network access. A rule detecting inbound SMB connections from non-standard sources (`192.168.64.30` → `192.168.64.20:445`) would have provided an earlier lateral movement indicator.

### Action Items

| # | Action | Owner | Priority | Target Date |
|---|--------|-------|----------|------------|
| 1 | Configure Wazuh Slack/email webhook for level ≥ 12 alerts | Lab Analyst | **P1** | 2026-04-25 |
| 2 | Enable SSH key-only auth on wazuh-manager: `PasswordAuthentication no` in sshd_config | Lab Analyst | **P1** | 2026-04-25 |
| 3 | Install and configure fail2ban on wazuh-manager: ban after 3 failures for 60 min | Lab Analyst | **P1** | 2026-04-25 |
| 4 | Enforce strong passwords (20+ char random) for all lab accounts; document in password manager | Lab Analyst | **P1** | 2026-04-25 |
| 5 | Configure auditd on wazuh-manager to watch `/var/ossec/etc/` and `/var/ossec/api/` | Lab Analyst | P2 | 2026-05-01 |
| 6 | Add Wazuh rule for inbound SMB (port 445) from kali-attacker to any lab host | Lab Analyst | P2 | 2026-05-01 |
| 7 | Rotate Wazuh API token and store in password manager; restrict API to localhost only | Lab Analyst | P2 | 2026-05-01 |
| 8 | Remove direct shell access for `soc` account; use Kibana web UI for all analyst operations | Lab Analyst | P3 | 2026-05-15 |

---

## Appendix

### A. Brute Force Statistics

```
Attack tool:            Hydra v9.4
Wordlist:               /usr/share/wordlists/fasttrack.txt (~250 entries)
Target:                 192.168.64.10:22 (OpenSSH on Ubuntu 24.04)
Username:               soc (single-user targeted)
Threads:                4 concurrent connections
Attempt rate:           ~3.5 attempts/second
Total attempts:         487
Successful at attempt:  ~245
Duration:               137 seconds (2:17)
```

### B. Kibana Queries Used

```
# All brute force and lateral movement alerts for this incident
rule.id:(100001 OR 100002 OR 100012) AND @timestamp:[2026-04-19T22:00:00Z TO 2026-04-19T23:00:00Z]

# All SSH failures from attacker IP on wazuh-manager
agent.name:"wazuh-manager" AND data.srcip:"192.168.64.30" AND rule.id:5710

# PsExec service installation on victim-windows
agent.name:"victim-windows" AND win.system.eventID:7045

# Full incident window, all agents
@timestamp:[2026-04-19T22:00:00Z TO 2026-04-20T09:00:00Z] AND
  (agent.name:"wazuh-manager" OR agent.name:"victim-windows")
```

### C. References

- [MITRE ATT&CK: T1110.001 — Brute Force: Password Guessing](https://attack.mitre.org/techniques/T1110/001/)
- [MITRE ATT&CK: T1021.002 — Remote Services: SMB/Windows Admin Shares](https://attack.mitre.org/techniques/T1021/002/)
- [MITRE ATT&CK: T1021.004 — Remote Services: SSH](https://attack.mitre.org/techniques/T1021/004/)
- [Related Sigma Rules](../detections/sigma/sigma-100001-brute-force-ssh.yml)
- [Related Wazuh Rules](../detections/wazuh-rules/100001-brute-force-ssh.xml)
- [Attack Scenario Reference](../attack-simulation/attack-scenarios/03-lateral-movement.md)
- [ART Test Plan](../attack-simulation/atomic-red-team/test-plan.md)
