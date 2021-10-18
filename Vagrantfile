# -*- mode: ruby -*-
# vi: set ft=ruby :

NUM_WORKERS = 2
WORKER_MEM = 1024
BASEIP="192.168.100"
MASTERIP=10

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.box_version = "20210917.0.0"
  config.vm.box_check_update = false

  # Master node
  config.vm.define "master", primary: true do |master|
    master.vm.hostname = "master"
    master.vm.network :private_network, ip: "#{BASEIP}.#{MASTERIP}"

    master.vm.provider :virtualbox do |prov|
	prov.name = "ICAP-P4-Master"
        prov.cpus = 1
        prov.memory = 1024
	prov.linked_clone = true

        for i in 0..1 do
            filename = "disks/#{master.vm.hostname}-disk#{i}.vdi"
            unless File.exist?(filename)
                prov.customize ["createmedium", "disk", "--filename", filename, "--format", "vdi", "--size", 5 * 1024]
            end
	    prov.customize ["storageattach", :id, "--storagectl", "SCSI", "--port", i + 3, "--device", 0, "--type", "hdd", "--medium", filename]
        end
    end
  end
  
  # Worker nodes
  (1..NUM_WORKERS).each do |i|
    config.vm.define "worker#{i}" do |worker|
        worker.vm.hostname = "worker#{i}"
        worker.vm.network :private_network, ip: "#{BASEIP}.#{i + MASTERIP}"
        
        worker.vm.provider :virtualbox do |prov|
	    prov.name = "ICAP-P4-Worker#{i}"
            prov.cpus = 1
            prov.memory = WORKER_MEM
	    prov.linked_clone = true

            for j in 0..1 do
                filename = "disks/#{worker.vm.hostname}-disk#{j}.vdi"
                unless File.exist?(filename)
                    prov.customize ["createmedium", "disk", "--filename", filename, "--format", "vdi", "--size", 5 * 1024]
                end
                prov.customize ["storageattach", :id, "--storagectl", "SCSI", "--port", j + 3, "--device", 0, "--type", "hdd", "--medium", filename]
            end
        end
    end
  end
  
  # Global provisioning bash script
  config.vm.provision "shell", path: "provisioning/bootstrap.sh" do |script|
      script.args = [NUM_WORKERS, BASEIP, MASTERIP]
  end
end
