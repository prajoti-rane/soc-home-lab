# Incident Reports

Post-incident analysis reports documenting attack simulations run in this SOC home lab. Each report follows the [TEMPLATE.md](TEMPLATE.md) format and is written as if a real SOC analyst investigated a real intrusion — with realistic UTC timestamps, synthetic IOCs from the lab network, MITRE ATT&CK mapping, and evidence-backed timelines.

---

## Report Index

| Report ID | File | Date | Technique | Severity | Status |
|-----------|------|------|-----------|----------|--------|
| IR-2026-001 | [IR-2026-001-credential-dumping.md](IR-2026-001-credential-dumping.md) | 2026-03-15 | T1003.001 — LSASS Credential Dumping | **Critical** | Closed |
| IR-2026-002 | [IR-2026-002-c2-beaconing.md](IR-2026-002-c2-beaconing.md) | 2026-04-02 | T1071.001 — C2 HTTP Beaconing (Sliver) | **Critical** | Closed |
| IR-2026-003 | [IR-2026-003-brute-force-lateral-movement.md](IR-2026-003-brute-force-lateral-movement.md) | 2026-04-19 | T1110.001 + T1021.002 — SSH Brute Force + PsExec | **High** | Closed |

---

## Naming Convention

```
IR-YYYY-NNN-short-description.md

IR    — Incident Report prefix
YYYY  — Year (4 digits)
NNN   — Sequential number within the year (001, 002, ...)
short-description — Kebab-case summary of the primary technique
```

**Examples:**
- `IR-2026-001-credential-dumping.md` — LSASS dump via procdump
- `IR-2026-002-c2-beaconing.md` — Sliver HTTP implant C2 channel
- `IR-2026-003-brute-force-lateral-movement.md` — SSH brute force into PsExec

---

## Severity Classification

| Severity | Criteria | Examples |
|----------|----------|---------|
| **Critical** | Direct evidence of credential theft, data exfiltration, or SIEM compromise | LSASS dump, C2 established, threat actor on SIEM |
| **High** | Successful unauthorized access; threat actor on an endpoint | SSH brute force + login, PsExec execution |
| **Medium** | Detected attacker activity without confirmed access | Brute force attempts (no success), port scan |
| **Low** | Suspicious but not confirmed malicious activity | Single failed login, unusual process with no network connection |

---

## How to Write a New Report

1. **Copy the template:**
   ```bash
   cp incident-reports/TEMPLATE.md incident-reports/IR-$(date +%Y)-NNN-short-title.md
   ```

2. **Fill in the Classification section** — severity, status, MITRE technique IDs

3. **Write the Executive Summary first** — 2–4 sentences for leadership, no jargon

4. **Build the Timeline from Kibana:**
   - Open Kibana Discover view
   - Set time range to the incident window
   - Sort by `@timestamp` ascending
   - Export significant events as CSV or copy timestamps manually

5. **Populate IOCs** from Sysmon event fields (`image`, `destinationIp`, `grantedAccess`, etc.)

6. **Map to MITRE ATT&CK** — each row should have direct evidence (a specific log event, not inference)

7. **Be honest in Detection Gaps** — this is the most actionable section and demonstrates analytical rigor

8. **Write Action Items** — each should be specific, assignable, and measurable

---

## SOC Workflow Integration

```
Attack simulation runs    ──▶   Wazuh alert fires
    (Phase 4 scenarios)              │
                                     ▼
                            Kibana dashboard review
                                     │
                                     ▼
                            Analyst investigates
                            (timeline reconstruction)
                                     │
                                     ▼
                            Incident report written
                            (this directory)
                                     │
                                     ▼
                            Action items → Phase 7
                            (detection improvements)
```

---

## MITRE ATT&CK Navigator

To visualize coverage across all three reports, create an ATT&CK Navigator layer:

1. Open [https://mitre-attack.github.io/attack-navigator/](https://mitre-attack.github.io/attack-navigator/)
2. Select "Create New Layer" → "Enterprise ATT&CK"
3. Search each technique below and mark it as covered (green):
   - T1003.001 (LSASS) — IR-2026-001
   - T1059.001 (PowerShell) — IR-2026-001, IR-2026-002
   - T1071.001 (Web Protocols C2) — IR-2026-002
   - T1036.005 (Masquerading) — IR-2026-002
   - T1110.001 (Brute Force) — IR-2026-003
   - T1021.002 (SMB/PsExec) — IR-2026-003
   - T1021.004 (SSH) — IR-2026-003
   - T1569.002 (Service Execution) — IR-2026-003
4. Export as JSON and save to `detections/mitre-navigator-layer.json`

---

## Why These Reports Matter for FAANG Interviews

Incident reports demonstrate several competencies that security engineering interviews specifically probe:

**1. Detection pipeline fluency** — "Walk me through how you'd detect a credential dumping attack." The reports show end-to-end: Sysmon → Wazuh rule → Kibana alert → analyst response.

**2. DFIR methodology** — Timeline reconstruction from logs, IOC extraction, kill chain attribution. This is what a Detection Engineer, Security Engineer, or Incident Responder does daily.

**3. Quantitative thinking** — Detection latency numbers (e.g., "rule fired in <1 second"), dwell time calculations, false positive analysis. FAANG security roles expect engineers who can reason about performance and scale.

**4. Gap analysis** — The "Detection Gaps" and "Action Items" sections demonstrate mature security thinking: understanding what you can't see is as important as what you can.

**5. Communication skills** — The Executive Summary is written for a non-technical VP. The Technical Analysis is written for a peer security engineer. Demonstrating both registers in one document is a differentiator.

---

## Data Notes

All incident reports in this directory use synthetic data:
- IP addresses are within the lab range `192.168.64.0/24`
- File hashes are synthetic 64-character hex strings
- Timestamps are from simulated attack executions
- No real organization names, hostnames, or personal data are included
- IOCs should NOT be submitted to threat intelligence platforms (they are not real IOCs)
