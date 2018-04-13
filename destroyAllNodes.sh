function delCluster {
for i in $( sudo lxc-ls );
do
sudo lxc-stop -k -n $i;
sudo lxc-destroy -n $i;
done
}
