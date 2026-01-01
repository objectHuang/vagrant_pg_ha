#!/bin/bash
# Common setup script for PostgreSQL HA cluster nodes

set -e

PG_VERSION=$1

echo "==> Installing dependencies..."

# Update and install prerequisites
apt-get update
apt-get install -y wget gnupg2 lsb-release curl python3 python3-pip python3-venv

# Add PostgreSQL APT Repository
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# Update and install PostgreSQL
apt-get update
apt-get install -y postgresql-${PG_VERSION} postgresql-contrib-${PG_VERSION}

# Stop and disable default PostgreSQL service (Patroni will manage it)
systemctl stop postgresql
systemctl disable postgresql

# Install Patroni and dependencies
echo "==> Installing Patroni..."
pip3 install patroni[etcd] psycopg2-binary

# Create patroni user and directories
useradd -r -s /bin/false patroni 2>/dev/null || true
mkdir -p /etc/patroni
mkdir -p /var/lib/patroni
mkdir -p /var/log/patroni
chown -R postgres:postgres /var/lib/patroni
chown -R postgres:postgres /var/log/patroni

echo "==> Common setup completed."
