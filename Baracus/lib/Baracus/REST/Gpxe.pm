package Baracus::REST::Gpxe;

use 5.006;
use Carp;
use strict;
use warnings;

use Baracus::Sql qw( :vars );
use Baracus::State qw( :vars :subs :admin :actions :events );
use Baracus::Config qw( :vars );
use Baracus::Cgi qw( :subs );
use Baracus::Core qw( :subs );
use Baracus::Aux qw( :subs );
use Baracus::Host qw( :subs );

$| = 1; # flush STDOUT

my $dbh = DBI->connect
    ("DBI:Pg:dbname=baracus;port=5162",
     "baracus",
     "",
     {
      PrintError => 1,          # warn() on errors
      RaiseError => 0,          # don't die on error
      AutoCommit => 1,          # commit executes
      # immediately
      }
     );

my $tftph = DBI->connect
    ("DBI:Pg:dbname=sqltftp;port=5162",
     "baracus",
     "",
     {
      PrintError => 1,          # warn() on errors
      RaiseError => 0,          # don't die on error
      AutoCommit => 1,          # commit executes
      # immediately
      }
     );

my $state = 0;
my $pxenext = 0;
my $admin = 0;

my %values = ();
my @fields = ();
my $fields = "";
my $values = "";
my $sql = "";
my $sth = 0;

my $href    = {};
my $macref  = {};
my $actref  = {};
my $distref = {};
my $hardref = {};
my $filename = "";
my $output = "";


#if ( $ENV{REQUEST_METHOD} eq "PUT" ) {
#    my $opts =
#    {
#     LASTERROR => "",
#     debug     => 0,
#     };

    ##
    ## Handle the uploading of files via "http PUT"
    ##
    ##   curl -b "mac=<mac>;status=<status>" -T <file> \
    ##       http://$baVar{serverip}/ba/inventory
    ##

#    foreach my $key ( $cgi->cookie() ) {
#        $input->{$key} = $cgi->cookie($key);
#    }

sub gpxe_inventory()
{
    ##
    ## REGISTER - STORE INVENTORY
    ##

    die "Missing 'mac=' in HTTP_COOKIE\n" unless ( defined $input->{mac} );

    print STDERR "$input->{mac} - host inventory received\n";

    $input->{mac} = &check_mac($input->{mac});
    $filename = $input->{mac} . ".inventory";

    $macref = &get_db_mac( $dbh, $input->{mac} );
    unless ( $macref ) {
        # user deleted entry while system was doing what baracus told it
        $state = BA_EVENT_FOUND;
        &add_db_mac( $dbh, $input->{mac}, $state );
        $macref = &get_db_mac( $dbh, $input->{mac} );
    }

    $href = &find_tftpfile( $opts, $tftph, $filename );

    # hum... always want the new inventory...
    # so we know we have to remove the old entry first
    if (defined $href and ($href->{name} eq $filename)) {
        &delete_tftpfile( $tftph, $filename );
    }

    $fields = "name,bin,description,size,enabled,insertion";
    $values = qq|'$filename',?,'lshw xml',$ENV{CONTENT_LENGTH},'1',CURRENT_TIMESTAMP(0)|;
    $sql = qq|INSERT INTO sqlfstable ( $fields ) VALUES ( $values )|;
    die "$!\n$tftph->errstr" unless ( $sth = $tftph->prepare( $sql ) );

    my $bin;
    my $bytes = 1;
    while ( $bytes ) {
        read( STDIN, $bytes, BA_DBMAXLEN );
        if ( $bytes ) {
            $bin = pack( 'u', $bytes );
            unless ( $sth->execute( $bin ) ) {
                print STDERR $sth->err;
                exit 0;
            }
        }
    }
    $sth->finish();
    $output = "upload success\n";

    $state = BA_EVENT_REGISTER;

    my $chkref = &get_db_action( $dbh, $input->{mac} );
    $actref = $chkref if ( defined $chkref );
    $actref->{cmdline} = "# inventory uploaded";
    &event_state_change( $dbh, $state, $macref, $actref );
    &update_db_mac_state( $dbh, $input->{mac}, $state );
    if ( defined $chkref ) {
        &update_db_action( $dbh, $actref );
    } else {
        $actref->{mac} = $input->{mac};
        &add_db_action( $dbh, $actref );
    }
}

sub gpxe_wipe()
{
    ##
    ## WIPE - ERASE DISK COMPLETION HOOK - STORE LOG
    ##

    die "Missing 'mac=' in COOKIE\n" unless ( defined $input->{mac} );
    die "Missing 'status=' in COOKIE\n" unless ( defined $input->{status} );

    print STDERR "$input->{mac} - wipe log received\n";

    $input->{mac} = &check_mac($input->{mac});
    $macref = &get_db_mac( $dbh, $input->{mac} );
    unless ( $macref ) {
        # user deleted entry while system was doing what baracus told it
        $state = BA_EVENT_FOUND;
        &add_db_mac( $dbh, $input->{mac}, $state );
        $macref = &get_db_mac( $dbh, $input->{mac} );
    }

    $filename = $input->{mac} . ".wipelog";
    $href = &find_tftpfile( $opts, $tftph, $filename );

    # hum... always want the new log...
    # so we know we have to remove the old entry first
    if (defined $href and ($href->{name} eq $filename)) {
        &delete_tftpfile( $tftph, $filename );
    }

    $fields = "name,bin,description,size,enabled,insertion";
    $values = qq|'$filename',?,'dban wipe log',$ENV{CONTENT_LENGTH},'1',CURRENT_TIMESTAMP(0)|;
    $sql = qq|INSERT INTO sqlfstable ( $fields ) VALUES ( $values )|;
    die "$!\n$tftph->errstr" unless ( $sth = $tftph->prepare( $sql ) );

    my $bin;
    my $bytes = 1;
    while ( $bytes ) {
        read( STDIN, $bytes, BA_DBMAXLEN ); # $ENV{CONTENT_LENGTH}
        if ( $bytes ) {
            $bin = pack( 'u', $bytes );
            unless ( $sth->execute( $bin ) ) {
                print STDERR $sth->err;
                exit 0;
            }
        }
    }
    $sth->finish();
    $output = "upload success\n";

    if ($input->{status} eq "pass") {
        $state = BA_EVENT_WIPED;
    } else {
        $state = BA_EVENT_WIPEFAIL;
    }

    my $chkref = &get_db_action( $dbh, $input->{mac} );
    $actref = $chkref if ( defined $chkref );
    $actref->{cmdline} = "# wipe log uploaded ($input->{status})";
    &event_state_change( $dbh, $state, $macref, $actref );
    &update_db_mac_state( $dbh, $input->{mac}, $state );
    if ( defined $chkref ) {
        &update_db_action( $dbh, $actref );
    } else {
        $actref->{mac} = $input->{mac};
        &add_db_action( $dbh, $actref );
    }

}

sub gpxe_env() {
    my $opts =
    {
     LASTERROR => "",
     debug     => 0,
     };

    ##
    ## Handle HTTP GET requests with or without CGI parameters
    ##
    ##   curl -s -o /tmp/pxemenu \
    ##       http://$baVar{serverip}/ba/boot?mac=<mac>&ip=<ip>
    ##

    foreach my $key ( $cgi->param() ) {
        $input->{$key} = $cgi->param($key);
    }

    if ( $ENV{REQUEST_URI} =~ m|^\s*/ba/env.*\s*$| ) {

        $output .= "CGI URL INPUT\n";
        foreach my $env ( keys %{$input} ) {

            $output .= "$env => $input->{ $env }\n";
        }

        $output .= "\n";
        $output .= "ENVIRONMENT\n";
        foreach my $env ( keys %ENV ) {
            $output .= "$env => $ENV{ $env }\n";
        }
    }
}

sub gpxe_chain()
{

    die "Missing 'mac=' in URL\n" unless ( defined $input->{mac} );

    my $default = qq|#!gpxe
dhcp net0
set net0/210:string http://$baVar{serverip}/ba/
set net0/209:string boot?mac=\${mac}&ip=\${ip}
chain http://$baVar{serverip}/ba/pxelinux.0?mac=\${mac}
|;

    $input->{mac} = &check_mac($input->{mac});
    $macref = &get_db_mac( $dbh, $input->{mac} );
    $actref = &get_db_action( $dbh, $input->{mac} );
    if ( not defined $macref or
         not defined $actref
       )
    {
        print STDERR "$input->{mac} - chain of unknown\n";
        $output = $default;
        print $cgi->header( -type => "text/plain",
                            -content_length => length
                            ($output)
                          ), $output;
        exit 0;
    }

    # found a mac and action entry - get the pxenext
    $pxenext = $actref->{pxenext};

    if ( $pxenext eq BA_ACTION_BUILD )
    {
        print STDERR "$input->{mac} - chain of build\n";
        $distref = &get_distro( $opts, $dbh, $actref );

        if ( $distref->{os} =~ m/solaris/i ) {
#            # my $iqn = "iqn.2010-01.lab.lsg:gfs-b9";
            $output = qq|#!gpxe
chain tftp://$baVar{serverip}/pxegrub
|;
        } elsif ( $distref->{os} =~ m/win/i ) {

            my $iqn = "iqn.2010-01.lab.lsg:gfs-b9";
            $output = qq|#!gpxe
chain http://$baVar{serverip}/ba/boot?mac=$input->{mac}
|;
#dhcp net0
#set keep-san-nb 1
#sanboot iscsi:151.155.230.116::::$iqn
#chain http://$baVar{serverip}/ba/startrom.0?mac=$input->{mac}
#|;
        } else {
            $output = $default;
        }
    } else {
        print STDERR "$input->{mac} - chain of non-build\n";
        $output = $default;
    }
}


sub gpxe_boot()
{
   my $mac = params->{mac};

    ##
    ## PXE - DIRECT TO INVENTORY, LOCALBOOT, INSTALL, WIPE
    ##

    die "Missing 'mac=' in URL\n" unless ( defined $mac );

    $mac = &check_mac($mac);
    $macref = &get_db_mac( $dbh, $mac );
    $actref = &get_db_action( $dbh, $mac );
    if ( not defined $macref or
         not defined $actref
        )
    {
        ##
        ## INVENTORY - missing 'mac' or 'action' entry (or entries)
        ##

        print STDERR "$mac - found and need inventory\n";

        # add the mac entry as found... if it's the one missing
        unless ( defined $macref ) {
            $state = BA_EVENT_FOUND;
            &add_db_mac( $dbh, $mac, $state );
            $macref = &get_db_mac( $dbh, $mac );
        }
        # set the check if we already have an action entry
        my $chkref = $actref if ( defined $actref );

        $actref->{cmdline} = "# pxeboot found";

        # this is where a state is first created by a trigger
        # and that trigger has to show movement to the next state
        # because we serve the inventory pxe now
        $state = BA_ACTION_INVENTORY;
        &action_state_change( $dbh, $state, $macref, $actref );

        &update_db_mac_state( $dbh, $mac, $state );
        if ( defined $chkref ) {
            # should never be the case that we have
            # action w/o mac first... but this don't hurt
            &update_db_action( $dbh, $actref );
        } else {
            $actref->{mac} = $mac;
            &add_db_action( $dbh, $actref );
        }

        &get_inventory( $cgi, \%baVar, $input ); # routine exits
    }

    # found a mac and action entry - get the pxenext
    $pxenext = $actref->{pxenext};

    # if admin is DISABLED or IGNORED then
    # do not care about serving anything
    $admin = $actref->{admin};

    # don't do list
    #
    # bahost remove - no mac will be found again
    # bado empty    - removes action entry, will be found again
    #
    # ignored, none ( also pxe auto disabled )
    # disabled, pxewait ( wiped, wipefail - push next action to pxewait )

    if ( $admin eq BA_ADMIN_IGNORED or
         $pxenext eq BA_ACTION_NONE
        )
    {
        # we shouldn't be here - we've already fed host pxe info...
        print STDERR "$input->{mac} - bad tftp daemon, bad.\n";
        exit 1;
    }

    if ( $admin eq BA_ADMIN_DISABLED or
         $pxenext eq BA_ACTION_PXEWAIT
        )
    {
        print STDERR "$input->{mac} - serving pxewait\n";
        &do_pxewait( $cgi );
        # do_pxewait call exits
    }

    if ( $pxenext eq BA_ACTION_NETBOOT ) {

        print STDERR "$input->{mac} - netboot $actref->{netbootip} $actref->{netboot}\n";
        &update_db_mac_state( $dbh, $macref->{mac}, $pxenext );
        if ( $actref->{oper} ne $pxenext or
             $actref->{pxecurr} ne $pxenext
            )
        {
            $actref->{oper} = $pxenext;
            $actref->{pxecurr} = $pxenext;
            $actref->{cmdline} = "# pxeboot network image";
            &update_db_action( $dbh, $actref );
        }

        &do_netboot( $cgi, $actref, $baVar{serverip} );
        # do_netboot exits
    }

    if ( $pxenext eq BA_ACTION_RESCUE ) {

        print STDERR "$input->{mac} - rescue mode\n";

        $distref = &get_distro( $opts, $dbh, $actref );
        $hardref = &get_hardware( $opts, $dbh, $actref, $actref->{hardware_ver} );

        unless ( defined $distref and defined $hardref ) {
            print STDERR "$input->{mac} - missing distro or hardware in db\n";
            exit 1;
        }

        &update_db_mac_state( $dbh, $macref->{mac}, $pxenext );
        if ( $actref->{oper} ne $pxenext or
             $actref->{pxecurr} ne $pxenext
           )
        {
            $actref->{oper} = $pxenext;
            $actref->{pxecurr} = $pxenext;
            $actref->{cmdline} = "# pxeboot rescue mode";
            &update_db_action( $dbh, $actref );
        }

        my $args;
        my $rescue;

        if ( $distref->{os} eq "opensuse" or
             $distref->{os} eq "sles"     or
             $distref->{os} eq "sled"   ) {
                $rescue = qq|rescue=$distref->{sharetype}://$distref->{shareip}$distref->{basepath} rescue=1 textmode=1 |;

        } elsif ( $distref->{os} eq "fedora" or
                  $distref->{os} eq "centos" or
                  $distref->{os} eq "esx"    or
                  $distref->{os} eq "rhel" ) {
                      $rescue = qq|text rescue ks=http://$baVar{serverip}/ba/auto?mac=$input->{mac}|;
        }

        $args = "$hardref->{bootargs} $actref->{raccess} $actref->{loghost}";

        &do_rescue( $cgi, $input->{mac}, $baVar{serverip}, "$args $rescue" );
        # do_rescue exits
    }

    # have we been directed to fetch inventory
    # or is it missing ? if so - get it now.

    $filename = $input->{mac} . ".inventory";
    $href = &find_tftpfile( $opts, $tftph, $filename );
    if ( $pxenext eq BA_ACTION_INVENTORY
         or
         (not defined $href
          or $href->{name} ne $filename
          or not defined $macref->{register}
          or $macref->{register} eq ""
          )
        )
    {
        ##
        ## INVENTORY - have 'mac' but still missing inventory
        ##
        my $args = "";

        $args = "$actref->{raccess} ";

# we need to get hardware or at least bootargs in here somehow
# to get around network level hangs with this:

#            $args .= " netsetup=1 ";

        print STDERR "$input->{mac} - get inventory from host\n";

        &update_db_mac_state( $dbh, $macref->{mac}, $pxenext );
        if ( $actref->{oper} ne $pxenext or
             $actref->{pxecurr} ne $pxenext
            ) {
            $actref->{oper} = $pxenext;
            $actref->{pxecurr} = $pxenext;
            $actref->{cmdline} = "# pxeboot inventory request";
            &update_db_action( $dbh, $actref );
        }

        &get_inventory( $cgi, \%baVar, $input, $args );
        # get_inventory call exits
    }

    if ( $pxenext eq BA_ACTION_LOCALBOOT )
    {
        ##
        ## LOCALBOOT - host built so just have it boot from localdisk
        ##

        print STDERR "$input->{mac} - building, built, localboot\n";

        &update_db_mac_state( $dbh, $macref->{mac}, $pxenext );
        if ( $actref->{oper} ne $pxenext or
             $actref->{pxecurr} ne $pxenext
            ) {
            $actref->{oper} = $pxenext;
            $actref->{pxecurr} = $pxenext;
            $actref->{cmdline} = "# pxeboot directing to localdisk";
            &update_db_action( $dbh, $actref );
        }

        &do_localboot( $cgi );
        # do_localboot exits
    }

    if ( $pxenext eq BA_ACTION_BUILD )
    {
        ##
        ## BUILD
        ##

        print STDERR "$input->{mac} - building\n";

        $state = BA_EVENT_BUILDING;

        &event_state_change( $dbh, $state, $macref, $actref );
        &update_db_mac_state( $dbh, $macref->{mac}, $state );
        $actref->{cmdline} = "# pxeboot directing to network install";
        &update_db_action( $dbh, $actref );

        my $args;

        $distref = &get_distro( $opts, $dbh, $actref );
        $hardref = &get_hardware( $opts, $dbh, $actref, $actref->{hardware_ver} );
        &load_distro( $opts, $dbh, $actref );
        &load_profile( $opts, $dbh, $actref );
        &load_vars( $opts, $actref );
        &load_baracusconfig( $opts, $actref );

        my $actauto = &get_action_autobuild_hash( $dbh, $input->{mac} );
        if ( defined $actauto->{autobuild} ) {
            $actref->{autobuild} = $actauto->{autobuild};
            $actref->{autobuild_ver} = $actauto->{autobuild_ver};
        } else {
            $actref->{autobuild} = "none";
        }

        if ( $distref->{os} eq "opensuse" or
             $distref->{os} eq "sles"     or
             $distref->{os} eq "sled"   )
        {
            $args = qq|textmode=1 install=$distref->{sharetype}://$distref->{shareip}$distref->{basepath}|;
            if ( $actref->{autobuild} ne "none" ) {
                $args .= qq| autoyast=http://$baVar{serverip}/ba/auto?mac=$input->{mac}|;
            }

            $output = qq|DEFAULT label_$actref->{hostname}
PROMPT 0
TIMEOUT 0

LABEL label_$actref->{hostname}
    kernel http://$baVar{serverip}/ba/linux?mac=$input->{mac}
    append initrd=http://$baVar{serverip}/ba/initrd?mac=$input->{mac} $hardref->{bootargs} $actref->{raccess} $args $actref->{loghost}
|;

        } elsif ( $distref->{os} eq "fedora" or
                  $distref->{os} eq "centos" or
                  $distref->{os} eq "esx"    or
                  $distref->{os} eq "rhel" ) {
            $args = qq|text|;
            if ( $actref->{autobuild} ne "none" ) {
                $args .= qq| ks=http://$baVar{serverip}/ba/auto?mac=$input->{mac}|;
            }

            $output = qq|DEFAULT label_$actref->{hostname}
PROMPT 0
TIMEOUT 0

LABEL label_$actref->{hostname}
    kernel http://$baVar{serverip}/ba/linux?mac=$input->{mac}
    append initrd=http://$baVar{serverip}/ba/initrd?mac=$input->{mac} $hardref->{bootargs} $actref->{raccess} $args $actref->{loghost}
|;

        } elsif ( $distref->{os} =~ m/ubuntu/ ) {
            $args = qq|hostname=unassigned-hostname locale=$actref->{lang} console-setup/ask_detect=$actref->{consoleaskdetect} console-setup/layoutcode=$actref->{consolelayoutcode}|;
            if ( $actref->{autobuild} ne "none" ) {
                $args .= qq| url=http://$baVar{serverip}/ba/auto?mac=$input->{mac}|;
            } else {
                $args .= qq| tasks=standard pkgsel/language-pack-patterns= pkgsel/install-language-support=false priority=low|;
            }


            $output = qq|DEFAULT label_$actref->{hostname}
PROMPT 0
TIMEOUT 0

LABEL label_$actref->{hostname}
    kernel http://$baVar{serverip}/ba/linux?mac=$input->{mac}
    append initrd=http://$baVar{serverip}/ba/initrd?mac=$input->{mac} $hardref->{bootargs} $actref->{raccess} $args $actref->{loghost}
|;

        } elsif ( $distref->{os} =~ m/solaris/i ) {
            $output = qq|DEFAULT label_$actref->{hostname}
#!gpxe
chain pxegrub
|;

        } elsif ( $distref->{os} =~ m/win/i ) {

# the mac isn't required here for operation but it identifies the requesting device 

            $output = qq|#!gpxe
chain http://$baVar{serverip}/ba/startrom.0
|;

#                $output = qq|DEFAULT label_$actref->{hostname}
#PROMPT 0
#TIMEOUT 0
#
#LABEL label_$actref->{hostname}
#    kernel tftp://$baVar{serverip}/startrom.0
#|;

#    kernel http://$baVar{serverip}/baracus/startrom.0
#    kernel http://$baVar{serverip}/ba/startrom.0?mac=$input->{mac}
#    kernel http://$baVar{serverip}/ba/linux?mac=$input->{mac}

        }
    }

    if ( $pxenext eq BA_ACTION_DISKWIPE )
    {
        ##
        ## WIPE
        ##

        print STDERR "$input->{mac} - wiping\n";

        $state = BA_EVENT_WIPING;

        &event_state_change( $dbh, $state, $macref, $actref );
        &update_db_mac_state( $dbh, $macref->{mac}, $pxenext );
        if ( $actref->{oper} ne $state ) {
            $actref->{cmdline} = "# pxeboot directing to wipe disk";
            &update_db_action( $dbh, $actref );
        }

        my $autonuke = "";
        $autonuke = " --autonuke" if ( $actref->{autonuke} );
        $output =
            qq|DEFAULT wipe
PROMPT 0
TIMEOUT 0

LABEL wipe
        kernel http://$baVar{serverip}/ba/linux.baracus
        append initrd=http://$baVar{serverip}/ba/initrd.baracus root=/dev/ram0 install=exec:/usr/bin/baracus.dban nuke="dwipe${autonuke}" baracus=$baVar{serverip} mac=$input->{mac}
|;

    }

}

sub gpxe_winst()
{
    die "Missing 'mac=' in URL\n" unless ( defined $input->{mac} );

    $input->{mac} = &check_mac($input->{mac});
    $macref = &get_db_mac( $dbh, $input->{mac} );
    $actref = &get_db_action( $dbh, $input->{mac} );
    $distref = &get_distro( $opts, $dbh, $actref );
    if ( not defined $macref or
         not defined $actref or
         not defined $distref
        )
    {
        ##
        ## WINST - missing 'mac' or 'action' entry (or entries)
        ##
        print STDERR "$input->{mac} - missing mac, action, distro in db\n";
        exit 1;
    }

    my $actauto = &get_action_autobuild_hash( $dbh, $input->{mac} );
    if ( defined $actauto->{autobuild} ) {
            $output .= qq|\@echo off
\@echo curl.exe -G http://$baVar{serverip}/ba/auto?mac=$input->{mac} -o X:\\Autounattend.xml
curl.exe -G http://$baVar{serverip}/ba/auto?mac=$input->{mac} -o X:\\Autounattend.xml

net use n: \\\\$distref->{shareip}\\$actref->{distro}
n:\\setup.exe /unattend:X:\\Autounattend.xml
|;
    } else {
            $output .=qq|\@echo off
net use n: \\\\$distref->{shareip}\\$actref->{distro}
n:\\setup.exe
|;
    }

}

sub gpxe_parm()
{
    die "Missing 'mac=' in URL\n" unless ( defined $input->{mac} );

    $input->{mac} = &check_mac($input->{mac});
    $macref = &get_db_mac( $dbh, $input->{mac} );
    $actref = &get_db_action( $dbh, $input->{mac} );
    $distref = &get_distro( $opts, $dbh, $actref );
    if ( not defined $macref or
         not defined $actref or
         not defined $distref
        )
    {
        ##
        ## WINST - missing 'mac' or 'action' entry (or entries)
        ##
        print STDERR "$input->{mac} - missing mac, action, distro in db\n";
        exit 1;
    }

    &load_distro( $opts, $dbh, $actref );

    if ( $actref->{arch} !~ m/s390/ ) {
        print STDERR "$input->{mac} - non-s390 arch request for parm file\n";
        exit 1;
    }

    &load_profile( $opts, $dbh, $actref );
    &load_vars( $opts, $actref );
    &load_baracusconfig( $opts, $actref );

## example parm
#
# ramdisk_size=65536 root=/dev/ram1 ro init=/linuxrc TERM=dumb
# ReadChannel=0.0.0700 WriteChannel=0.0.0701 DataChannel=0.0.0702
# OsaInterface=qdio OsaMedium=eth
# InstNetDev=osa layer2=0 PortNo=0
# Portname=VSW1
# Hostname=s390vm01.suse.de HostIP=10.10.220.97
# Gateway=10.10.0.8 Nameserver=10.10.0.1
# Netmask=255.255.0.0 Broadcast=10.10.255.255
# Install=nfs://10.10.0.100/dist/install/SLP/SLES-11-GM/s390x/DVD1/
# UseSSH=1 SSHPassword=testing linuxrcstderr=/dev/console

    $output = qq|ramdisk_size=65536 root=/dev/ram1 ro init=/linuxrc TERM=dumb
ReadChannel=0.0.0700 WriteChannel=0.0.0701 DataChannel=0.0.0702
OsaInterface=qdio OsaMedium=eth
InstNetDev=osa layer2=0 PortNo=0
Portname=VSW1
Hostname=$actref->{hostname}.$actref->{dnsdomain}
Install=$actref->{sharetype}://$actref->{shareip}$actref->{basepath}
linuxrcstderr=/dev/console
|;

    my $args = "";

    if ( $actref->{ip} ne "dhcp" ) {
        $args .= "HostIP=$actref->{ip} Netmask=$actref->{netmask} Broadcast=$actref->{broadcast} Gateway=$actref->{gateway} Nameserver=$actref->{dns1}\n";
    }
    if ( $actref->{raccess} =~ m|(usessh=1)| ) {
        $args .= $1 . " " ;
        $args .= $1 . " " if ( $actref->{raccess} =~ m|(sshpassword=[^ \t\s]+)| );
    }
#       if ( $actref->{autobuild} ne "none" )
#       {
#           $args .= qq| autoyast=http://$baVar{serverip}/ba/auto?mac=$input->{mac}|;
#       }
    $output .= $args;
}

sub gpxe_startrom_0()  { &gpxe_file( @_ ); }
sub gpxe_pxelinux_0()  { &gpxe_file( @_ ); }
sub gpxe_sanboot_c32() { &gpxe_file( @_ ); }
sub gpxe_file()
{
    my $file = $1;

    print STDERR "# no mac required to serve $file\n";

    $sql = qq|SELECT bin FROM sqlfstable WHERE name = '$file'|;

    die "$!\n$tftph->errstr" unless ( $sth = $tftph->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    while ( $href = $sth->fetchrow_hashref( ) ) {
        $output .= unpack( 'u', $href->{'bin'} );
    }
    $sth->finish();
}


sub gpxe_auto()
#    elsif ( $ENV{REQUEST_URI} =~ m{^\s*/ba/(auto)\?.*\s*$} )
{
    my $file = $1;

#    my $date = &get_rundate();
#    print STDERR "# start time for get $file : $date\n";

    ##
    ## AUTOBUILD FILE
    ##

    die "Missing 'mac=' in URL\n" unless ( defined $input->{mac} );

    $input->{mac} = &check_mac($input->{mac});
    $macref = &get_db_mac( $dbh, $input->{mac} );
    if ( not defined $macref ) {
        $output = "$input->{mac} - user vs cgi... missing db mac entry\n";
        print STDERR $output;
        print $cgi->header( -type => "text/plain",
                            -content_length => length
                            ($output)
                          ), $output;
        exit 0;
    }

    $actref = &get_db_action( $dbh, $input->{mac} );
    if (not defined $actref ) {
        $output = "$input->{mac} - user vs cgi... missing db action entry\n";
        print STDERR $output;
        print $cgi->header( -type => "text/plain",
                            -content_length => length
                            ($output)
                          ), $output;
        exit 0;
    }

    $actref->{serverip} = $baVar{serverip};

    # the mac and action might have been produced with an inventory req

    my $actauto = &get_action_autobuild_hash( $dbh, $input->{mac} );
    unless ( defined $actauto->{autobuild} ) {
        # this entry has no related autobuild and shouldn't be asking
        $output = "$input->{mac} - user vs cgi... no 'autobuild' entry\n";
        print STDERR $output;
        print $cgi->header( -type => "text/plain",
                            -content_length => length
                            ($output)
                          ), $output;
        exit 0;
    }

    $actref->{autobuild} = $actauto->{autobuild};
    $actref->{autobuild_ver} = $actauto->{autobuild_ver};

    my $actmod = &get_action_modules_hash( $dbh, $input->{mac} );
    if ( defined $actmod ) {
        $actref->{modules} = join ' ', keys %{$actmod};
    } else {
        $actref->{modules} = '';
    }

    &load_profile ( $opts, $dbh, $actref );
    &load_hardware( $opts, $dbh, $actref );
    &load_distro  ( $opts, $dbh, $actref );
    &load_addons  ( $opts, $dbh, $actref );
    &load_modules ( $opts, $dbh, $actref );

    &load_vars         ( $opts, $actref );
    &load_baracusconfig( $opts, $actref );

    print STDERR "$input->{mac} - serving autobuild $file\n";

    $output .= &get_autobuild_expanded( $opts, $dbh, $actref );

#    $date = &get_rundate();
#    print STDERR "# stop time for get $file : $date\n";
}

sub gpxe_linux()  { &gpxe_linux_files( @_ ); }
sub gpxe_initrd() { &gpxe_linux_files( @_ ); }
sub gpxe_linux_files()
{
    my $file = $1;

    ##
    ## KERNEL OR INITRD OR AUTOBUILD FILE
    ##

    die "Missing 'mac=' in URL\n" unless ( defined $input->{mac} );

    $input->{mac} = &check_mac($input->{mac});
    $macref = &get_db_mac( $dbh, $input->{mac} );
    if ( not defined $macref ) {
        $output = "$input->{mac} - user vs cgi... missing db mac entry\n";
        print STDERR $output;
        print $cgi->header( -type => "text/plain",
                            -content_length => length
                            ($output)
                          ), $output;
        exit 0;
    }

    $actref = &get_db_action( $dbh, $input->{mac} );
    if (not defined $actref ) {
        $output = "$input->{mac} - user vs cgi... missing db action entry\n";
        print STDERR $output;
        print $cgi->header( -type => "text/plain",
                            -content_length => length
                            ($output)
                          ), $output;
        exit 0;
    }

    $file = "$file.$actref->{distro}";

    print STDERR "$input->{mac} - serving $file\n";

    $sql = qq|SELECT bin FROM sqlfstable WHERE name = '$file'|;

    die "$!\n$tftph->errstr" unless ( $sth = $tftph->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    while ( $href = $sth->fetchrow_hashref( ) ) {
        $output .= unpack( 'u', $href->{'bin'} );
    }
    $sth->finish();
}
sub gpxe_built()
{
    my $hostname = $input->{ hostname };
    my $uuid = $input->{ uuid };
    my $ip = $ENV{ REMOTE_ADDR };

    my $built   = "$baDir{hooks}/verify_client_build_passed";
    my $spoofed = "$baDir{hooks}/verify_client_build_failed";

    # hash with a hostname
    $actref = &get_db_action_by_hostname( $dbh, $input->{hostname} );
    unless ( defined $actref ) {
        $output = "$input->{hostname} - build callback unable to find $hostname\n";
        print STDERR $output;
        print $cgi->header( -type => "text/plain",
                            -content_length => length
                            ($output)
                           ), $output;
        exit 0;
    }
    $input->{mac} = $actref->{ mac };
    $macref = &get_db_mac( $dbh, $input->{mac} );

    # check for spoofing of url access
    if (( "$uuid" ne "$actref->{'uuid'}" ) or
        (( "$ip"  ne "$actref->{'ip'}"  ) and
         ( "dhcp" ne "$actref->{'ip'}"  ))) {

        $state = BA_EVENT_SPOOFED;
        $actref->{cmdline} = "# build complete callback spoofed";

        print STDERR "$input->{mac} - $hostname $actref->{cmdline}\n";
        $output = "build spoofed - spoof hook called\n";

        if ( -f $spoofed ) {
            my $cmd = "$spoofed $hostname $ip $uuid $input->{mac}";
#            print STDERR $cmd;
#            system($cmd);
#            my $rfile = BATools::generate_random_string();
#            $cmd = "sudo $BATools::baPath/modules/pfork.bin ".$cmd." $rfile";
            $cmd = "sudo $cmd";
            my $output = `$cmd`;
        }
    }
    else {
        $state = BA_EVENT_BUILT;
        $actref->{cmdline} = "# build complete callback verified";
        print STDERR "$input->{mac} - $hostname $actref->{cmdline}\n";
        $output = "build verified - verify hook called\n";

        if ( -f $built ) {
            my $cmd = "$built $hostname $ip $uuid $input->{mac}";
#            print STDERR $cmd;
#            system($cmd);
#            my $rfile = BATools::generate_random_string();
#            $cmd = "sudo $BATools::baPath/modules/pfork.bin ".$cmd." $rfile";
            $cmd = "sudo $cmd";
            my $output = `$cmd`;
        }
    }

    &event_state_change( $dbh, $state, $macref, $actref );
    &update_db_mac_state( $dbh, $input->{mac}, $state );
    &update_db_action( $dbh, $actref );
}

##
## kernel and initrd for inventory and dban
##
sub gpxe_linux_baracus()  { &gpxe_baracus_bootstrap( @_ ); }
sub gpxe_initrd_baracus() { &gpxe_baracus_bootstrap( @_ ); }
sub gpxe_baracus_bootstrap{

    $sql = qq|SELECT bin FROM sqlfstable WHERE name = '$1'|;
    die "$!" unless ( $sth = $tftph->prepare( $sql ) );
    die "$!" unless ( $sth->execute( ) );

    while ( $href = $sth->fetchrow_hashref( ) ) {
        $output .= unpack( 'u', $href->{'bin'} );
    }
}

    else {
        # shoudld be some 401 or something
        $output = "invalid URL";
    }
}

## NEED TO ADD THIS TO Baracus.pm ROUTES FOR GPXE
#print $cgi->header( -type => "text/plain", -content_length => length ($output)), $output;

exit 0;

1;
