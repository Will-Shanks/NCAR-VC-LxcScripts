CLUSTER_BACKUP='/root/CLUSTER_BACKUP/'
LXCDIR='/var/lib/lxc/'
SALTFILES='/root/salt/'
FILES='/root/lxcScripts/'
source $FILES/makeCluster.sh

function vc-stop {
echo 'stopping all containers';
for i in $( sudo lxc-ls );
do
echo -e "\tstopping $i";
sudo lxc-stop -k -n $i;
done
echo "all containers stopped";
}

function vc-start {
echo 'starting all containers';
for i in $( sudo lxc-ls );
do
echo -e "\tstarting $i";
sudo lxc-start -n $i -d;
done
echo 'all containers started';
}

function vc-del {
echo "deleting all containers";
for i in $( sudo lxc-ls );
do
echo -e "\tdeleting $i";
sudo lxc-stop -k -n $i;
sudo lxc-destroy -n $i;
done
echo "all containers deleted";
}

function vc-backup {
vc-stop
echo "Backing up all containers in $LXCDIR to $CLUSTER_BACKUP"
rsync -a --del $LXCDIR $CLUSTER_BACKUP

echo "all containers backed up to $CLUSTER_BACKUP"
}

function vc-clean {
vc-stop

rsync -a --del "$CLUSTER_BACKUP" "$LXCDIR"

vc-delVeth

vc-start
}

function vc-highstate {
if [ $1"_" == "_" ]; then
  target="'*'"
else
  target="'$1'"
fi
if [ $2"_" == "_" ]; then
  state=""
else
  state="'$2'"
fi
echo "syncing salt info"
rsync -a $SALTFILES $LXCDIR/vcsalt/rootfs/srv/salt
# after nfs mounted dropping files into /root on vcsalt doesn't work, need to drop it into vcnfs1:/root so it appears in vcsalt's root/
printf "salt $target saltutil.refresh_pillar\nsalt $target state.apply $state\n" > "$LXCDIR/vcsalt/rootfs/root/saltHighState.sh"
printf "salt $target saltutil.refresh_pillar\nsalt $target state.apply $state\n" > "$LXCDIR/vcnfs1/rootfs/root/saltHighState.sh"
chmod 744 "$LXCDIR/vcsalt/rootfs/root/saltHighState.sh"
chmod 744 "$LXCDIR/vcnfs1/rootfs/root/saltHighState.sh"
cat /$LXCDIR/vcsalt/rootfs/root/saltHighState.sh
runCommand 'vcsalt' '/bin/bash /root/saltHighState.sh'
rm -f "$LXCDIR/vcsalt/rootfs/root/saltHighState.shi"
rm -f "$LXCDIR/vcnfs1/rootfs/root/saltHighState.sh"
}

function vc-new {
vc-del
rm -f $FILES/setup.txt
makeCluster >> $FILES/setup.txt
echo "cluster built"
}

function vc-make {
if [ "_"$1 == "_" ]; then
  echo "must give new node's name"
  exit
fi
makeNode $1
sleep 30
acceptSaltKeys
}

function vc-delVeth {
for i in `ip a | grep veth | cut -b 5-16`; do
  ip link delete $i;
done
}
