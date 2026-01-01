#!/bin/bash
# Rejoin a failed primary (or any node) as a replica
# Usage: sudo ./rejoin-as-replica.sh <new_primary_ip>

set -e

if [ -z "$1" ]; then
    echo "Usage: sudo ./rejoin-as-replica.sh <new_primary_ip>"
    echo "Example: sudo ./rejoin-as-replica.sh 192.168.8.11"
    exit 1
fi

PG_VERSION="16"
PRIMARY_IP=$1
PG_DATA="/var/lib/postgresql/${PG_VERSION}/main"
PG_CONF="/etc/postgresql/${PG_VERSION}/main"

echo "=========================================="
echo "  Rejoin as Replica Script"
echo "=========================================="
echo ""
echo "New Primary IP: ${PRIMARY_IP}"
echo "This node will become a REPLICA"
echo ""
echo "WARNING: This will DESTROY all local data!"
read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Operation cancelled."
    exit 0
fi

echo ""
echo "==> Step 1: Stopping PostgreSQL..."
systemctl stop postgresql

echo ""
echo "==> Step 2: Removing old data directory..."
rm -rf ${PG_DATA}/*

echo ""
echo "==> Step 3: Creating .pgpass for replication..."
cat > /var/lib/postgresql/.pgpass << EOF
${PRIMARY_IP}:5432:replication:replicator:replicator_password
EOF
chown postgres:postgres /var/lib/postgresql/.pgpass
chmod 600 /var/lib/postgresql/.pgpass

echo ""
echo "==> Step 4: Performing base backup from new primary..."
sudo -u postgres pg_basebackup \
    -h ${PRIMARY_IP} \
    -D ${PG_DATA} \
    -U replicator \
    -P -v -R -X stream \
    -C -S $(hostname)_slot

echo ""
echo "==> Step 5: Ensuring proper ownership..."
chown -R postgres:postgres ${PG_DATA}

echo ""
echo "==> Step 6: Starting PostgreSQL as replica..."
systemctl start postgresql

sleep 3

echo ""
echo "==> Step 7: Verifying replica status..."
IS_REPLICA=$(sudo -u postgres psql -tAc "SELECT pg_is_in_recovery();")

if [ "$IS_REPLICA" == "t" ]; then
    echo "✓ SUCCESS: This node is now a REPLICA!"
else
    echo "✗ ERROR: Node is not in recovery mode. Check logs."
    exit 1
fi

echo ""
echo "=========================================="
echo "  REJOIN COMPLETE"
echo "=========================================="
echo ""
echo "This node is now replicating from: ${PRIMARY_IP}"
echo ""
echo "Verify with: sudo -u postgres psql -c \"SELECT pg_is_in_recovery();\""
echo ""
