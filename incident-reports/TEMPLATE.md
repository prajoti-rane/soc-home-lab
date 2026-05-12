# Incident Report: [IR-YYYY-NNN] [Short Descriptive Title]

**Date Opened:** YYYY-MM-DD  
**Date Closed:** YYYY-MM-DD (leave blank if open)  
**Lead Analyst:** [Full Name]  
**Review Status:** Draft / Under Review / Approved  

---

## Classification

| Field | Value |
|-------|-------|
| **Severity** | Critical / High / Medium / Low |
| **Status** | Open / Investigating / Contained / Eradicated / Closed |
| **MITRE ATT&CK Tactics** | Initial Access, Execution, Persistence, Credential Access, etc. |
| **MITRE ATT&CK Techniques** | T1059.001, T1003.001, T1071.001, etc. |
| **Affected Systems** | [hostname(s)] |
| **Detection Source** | Wazuh SIEM / Sysmon / Manual |

---

## Executive Summary

> *Write 2–4 sentences for non-technical leadership. Cover: what happened, when it was detected, what data was at risk, and what action was taken. Avoid jargon. Example: "On [date], automated monitoring detected unauthorized access to the [system]. An attacker used [technique] to [impact]. The affected system was isolated at [time], and all malicious artifacts were removed by [time]. No evidence of data exfiltration was found."*

[Write executive summary here]

---

## Timeline (UTC)

> *Reconstruct chronologically from logs, Kibana, and Sysmon telemetry. Include all significant events: first attacker action, first alert, analyst response, containment, eradication. Use Kibana's Discover view with `@timestamp` sorted ascending to build this.*

| Timestamp (UTC) | Event | Source | Details |
|----------------|-------|--------|---------|
| YYYY-MM-DD HH:MM:SS | [what happened] | [Wazuh / Sysmon EID X / Windows EventLog] | [specific fields, rule IDs, process names] |
| YYYY-MM-DD HH:MM:SS | First Wazuh alert fired | Wazuh Rule NNNNNN | [alert description and level] |
| YYYY-MM-DD HH:MM:SS | Analyst notified | Kibana dashboard | [how the alert was surfaced] |
| YYYY-MM-DD HH:MM:SS | Containment initiated | Analyst action | [specific step taken] |
| YYYY-MM-DD HH:MM:SS | Eradication confirmed | Analyst verification | [how clean state was verified] |

---

## Affected Assets

> *List every host, account, and service touched by the incident. "Impact" should describe what the attacker did to or could have done to that asset.*

| Asset | IP Address | Role | Impact |
|-------|-----------|------|--------|
| [hostname] | [192.168.64.XX] | [SIEM / Victim / Attacker] | [compromised / accessed / credential exposed / no impact] |

---

## Technical Analysis

### Attack Vector

> *How did the attacker gain initial access? What vulnerability, misconfiguration, or user action enabled entry? Include the specific tool or technique.*

[Describe the initial access method: e.g., "The attacker exploited the absence of account lockout policy on the SSH service to brute-force valid credentials."]

### Execution

> *What did the attacker do after gaining access? Walk through each action in technical detail. Reference specific process names, command lines, registry keys, and file paths observed in the telemetry.*

[Step-by-step description of attacker actions with evidence citations]

### Evidence

> *Paste key log snippets, Kibana screenshots descriptions, or Sysmon event fields. Focus on the most forensically significant evidence. Synthetic/redacted data acceptable in lab reports.*

**Sysmon Event (relevant fields):**

```json
{
  "timestamp": "YYYY-MM-DDTHH:MM:SS.mmmZ",
  "rule": {
    "id": "NNNNN",
    "level": N,
    "description": "[rule description]"
  },
  "agent": { "name": "[hostname]", "ip": "[192.168.64.XX]" },
  "data": {
    "win": {
      "system": { "eventID": "N", "channel": "[channel]" },
      "eventdata": {
        "[relevant field]": "[value]"
      }
    }
  }
}
```

### Root Cause

> *Why was this attack possible? Was it a misconfiguration, missing control, disabled security feature, or design limitation? Be specific.*

[Root cause statement — e.g., "LSASS access was possible because Windows Credential Guard was not enabled on the victim VM. Credential Guard uses virtualization-based security to isolate LSASS in a protected process."]

---

## Indicators of Compromise (IOCs)

> *List every observable artifact left by the attacker. Use these to search for the same attack on other systems. In lab reports, use synthetic values from the 192.168.64.0/24 network.*

| Type | Value | Context |
|------|-------|---------|
| IP Address | 192.168.64.XX | [Attacker C2 / Source of brute force / etc.] |
| File Hash (SHA256) | `[64-character hex string]` | [Malicious binary] |
| File Path | `[C:\path\to\file.exe]` | [Implant / dump file / tool] |
| Process Name | `[process.exe]` | [Attacker tool] |
| Registry Key | `[HKLM\...\key]` | [Persistence mechanism] |
| Network Port | [port/protocol] | [C2 channel / lateral movement] |
| User-Agent | `[user agent string]` | [Malicious HTTP request] |

---

## MITRE ATT&CK Mapping

> *Map each attacker action to a specific ATT&CK technique. Include only techniques for which you have direct evidence.*

| Tactic | Technique Name | ID | Evidence Observed |
|--------|---------------|-----|------------------|
| [e.g., Credential Access] | [e.g., OS Credential Dumping: LSASS Memory] | [e.g., T1003.001] | [e.g., Sysmon EID 10, sourceImage=procdump64.exe, targetImage=lsass.exe] |

---

## Detection

### Rules That Fired

> *For each Wazuh rule that generated an alert during this incident, record the rule details and the specific event that triggered it.*

| Rule ID | Rule Name | Alert Level | First Fire Time (UTC) | What It Caught |
|---------|-----------|------------|----------------------|---------------|
| [NNNNN] | [rule description] | [N/Critical/High] | [HH:MM:SS] | [specific field values that matched] |

### Detection Latency

| Event | Time of Event (UTC) | Time of Alert (UTC) | Latency |
|-------|--------------------|--------------------|---------|
| [Attacker action] | [HH:MM:SS] | [HH:MM:SS] | [X seconds] |

### Detection Gaps

> *What did the attacker do that was NOT detected by any rule? Be honest — gaps are the most actionable part of this section.*

- [ ] [Specific attacker action that had no corresponding alert]
- [ ] [Missing telemetry source — e.g., HTTP proxy logs not collected]
- [ ] [Rule condition that was too narrow to catch this variant]

---

## Containment & Eradication

> *Ordered steps taken to stop the attack and remove attacker presence. Include timestamps where possible.*

### Containment

1. [Time] — [Action taken to limit spread, e.g., "Isolated victim-windows from the lab network by suspending VM"]
2. [Time] — [Blocked attacker IP or port]
3. [Time] — [Killed malicious process]

### Eradication

1. [Action taken to remove attacker artifacts]
2. [Credential reset procedure]
3. [Registry key or persistence mechanism removed]

### Eradication Verification

```bash
# Commands used to verify clean state
[e.g., Get-Process | Where-Object { $_.Path -like "*Temp*" }]
[e.g., Get-ScheduledTask | Where-Object { $_.TaskName -like "*update*" }]
```

---

## Recovery

> *Steps taken to restore systems to normal, verified-clean operation.*

1. [Restore VM from clean snapshot / Re-enable disabled services]
2. [Reset compromised credentials]
3. [Re-enable security controls (e.g., Defender) if disabled by attacker]
4. [Verify Wazuh agent and Sysmon are running and reporting]
5. [Confirm no persistence mechanisms remain]

---

## Lessons Learned

### What Worked Well

- [e.g., "Sysmon EID 10 fired within 2 seconds of LSASS access — detection latency was excellent"]
- [e.g., "Wazuh rule level 14 (Critical) immediately surfaced the alert in the Kibana dashboard"]

### What Needs Improvement

- [e.g., "HTTP download of the implant binary was not detected — no network proxy logging configured"]
- [e.g., "Rule 100005 fired but did not trigger an active response to automatically isolate the host"]

### Action Items

> *Specific, assignable improvements resulting from this incident. Each action should reduce the likelihood or impact of a recurrence.*

| # | Action | Owner | Priority | Target Date |
|---|--------|-------|----------|------------|
| 1 | [Specific technical improvement] | [Analyst / Blue Team] | P1 / P2 / P3 | YYYY-MM-DD |
| 2 | [Rule tuning or new rule] | [Analyst] | P2 | YYYY-MM-DD |
| 3 | [Process or policy change] | [Team Lead] | P3 | YYYY-MM-DD |

---

## Appendix

### A. Raw Wazuh Alert JSON

> *Paste the most forensically significant alert(s) in full JSON format. Redact any sensitive data (real hostnames, real IPs) in production environments. In this lab, all values are synthetic.*

```json
{
  "placeholder": "paste full alert JSON from Kibana → Actions → Inspect → JSON"
}
```

### B. Kibana Queries Used

```
# Query used to find all incident-related alerts
rule.id:(NNNNN OR NNNNN) AND @timestamp:[YYYY-MM-DDTHH:MM:SSZ TO YYYY-MM-DDTHH:MM:SSZ]

# Query to find all events from attacker source IP
win.eventdata.sourceIp:192.168.64.XX AND @timestamp:[...]
```

### C. References

- [MITRE ATT&CK Technique Page](https://attack.mitre.org/techniques/TXXXX/XXX/)
- [Wazuh Rule Documentation](https://documentation.wazuh.com/current/user-manual/ruleset/)
- [Related Sigma Rule](../detections/sigma/sigma-NNNNN-*.yml)
- [ART Test Used](../attack-simulation/atomic-red-team/test-plan.md)
