!/bin/sh
# if you don't want to deal with the fstab,
# you can also remove that file from your image
# so the one created by autoyast is not overwritten
# by your image extraction
mv /mnt/etc/fstab /tmp/
wget -O - http://10.10.0.162/kiwi_image.tgz 2>/dev/null| tar xfz - -C /mnt

