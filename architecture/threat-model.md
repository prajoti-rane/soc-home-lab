# Threat Model — STRIDE Analysis

## Scope

**What are we protecting?**

1. **Detection capability** — The SIEM's ability to accurately detect attacker behavior and generate alerts
2. **Log integrity** — The trustworthiness of the evidence chain from endpoint to Elasticsearch
3. **Lab isolation** — Prevention of lab traffic escaping to the home network or internet
4. **Credential confidentiality** — API keys, Wazuh manager credentials, Kibana passwords

**Threat actors modeled:**

- Attacker operating from Kali VM (intentional — this is the red team)
- Accidental misconfiguration by the lab operator
- Simulated insider threat (compromised victim VM pivoting to SIEM)

---

## STRIDE Analysis

### S — Spoofing

| Threat | Description | Risk | Mitigation | Detection Rule |
|--------|-------------|------|-----------|---------------|
| Agent identity spoofing | Attacker registers a rogue Wazuh agent using a stolen agent key to inject false log data | **High** | Wazuh agent authentication via pre-shared keys; restrict agent registration to known IPs in `ossec.conf` | Wazuh rule 504 (agent disconnection), custom rule for new agent registration from unexpected IPs |
| IP spoofing on lab network | Kali VM spoofs victim IP to poison Wazuh geolocation or bypass IP-based rules | **Medium** | UTM network isolation; ARP monitoring; Wazuh active response can block spoofed IPs | Wazuh rule 40101 (ARP anomaly) |
| Kibana SSO bypass | Attacker with host access bypasses Kibana authentication | **Low** | Kibana basic auth + local-only binding (127.0.0.1 on manager); SSH port-forward for host access | Kibana audit log (login failures) |

---

### T — Tampering

| Threat | Description | Risk | Mitigation | Detection Rule |
|--------|-------------|------|-----------|---------------|
| Sysmon config tampering | Attacker modifies Sysmon config to blind specific Event IDs (e.g., stops logging process creation) | **Critical** | Monitor Sysmon config file hash; Wazuh FIM on `C:\Windows\System32\drivers\etc\` and Sysmon install path | Wazuh FIM rule 550/553 (file modified); custom rule for Sysmon service stop |
| Windows Event Log clearing | Attacker runs `wevtutil cl Security` to clear Security event log | **Critical** | Wazuh agent reads events in real-time before clearing; alert on EventID 1102 (log cleared) | Wazuh rule 18145 (Windows event log cleared) — fires even if log is then cleared |
| Elasticsearch index tampering | Compromised manager VM; attacker deletes or modifies alert indices | **High** | Elasticsearch security (TLS + X-Pack auth); snapshot policy to S3-compatible storage | Elasticsearch audit log; Wazuh rule for ES API calls to DELETE index |
| Log injection via crafted events | Attacker crafts malicious event payloads to trigger false-positive rules or inject SIEM commands | **Medium** | Wazuh input validation; limit agent privileges; validate field lengths in decoders | Custom decoder validation; alert on oversized field values |

---

### R — Repudiation

| Threat | Description | Risk | Mitigation | Detection Rule |
|--------|-------------|------|-----------|---------------|
| Attacker denies executing commands | No process-level audit trail on Windows | **High** | Sysmon EventID 1 logs every process with hash, parent, CLI args, user; Windows Security EventID 4688 | Sysmon rule + Wazuh correlation rule 92000+ (process execution) |
| Admin actions not logged | Lab operator makes changes to Wazuh rules without audit trail | **Medium** | Wazuh API audit log enabled; git-track all rule changes in this repo | Wazuh API log: `wazuh-api.log` |
| Kali attack tool execution undocumented | Red team runs techniques with no written record | **Low** | Maintain `attack-simulation/attack-scenarios/` logs; Sliver operator logs | Manual process — see runbook/08-attack-simulation.md |

---

### I — Information Disclosure

| Threat | Description | Risk | Mitigation | Detection Rule |
|--------|-------------|------|-----------|---------------|
| Wazuh API key exposure | `ossec.conf` or `.env` files committed to public GitHub | **Critical** | `.gitignore` blocks `*.key`, `.env`, `secrets/`; pre-commit hook checks for secrets | GitHub secret scanning (enabled on public repo); truffleHog scan |
| Kibana dashboard exposure | Kibana bound to 0.0.0.0 and reachable from home LAN | **High** | Bind Kibana to 127.0.0.1 on manager; access via SSH tunnel from host | Network scan detection; UTM shared network isolates from LAN |
| Elasticsearch data leakage | ES API accessible without auth on port 9200 | **High** | Enable X-Pack security (TLS + basic auth) in `elasticsearch.yml`; firewall port 9200 to loopback | Wazuh rule for unauthenticated ES access |
| Sliver C2 traffic leaving lab | Implant callbacks escape UTM shared network to internet | **Medium** | UTM shared network uses NAT; implant listener bound to lab IP only; iptables on Kali block WAN C2 | DNS query monitoring (Wazuh rule 82000+) |

---

### D — Denial of Service

| Threat | Description | Risk | Mitigation | Detection Rule |
|--------|-------------|------|-----------|---------------|
| Log flood / alert storm | Atomic Red Team technique generates 50,000+ events/min, overwhelming Elasticsearch | **High** | Wazuh rate limiting in `ossec.conf` (`<logall_json>` cap); ILM delete policy protects disk | Custom rule: alert if event rate > 5,000/min from single agent |
| Elasticsearch disk exhaustion | Archive indices fill the 60 GB VM disk | **High** | ILM hot/warm/delete policy; set disk watermark in `elasticsearch.yml` (85% low, 90% high) | Wazuh rule for disk usage > 85% (rule 531) |
| Wazuh manager crash | Crafted oversized event crashes manager process | **Medium** | Pin Wazuh to latest stable; `ulimit` on manager process; systemd auto-restart | Systemd unit restart counter; Wazuh manager heartbeat loss alert |
| VM resource starvation | All VMs running simultaneously exhausts Mac RAM (20 GB needed, 16 GB Mac) | **Medium** | Never run all 3 VMs simultaneously without 24 GB+ RAM; see vm-specs.md minimum requirements | macOS Activity Monitor; UTM memory cap per VM |

---

### E — Elevation of Privilege

| Threat | Description | Risk | Mitigation | Detection Rule |
|--------|-------------|------|-----------|---------------|
| Wazuh agent → manager pivot | Compromised Windows victim pivots via Wazuh agent protocol to execute commands on manager | **High** | Wazuh active response runs as limited user; disable bidirectional commands in agent if not needed | Wazuh rule for active response execution (rule 100010); monitor agent-initiated connections |
| Kali → Wazuh API lateral movement | Attacker on Kali discovers Wazuh API port 55000 and authenticates with default credentials | **High** | Change default Wazuh API password on install; firewall 55000 to manager loopback | Failed Wazuh API auth (wazuh-api.log); Wazuh rule 550 |
| Local privilege escalation on manager | SIEM VM kernel exploit grants root; attacker modifies detection rules | **Critical** | Apply Ubuntu security updates weekly; run Wazuh/ES as non-root service users | Wazuh FIM on `/var/ossec/rules/`; Linux audit rules for setuid execution (rule 2502) |
| Windows token theft | Attacker uses Sliver `getuid` / `steal_token` to impersonate SYSTEM | **Medium** | Sysmon EventID 10 (process access) catches `OpenProcess` with `PROCESS_DUP_HANDLE` | Wazuh rule 92000+ + Sysmon EventID 10 decoder |

---

## Risk Matrix

| Threat | Likelihood | Impact | Risk Score |
|--------|-----------|--------|-----------|
| Log clearing (EventID 1102) | High (intentional in lab) | Critical | **Critical** |
| Sysmon config tampering | Medium | Critical | **High** |
| Wazuh API credential exposure | Low | High | **High** |
| Elasticsearch disk exhaustion | Medium | High | **High** |
| Agent identity spoofing | Low | High | **Medium** |
| Log flood / alert storm | High (during attack sim) | Medium | **Medium** |
| Kibana exposure to LAN | Low (UTM isolation) | Medium | **Low** |

---

## Residual Risks Accepted

The following risks are accepted as inherent to a home lab environment:

1. No hardware security module (HSM) for key storage — credentials stored as plaintext in Ansible vault
2. No network tap / span port — all detection relies on endpoint agents, not network IDs
3. Single-node Elasticsearch — no replication; if the VM disk fails, alert history is lost
4. UTM VMs not isolated from macOS host filesystem — `.vmdk` files readable if host is compromised
