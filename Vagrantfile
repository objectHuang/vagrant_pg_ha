# -*- mode: ruby -*-
# vi: set ft=ruby :

# PostgreSQL HA Cluster with Patroni + etcd
# Using Ansible for provisioning
#
# USAGE: Just run "vagrant up"

CLUSTER_CONFIG = {
  :nodes => [
    { :name => "pg-node1", :ip => "192.168.8.10" },
    { :name => "pg-node2", :ip => "192.168.8.11" },
    { :name => "pg-node3", :ip => "192.168.8.12" }
  ]
}

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_check_update = false

  CLUSTER_CONFIG[:nodes].each_with_index do |node, index|
    is_last_node = (index == CLUSTER_CONFIG[:nodes].length - 1)

    config.vm.define node[:name] do |node_config|
      node_config.vm.hostname = node[:name]
      node_config.vm.network "private_network", ip: node[:ip]

      node_config.vm.provider "virtualbox" do |vb|
        vb.name = node[:name]
        vb.memory = 4096
        vb.cpus = 2
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      end

      # Run Ansible ONLY after the last node is created
      # This ensures all VMs exist before provisioning starts
      if is_last_node
        node_config.vm.provision "ansible" do |ansible|
          ansible.playbook = "ansible/playbook.yml"
          ansible.inventory_path = "ansible/inventory.ini"
          ansible.limit = "all"
          ansible.groups = {
            "pg_cluster" => CLUSTER_CONFIG[:nodes].map { |n| n[:name] }
          }
        end
      end
    end
  end
end
