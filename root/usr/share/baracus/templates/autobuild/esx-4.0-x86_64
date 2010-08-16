# NFS Install
install __SHARETYPE__ --server=__SHAREIP__ --dir=__BUILDROOT__/__OS__/__RELEASE__/__ARCH__/dvd

# HTTP Install
# install URL --url __SHARETYPE__://__SHAREIP__/__BUILDROOT__/__OS__/__RELEASE__/__ARCH__/dvd

# Localization
lang "__LANG__"
keyboard "__KEYMAP__"

# Mouse Configuration
mouse generic3ps/2 --device psaux

# Skip X configuration
skipx

# Text install
text

# Network information
network --device eth0 --bootproto static --ip __IP__ --netmask __NETMASK__ --gateway __GATEWAY__ --nameserver __DNS1__ --hostname __HOSTNAME__.__DNSDOMAIN__

# Encrypted root password
rootpw --baracus

# Disable the firewall
firewall --disabled

# Auth Configuration
authconfig --enableshadow --enablemd5

# Timezone
timezone "__TIMEZONE__"

# Bootloader config
bootloader --useLilo --location=mbr

# Reboot
reboot

# VMware Licensing
vmaccepteula
# vmserialnum --esx=XXXXX-XXXXX-XXXXX-XXXXX --esxsmp=XXXXX-XXXXX-XXXXX-XXXXX 
# Amount of memory to reserve for the console OS
# 192M up to 8 virtual machines
# 272M up to 16 virtual machines
# 384M up to 32 virtual machines
# 512 more than 32 virtual machines
vmservconmem --reserved=512

# Partitioning
# *Note: ESX 3.0 Will require a 100M /boot parition for an upgrade.
clearpart --all --initlabel
part /boot     --size 100   --ondisk __ROOTDISK__ --fstype ext3    --asprimary
part /         --size 10240 --ondisk __ROOTDISK__ --fstype ext3    --asprimary
part swap      --size 2048  --ondisk __ROOTDISK__ --fstype swap    --asprimary
part /vmimages --size 10240 --ondisk __ROOTDISK__ --fstype ext3 
part local     --size 1     --ondisk __ROOTDISK__ --fstype vmfs2   --grow
part vmkcore   --size 100   --ondisk __ROOTDISK__ --fstype vmkcore 

# Not sure how to specify this without device labels
vmswap --volume="local" --size="8192" --name "SwapFile.vswp"

# Set up virtual switches.
vmnetswitch --name="vmotion"  --vmnic=vmnic0
vmnetswitch --name="internal" --vmnic=vmnic1 --vmnic=vmnic2
vmnetswitch --name="vlan_1"   --vmnic="internal.1" 
vmnetswitch --name="vlan_2"   --vmnic="internal.2" 
vmnetswitch --name="vlan_3"   --vmnic="internal.3" 
vmnetswitch --name="vlan_4"   --vmnic="internal.4" 
vmnetswitch --name="vlan_5"   --vmnic="internal.5" 
vmnetswitch --name="dmz1"     --vmnic=vmnic4
vmnetswitch --name="dmz2"     --vmnic=vmnic5
vmnetswitch --name="private_network"

# Assign all PCI devices ( All of these device IDs can be obtained by looking at /etc/vmware/hwconfig )
# 2/4/0 scsi = vmhba0 (shared) Onboard RAID controller
# 3/6/0 nic  = vmnic0 (shared) First onboard GigE NIC
# 3/6/1 nic  = vmnic1 (vm) Second onboard GigE NIC
# 6/4/0 nic  = vmnic2 (vm) Intel 1000MT NIC Port 1
# 6/4/1 nic  = vmnic3 (vm) Intel 1000MT NIC Port 2
# 6/6/0 nic  = vmnic4 (vm) Intel 1000MT NIC Port 3
# 6/6/1 nic  = vmnic5 (vm) Intel 1000MT NIC Port 4
# 7/9/0 fc   = vmhba1 (vm) Qlogic 2340 Fibre HBA
vmpcidivy --shared=2/4/0 --shared=3/6/0 --vms=3/6/1 --vms=6/4/0 --vms=6/4/1 --vms=6/6/0 --vms=6/6/1 --vms=7/9/0

%packages
@ ESX Server
kernel-smp

%post

# # Modify /etc/resolv.conf
# cat > /etc/resolv.conf << EOF
# search yourdomain.com
# nameserver 172.16.1.2
# nameserver 172.16.1.3
# EOF

# # NTP Configuration
# chkconfig --level 345 ntpd on
# perl -spi -e 's|# restrict mytrustedtimeserverip mask 255.255.255.255 nomodify notrap noquery|restrict 172.16.1.4 mask 255.255.255.255 
# nomodify notrap noquery|' /etc/ntp.conf
# perl -spi -e 's|# server mytrustedtimeserverip|server 172.16.1.4|' /etc/ntp.conf
# cat > /etc/ntp/step-tickers << EOF
# 172.16.1.4
# EOF

# Install vmkusage
/usr/bin/vmkusage -regroove
cat <<EOF > /etc/cron.d/vmkusage-cron.sh
#!/bin/bash
*/1 * * * * root /usr/bin/vmkusage > /dev/null 2>&1
EOF
/bin/chmod +x /etc/cron.d/vmkusage-cron.sh

# Set up restriction banners
perl -spi -e 's|#Banner /some/path|Banner /etc/restricted_access|' /etc/ssh/sshd_config
cat > /etc/restricted_access << EOF
Welcome to ESX 4.0 server built by baracus
EOF

wget http://__SERVERIP__/ba/built?uuid=__UUID__\&hostname=__HOSTNAME__

__MODULE__
