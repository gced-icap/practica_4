#!/bin/bash

if [ "$#" -ne 5 ]; then
    echo "Sintaxis: $0 NUM_WORKERS BASEIP MASTERIP MASTER_HOSTNAME WORKER_HOSTNAME"
    exit -1
fi

NUM_WORKERS=$1
BASEIP=$2
MASTERIP=$3
MASTER_HOSTNAME=$4
WORKER_HOSTNAME=$5

# Format and mount disks to be used with Hadoop HDFS
if [ ! -d "/data/disk0" ]; then
    mkdir -p /data/disk0
    mkfs.ext4 -F /dev/sdb
    mount /dev/sdb /data/disk0
    chmod 1777 /data/disk0
else
    mount /dev/sdb /data/disk0 >& /dev/null
    chmod 1777 /data/disk0
fi

if [ ! -d "/data/disk1" ]; then
    mkdir -p /data/disk1
    mkfs.ext4 -F /dev/sdc
    mount /dev/sdc /data/disk1
    chmod 1777 /data/disk1
else
    mount /dev/sdc /data/disk1 >& /dev/null
    chmod 1777 /data/disk1
fi

if [ ! -d "/data/disk0/hdfs" ]; then
    mkdir /data/disk0/hdfs
else
    rm -rf /data/disk0/hdfs/*
fi

if [ ! -d "/data/disk1/hdfs" ]; then
    mkdir /data/disk1/hdfs
else
    rm -rf /data/disk1/hdfs/*
fi

chmod 1777 /data/disk0/hdfs
chmod 1777 /data/disk1/hdfs

if ! grep -Fq /dev/sdb /etc/fstab ; then
    echo -e "/dev/sdb        /data/disk0     ext4    defaults,relatime       0       0" >> /etc/fstab
fi
if ! grep -Fq /dev/sdc /etc/fstab ; then
    echo -e "/dev/sdc        /data/disk1     ext4    defaults,relatime       0       0" >> /etc/fstab
fi

#Fixes for Java 11
if [ ! -d "/etc/apt/keyrings" ]; then
    mkdir -p /etc/apt/keyrings
fi

if [ ! -f /etc/apt/keyrings/adoptium.asc ]; then
    wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | tee /etc/apt/keyrings/adoptium.asc
fi

if [ ! -f /etc/apt/sources.list.d/adoptium.list ]; then
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list
fi

# Install basic software
apt-get update
apt-get install -y ntp vim nano sshpass unzip python-apt-common fdisk dnsutils dos2unix whois nfs-common temurin-11-jdk
timedatectl set-timezone Europe/Madrid

# Populate /etc/hosts
sed -i "/$HOSTNAME/d" /etc/hosts
sed -i "/master/d" /etc/hosts
echo -e "$BASEIP.$MASTERIP \t $MASTER_HOSTNAME" >> /etc/hosts

ini=$(($MASTERIP+1))
fin=$(($MASTERIP+$NUM_WORKERS))
num=1
for (( i=$ini; i<=$fin; i++ )); do
    sed -i "/worker$num/d" /etc/hosts
    echo -e "$BASEIP.$i \t $WORKER_HOSTNAME$num" >> /etc/hosts
    num=$((num+1))
done

# SSH config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

#profile
if ! grep -Fq JAVA_HOME /home/vagrant/.profile ; then
    echo "export JAVA_HOME=/usr/lib/jvm/temurin-11-jdk-amd64" >> /home/vagrant/.profile
fi

# NFS and SSH keys setup
SSH_PUBLIC_KEY=/vagrant/provisioning/id_rsa.pub
SSH_DIR=/home/vagrant/.ssh

if [ ! -d "/share" ]; then
    mkdir /share >& /dev/null
fi

if grep -Fq /share /etc/fstab ; then
    sed -i "/share/d" /etc/fstab
fi

if [[ "$HOSTNAME" == *"master" ]]; then
    echo "Installing and configuring NFS"
    # Install NFS server
    apt-get install -y nfs-kernel-server

    if [ ! -f $SSH_DIR/id_rsa.pub ]; then
	# Create ssh keys
	echo -e 'y\n' | sudo -u vagrant ssh-keygen -t rsa -f $SSH_DIR/id_rsa -q -N ''

	if [ ! -f $SSH_DIR/id_rsa.pub ]; then
		echo "SSH public key could not be created"
		exit -1
	fi
    fi

    chown vagrant:vagrant $SSH_DIR/id_rsa*
    cp $SSH_DIR/id_rsa.pub /vagrant/provisioning

    # Configure NFS export
    chmod 1777 /share
    sed -i "/share/d" /etc/exports
    echo -e "/share        $BASEIP.0/24(rw,sync,no_subtree_check)" >> /etc/exports
    exportfs -ra
else
    umount /share >& /dev/null && sleep 1
    if ! grep -Fq /share /etc/fstab ; then
        echo -e "$MASTER_HOSTNAME:/share        /share     nfs    auto,relatime,tcp       0       0" >> /etc/fstab
    fi
    echo "Mounting NFS export"
    sleep 2 && mount -t nfs4 /share
fi

# Check SSH keys setup
if [ ! -f $SSH_PUBLIC_KEY ]; then
	echo "SSH public key does not exist"
	exit -1
fi

sed -i "/master/d" .ssh/authorized_keys >& /dev/null
cat $SSH_PUBLIC_KEY >> $SSH_DIR/authorized_keys
chown vagrant:vagrant $SSH_DIR/authorized_keys
chmod 0600 $SSH_DIR/authorized_keys >& /dev/null

