#!/bin/bash
# Replica node setup script

set -e

PG_VERSION=$1
PRIMARY_IP=$2
PG_DATA="/var/lib/postgresql/${PG_VERSION}/main"
PG_CONF="/etc/postgresql/${PG_VERSION}/main"

echo "==> Configuring Replica PostgreSQL node..."
echo "==> Primary IP: ${PRIMARY_IP}"

# Remove existing data directory
rm -rf ${PG_DATA}/*

# Wait for primary to be ready
echo "==> Waiting for primary node to be ready..."
sleep 10

# Create .pgpass file for passwordless replication
cat > /var/lib/postgresql/.pgpass << EOF
${PRIMARY_IP}:5432:replication:replicator:replicator_password
EOF
chown postgres:postgres /var/lib/postgresql/.pgpass
chmod 600 /var/lib/postgresql/.pgpass

# Perform base backup from primary
echo "==> Performing base backup from primary..."
sudo -u postgres pg_basebackup -h ${PRIMARY_IP} -D ${PG_DATA} -U replicator -P -v -R -X stream -C -S $(hostname)_slot

# Configure postgresql.conf for hot standby
cat >> ${PG_CONF}/postgresql.conf << EOF

# Hot Standby Settings
listen_addresses = '*'
hot_standby = on
hot_standby_feedback = on

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d.log'
EOF

# Ensure proper ownership
chown -R postgres:postgres ${PG_DATA}

# Start PostgreSQL as replica
systemctl start postgresql

# Wait and verify replication
sleep 5

echo "==> Verifying replication status..."
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"

echo "==> Replica node configuration completed."
echo "==> Replica IP: $(hostname -I | awk '{print $2}')"
