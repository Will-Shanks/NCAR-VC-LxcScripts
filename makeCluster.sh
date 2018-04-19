function runCommand {
  echo "lxc-attach -n $1 -- $2";
  sudo lxc-attach -n $1 -- $2;
}

function installSalt {
  runCommand $1 'yum -y upgrade';
  runCommand $1 "yum -y install salt-$2";

  if [ $2 == 'master' ]; then
    rsync -a  $FILES/master  $LXCDIR/vcsalt/rootfs/etc/salt/master
  else
    echo 'master: vcsalt' >> $LXCDIR/$1/rootfs/etc/salt/minion
  fi

  printf "systemctl enable salt-$2.service \n systemctl start salt-$2.service" >> "$LXCDIR/$1/rootfs/root/startSalt.sh"
  chmod 744 "$LXCDIR/$1/rootfs/root/startSalt.sh"
  runCommand $1 '/bin/bash /root/startSalt.sh'
  rm -f "$LXCDIR/$1/rootfs/root/startSalt.sh"
}

function makeNode {
  sudo lxc-create -n $1 -t centos;
  echo 'proxy=http://pkg-cache.ssg.ucar.edu:3142/' >> "$LXCDIR/$1/rootfs/etc/yum.conf"
  sudo lxc-start -n $1 -d;
  sleep 30;
  printf "chpasswd root:superSecretPassword" >> "$LXCDIR/$1/rootfs/root/setpasswd.sh"
  chmod 744 "$LXCDIR/$1/rootfs/root/setpasswd.sh"
  runCommand $1 'bin/bash /root/setpasswd.sh'
  rm -f "/$LXCDIR/$1/rootfs/root/setpasswd.sh"
  runCommand $1 'yum -y install epel-release';

  if [ "_"$2 == "_" ]; then
    installSalt "$1" 'minion';
  else
    installSalt "$1" "$2";
    if [ $2 == 'master' ]; then
      installSalt "$1" 'minion';
    fi
  fi
}

function makeSaltMaster {
  echo "1 salt nodes";
  makeNode 'vcsalt' 'master';
  runCommand 'vcsalt' 'yum -y install net-tools vim-enhanced'
}

function makeNodeType {
  if [ "_"$2 == "_" ]; then
    echo "$1 compute nodes";
  else
    echo "$1 $2 nodes";
  fi

  for i in `seq 1 $1`;
  do
    makeNode "vc$2$i" &
  done

  wait
}

function acceptSaltKeys {
  runCommand 'vcsalt' 'salt-key -y --accept-all';
}

function setupSalt {
  cp -r $SALTFILES $LXCDIR/vcsalt/rootfs/srv/salt/
#  printf "salt '*' test.ping \n salt '*' state.apply" >> "$LXCDIR/salt/rootfs/root/saltHighState.sh"
#  chmod 744 "$LXCDIR/salt/rootfs/root/saltHighState.sh"
#  runCommand 'salt' '/bin/bash /root/saltHighState.sh'
#  rm -f "$LXCDIR/salt/rootfs/root/saltHighState.sh"
}

function makeCluster {
makeSaltMaster &
makeNodeType '5' &
makeNodeType '1' 'slurm' &
makeNodeType '2' 'login' &
makeNodeType '1' 'nfs' &
wait
stty sane
echo "waiting to accept salt keys";
#sleep 60;
#acceptSaltKeys;
#sleep 30;
setupSalt
echo "don't forget to accept salt keys!"
}
