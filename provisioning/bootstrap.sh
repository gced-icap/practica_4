#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

if [ "$#" -ne 4 ]; then
    echo "Sintaxis: $0 MASTER_IP MASTER_HOSTNAME WORKER_HOSTNAME NUM_WORKERS"
    exit -1
fi

MASTER_IP=$1
MASTER_HOSTNAME=$2
WORKER_HOSTNAME=$3
NUM_WORKERS=$4

# Format and mount disks to be used with Hadoop HDFS
if [ ! -d "/data/disk0" ]; then
    mkdir -p /data/disk0
    mkfs.ext4 -F /dev/sdb
    mount /dev/sdb /data/disk0
    chmod 1777 /data/disk0
else
    if ! grep -Fq /dev/sdb /proc/mounts ; then
        mount /dev/sdb /data/disk0 >& /dev/null
        chmod 1777 /data/disk0
    fi
fi

if [ ! -d "/data/disk1" ]; then
    mkdir -p /data/disk1
    mkfs.ext4 -F /dev/sdc
    mount /dev/sdc /data/disk1
    chmod 1777 /data/disk1
else
    if ! grep -Fq /dev/sdc /proc/mounts ; then
        mount /dev/sdc /data/disk1 >& /dev/null
        chmod 1777 /data/disk1
    fi
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

# Install software
apt-get update -y -qq
SOFTWARE="nano sshpass unzip python-apt-common fdisk dnsutils dos2unix whois nfs-common openjdk-11-jdk"
echo "==> Installing software packages..."
if ! apt-get install -y -qq $SOFTWARE > /tmp/apt.log 2>&1; then
    echo "Error when installing software, log:"
    cat /tmp/apt.log
    exit 1
fi
echo "==> done"

timedatectl set-timezone Europe/Madrid
passwd -d root
echo 'root:vagrant' | chpasswd -m
passwd -d vagrant
echo 'vagrant:vagrant' | chpasswd -m

# Populate /etc/hosts
sed -i "/$HOSTNAME/d" /etc/hosts
sed -i "/master/d" /etc/hosts
echo -e "$MASTER_IP \t $MASTER_HOSTNAME" >> /etc/hosts

IP_PREFIX=$(echo "$MASTER_IP" | cut -d. -f1-3)
IP_LAST=$(echo "$MASTER_IP" | cut -d. -f4)
for (( i=1; i<=$NUM_WORKERS; i++ )); do
	worker_ip="$IP_PREFIX.$((IP_LAST + i))"
	echo -e "${worker_ip} \t ${WORKER_HOSTNAME}${i}" >> /etc/hosts
done

# SSH config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication/PasswordAuthentication/' /etc/ssh/sshd_config
sed -i 's/KbdInteractiveAuthentication no/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#KbdInteractiveAuthentication/KbdInteractiveAuthentication/' /etc/ssh/sshd_config
systemctl restart ssh

# .profile
sed -i "/sbin/d" /home/vagrant/.profile
echo 'PATH=/sbin:$PATH' >> /home/vagrant/.profile

if ! grep -Fq WORDCOUNT /home/vagrant/.profile ; then
	echo "export WORDCOUNT=/share/hadoop-3.4.2/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.2.jar" >> /home/vagrant/.profile
fi

if ! grep -Fq JAVA_HOME /home/vagrant/.profile ; then
    echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /home/vagrant/.profile
fi

if [ "$(hostname)" = "$MASTER_HOSTNAME" ]; then
    echo "Downloading fileGen.sh script..."
    cd /home/vagrant
    wget https://gac.udc.es/~rober/icap/fileGen.sh
    if [ $? -ne 0 ]; then
        echo "Error: download failed!"
        exit -1
    fi
    chmod +x fileGen.sh
    chown vagrant:vagrant fileGen.sh
    echo 'echo "$number characters" >> $path/$filename' >> fileGen.sh
fi

# NFS and SSH keys setup
SSH_PUBLIC_KEY=/share/id_rsa.pub
SSH_DIR=/home/vagrant/.ssh

if [ ! -d "/share" ]; then
    mkdir /share >& /dev/null
fi

if grep -Fq /share /etc/fstab ; then
    sed -i "/share/d" /etc/fstab
fi

if [ "$(hostname)" = "$MASTER_HOSTNAME" ]; then
    # Install NFS server
    echo "==> Installing and configuring NFS server..."
    if ! apt-get install -y -qq nfs-kernel-server >/tmp/apt.log 2>&1; then
    	echo "Error when installing software, log:"
    	cat /tmp/apt.log
    	exit 1
    fi
    echo "==> done"

    if [ ! -f $SSH_DIR/id_rsa.pub ]; then
	# Create ssh keys
	echo -e 'y\n' | sudo -u vagrant ssh-keygen -t rsa -f $SSH_DIR/id_rsa -q -N ''

	if [ ! -f $SSH_DIR/id_rsa.pub ]; then
		echo "SSH public key could not be created"
		exit -1
	fi
    fi

    if [ ! -f /etc/ssh/ssh_config.d/90-key-checking.conf ]; then
        cat > /etc/ssh/ssh_config.d/90-key-checking.conf << EOF
Host *
    StrictHostKeyChecking no
EOF
    fi

    chown vagrant:vagrant $SSH_DIR/id_rsa*
    cp $SSH_DIR/id_rsa.pub $SSH_PUBLIC_KEY

    # Configure NFS export
    chmod 1777 /share
    sed -i "/share/d" /etc/exports
    echo -e "/share        $IP_PREFIX.0/24(rw,sync,no_subtree_check)" >> /etc/exports
    exportfs -ra
else
    umount /share >& /dev/null && sleep 2
    if ! grep -Fq /share /etc/fstab ; then
        echo -e "$MASTER_HOSTNAME:/share        /share     nfs    auto,relatime,tcp       0       0" >> /etc/fstab
    fi
    echo "Mounting NFS export"
    sleep 2 && mount $MASTER_HOSTNAME:/share /share
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
