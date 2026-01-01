#!/bin/bash
# Primary node setup script

set -e

PG_VERSION=$1
NETWORK_PREFIX=$2
PG_DATA="/var/lib/postgresql/${PG_VERSION}/main"
PG_CONF="/etc/postgresql/${PG_VERSION}/main"

echo "==> Configuring Primary PostgreSQL node..."

# Configure postgresql.conf for replication
cat >> ${PG_CONF}/postgresql.conf << EOF

# Replication Settings
listen_addresses = '*'
wal_level = replica
max_wal_senders = 5
wal_keep_size = 256MB
hot_standby = on
synchronous_commit = on

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d.log'
log_statement = 'ddl'
log_connections = on
log_disconnections = on
EOF

# Configure pg_hba.conf for replication access
cat >> ${PG_CONF}/pg_hba.conf << EOF

# Replication connections
host    replication     replicator      ${NETWORK_PREFIX}.0/24          scram-sha-256
host    all             all             ${NETWORK_PREFIX}.0/24          scram-sha-256
EOF

# Start PostgreSQL
systemctl start postgresql

# Wait for PostgreSQL to be ready
sleep 5

# Create replication user
sudo -u postgres psql << EOF
CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'replicator_password';
EOF

# Create a test database
sudo -u postgres psql << EOF
CREATE DATABASE testdb;
\c testdb
CREATE TABLE test_table (
    id SERIAL PRIMARY KEY,
    data VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO test_table (data) VALUES ('Initial data from primary');
EOF

echo "==> Primary node configuration completed."
echo "==> Primary IP: $(hostname -I | awk '{print $2}')"
echo "==> Replication user: replicator"
