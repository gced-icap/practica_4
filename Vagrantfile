# -*- mode: ruby -*-
# vi: set ft=ruby :

# Modifica la variable STUDENT_PREFIX para sustituir "X" por tu prefijo
# Ejemplo, el alumno Roberto Rey Expósito, que hace la práctica en el curso
# 26/27, utilizará el siguiente prefijo: rre2627
STUDENT_PREFIX = "X"

# require a Vagrant recent version
Vagrant.require_version ">= 2.4.0"

# Hostnames, IP addresses and resources
MASTER_HOSTNAME    = "#{STUDENT_PREFIX}-master"
WORKER_HOSTNAME    = "#{STUDENT_PREFIX}-worker"
MASTER_IP          = "192.168.100.10"
NUM_WORKERS        = 2
MASTER_CORES       = 1
MASTER_MEMORY      = 1024
WORKER_CORES       = 1
WORKER_MEMORY      = 2048
NUM_DISKS          = 2
DISK_SIZE          = "10GB"
CPU_EXECUTION_CAP  = 100

require "ipaddr"

Vagrant.configure("2") do |config|
  config.vm.box = "rreye/debian-13"
  config.vm.box_version = "20260304"
  config.vm.box_check_update = false
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider "virtualbox" do |vbox|
    vbox.gui = false
    vbox.linked_clone = false
    vbox.check_guest_additions = false
    vbox.customize ["modifyvm", :id, "--cpuexecutioncap", CPU_EXECUTION_CAP]
  end

  # Master node
  config.vm.define "master", primary: true do |master|
    master.vm.hostname = MASTER_HOSTNAME
    master.vm.network "private_network", ip: MASTER_IP, virtualbox__intnet: true
    master.vm.network "forwarded_port", guest: 9870, host: 8080, host_ip: "127.0.0.1"
    master.vm.synced_folder ".", "/vagrant", disabled: false

    (1..NUM_DISKS).each do |n|
        master.vm.disk :disk, size: DISK_SIZE, primary: false, name: "master-disk#{n}"
    end
    
    master.vm.provider "virtualbox" do |vbox|
        vbox.name = "ICAP-P4-Master"
        vbox.cpus = MASTER_CORES
        vbox.memory = MASTER_MEMORY
    end
  end
  
  # Worker nodes
  current_ip = IPAddr.new(MASTER_IP)
  
  (1..NUM_WORKERS).each do |i|
    worker_name = "worker#{i}"
    current_ip = current_ip.succ
    worker_ip   = current_ip.to_s
      
    config.vm.define "worker#{i}" do |worker|
        worker.vm.hostname = "#{WORKER_HOSTNAME}#{i}"
        worker.vm.network "private_network", ip: worker_ip, virtualbox__intnet: true

        (1..NUM_DISKS).each do |n|
            worker.vm.disk :disk, size: DISK_SIZE, primary: false, name: "worker#{i}-disk#{n}"
        end
              
        worker.vm.provider "virtualbox" do |vbox|
            vbox.name = "ICAP-P4-Worker#{i}"
            vbox.cpus = WORKER_CORES
            vbox.memory = WORKER_MEMORY
        end
      end
  end

  # Global provisioning bash script
  config.vm.provision "shell", path: "provisioning/bootstrap.sh" do |script|
      script.args = [MASTER_IP, MASTER_HOSTNAME, WORKER_HOSTNAME, NUM_WORKERS]
  end
end
