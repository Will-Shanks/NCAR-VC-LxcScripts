CLUSTER_BACKUP='/root/CLUSTER_BACKUP/'
LXCDIR='/var/lib/lxc/'
SALTFILES='/root/salt/'
FILES='/root/lxcScripts/'

function runCommand {
  echo "lxc-attach -n $1 -- $2";
  sudo lxc-attach -n $1 -- $2
}

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

rsync -a --del $LXCDIR $CLUSTER_BACKUP

echo "all containers backed up to $CLUSTER_BACKUP";
}

function vc-clean {
vc-stop

rsync -a --del "$CLUSTER_BACKUP" "$LXCDIR"

vc-start
}

function vc-highstate {
if [ $1"_" == "_" ]; then
  target="'*'"
else
  target="$1"
fi
if [ $2"_" == "_" ]; then
  state=""
else
  state="'$2'"
fi
echo "syncing salt info"
rsync -a $SALTFILES $LXCDIR/vcsalt/rootfs/srv/salt/
echo "salt $target state.apply $state"
printf "salt $target state.apply $state" > "$LXCDIR/vcsalt/rootfs/root/saltHighState.sh"
chmod 744 "$LXCDIR/vcsalt/rootfs/root/saltHighState.sh"
runCommand 'vcsalt' '/bin/bash /root/saltHighState.sh'
}

function vc-new {
vc-del
sudo bash $FILES/makeCluster.sh
}
