#!/bin/bash
# Setup Patroni for PostgreSQL HA

set -e

NODE_NAME=$1
NODE_IP=$2
PG_VERSION=$3
PATRONI_SCOPE=$4
ETCD_ENDPOINTS=$5

echo "==> Configuring Patroni on ${NODE_NAME}..."

# Create Patroni configuration
cat > /etc/patroni/patroni.yml << EOF
scope: ${PATRONI_SCOPE}
namespace: /postgresql/
name: ${NODE_NAME}

restapi:
  listen: ${NODE_IP}:8008
  connect_address: ${NODE_IP}:8008

etcd:
  hosts: ${ETCD_ENDPOINTS}

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: on
        max_wal_senders: 5
        max_replication_slots: 5
        wal_keep_size: 256MB
        hot_standby_feedback: on
        logging_collector: on
        log_directory: log
        log_filename: postgresql-%Y-%m-%d.log
        log_statement: ddl
        log_connections: on
        log_disconnections: on

  initdb:
    - encoding: UTF8
    - data-checksums

  pg_hba:
    - host replication replicator 192.168.8.0/24 scram-sha-256
    - host all all 192.168.8.0/24 scram-sha-256
    - host all all 0.0.0.0/0 scram-sha-256

  users:
    admin:
      password: admin_password
      options:
        - createrole
        - createdb
    replicator:
      password: replicator_password
      options:
        - replication

postgresql:
  listen: ${NODE_IP}:5432
  connect_address: ${NODE_IP}:5432
  data_dir: /var/lib/patroni/${PATRONI_SCOPE}
  bin_dir: /usr/lib/postgresql/${PG_VERSION}/bin
  pgpass: /var/lib/postgresql/.pgpass
  authentication:
    replication:
      username: replicator
      password: replicator_password
    superuser:
      username: postgres
      password: postgres_password
    rewind:
      username: postgres
      password: postgres_password
  parameters:
    unix_socket_directories: /var/run/postgresql

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
EOF

chown postgres:postgres /etc/patroni/patroni.yml
chmod 600 /etc/patroni/patroni.yml

# Create Patroni data directory
mkdir -p /var/lib/patroni/${PATRONI_SCOPE}
chown -R postgres:postgres /var/lib/patroni

# Create Patroni systemd service
cat > /etc/systemd/system/patroni.service << EOF
[Unit]
Description=Patroni PostgreSQL Cluster Manager
Documentation=https://patroni.readthedocs.io
After=network.target etcd.service
Wants=network-online.target

[Service]
Type=simple
User=postgres
Group=postgres
ExecStart=/usr/local/bin/patroni /etc/patroni/patroni.yml
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
TimeoutSec=30
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable but don't start Patroni (finalize-node.sh will start it after etcd is ready)
systemctl daemon-reload
systemctl enable patroni

echo "==> Patroni configured on ${NODE_NAME}"
echo "==> Patroni will be started by finalize-node.sh after etcd is ready"
