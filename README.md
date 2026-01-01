# PostgreSQL HA Cluster with Automatic Failover

This project creates a highly available PostgreSQL cluster using **Patroni** and **etcd** for automatic failover, provisioned with **Ansible**.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    PostgreSQL HA Cluster                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                     etcd Cluster                            │ │
│  │   (Distributed Consensus for Leader Election)               │ │
│  │                                                              │ │
│  │  ┌──────────┐    ┌──────────┐    ┌──────────┐              │ │
│  │  │  etcd    │◄──►│  etcd    │◄──►│  etcd    │              │ │
│  │  │ (node1)  │    │ (node2)  │    │ (node3)  │              │ │
│  │  └──────────┘    └──────────┘    └──────────┘              │ │
│  └────────────────────────────────────────────────────────────┘ │
│                              │                                   │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Patroni Layer                            │ │
│  │   (Manages PostgreSQL + Automatic Failover)                 │ │
│  │                                                              │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │ │
│  │  │   Patroni    │  │   Patroni    │  │   Patroni    │      │ │
│  │  │  (pg-node1)  │  │  (pg-node2)  │  │  (pg-node3)  │      │ │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │ │
│  └─────────┼─────────────────┼─────────────────┼──────────────┘ │
│            │                 │                 │                 │
│            ▼                 ▼                 ▼                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │  PostgreSQL  │    │  PostgreSQL  │    │  PostgreSQL  │       │
│  │   PRIMARY    │───►│   REPLICA    │    │   REPLICA    │       │
│  │ 192.168.8.10 │    │ 192.168.8.11 │    │ 192.168.8.12 │       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads) (>= 2.3)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (>= 7.0)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/) (>= 2.9)
- At least 12GB of free RAM
- At least 30GB of free disk space

### Install Ansible (if not installed)

```bash
# Create a Python virtual environment
python3 -m venv venv

# Activate the virtual environment
source venv/bin/activate

# Install Ansible via pip
pip3 install ansible

# Verify installation
ansible --version
```

> **Note**: Always activate the virtual environment (`source venv/bin/activate`) before running `vagrant up`.

## Quick Start

```bash
# Activate virtual environment (if not already active)
source venv/bin/activate

# Start the cluster (creates VMs and provisions with Ansible)
vagrant up

# Check cluster status
vagrant ssh pg-node1 -c "sudo patronictl -c /etc/patroni/patroni.yml list"
```

## How It Works

Ansible solves the etcd bootstrap problem:

```
Phase 1: Vagrant creates all 3 VMs (sequential)
         pg-node1 → pg-node2 → pg-node3

Phase 2: Ansible runs on ALL nodes (parallel!)
         ┌─────────┐  ┌─────────┐  ┌─────────┐
         │ node1   │  │ node2   │  │ node3   │
         │ install │  │ install │  │ install │  ← All at once
         └────┬────┘  └────┬────┘  └────┬────┘
              │            │            │
              └────────────┼────────────┘
                           ▼
         ┌─────────┐  ┌─────────┐  ┌─────────┐
         │ etcd    │──│ etcd    │──│ etcd    │  ← Start together
         └────┬────┘  └────┬────┘  └────┬────┘
              │            │            │
              └────────────┼────────────┘
                           ▼
         ┌─────────┐  ┌─────────┐  ┌─────────┐
         │patroni  │  │patroni  │  │patroni  │  ← Start together
         └─────────┘  └─────────┘  └─────────┘
```

## Cluster Details

| Node | IP Address | Services |
|------|------------|----------|
| pg-node1 | 192.168.8.10 | etcd, Patroni, PostgreSQL |
| pg-node2 | 192.168.8.11 | etcd, Patroni, PostgreSQL |
| pg-node3 | 192.168.8.12 | etcd, Patroni, PostgreSQL |

## Usage Commands

### Check Cluster Status
```bash
vagrant ssh pg-node1
sudo patronictl -c /etc/patroni/patroni.yml list
```

### Planned Switchover
```bash
sudo patronictl -c /etc/patroni/patroni.yml switchover
```

### Test Automatic Failover
```bash
# Stop primary's Patroni
vagrant ssh pg-node1 -c "sudo systemctl stop patroni"

# Wait 30 seconds, check new leader
vagrant ssh pg-node2 -c "sudo patronictl -c /etc/patroni/patroni.yml list"

# Restart old primary (rejoins as replica)
vagrant ssh pg-node1 -c "sudo systemctl start patroni"
```

## Credentials

| User | Password | Purpose |
|------|----------|---------|
| postgres | postgres_password | Superuser |
| admin | admin_password | Admin |
| replicator | replicator_password | Replication |

## Project Structure

```
.
├── Vagrantfile              # Defines VMs and auto-generates Ansible inventory
├── ansible/
│   ├── ansible.cfg          # SSH and host key settings
│   ├── playbook.yml         # Main provisioning playbook
│   └── templates/
│       ├── etcd.service.j2
│       ├── patroni.yml.j2
│       └── patroni.service.j2
└── README.md
```

> **Note**: Vagrant automatically generates the Ansible inventory file at `.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory` during provisioning.

## Troubleshooting

```bash
# Check services
vagrant ssh pg-node1 -c "sudo systemctl status etcd patroni"

# View logs
vagrant ssh pg-node1 -c "sudo journalctl -u patroni -f"

# Re-run Ansible only
vagrant provision
```

## License

MIT

MIT
