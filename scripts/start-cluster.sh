#!/bin/bash
# Start PostgreSQL HA Cluster
# Run this AFTER all VMs are created: vagrant ssh pg-node1 -c "sudo /vagrant/scripts/start-cluster.sh"

set -e

# Cluster node IPs
NODES="192.168.8.10 192.168.8.11 192.168.8.12"

echo "=============================================="
echo "  Starting PostgreSQL HA Cluster"
echo "=============================================="
echo ""

# Check if we can reach all nodes
echo "==> Checking connectivity to all nodes..."
for ip in ${NODES}; do
    if ping -c 1 -W 2 ${ip} >/dev/null 2>&1; then
        echo "   ✓ ${ip} is reachable"
    else
        echo "   ✗ ${ip} is NOT reachable"
        echo "   ERROR: All nodes must be running. Use 'vagrant up' first."
        exit 1
    fi
done

echo ""
echo "==> Step 1: Starting etcd on ALL nodes simultaneously..."
echo ""

# Start etcd on all nodes in parallel using SSH
for ip in ${NODES}; do
    echo "   Starting etcd on ${ip}..."
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        vagrant@${ip} "sudo systemctl start etcd" 2>/dev/null &
done

# Wait for all SSH commands to complete
wait
echo "   All etcd start commands sent."

echo ""
echo "==> Step 2: Waiting for etcd cluster to form..."
sleep 5

for i in {1..60}; do
    if etcdctl endpoint health 2>/dev/null; then
        echo ""
        echo "   ✓ etcd cluster is healthy!"
        etcdctl member list 2>/dev/null
        break
    fi
    if [ $i -eq 60 ]; then
        echo "   Warning: etcd health check timed out"
    fi
    echo "   Waiting for etcd cluster... (attempt $i/60)"
    sleep 3
done

echo ""
echo "==> Step 3: Starting Patroni on ALL nodes..."
echo ""

# Start Patroni on all nodes in parallel
for ip in ${NODES}; do
    echo "   Starting Patroni on ${ip}..."
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        vagrant@${ip} "sudo systemctl start patroni" 2>/dev/null &
done

wait
echo "   All Patroni start commands sent."

echo ""
echo "==> Step 4: Waiting for Patroni cluster to initialize..."
sleep 10

# Check Patroni status
echo ""
echo "==> Cluster Status:"
echo ""
patronictl -c /etc/patroni/patroni.yml list 2>/dev/null || \
    echo "   (Patroni still initializing, try again in a few seconds)"

echo ""
echo "=============================================="
echo "  Cluster Startup Complete!"
echo "=============================================="
echo ""
echo "Useful commands:"
echo "  patronictl -c /etc/patroni/patroni.yml list"
echo "  patronictl -c /etc/patroni/patroni.yml switchover"
echo "  etcdctl member list"
echo ""
