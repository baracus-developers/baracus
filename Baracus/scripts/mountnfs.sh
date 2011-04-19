#!/bin/bash
ROOT=$1
SERVER=$2
SHARE=$3

NFSLOCAL=$ROOT/${SERVER}${SHARE}
NFSREMOTE=$SERVER:$SHARE

sudo mkdir -p $NFSLOCAL
sudo umount $NFSLOCAL 2&>/dev/null
sudo mount -o soft,async -t nfs $NFSREMOTE $NFSLOCAL
