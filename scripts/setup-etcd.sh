#!/bin/bash
# Setup etcd for distributed consensus
# Installs and configures etcd (does NOT start - finalize-node.sh starts it)

set -e

NODE_NAME=$1
NODE_IP=$2
INITIAL_CLUSTER=$3

ETCD_VERSION="v3.5.11"

echo "==> Installing etcd ${ETCD_VERSION}..."

# Download and install etcd
cd /tmp
curl -L https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz -o etcd.tar.gz
tar xzf etcd.tar.gz
mv etcd-${ETCD_VERSION}-linux-amd64/etcd* /usr/local/bin/
rm -rf etcd-${ETCD_VERSION}-linux-amd64 etcd.tar.gz

# Create etcd user and directories
useradd -r -s /bin/false etcd 2>/dev/null || true
mkdir -p /var/lib/etcd
chown -R etcd:etcd /var/lib/etcd

# Create etcd systemd service
cat > /etc/systemd/system/etcd.service << EOF
[Unit]
Description=etcd distributed key-value store
Documentation=https://github.com/etcd-io/etcd
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
User=etcd
TimeoutStartSec=0
ExecStart=/usr/local/bin/etcd \\
  --name ${NODE_NAME} \\
  --data-dir /var/lib/etcd \\
  --initial-advertise-peer-urls http://${NODE_IP}:2380 \\
  --listen-peer-urls http://0.0.0.0:2380 \\
  --listen-client-urls http://${NODE_IP}:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls http://${NODE_IP}:2379 \\
  --initial-cluster-token pg-etcd-cluster \\
  --initial-cluster ${INITIAL_CLUSTER} \\
  --initial-cluster-state new \\
  --enable-v2=true \\
  --heartbeat-interval 1000 \\
  --election-timeout 5000

Restart=always
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable etcd

echo "==> etcd installed and configured on ${NODE_NAME}"
echo "==> etcd will be started by finalize-node.sh after all nodes are ready"

echo "==> etcd setup completed on ${NODE_NAME}"
