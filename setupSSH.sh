#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Sintaxis: $0 NUM_WORKERS"
    exit
fi

USER_DIR=/home/vagrant/.ssh
PASSWORD=vagrant
NUM_WORKERS=$1

if [ "$HOSTNAME" = "master" ]; then
    echo -e 'y\n' | ssh-keygen -t rsa -f $USER_DIR/id_rsa -q -N ''
    rm $USER_DIR/host-ids.pub >& /dev/null
    rm $USER_DIR/known_hosts >& /dev/null
    cat $USER_DIR/id_rsa.pub > $USER_DIR/host-ids.pub
    
    # For vagrant user, do NOT delete the key inserted by vagrant (the first one)
    sed -i '1!d' $USER_DIR/authorized_keys >& /dev/null    
    chmod 0600 $USER_DIR/authorized_keys >& /dev/null

    for (( num=1; num<$NUM_WORKERS+1; num++ )); do
        sshpass -p $PASSWORD ssh -oStrictHostKeyChecking=no "worker$num" "sed -i '1!d' $USER_DIR/authorized_keys"
        sshpass -p $PASSWORD ssh "worker$num" "echo -e 'y\n' | ssh-keygen -t rsa -f $USER_DIR/id_rsa -q -N ''"
        sshpass -p $PASSWORD ssh "worker$num" "chmod 0600 $USER_DIR/authorized_keys" >& /dev/null
        sshpass -p $PASSWORD ssh "worker$num" "cat $USER_DIR/id_rsa.pub" >> $USER_DIR/host-ids.pub
    done
    
    for (( num=1; num<$NUM_WORKERS+1; num++ )); do
        sshpass -p $PASSWORD ssh-copy-id -f -i $USER_DIR/host-ids.pub "worker$num"
    done
    
    cat $USER_DIR/host-ids.pub >> $USER_DIR/authorized_keys
fi
