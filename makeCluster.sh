#!/bin/bash

LXCDIR="/var/lib/lxc/"
SALTFILES='/root/salt/'

function runCommand {
echo "********************************************************************";
echo "lxc-attach -n $1 -- $2;";
lxc-attach -n $1 -- $2;
echo "********************************************************************";
}


function installSalt {
runCommand $1 'yum -y upgrade';
runCommand $1 "yum -y install salt-$2";
printf "systemctl enable salt-$2.service \n systemctl start salt-$2.service" >> "$LXCDIR/$1/rootfs/root/startSalt.sh"
chmod 744 "$LXCDIR/$1/rootfs/root/startSalt.sh"
runCommand $1 '/bin/bash /root/startSalt.sh'
rm -f "$LXCDIR/$1/rootfs/root/startSalt.sh"
}

function makeNode {
lxc-create -n $1 -t centos;
echo 'proxy=http://pkg-cache.ssg.ucar.edu:3142/' >> "$LXCDIR/$1/rootfs/etc/yum.conf"
lxc-start -n $1 -d;
sleep 30;
runCommand $1 'yum -y install epel-release';
if [ "_"$2 == "_" ]; then
    installSalt "$1" 'minion';
else
    installSalt "$1" "$2";
fi
}

function makeSaltMaster {
makeNode 'salt' 'master';
runCommand 'salt' 'yum -y install net-tools vim-enhanced'
echo 'salt master node setup';
}

function makeComputeNodes {
for i in `seq 1 $1`;
do
    makeNode "vc$i" &
    echo "compute node $i of $1 setup";
done
wait
}

function makeSlurmNodes {
for i in `seq 1 $1`;
do
    makeNode "vcSlurm$i" &
    echo "Slurm node $i of $1 setup";
done
wait
}

function makeLoginNodes {
for i in `seq 1 $1`;
do
    makeNode "vcLogin$i" &
    echo "Login node $i of $1 setup";
done
wait
}

function acceptSaltKeys {
runCommand 'salt' 'salt-key -y --accept-all';
}

function setupSalt {
#copy salt stuff to salt master
cp -r SALTFILES $LXCDIR/salt/rootfs/srv/salt/
runCommand 'salt' "salt '*' state.apply"
}

makeSaltMaster &
makeComputeNodes '10' &
makeSlurmNodes '1' &
makeLoginNodes '2' &
wait
sleep 30;
acceptSaltKeys;
echo 'All nodes created';
setupSalt
#runCommand 'salt' 'salt "\*" state.apply';
#echo 'Nodes provisioned';
