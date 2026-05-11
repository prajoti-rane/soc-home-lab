# Attack Scenarios

> **FOR AUTHORIZED HOME LAB USE ONLY**
> All scenarios run exclusively within the isolated UTM lab (192.168.64.0/24).
> Never replicate these techniques on systems you do not own or have written authorization to test.

Full end-to-end attack scenarios combining multiple MITRE ATT&CK techniques into a realistic kill chain. Each scenario documents exact commands, expected Wazuh detections, and cleanup procedures.

## Scenario Index

| # | File | Techniques | Complexity | Duration | Rules Exercised |
|---|------|-----------|-----------|----------|-----------------|
| 01 | [01-initial-access-c2.md](01-initial-access-c2.md) | T1071.001, T1059.001 | Beginner | 30 min | 100006, 100009, 100010 |
| 02 | [02-credential-dumping.md](02-credential-dumping.md) | T1003.001, T1059.001 | Intermediate | 20 min | 100005, 100007, 100008 |
| 03 | [03-lateral-movement.md](03-lateral-movement.md) | T1110.001, T1021.002 | Intermediate | 25 min | 100001, 100002, 100012, 100013 |
| 04 | [04-persistence.md](04-persistence.md) | T1053.005, T1562.001 | Beginner–Int. | 20 min | 100015, 100016, 100017, 100018, 100019 |
| 05 | [05-full-kill-chain.md](05-full-kill-chain.md) | All techniques | **Advanced** | 90 min | **All 8 rule groups** |

## Standard Pre-Execution Checklist

Before running **any** scenario:

- [ ] All 3 VMs are running and healthy
- [ ] UTM snapshots taken: `UTM → right-click VM → New Snapshot`
- [ ] Kibana accessible: [http://192.168.64.10:5601](http://192.168.64.10:5601)
- [ ] Verify Sysmon on victim-windows: `Get-Service Sysmon64a`
- [ ] Verify Filebeat on victim-windows: `Get-Service filebeat`
- [ ] Verify Wazuh agent on victim-windows: `Get-Service WazuhSvc`
- [ ] Note UTC start time: `[System.DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")`

## Standard Post-Execution Checklist

After **every** scenario:

- [ ] Terminate all Sliver sessions and listeners
- [ ] Remove all implant binaries from victim-windows
- [ ] Delete all persistence mechanisms (tasks, Run keys, services)
- [ ] **Re-enable Windows Defender** (critical after Scenario 04/05)
- [ ] Delete LSASS dump files (if created)
- [ ] Restore VMs to clean snapshot (recommended)

## How to Use These Scenarios

1. **Start with Scenario 01** — get familiar with the tooling and the Kibana workflow
2. **Run each scenario independently** first before attempting the full kill chain (Scenario 05)
3. **Compare expected vs. actual detections** — note any rule that doesn't fire (detection gap)
4. **Document results** in an incident report using [TEMPLATE.md](../../incident-reports/TEMPLATE.md)
5. **Scenario 05 is the interview demo** — it exercises all 8 detection rules in sequence

## Lab Network Reference

| VM | IP | Role | Key Services |
|----|-----|------|-------------|
| wazuh-manager | 192.168.64.10 | SIEM/Blue Team | Wazuh Manager, Elasticsearch, Kibana :5601 |
| victim-windows | 192.168.64.20 | Target | Sysmon, Wazuh Agent, Filebeat, RDP :3389 |
| kali-attacker | 192.168.64.30 | Operator | Sliver, ART (on victim), Hydra, Nmap |
