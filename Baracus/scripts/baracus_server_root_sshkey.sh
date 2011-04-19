#!/bin/bash

rdir=/root/.ssh
rconf=$rdir/config
bdir=/var/spool/baracus/.ssh

[ -d $rdir ] || mkdir -p $rdir
cp $bdir/id_rsa $rdir/baracuskey
cp $bdir/id_rsa.pub $rdir/baracuskey.pub
if [[ ! -f $rconf ]] || [[ ! $(grep baracuskey $rconf) ]] ; then
    touch $rconf
    cat >> $rconf <<EOF
IdentityFile $rdir/baracuskey
EOF
fi
