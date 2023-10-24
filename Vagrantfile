# -*- mode: ruby -*-
# vi: set ft=ruby :

# Modifica la variable STUDENT_PREFIX para sustituir "xxx" por tu prefijo
# Ejemplo, el alumno Roberto Rey Expósito, que hace la práctica en el curso
# 23/24, utilizará el siguiente prefijo: rre2324
STUDENT_PREFIX="xxx"

# require a Vagrant recent version
Vagrant.require_version ">= 2.3.0"

# Hostnames and IP addresses
MASTER_HOSTNAME = "#{STUDENT_PREFIX}-master"
WORKER_HOSTNAME = "#{STUDENT_PREFIX}-worker"
NUM_WORKERS = 2
WORKER_MEM = 1024
BASEIP="10.10.0"
MASTERIP=10

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"
  config.vm.box_version = "12.20230723.1"
  config.vm.box_check_update = false
  config.vbguest.auto_update = false

  # Master node
  config.vm.define "master", primary: true do |master|
    master.vm.hostname = MASTER_HOSTNAME
    master.vm.network "private_network", ip: "#{BASEIP}.#{MASTERIP}", virtualbox__intnet: true
    master.vm.network "forwarded_port", guest: 9870, host: 8080, host_ip: "127.0.0.1"

    master.vm.provider "virtualbox" do |prov|
	prov.name = "ICAP-P4-Master"
        prov.cpus = 1
        prov.memory = 1024
	prov.gui = false
	prov.linked_clone = false

        for i in 0..1 do
            filename = "disks/master-disk#{i}.vdi"
            unless File.exist?(filename)
                prov.customize ["createmedium", "disk", "--filename", filename, "--format", "vdi", "--size", 5 * 1024]
            end
	    prov.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", i + 1, "--device", 0, "--type", "hdd", "--medium", filename]
        end
    end
  end
  
  # Worker nodes
  (1..NUM_WORKERS).each do |i|
    config.vm.define "worker#{i}" do |worker|
        worker.vm.hostname = "#{WORKER_HOSTNAME}#{i}"
        worker.vm.network "private_network", ip: "#{BASEIP}.#{i + MASTERIP}", virtualbox__intnet: true
        
        worker.vm.provider "virtualbox" do |prov|
	    prov.name = "ICAP-P4-Worker#{i}"
            prov.cpus = 1
            prov.memory = WORKER_MEM
	    prov.gui = false
	    prov.linked_clone = false

            for j in 0..1 do
                filename = "disks/worker#{i}-disk#{j}.vdi"
                unless File.exist?(filename)
                    prov.customize ["createmedium", "disk", "--filename", filename, "--format", "vdi", "--size", 5 * 1024]
                end
                prov.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", j + 1, "--device", 0, "--type", "hdd", "--medium", filename]
            end
        end
    end
  end
  
  # Global provisioning bash script
  config.vm.provision "shell", path: "provisioning/bootstrap.sh" do |script|
      script.args = [NUM_WORKERS, BASEIP, MASTERIP, MASTER_HOSTNAME, WORKER_HOSTNAME]
  end
end
