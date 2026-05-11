# Step 4: Wazuh + ELK Stack Installation

Deploy Wazuh Manager, Elasticsearch, Logstash, and Kibana on the `wazuh-manager` VM (192.168.64.10, Ubuntu 24.04 ARM64).

**Estimated time:** 45–60 minutes

---

## Option A: Wazuh All-in-One Installer (Recommended)

Wazuh provides an official installation assistant that deploys the full stack:

```bash
# [manager] Download and run the Wazuh installation assistant
curl -sO https://packages.wazuh.com/4.x/wazuh-install.sh
curl -sO https://packages.wazuh.com/4.x/config.yml
```

Edit `config.yml` to set your node names and IPs:

```yaml
nodes:
  indexer:
    - name: node-1
      ip: 192.168.64.10
  server:
    - name: wazuh-1
      ip: 192.168.64.10
  dashboard:
    - name: dashboard
      ip: 192.168.64.10
```

```bash
# [manager] Generate certificates
bash wazuh-install.sh --generate-config-files

# [manager] Install Wazuh indexer (Elasticsearch fork)
bash wazuh-install.sh --wazuh-indexer node-1

# [manager] Install Wazuh manager + Filebeat
bash wazuh-install.sh --wazuh-server wazuh-1

# [manager] Install Wazuh dashboard (Kibana fork)
bash wazuh-install.sh --wazuh-dashboard dashboard
```

> **Note:** The Wazuh stack uses its own Elasticsearch-compatible indexer (OpenSearch-based). For ELK 8.x, see Option B.

---

## Option B: Vanilla ELK 8.x + Wazuh Manager (Advanced)

Use this if you want the upstream Elasticsearch + Kibana 8.x stack.

### Install Elasticsearch 8.x

```bash
# [manager] Add Elastic GPG key and repo
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
sudo apt update && sudo apt install -y elasticsearch

# [manager] Configure Elasticsearch
sudo nano /etc/elasticsearch/elasticsearch.yml
```

Key settings in `elasticsearch.yml`:

```yaml
cluster.name: soc-lab
node.name: node-1
network.host: 127.0.0.1
http.port: 9200
discovery.type: single-node
xpack.security.enabled: true
xpack.security.enrollment.enabled: true
```

```bash
# [manager] Set JVM heap (4 GB for 8 GB VM)
echo "-Xms4g" | sudo tee /etc/elasticsearch/jvm.options.d/heap.options
echo "-Xmx4g" | sudo tee -a /etc/elasticsearch/jvm.options.d/heap.options

# [manager] Start and enable
sudo systemctl daemon-reload
sudo systemctl enable --now elasticsearch
sudo systemctl status elasticsearch
```

### Install Kibana

```bash
# [manager]
sudo apt install -y kibana

sudo nano /etc/kibana/kibana.yml
```

Key settings:

```yaml
server.host: "0.0.0.0"
server.name: "soc-lab-kibana"
elasticsearch.hosts: ["https://127.0.0.1:9200"]
xpack.security.enabled: true
```

```bash
sudo systemctl enable --now kibana
```

### Install Wazuh Manager

```bash
# [manager] Add Wazuh GPG key and repo
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo gpg --dearmor -o /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list
sudo apt update && sudo apt install -y wazuh-manager

sudo systemctl enable --now wazuh-manager
sudo systemctl status wazuh-manager
```

### Install Logstash

```bash
# [manager]
sudo apt install -y logstash

# Download Wazuh Logstash pipeline config
sudo curl -o /etc/logstash/conf.d/wazuh-logstash.conf \
  https://packages.wazuh.com/integrations/elastic/4.x-8.x/logstash/wazuh-logstash.conf

sudo systemctl enable --now logstash
```

---

## Verify Installation

```bash
# [manager] Check all services
sudo systemctl status wazuh-manager elasticsearch logstash kibana

# [manager] Check Wazuh manager is listening
ss -tlnp | grep -E '1514|1515|55000'

# [host] Access Kibana dashboard
open https://192.168.64.10:5601
# Default credentials: admin / (generated during install — check wazuh-passwords.txt)
```

---

## Post-Install Configuration

```bash
# [manager] Change default Wazuh API password
sudo /var/ossec/bin/wazuh-control restart

# [manager] Verify agent manager is ready for registrations
sudo /var/ossec/bin/agent_control -l
```

Save the generated passwords from the installer output. They will be needed for agent registration and Kibana login.
