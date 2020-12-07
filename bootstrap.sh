#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "Sintaxis: $0 NUM_WORKERS BASEIP MASTERIP"
    exit
fi

NUM_WORKERS=$1
BASEIP=$2
MASTERIP=$3

# Format and mount disks to be used with Hadoop HDFS
if [ ! -d "/data/disk0" ]; then
    mkdir -p /data/disk0 >& /dev/null
    mkfs.ext4 -F /dev/sdb
    mount /dev/sdb /data/disk0
    chmod 1777 /data/disk0
else
    mount /dev/sdb /data/disk0 >& /dev/null
    chmod 1777 /data/disk0
fi

if [ ! -d "/data/disk1" ]; then
    mkdir -p /data/disk1 >& /dev/null
    mkfs.ext4 -F /dev/sdc
    mount /dev/sdc /data/disk1
    chmod 1777 /data/disk1
else
    mount /dev/sdc /data/disk1 >& /dev/null
    chmod 1777 /data/disk1
fi

if ! grep -Fq /dev/sdb /etc/fstab ; then
    echo -e "/dev/sdb        /data/disk0     ext4    defaults,relatime       0       0" >> /etc/fstab
fi
if ! grep -Fq /dev/sdc /etc/fstab ; then
    echo -e "/dev/sdc        /data/disk1     ext4    defaults,relatime       0       0" >> /etc/fstab
fi

apt-get update
# Install basic software
apt-get install -y ntp vim nano sshpass unzip python-apt dnsutils dos2unix whois nfs-kernel-server nfs-common openjdk-8-jdk
timedatectl set-timezone Europe/Madrid
systemctl enable ntp
systemctl start ntp

# Populate /etc/hosts
sed -i "/$HOSTNAME/d" /etc/hosts

if ! grep -Fq $BASEIP.$MASTERIP /etc/hosts ; then
    echo -e "$BASEIP.$MASTERIP \t master" >> /etc/hosts
fi

ini=$(($MASTERIP+1))
fin=$(($MASTERIP+$NUM_WORKERS))
num=1
for (( i=$ini; i<=$fin; i++ )); do
    if ! grep -Fq $BASEIP.$i /etc/hosts ; then
        echo -e "$BASEIP.$i \t worker$num" >> /etc/hosts
    fi
    num=$((num+1))
done

# SSH config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd


#profile
if ! grep -Fq JAVA_HOME /home/vagrant/.profile ; then
    echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> /home/vagrant/.profile
fi

# NFS setup
if [ ! -d "/share" ]; then
    mkdir /share >& /dev/null
fi
    
if [ "$HOSTNAME" = "master" ]; then
    cp /vagrant/setupSSH.sh /home/vagrant
    dos2unix ./setupSSH.sh
    chown vagrant:vagrant ./setupSSH.sh
    chmod +x ./setupSSH.sh

    chmod 1777 /share

    if ! grep -Fq /share /etc/exports ; then
        echo -e "/share        $BASEIP.0/24(rw,sync,no_subtree_check)" >> /etc/exports
    fi
    exportfs -a
else
    umount /share >& /dev/null
    if ! grep -Fq /share /etc/fstab ; then
        echo -e "master:/share        /share     nfs    auto,relatime,tcp       0       0" >> /etc/fstab
    fi
    mount /share
fi
