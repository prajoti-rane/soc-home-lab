# Step 4: Wazuh + ELK Stack Installation

Install Wazuh Manager, Elasticsearch, Logstash, and Kibana on the `wazuh-manager` VM (192.168.64.10, Ubuntu 24.04 ARM64).

**Run all commands on wazuh-manager via SSH:**
```bash
# [host]
ssh ubuntu@192.168.64.10
```

**Estimated time:** 45–60 minutes

---

## Choose Your Install Path

| Option | Time | When to use |
|--------|------|-------------|
| **A — Wazuh All-in-One Installer** | 30–45 min | First time building the lab; handles all certs and config automatically |
| **B — Ansible Automation** | 15–20 min | Rebuilding the lab; already ran Option A at least once; want repeatable provisioning |

Both options produce an identical working stack. Use **Option A** the first time so you understand what's being installed.

---

## Option A: Wazuh All-in-One Installer (Recommended for First Build)

Wazuh provides an official bash installer that deploys the complete stack.

### A.1 — Prepare the System

```bash
# [manager] Update packages first
sudo apt update && sudo apt upgrade -y

# [manager] Set the correct hostname (should already be set from Ubuntu install)
hostname
# Expected: wazuh-manager
# If wrong: sudo hostnamectl set-hostname wazuh-manager && sudo reboot
```

### A.2 — Download the Installer

```bash
# [manager]
cd ~
curl -sO https://packages.wazuh.com/4.x/wazuh-install.sh
curl -sO https://packages.wazuh.com/4.x/config.yml
```

### A.3 — Configure Nodes

Edit `config.yml` to match your lab IPs:

```bash
# [manager]
nano ~/config.yml
```

Replace the entire contents with:

```yaml
nodes:
  indexer:
    - name: node-1
      ip: "192.168.64.10"
  server:
    - name: wazuh-1
      ip: "192.168.64.10"
  dashboard:
    - name: dashboard
      ip: "192.168.64.10"
```

Save (Ctrl+O → Enter) and exit (Ctrl+X).

### A.4 — Run the Installer (4 commands)

Each command takes several minutes. Run them sequentially, not in parallel.

```bash
# [manager] Step 1: Generate TLS certificates (fast — <1 min)
sudo bash wazuh-install.sh --generate-config-files
# Expected final line: "INFO: Config files created: ./wazuh-install-files.tar"
```

```bash
# [manager] Step 2: Install Wazuh Indexer (~10 min)
sudo bash wazuh-install.sh --wazuh-indexer node-1
# Wait for: "INFO: Wazuh indexer cluster initialized."
# This installs OpenSearch (Elasticsearch-compatible indexer)
```

```bash
# [manager] Step 3: Install Wazuh Manager + Filebeat (~10 min)
sudo bash wazuh-install.sh --wazuh-server wazuh-1
# Wait for: "INFO: Wazuh server cluster started."
# This installs wazuh-manager + wazuh-filebeat
```

```bash
# [manager] Step 4: Install Wazuh Dashboard (~10 min)
sudo bash wazuh-install.sh --wazuh-dashboard dashboard
# Wait for: "INFO: Wazuh web interface ready."
# This installs the Kibana-based Wazuh Dashboard
```

### A.5 — Save Your Credentials

At the end of Step 4, the installer prints credentials:

```
INFO: --- Summary ---
INFO: You can access the web interface https://192.168.64.10
    User: admin
    Password: XXXXXXXXXXXXXXXX
INFO: Installation finished.
```

**Save these credentials immediately** — they're not stored in a readable location after install:

```bash
# [manager] The installer saves passwords here during install
# If you missed them, try:
sudo cat ~/wazuh-passwords.txt 2>/dev/null || echo "File not found — check installer output above"
```

Write the `admin` password in a secure note.

### A.6 — Verify All Services

```bash
# [manager]
sudo systemctl status wazuh-indexer
sudo systemctl status wazuh-manager
sudo systemctl status wazuh-dashboard
sudo systemctl status filebeat
```

All four should show `Active: active (running)`.

```bash
# [manager] Check Wazuh manager is listening on agent ports
ss -tlnp | grep -E '1514|1515|55000'
# Expected output:
# LISTEN  0  4096  0.0.0.0:1514  ...  (agent TCP)
# LISTEN  0  4096  0.0.0.0:1515  ...  (agent enrollment)
# LISTEN  0  4096  0.0.0.0:55000 ...  (Wazuh API)
```

### A.7 — Access the Wazuh Dashboard

```bash
# [host] Open in your Mac browser
open https://192.168.64.10
```

- Accept the self-signed certificate warning (click "Advanced" → "Proceed anyway")
- Log in: username `admin`, password from Step A.5
- Navigate: **Wazuh → Agents** — you'll see 0 agents now (we add them in Step 6)

If the dashboard doesn't load:
```bash
# [manager] Check dashboard service
sudo systemctl status wazuh-dashboard
sudo journalctl -u wazuh-dashboard -n 50 --no-pager
```

### A.8 — Deploy Custom Detection Rules

Copy the Phase 3 detection rules to the Wazuh rules directory:

```bash
# [host] Copy rules from the repo to wazuh-manager
scp ~/Projects/soc-home-lab/detections/wazuh-rules/*.xml ubuntu@192.168.64.10:/tmp/

# [manager] Move rules to the correct location
sudo cp /tmp/100*.xml /var/ossec/etc/rules/

# [manager] Verify syntax (Wazuh checks XML on restart)
sudo /var/ossec/bin/wazuh-control restart
sudo /var/ossec/bin/wazuh-control status
# Expected: All Wazuh processes are running
```

Verify rules loaded:

```bash
# [manager]
sudo grep -l "100001\|100003\|100005" /var/ossec/etc/rules/*.xml
# Expected: lists the XML files you copied
```

---

## Option B: Ansible Automation (Fast Rebuild)

Use this if you've already run Option A once and want to rebuild the lab quickly.

### B.1 — Verify Ansible Inventory

```bash
# [host]
cat ~/Projects/soc-home-lab/ansible/inventory.yml
# Confirm wazuh-manager shows 192.168.64.10
```

If the IPs don't match, edit the inventory:

```bash
# [host]
nano ~/Projects/soc-home-lab/ansible/inventory.yml
```

### B.2 — Test Connectivity

```bash
# [host]
cd ~/Projects/soc-home-lab/ansible
ansible -i inventory.yml wazuh_manager -m ping
# Expected: 192.168.64.10 | SUCCESS => {"ping": "pong"}
```

### B.3 — Run the Playbook

```bash
# [host]
cd ~/Projects/soc-home-lab/ansible
ansible-playbook -i inventory.yml playbooks/wazuh-manager.yml -K
# -K prompts for the sudo password on the remote VM
```

Expected output (abbreviated):

```
PLAY [Deploy Wazuh Manager] ************************************
TASK [common : Update apt cache] *** ok: [192.168.64.10]
TASK [wazuh : Install wazuh-manager] *** changed: [192.168.64.10]
TASK [elk : Install elasticsearch] *** changed: [192.168.64.10]
...
PLAY RECAP ****
192.168.64.10  : ok=47   changed=31   unreachable=0    failed=0
```

If `failed=0`, the stack is installed. If anything fails, the error message will name the failing task — search that task name in `ansible/roles/` for the relevant config.

### B.4 — Verify

Same verification as Option A:

```bash
# [host]
open https://192.168.64.10
# Log in with admin credentials
# Ansible stores generated passwords in ansible/group_vars/wazuh_manager.yml
```

---

## Post-Install Configuration

### Add Sysmon Log Source

After deploying Wazuh agents in Step 6, verify the Sysmon event channel is monitored:

```bash
# [manager]
sudo grep -A3 "Sysmon" /var/ossec/etc/ossec.conf
```

If missing, add it:

```bash
# [manager]
sudo nano /var/ossec/etc/ossec.conf
```

Add inside the `<ossec_config>` block (before the closing `</ossec_config>`):

```xml
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

```bash
# [manager] Restart to pick up config
sudo systemctl restart wazuh-manager
```

### Enable Wazuh Active Response (Optional)

Active response can automatically block IPs that trigger brute force rules. Enable it to test automated containment:

```bash
# [manager]
sudo nano /var/ossec/etc/ossec.conf
```

Find `<active-response>` or add before `</ossec_config>`:

```xml
<active-response>
  <command>firewall-drop</command>
  <location>local</location>
  <rules_id>100002</rules_id>  <!-- SSH brute force + success -->
  <timeout>600</timeout>
</active-response>
```

This drops traffic from any IP that triggers rule 100002 (SSH brute force with successful login) for 10 minutes.

---

## Troubleshooting

**Installer fails at "Generating certificates"**
```bash
# [manager] Check if the config.yml has correct IPs
cat ~/config.yml
# Ensure no spaces before/after IPs, valid YAML indentation
```

**`wazuh-indexer` service fails to start**
```bash
# [manager]
sudo journalctl -u wazuh-indexer -n 100 --no-pager
# Common cause: not enough RAM — indexer needs 4+ GB heap
# Fix: ensure VM has 8 GB RAM allocated in UTM
```

**Dashboard shows "Wazuh API" connection error**
```bash
# [manager]
sudo systemctl status wazuh-manager
# If stopped: sudo systemctl start wazuh-manager
# Then refresh the browser (Ctrl+Shift+R)
```

**"curl: SSL certificate problem" during download**
```bash
# [manager]
sudo apt install -y ca-certificates curl
sudo update-ca-certificates
# Retry the curl command
```

**Ansible playbook fails: "UNREACHABLE"**
```bash
# [host] Test manually
ssh ubuntu@192.168.64.10
# If this works, check that the inventory.yml has correct ansible_user and IP
# If this fails, return to Step 3 to fix network
```

**Port 1514 not listening after install**
```bash
# [manager]
sudo /var/ossec/bin/wazuh-control start
sudo /var/ossec/bin/wazuh-control status
# All processes should show "running"
```

---

## Checklist — Step 4 Complete When:

- [ ] `sudo systemctl status wazuh-indexer wazuh-manager wazuh-dashboard filebeat` — all Active
- [ ] `ss -tlnp | grep 1514` shows LISTEN
- [ ] `https://192.168.64.10` opens Wazuh Dashboard in Mac browser
- [ ] Logged in with admin credentials
- [ ] Custom rules (100001-100019) copied to `/var/ossec/etc/rules/`
- [ ] `wazuh-control restart` completed with no errors

**Parallel next steps:**
- **→ [05-sysmon-setup.md](05-sysmon-setup.md)** — set up Windows telemetry  
- **→ [07-kali-setup.md](07-kali-setup.md)** — set up attack tools  
- **Step 6** is blocked until both Step 4 and Step 5 are done.
