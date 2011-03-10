NFSBASE=/var/spool/baracus/nfsroot
sudo mkdir -p $NFSBASE/$1/$2
sudo umount $NFSBASE/$1/$2
sudo mount -t nfs $1:$2 $NFSBASE/$1/$2
