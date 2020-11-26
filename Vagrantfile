# -*- mode: ruby -*-
# vi: set ft=ruby :

NUM_WORKERS = 2
WORKER_MEM = 1024
BASEIP="192.168.100"
MASTERIP=10

Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp/bionic64"

  # Master node
  config.vm.define "master", primary: true do |master|
    master.vm.hostname = "master"
    master.vm.network :private_network, ip: "#{BASEIP}.#{MASTERIP}"

    master.vm.provider :virtualbox do |prov|
        prov.cpus = "1"
        prov.memory = "1024"

        for i in 0..1 do
            filename = "./disks/#{master.vm.hostname}-disk#{i}.vmdk"
            unless File.exist?(filename)
                prov.customize ["createmedium", "disk", "--filename", filename, "--size", 5 * 1024]
                prov.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", i + 1, "--device", 0, "--type", "hdd", "--medium", filename]
            end
        end
    end
  end
  
  # Worker nodes
  (1..NUM_WORKERS).each do |i|
    config.vm.define "worker#{i}" do |worker|
        worker.vm.hostname = "worker#{i}"
        worker.vm.network :private_network, ip: "#{BASEIP}.#{i + MASTERIP}"
        
        worker.vm.provider :virtualbox do |prov|
            prov.cpus = 1
            prov.memory = WORKER_MEM

            for i in 0..1 do
                filename = "./disks/#{worker.vm.hostname}-disk#{i}.vmdk"
                unless File.exist?(filename)
                    prov.customize ["createmedium", "disk", "--filename", filename, "--size", 5 * 1024]
                    prov.customize ["storageattach", :id, "--storagectl", "SATA Controller", "--port", i + 1, "--device", 0, "--type", "hdd", "--medium", filename]
                end
            end
        end
    end
  end
  
  # Global provisioning bash script
  config.vm.provision "shell", path: "./bootstrap.sh" do |script|
      script.args = [NUM_WORKERS, BASEIP, MASTERIP]
  end
end
