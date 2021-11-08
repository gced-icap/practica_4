#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "Sintaxis: $0 NUM_WORKERS BASEIP MASTERIP"
    exit -1
fi

NUM_WORKERS=$1
BASEIP=$2
MASTERIP=$3

# Format and mount disks to be used with Hadoop HDFS
if [ ! -d "/data/disk0" ]; then
    mkdir -p /data/disk0 >& /dev/null
    mkfs.ext4 -F /dev/sdc
    mount /dev/sdc /data/disk0
    chmod 1777 /data/disk0
else
    mount /dev/sdc /data/disk0 >& /dev/null
    chmod 1777 /data/disk0
fi

if [ ! -d "/data/disk1" ]; then
    mkdir -p /data/disk1 >& /dev/null
    mkfs.ext4 -F /dev/sdd
    mount /dev/sdd /data/disk1
    chmod 1777 /data/disk1
else
    mount /dev/sdd /data/disk1 >& /dev/null
    chmod 1777 /data/disk1
fi

if [ ! -d "/data/disk0/hdfs" ]; then
    mkdir /data/disk0/hdfs
fi

if [ ! -d "/data/disk1/hdfs" ]; then
    mkdir /data/disk1/hdfs
fi

chmod 1777 /data/disk0/hdfs
chmod 1777 /data/disk1/hdfs

if ! grep -Fq /dev/sdc /etc/fstab ; then
    echo -e "/dev/sdc        /data/disk0     ext4    defaults,relatime       0       0" >> /etc/fstab
fi
if ! grep -Fq /dev/sdd /etc/fstab ; then
    echo -e "/dev/sdd        /data/disk1     ext4    defaults,relatime       0       0" >> /etc/fstab
fi

apt-get update
# Install basic software
apt-get install -y ntp vim nano sshpass unzip python-apt dnsutils dos2unix whois nfs-kernel-server nfs-common openjdk-8-jdk
timedatectl set-timezone Europe/Madrid
systemctl enable ntp
systemctl start ntp

# Populate /etc/hosts
sed -i "/$HOSTNAME/d" /etc/hosts
sed -i "/master/d" /etc/hosts

if ! grep -Fq master /etc/hosts ; then
    echo -e "$BASEIP.$MASTERIP \t master" >> /etc/hosts
fi

ini=$(($MASTERIP+1))
fin=$(($MASTERIP+$NUM_WORKERS))
num=1
for (( i=$ini; i<=$fin; i++ )); do
    sed -i "/worker$num/d" /etc/hosts
    echo -e "$BASEIP.$i \t worker$num" >> /etc/hosts
    num=$((num+1))
done

# SSH config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd


#profile
if ! grep -Fq JAVA_HOME /home/vagrant/.profile ; then
    echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> /home/vagrant/.profile
fi

# NFS and SSH keys setup
SSH_PUBLIC_KEY=/vagrant/provisioning/id_rsa.pub
SSH_DIR=/home/vagrant/.ssh

if [ ! -d "/share" ]; then
    mkdir /share >& /dev/null
fi
    
if [ "$HOSTNAME" = "master" ]; then
    # Create ssh keys
    echo -e 'y\n' | sudo -u vagrant ssh-keygen -t rsa -f $SSH_DIR/id_rsa -q -N ''

    if [ ! -f $SSH_DIR/id_rsa.pub ]; then
        echo "SSH public key could not be created"
        exit -1
    fi

    chown vagrant:vagrant $SSH_DIR/id_rsa*
    cp $SSH_DIR/id_rsa.pub /vagrant/provisioning

    # NFS export
    chmod 1777 /share

    sed -i "/share/d" /etc/exports
    echo -e "/share        $BASEIP.0/24(rw,sync,no_subtree_check)" >> /etc/exports

    exportfs -a
else
    umount /share >& /dev/null && sleep 1

    sed -i "/share/d" /etc/fstab
    echo -e "master:/share        /share     nfs    auto,relatime,tcp       0       0" >> /etc/fstab

    sleep 1 && mount /share
fi

# Finish SSH keys setup
if [ ! -f $SSH_PUBLIC_KEY ]; then
	echo "SSH public key does not exist"
	exit -1
fi

sed -i "/master/d" .ssh/authorized_keys >& /dev/null
cat $SSH_PUBLIC_KEY >> $SSH_DIR/authorized_keys
chown vagrant:vagrant $SSH_DIR/authorized_keys
chmod 0600 $SSH_DIR/authorized_keys >& /dev/null

