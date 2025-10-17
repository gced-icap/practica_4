# -*- mode: ruby -*-
# vi: set ft=ruby :

# Modifica la variable STUDENT_PREFIX para sustituir "X" por tu prefijo
# Ejemplo, el alumno Roberto Rey Expósito, que hace la práctica en el curso
# 25/26, utilizará el siguiente prefijo: rre2526
STUDENT_PREFIX="X"

# require a Vagrant recent version
Vagrant.require_version ">= 2.4.0"

# Hostnames and IP addresses
MASTER_HOSTNAME = "#{STUDENT_PREFIX}-master"
WORKER_HOSTNAME = "#{STUDENT_PREFIX}-worker"
MASTER_CORES = 1
MASTER_MEM = 1024
NUM_WORKERS = 2
WORKER_CORES = 1
WORKER_MEM = 2048
MASTER_IP="192.168.100.10"

require "ipaddr"
WORKER_IP_ADDR = IPAddr.new(MASTER_IP)

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.box_version = "202508.03.0"
  config.vm.box_check_update = false
  config.vbguest.auto_update = false

  # Master node
  config.vm.define "master", primary: true do |master|
    master.vm.hostname = MASTER_HOSTNAME
    master.vm.network "private_network", ip: "#{MASTER_IP}", virtualbox__intnet: true
    master.vm.network "forwarded_port", guest: 9870, host: 8080, host_ip: "127.0.0.1"
    master.vm.synced_folder ".", "/vagrant", disabled: false

    master.vm.provider "virtualbox" do |prov|
        prov.name = "ICAP-P4-Master"
        prov.cpus = MASTER_CORES
        prov.memory = MASTER_MEM
        prov.gui = false
        prov.linked_clone = false

        for i in 0..1 do
            filename = "disks/master-disk#{i}.vdi"
            unless File.exist?(filename)
                prov.customize ["createmedium", "disk", "--filename", filename, "--format", "vdi", "--size", 10 * 1024]
            end
            prov.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", i + 1, "--device", 0, "--type", "hdd", "--medium", filename]
        end
    end
  end
  
  # Worker nodes
  (1..NUM_WORKERS).each do |n|
    NAME = "worker#{n}"
    WORKER_IP_ADDR = WORKER_IP_ADDR.succ
    ip_addr = WORKER_IP_ADDR.to_s
      
    config.vm.define "worker#{n}" do |worker|
        worker.vm.hostname = "#{WORKER_HOSTNAME}#{n}"
        worker.vm.network "private_network", ip: ip_addr, virtualbox__intnet: true
        worker.vm.synced_folder ".", "/vagrant", disabled: true
          
        worker.vm.provider "virtualbox" do |prov|
            prov.name = "ICAP-P4-Worker#{n}"
            prov.cpus = WORKER_CORES
            prov.memory = WORKER_MEM
            prov.gui = false
            prov.linked_clone = false

            for i in 0..1 do
                filename = "disks/worker#{n}-disk#{i}.vdi"
                unless File.exist?(filename)
                    prov.customize ["createmedium", "disk", "--filename", filename, "--format", "vdi", "--size", 10 * 1024]
                end
                prov.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", i + 1, "--device", 0, "--type", "hdd", "--medium", filename]
            end
        end
    end
  end
  
  # Global provisioning bash script
  config.vm.provision "shell", path: "provisioning/bootstrap.sh" do |script|
      script.args = [MASTER_IP, MASTER_HOSTNAME, WORKER_HOSTNAME, NUM_WORKERS]
  end
end
