package Baracus::REST::Do;

###########################################################################
#
# Baracus build and boot management framework
#
# Copyright (C) 2010 Novell, Inc, 404 Wyman Street, Waltham, MA 02451, USA.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the Artistic License 2.0, as published
# by the Perl Foundation, or the GNU General Public License 2.0
# as published by the Free Software Foundation; your choice.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  Both the Artistic
# Licesnse and the GPL License referenced have clauses with more details.
#
# You should have received a copy of the licenses mentioned
# along with this program; if not, write to:
#
# FSF, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110, USA.
# The Perl Foundation, 6832 Mulderstraat, Grand Ledge, MI 48837, USA.
#
###########################################################################

use 5.006;
use Carp;
use strict;
use warnings;

use Dancer qw( :syntax);
use Dancer::Plugin::Database;

use Baracus::DB;
use Baracus::Sql     qw( :vars :subs );
use Baracus::Core    qw( :subs );
use Baracus::Config  qw( :vars :subs );
use Baracus::Host    qw( :subs );
use Baracus::State   qw( :admin :actions :subs :vars );
use Baracus::Source  qw( :vars :subs );
use Baracus::Aux     qw( :subs );
use Baracus::Storage qw( :vars :subs );

use Dancer qw( :syntax );

BEGIN {
    use Exporter ();
    use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    @EXPORT_OK   = qw();
    %EXPORT_TAGS =
        (
         subs   =>
         [qw(
                do_admin
         )],
         );

    Exporter::export_ok_tags('subs');
}

our $VERSION = '2.01';


###########################################################################
##
## Main Do REST Subroutines (build/empty/inventory/localboot/netboot/norescue/rescue/wipe)

sub do_admin() {

    my %action_to_take = (    
        'build'     => \&do_build,
        'image'     => \&do_image,
        'clone'     => \&do_clone,
        'empty'     => \&do_empty,
        'inventory' => \&do_inventory,
        'migrate'   => \&do_migrate,
        'localboot' => \&do_localboot,
        'netboot'   => \&do_netboot,
        'pxewait'   => \&do_pxewait,
        'rescue'    => \&do_rescue,
        'wipe'      => \&do_wipe,
        'list'      => \&do_list,
    );

    if ( defined $action_to_take{ request->params->{verb} }) {
        $action_to_take{ request->params->{verb} }( @_ )  ;
    } else {
        status '406';
        error "invalid host action";
        return { code => "41", error => "invalid host action" };
    }
}

sub do_build() {

    my $command = "build";

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my %entry;
    my $cols = lc get_cols( $baTbls{ action });
    foreach my $key (split(/[,\s*]/, $cols )) {
        $entry{$key} = '';
    }

    my $disk      = "0";
    my $partition = "0";

    #Make dhcp the default for ip
    $entry{ip} = 'dhcp';
    $entry{storageid} = '0';

    $entry{mac}        = request->params->{mac}       if ( defined request->params->{mac} );
    $entry{hostname}   = request->params->{hostname}  if ( defined request->params->{hostname} );
    $entry{ip}         = request->params->{ip}        if ( defined request->params->{ip} );
    $entry{distro}     = request->params->{distro}    if ( defined request->params->{distro} );
    $entry{hardware}   = request->params->{hardware}  if ( defined request->params->{hardware} );
    $entry{profile}    = request->params->{profile}   if ( defined request->params->{profile} );
    $entry{autobuild}  = request->params->{autobuild} if ( defined request->params->{autobuild} );
    $entry{storageid}  = request->params->{storageid} if ( defined request->params->{storageid} );
    $entry{addon}      = request->params->{addon}      if ( defined request->params->{addon} );
    $entry{vars}       = request->params->{vars}       if ( defined request->params->{vars} );
    $entry{modules}    = request->params->{module}     if ( defined request->params->{module} );
    my $usevnc         = request->params->{usevnc}     if ( defined request->params->{usevnc} );
    my $vncpass        = request->params->{vncpass}    if ( defined request->params->{vncpass} );
    my $usessh         = request->params->{usessh}     if ( defined request->params->{usessh} );
    my $sshpass        = request->params->{sshpass}    if ( defined request->params->{sshpass} );
    my $serialtty      = request->params->{serialtty}  if ( defined request->params->{serialtty} );
    my $serialbaud     = request->params->{serialbaud} if ( defined request->params->{serialbaud} );
    $disk           = request->params->{disk}       if ( defined request->params->{disk} );
    $partition      = request->params->{partition}  if ( defined request->params->{partition} );

    my $chkref;
    my $actref;
    my $hostref;
    my $macref;

    my %returnHash;

    if ( &check_host_action ( $opts, \%entry, $chkref, $actref )) {
        status '406';
        error "invalid host action";
        return { code => "41", error => "invalid host action" }; 
    }

    if ( $entry{ip} eq "" and
         defined $chkref and
         $chkref->{ip} ne ""
        )
    {
        $entry{ip}=$chkref->{ip};
    }

    $entry{ip} = lc $entry{ip};
    &check_ip( $entry{ip} );

    if ( $entry{ip} eq "" ) {
        status '406';
        error "missing required argument";
        return { code => "10", error => "missing required argument" };
    }

    # done with all checking of hostname/mac/ip
    # begin loading of hash used for remainder of processing command
    undef $actref;

    $actref = {};
    $actref->{storageid} = "";  # default to wiping the storageid info

    # baDir and baVar into actref
    &load_baracusconfig( $opts, $actref );

    unless ( defined $entry{profile} and $entry{profile} ne "" ) {
        debug "profile unspecified. Using 'default'\n";
        $entry{profile} = "default";
    }

    # breakout possible compound ver:name with call get back ( name, ver/undef )
    ( $actref->{profile}, $actref->{profile_ver} ) =
        &get_name_version( $entry{profile} );
    debug "profile $actref->{profile}\n";
    debug "profile version $actref->{profile_ver}\n" if (defined $actref->{profile_ver} and $opts->{debug});

    if ( &load_profile( $opts, $actref ) ) {
        status '406';
        error "generic do error";
        return { code => "40", error => "generic do error" };
    }
    foreach my $key ( sort ( keys %{$actref} )) {
        debug "add post-profile:  $key => $actref->{$key}\n";
    }

    # storageid may be in profile and specified on the command line
    # command line wins over profile entry
    # also note that cmdline --storageid="" will clear the initial '0' value
    # so that an empty string can be passed to "null" the storageid from a profile
    $actref->{storageid} = $entry{storageid} if ($entry{storageid} ne "0");

    # storageid may not be specified at all
    if ( defined $actref->{storageid} and $actref->{storageid} ne "" ) {
        if ( &load_storage( $opts, $actref ) ) {
            status '406';
            error "generic do error";
            return { code => "40", error => "generic do error" };
        }
        foreach my $key ( sort ( keys %{$actref} )) {
            debug "add post-storage:  $key => $actref->{$key}\n";
        }
    }

    # distro file may be in profile *and* on command line
    # command line wins over profile entry
    $actref->{'distro'} = $entry{distro} if ($entry{distro});

    unless ($actref->{'distro'}) {
        status '406';
        error "Need distro provided somewhere";
        return { code => "40", error => "generic do error" };
    }

    if ( &load_distro( $opts, $actref ) ) {
        status '406';
        error "generic do error";
        return { code => "40", error => "generic do error" };
    }

    foreach my $key ( sort ( keys %{$actref} )) {
        debug "add post-distro:  $key => $actref->{$key}\n";
    }

    my $addons_in;
    # addons may have been specified in profile
    $addons_in = $actref->{'addons'} if ( defined $actref->{addons} );
    # command line wins over profile entry
    $addons_in = $entry{addons} if ($entry{addons});

    if ( my $dinc = get_distro_includes( $opts, $actref->{distro} ) ) {
        debug "lumping in sdk addon $dinc for $actref->{distro}\n";

        if ( $addons_in ) {
            $addons_in = "$dinc " . $addons_in;
        } else {
            $addons_in = $dinc;
        }
    }
    # we're going to store this list of addons in the db
    $actref->{addons} = $addons_in;

    # if actref->{'addon'} was set by reading a profile addon= line
    # we need to clear it from $hash as that is for the __ADDON__ autobuild
    $actref->{'addon'} = '';
    if ( defined $addons_in and $addons_in ne "" ) {
        debug "add pre-addons:  $addons_in\n" if ($opts->{debug} > 1);
        if ( &load_addons( $opts, $actref ) ) {
            status '406';
            error "generic do error";
            return { code => "40", error => "generic do error" };
        }
    }
    foreach my $key ( sort ( keys %{$actref} )) {
        debug "add post-addons:  $key => $actref->{$key}\n";
    }

    # hardware file may be in profile *and* on command line
    # command line wins over profile entry
    $actref->{'hardware'}= $entry{hardware} if ($entry{hardware});

    unless ($actref->{'hardware'}) {
        status '406';
        error "Need hardware defined somewhere";
        return { code => "40", error => "generic do error" };
    }

    # breakout possible compound ver:name with call get back ( name, ver/undef )
    ( $actref->{hardware}, $actref->{hardware_ver} ) =
        &get_name_version( $actref->{hardware} );
    debug "hardware $actref->{hardware}\n";
    debug "hardware version $actref->{hardware_ver}\n" if ( defined $actref->{hardware_ver} );


    if ( &load_hardware( $opts, $actref ) ) {
        status '406';
        error "generic do error";
        return { code => "40", error => "generic do error" };
    }
    if ( &check_cert( $opts, $actref->{'distro'}, "hardware", $actref->{'hardware'}) ) {
        status '406';
        error "generic do error";
        return { code => "40", error => "generic do error" };
    }

    foreach my $key ( sort ( keys %{$actref} )) {
        debug "add post-hardware:  $key => $actref->{$key}\n";
    }

    my $modules_in;
    # modules may have been specified in profile
    $modules_in = $actref->{'modules'} if ( defined $actref->{'modules'} );
    # command line wins over profile entry
    $modules_in = $entry{modules} if ($entry{modules});

    # Check for and add mandatory modules
    my $mandatory_in = &get_mandatory_modules( $opts, $actref->{distro} );
    if ( defined $mandatory_in ) {
        debug "lumping in mandatory module(s) for $actref->{distro}\n  $mandatory_in"
            if ( $opts->{debug} );

        if ( $modules_in ) {
            $modules_in = "$mandatory_in " . $modules_in;
        } else {
            $modules_in = $mandatory_in;
        }
    }

    # we're going to store this list of modules in a join table
    $actref->{modules} = $modules_in;

    # if hash{'module'} was set by reading a profile module= line
    # we need to clear it from $hash as that is for the __MODULE__ autobuild
    $actref->{'module'} = '';

    # modules are optional do not attempt to load if none specified
    if ( defined $modules_in and $modules_in ne "" ) {
        debug "add pre-modules: $modules_in\n" if ( $opts->{debug} );
        if ( &load_modules( $opts, $actref ) ) {
            status '406';
            error "generic do error";
            return { code => "40", error => "generic do error" };
        }
        if ( &check_cert( $opts, $actref->{distro}, "module", $modules_in )) {
            status '406';
            error "generic do error";
            return { code => "40", error => "generic do error" };
        }
    }

    # autobuild may be in profile *and* on command line
    # command line wins over profile entry
    $actref->{'autobuild'} = $entry{autobuild} if ($entry{autobuild});

    unless ($actref->{'autobuild'}) {
        $actref->{'autobuild'} = "none";
        debug "Without autobuild provided installer is defaulting to interactive"
    }

    # breakout possible compound ver:name with call get back ( name, ver/undef )
    ( $actref->{'autobuild'}, $actref->{'autobuild_ver'} ) =
        &get_name_version( $actref->{autobuild} );
    debug "autobuild $actref->{autobuild}\n";
    debug "autobuild version $actref->{autobuild_ver}\n" if ( defined $actref->{autobuild_ver} );

    if ( $actref->{'autobuild'} ne "none" ) {
        if ( &load_autobuild( $opts, $actref )) {
            status '406';
            error "generic do error";
            return { code => "40", error => "generic do error" };
        }
        if ( &check_cert( $opts, $actref->{'distro'}, 'autobuild', $actref->{'autobuild'} )) {
            status '406';
            error "generic do error";
            return { code => "40", error => "generic do error" };
        }
    }

    # Remote Access configurations
    my @raccess;
    # vnc remote access may be specified in profile *and* on command line
    # command line wins over profile entry
    if (($vncpass) and !($usevnc)) {
        status '406';
        error "vncpass requires usevnc\n";
        return { code => "40", error => "generic do error" };
    } elsif (!($vncpass) and ($usevnc)) {
        status '406';
        error "usevnc requires vncpass\n";
        return { code => "40", error => "generic do error" };
    }

    if ($vncpass) {
        if ( length( $vncpass) < 8 ) {
            status '406';
            error "minimum password length of 8 chars required";
            return { code => "40", error => "generic do error" };
        }
        $vncpass =~ s/$vncpass/vncpassword=$vncpass/;
        if ( $actref->{os} =~ m|rhel|   or
             $actref->{os} =~ m|esx|    or
             $actref->{os} =~ m|fedora| or
             $actref->{os} =~ m|centos| ) {
            push(@raccess, "vnc", $vncpass);
        } else {
            push(@raccess, "vnc=1", $vncpass);
        }
    }

    # ssh remote access may be specified in profile *and* on command line
    # command line wins over profile entry
    if (($sshpass) or ($usessh)) {
        if ( $actref->{os} =~ m|rhel|   or
             $actref->{os} =~ m|esx|    or
             $actref->{os} =~ m|fedora| or
             $actref->{os} =~ m|centos| ) {
            status '406';
            error "RHEL, ESX, Fedora, CentOS do not support ssh install";
            return { code => "40", error => "generic do error" };
        }
    }
    if (($sshpass) and !($usessh)) {
        status '406';
        error "sshpass requires usessh\n";
        return { code => "40", error => "generic do error" };
    } elsif (!($sshpass) and ($usessh)) {
        status '406';
        error "usessh requires sshpass\n";
        return { code => "40", error => "generic do error" };
    }

    if ($usessh) {
        $sshpass =~ s/$sshpass/sshpassword=$sshpass/;
        push(@raccess, "usessh=1", $sshpass);
    }

    # serial remote access may be specified in profile *and* on command line
    # command line wins over profile entry
    $actref->{console} = "";

    if (($serialtty) and !($serialbaud)) {
        status '406';
        error "serialtty requires serialbaud";
        return { code => "40", error => "generic do error" };
    } elsif (!($serialtty) and ($serialbaud)) {
        status '406';
        error "serialbaud requires erialtty";
        return { code => "40", error => "generic do error" };
    }
    if (($serialbaud) and ($serialtty)) {
        if ( $actref->{os} =~ m|rhel|   or
             $actref->{os} =~ m|esx|    or
             $actref->{os} =~ m|fedora| or
             $actref->{os} =~ m|centos| or
             $actref->{distro} =~ m|sles-9| ) {
            ##
            ##  INCLUDE SLES9 FOR MINIMAL CMD LINE TXT
            ##
            my $serialopts = "console=tty0 console=$serialtty,$serialbaud";
            push(@raccess, $serialopts);
            $actref->{console} = $serialopts;
        } else {
            my $serialopts = "console=tty0 console=$serialtty,$serialbaud";
            $serialopts .= " earlyprintk=serial,$serialtty,$serialbaud";
            push(@raccess, $serialopts);
            $actref->{console} = $serialopts;
        }
    }


    # Join all raccess args
    $actref->{'raccess'} = join " ", @raccess;

    ## Commandline options
    ##   - comes after reading profile
    ##   - harware, distro override profile values
    ##   - cmdline values override any file values

    ## If passed on command line via vars, then honor those
    ##
    if ($entry{vars}) {
        $actref->{vars} = $entry{vars};
        &load_vars( $opts, $actref );
    }

    # do not want any setting to override these values

   # $actref->{'cmdline'} = $cmdline;
    $actref->{'cmdline'} = 'boinkers';
    $actref->{'hostname'} = $entry{hostname};
    $actref->{'ip'} = $entry{ip};
    $actref->{'mac'} = $entry{mac};
    $actref->{'uuid'} = &get_uuid;
    $actref->{'autoinst'} = &automac( $entry{mac} );
    $actref->{'basedist'} = "$actref->{os}-$actref->{release}-$actref->{arch}";
    $actref->{'initrd'} = "initrd.$actref->{'basedist'}";
    $actref->{'kernel'} = "linux.$actref->{'basedist'}";

    $actref->{'admin'}   = BA_ADMIN_ENABLED;
    $actref->{'oper'}    = BA_ADMIN_ADDED;
    $actref->{'pxecurr'} = BA_ACTION_INVENTORY;
    $actref->{'pxenext'} = BA_ACTION_BUILD;

    $actref->{'autonuke'} = 0;

    if ( $baVar{remote_logging} eq "yes" ) {
        if ( $actref->{os} =~ m|rhel|   or
             $actref->{os} =~ m|esx|    or
             $actref->{os} =~ m|fedora| or
             $actref->{os} =~ m|centos| ) {
            $actref->{'loghost'} = "syslog=$actref->{serverip}";
        } elsif ( $actref->{os} =~ m|ubuntu| ) {
            $actref->{'loghost'} = "log_host=$actref->{serverip}";
        } else {
            $actref->{'loghost'} = "loghost=$actref->{serverip}";
        }
    } else {
        $actref->{'loghost'} = ""
    }

    # Check if broadcast address is set
    &check_broadcast( $opts, $actref );

    unless ( $disk =~ /^\d+$/ ) {
        status '406';
        error "disk needs to be an integer";
        return { code => "40", error => "generic do error" };
    }

    unless ( $partition =~ /\d+$/ ) {
        status '406'; 
        error "partition needs to be an integer";
        return { code => "40", error => "generic do error" };
    }

    $actref->{disk} = $disk;
    $actref->{partition} = $partition;

    $macref = &check_add_db_mac( $opts, $macref, $actref->{mac} );

    $hostref = &get_db_data( $opts, 'host', $entry{hostname} );
    unless ( defined $hostref ) {
        &add_db_data( $opts, 'host', $actref );
    }

    # reset action_module join table list
    # now that modules have been checked and loaded
    # create the action_module entries and store ver

    &action_state_change( $opts, BA_ACTION_BUILD, $actref );

    &update_db_mac_state ( $opts, $actref->{mac}, BA_ACTION_BUILD);

    # find existing action relation and update it or create if not found
    # avoid overwrite of the carefully constructed $actref hash
    my $tmpref = &get_db_data( $opts, 'action', $actref->{mac} );
    if ( defined $tmpref ) {
        # here's a rather involved check
        # to make sure we're not updating a dup
        my $gotdiff = 0;
        while ( my ($key, $val) = each %{$tmpref} ) {
            next if $key eq "uuid"; # changes every invocation
            next if $key eq "creation";
            next if $key eq "change";
            next if $key eq "cmdline"; # order diff and -d -v -q don't matter

            ## If a key was specified on the command line, we have to see if 
            ## that same key is already defined, if it is, and they don't match, we
            ## have to update the DB.  If one of the keys exists and the other one
            ## doesn't, we consider them not equal and have to update the DB.  If 
            ## both keys do not exist, we just skip to the next key.
            if ( defined $actref->{$key} ) {
                if ( !defined $val or
                     (defined $val and $actref->{$key} ne $val) ) {
                    if ( defined $val) {
                        debug "cmp $key \n\tin actref '$actref->{$key}' \n\twith val '$val'\n";
                    } else {
                        debug "cmp $key \n\tin actref '$actref->{$key}' \n\twith val <undefined> '\n";
                    }
                    $gotdiff = 1;
                    last;
                }

            } elsif ( defined $val ) {
                debug "cmp $key \n\tin actref <undefined> \n\twith val '$val'\n";
                $gotdiff = 1;
                last;
            } else {
                    next;
            }
        }
        if ( $gotdiff != 0 ) {
            &update_db_data( $opts, 'action', $actref);
        }
    } else {
        &add_db_data( $opts, 'action', $actref);
    }

    if ( &remove_db_data_by( $opts, 'actmod', $actref->{mac}, 'mac' ) ) {
        status '406';
        error "generic do error";
        return { code => "40", error => "generic do error" };
    }

    # prep action_module entry
    my $actmodref->{mac} = $actref->{mac};
    if ( $actref->{modules} ) {
        foreach my $mod ( split( /[,\s*]/, $actref->{modules} ) ) {
            my ( $mname, $mvers ) = &get_name_version( $mod );
            my $mfound = get_version_or_enabled( $opts, "module", $mname, $mvers );
            unless ( defined $mfound ) {
                status '406';
                error "generic do error";
                return { code => "40", error => "generic do error" };
            }

            $actmodref->{module} = $mname;
            $actmodref->{module_ver} = $mfound->{version};
            if ( &add_action_modules( $opts, $actmodref ) ) {
                status '406';
                error "generic do error";
                return { code => "40", error => "generic do error" }; 
            }
        }
    }

    if ( &remove_db_data( $opts, 'actabld', $actref->{mac} ) ) {
        status '406';
        error "generic do error";
        return { code => "40", error => "generic do error" };
    }

    unless ( $actref->{'autobuild'} eq "none" ) {
        # get_autobuild_expanded here is to make sure we have all
        # the 'ingredients' collected to generate a 'recipe'
        my $abfile = &get_autobuild_expanded( $opts, $actref );
        unless ( defined $abfile ) {
            status '406';
            error "generic do error";
            return { code => "40", error => "generic do error" };
        }

        # prep action_autobuild entry
        my $actabref =
        {
         mac           => $actref->{mac},
         autobuild     => $actref->{autobuild},
         autobuild_ver => $actref->{autobuild_ver},
         };

        if ( &add_action_autobuild( $opts, $actabref ) ) {
            status '406';
            error "generic do error";
            return { code => "40", error => "generic do error" };
        }

        debug $abfile;
    }

    debug "Build recipe set.  Next pxeboot of $entry{hostname} will start install cycle.";

    $returnHash{mac} = $entry{mac};
    $returnHash{hostname} = $entry{hostname};
    $returnHash{action} = $command;
    $returnHash{result}   = '0';

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub do_image() {

    my $command = "image";
debug "DEBUG: in start of command=$command \n";

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    } 
debug "DEBUG: well got here ";
    my %entry;
    my $cols = lc get_cols( $baTbls{ action });
    foreach my $key (split(/[,\s*]/, $cols )) {
        $entry{$key} = '';
    }
debug "DEBUG: well got here 0 ";
    my $mcast = "";
    my $disk = "0";
    my $partition = "0";

    $entry{mac}       = request->params->{mac}       if ( defined request->params->{mac} );
    $entry{hostname}  = request->params->{hostname}  if ( defined request->params->{hostname} );
    $entry{storageid} = request->params->{storageid} if ( defined request->params->{storageid} ); 
    $entry{mcastid}   = request->params->{mcastid}   if ( defined request->params->{mcastid} );
    $entry{hardware}  = request->params->{hardware}  if ( defined request->params->{hardware} );
    $entry{disk}      = request->params->{disk}      if ( defined request->params->{disk} );
    $entry{partition} = request->params->{partition} if ( defined request->params->{partition} );

    my %returnHash;

    my $chkref;
    my $macref;
    my $hostref;
    my $actref;
    my $sref;

    if ( $entry{mcastid} ne "" and $entry{storageid} ne "" ) {
        status '406';
        error "Either --storageid or --mcastid, not both";
        return { code => "40", error => "Either --storageid or --mcastid, not both" };
    } elsif ( $entry{mcastid} ne "" ) {
        ;
        # need to write mcastid checker
        # &check_mcastid( $entry{mcastid} );
    } elsif ( $entry{storageid} ne "" ) {
        # get and check for image based on id
        $sref = &get_db_data( $opts, 'storage', $entry{storageid} );
        unless ( defined $sref ) {
            status '406';
            error "storageid does not exist: $entry{storageid}";
            return { code => "40", error => "storageid does not exist: $entry{storageid}" };
        }
        if ( $sref->{type} != BA_STORAGE_IMAGE ) {
            status '406';
            error "Storage specified has non-image type: $baStorageType{ $sref->{type} }";
            return { code => "40", error => "Storage specified has non-image type: $baStorageType{ $sref->{type} } " };
        }
        unless ( -f "$baDir{images}/$sref->{storage}" ) {
            status '406';
            error "Unable to find specified image:  $baDir{images}/$sref->{storage}";
            return { code => "40", error => "Unable to find specified image:  $baDir{images}/$sref->{storage} " };
        }
    } else {
        status '406';
        error "Neither --storageid nor --mcastid provided";
        return { code => "40", error => "Neither --storageid nor --mcastid provided" };
    }
debug "DEBUG: well got here 1 ";
    if ( &check_host_action ( $opts, \%entry, $chkref, $actref )) {
        status '406';
        error "check_host_action failed";
        return { code => "40", error => "check_host_action failed" };
    }

    # hardware file may be in profile *and* on command line
    # command line wins over profile entry
    $actref->{'hardware'} = $entry{hardware} if ($entry{hardware});

    unless ($actref->{'hardware'}) {
        status '406';
        error "Need hardware specified";
        return { code => "40", error => "Need hardware specified" };
    }

    # breakout possible compound ver:name with call get back ( name, ver/undef )
    ( $actref->{hardware}, $actref->{hardware_ver} ) =
        &get_name_version( $actref->{hardware} );
    debug "hardware $actref->{hardware}\n";
    debug "hardware version $actref->{hardware_ver}\n" if ( defined $actref->{hardware_ver} );


    if ( &load_hardware( $opts, $actref ) ) {
        status '406';
        error "load_hardware failed";
        return { code => "40", error => "load_hardware failed" };
    }

    foreach my $key ( sort ( keys %{$actref} )) {
        debug "add post-hardware:  $key => $actref->{$key}\n";
    }

    unless ( $disk =~ /^\d+$/ ) {
        status '406';
        error "disk needs to be an integer";
        return { code => "40", error => "disk needs to be an integer" };
    }

    unless ( $partition =~ /\d+$/ ) {
        status '406';
        error "partition needs to be an integer";
        return { code => "40", error => "partition needs to be an integer" };
    }

    $actref->{disk} = $disk;
    $actref->{partition} = $partition;
    $actref->{storageid} = "";  # wipe the storageid info

    # do not want any setting to override these values

   # $actref->{'cmdline'} = $cmdline;
    $actref->{'cmdline'} = "wham";
    $actref->{'hostname'} = $entry{hostname} if (defined $entry{hostname} and $entry{hostname}  ne "");
    $actref->{'ip'} = $entry{ip};
    $actref->{'mac'} = $entry{mac};
    $actref->{'uuid'} = &get_uuid;
    $actref->{'storageid'} = $entry{storageid} if ( defined $entry{storageid} );
    $actref->{'mcastid'} = $entry{mcastid} if ( defined $entry{mcastid} );

    debug "settings to use:\n";
    foreach my $key ( sort keys %{$actref} ) {
        debug "actref:  $key => %s\n",
            defined $actref->{$key} ? $actref->{$key} : "";
    }

    $macref = &check_add_db_mac( $opts, $macref, $actref->{mac} );

    $hostref = &get_db_data_by( $opts, 'host', $actref->{mac}, 'mac' );
    unless ( defined $hostref ) {
        &add_db_data( $opts, 'host', $actref );
    }

    # reset action_module join table list
    # now that modules have been checked and loaded
    # create the action_module entries and store ver

    my $action = $entry{mcastid} ? BA_ACTION_MCAST : BA_ACTION_IMAGE ;

    &action_state_change( $opts, $action, $actref );

    &update_db_mac_state ( $opts, $actref->{mac}, $action );

    # find existing action relation and update it or create if not found
    # avoid overwrite of the carefully constructed $actref hash
    my $tmpref = get_db_data( $opts, 'action', $actref->{mac} );
    if ( defined $tmpref ) {
        # here's a rather involved check
        # to make sure we're not updating a dup
        my $gotdiff = 0;
        while ( my ($key, $val) = each %{$tmpref} ) {
            next if $key eq "uuid"; # changes every invocation
            next if $key eq "creation";
            next if $key eq "change";
            next if $key eq "cmdline"; # order diff and -d -v -q don't matter

            ## If a key was specified on the command line, we have to see if 
            ## that same key is already defined, if it is, and they don't match, we
            ## have to update the DB.  If one of the keys exists and the other one
            ## doesn't, we consider them not equal and have to update the DB.  If 
            ## both keys do not exist, we just skip to the next key.
            if ( defined $actref->{$key} ) {
                if ( !defined $val or
                     (defined $val and $actref->{$key} ne $val) ) {
                    if ( defined $val) {
                        debug "cmp $key \n\tin actref '$actref->{$key}' \n\twith val '$val'\n";
                    } else {
                        debug "cmp $key \n\tin actref '$actref->{$key}' \n\twith val <undefined> '\n";
                    }
                    $gotdiff = 1;
                    last;
                }

            } elsif ( defined $val ) {
                debug "cmp $key \n\tin actref <undefined> \n\twith val '$val'\n" if ($opts->{debug});
                $gotdiff = 1;
                last;
            } else {
                    next;
            }
        }
        if ( $gotdiff != 0 ) {
            &update_db_data( $opts, 'action', $actref);
        }
    } else {
        &add_db_data( $opts, 'action', $actref);
    }

    debug "Image assigned. Next pxeboot of $entry{mac} will start image install cycle.";

    $returnHash{mac} = $entry{mac};
    $returnHash{hostname} = $entry{hostname};
    $returnHash{action} = $command;
    $returnHash{result}   = '0';

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status '406';
        error "generic return error";
        return { code => "40", error => "generic return error" };
    }

}

sub do_clone() {

}

sub do_migrate() {

}

sub do_empty() {

}

sub do_inventory() {

}

sub do_localboot() {

}

sub do_netboot() {

    my $command = "netboot";
debug "DEBUG: in start of command=$command \n";

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $mac="";
    my $hostname="";
    my $storageid  = "";

    $mac       = request->params->{mac}        if ( defined request->params->{mac} );
    $hostname  = request->params->{hostname}   if ( defined request->params->{hostname} );
    $storageid = request->params->{storageid}  if ( defined request->params->{storageid} );

    my %returnHash;
    my $chkref;
    my $macref;
    my $actref;

    $mac = &get_mac_by_hostname( $opts, 'host', $hostname );
    unless ( defined $mac ) {
        status '406';
        error "error mac undefined";
        return { code => "40", error => "error mac undefined" };
    }

    if ( $storageid eq "" ) {
        status '406';
        error "storageid needed for netboot";
        return { code => "40", error => "storageid needed for netboot" };
    }

    $macref = &check_add_db_mac( $opts, $macref, $mac );

    while ( my ($key, $val) = each( %$macref ) ) {
        debug "macref:  $key => %s\n", defined ${val} ? ${val} : "";
    }

    $chkref = &get_db_data( $opts, 'action', $mac );
    if ( defined $chkref ) {
        while ( my ($key, $val) = each( %$chkref ) ) {
            debug "actref:  $key => %s\n", defined ${val} ? ${val} : "";
        }

        if ( ( $chkref->{pxenext} eq BA_ACTION_NETBOOT ) and
             ( $chkref->{storageid} eq $storageid )
            ) {
            status '406';
            error "device in NETBOOT state using $chkref->{storageid}";
            return { code => "40", error => "device in NETBOOT state using $chkref->{storageid}" };
        }

        # store a copy of the ref found for modification
        $actref = $chkref;
    }

    #$actref->{cmdline} = $cmdline;
    $actref->{cmdline} = "yikes";
    $actref->{mac}     = $mac;
    $actref->{storageid} = $storageid;

    if ( &load_storage( $opts, $actref ) ) {
        status '406';
        error "loading storageid $storageid failed";
        return { code => "40", error => "loading storageid $storageid failed" };
    }

    ##
    ## ALL CHECKS DONE - DO MODS

    # if passed both mac and hostname create a host table entry
    if ( $hostname ne "" ) {
        $actref->{hostname} = $hostname;
        unless ( &get_db_data( $opts, 'host', $hostname ) ) {
            &add_db_data( $opts, 'host', $actref );
        }
    }

    &action_state_change( $opts, BA_ACTION_NETBOOT, $actref );

    &update_db_mac_state( $opts, $mac, BA_ACTION_NETBOOT );

    # for proper command history update we update
    if ( defined $chkref ) {
        &update_db_data( $opts, 'action', $actref );
    } else {
        &add_db_data( $opts, 'action', $actref );
    }

    debug "Netboot set -nNext pxeboot of %s will use remote storageid $mac";

    my %returnHash;

    $returnHash{mac} = $mac;
    $returnHash{hostname} = $hostname;
    $returnHash{action} = $command;
    $returnHash{result}   = '0';

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status '406';
        error "generic return error";
        return { code => "40", error => "generic return error" };
    }

}

sub do_pxewait() {

    my $command = "pxewait";
debug "DEBUG: in start of command=$command \n";

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $mac="";
    my $hostname="";

    $mac      = request->params->{mac}       if ( defined request->params->{mac} );
    $hostname = request->params->{hostname}  if ( defined request->params->{hostname} );

    my %returnHash;

    my $macref;
    my $actref;
    my $chkref;

    $mac = &get_mac_by_hostname( $opts, 'host', $hostname );
    unless ( defined $mac ) {
        status '406';
        error "generic return error";
        return { code => "40", error => "generic return error" };
    }

    $macref = &check_add_db_mac( $opts, $macref, $mac );

    while ( my ($key, $val) = each %{$macref} ) {
        debug "macref:  $key => %s\n", defined ${val} ? ${val} : "";
    }

    $chkref = &get_db_data( $opts, 'action', $mac );
    if ( defined $chkref ) {
        while ( my ($key, $val) = each %{$chkref} ) {
            debug "actref:  $key => %s\n", defined ${val} ? ${val} : "";
        }
        # store a copy of the ref found for modification
        $actref = $chkref;
    }

    if ( defined $chkref and $chkref->{pxenext} eq BA_ACTION_PXEWAIT ) {
        status '406';
        error "device already set to $command";
        return { code => "40", error => "device already set to $command." };
    }

    ##
    ## ALL CHECKS DONE - DO MODS

#    $actref->{cmdline} = $cmdline;
    $actref->{cmdline} = "zoinks";
    $actref->{mac} = $mac;

    # if passed both mac and hostname create a host table entry
    if ( $hostname ne "" ) {
        $actref->{hostname} = $hostname;
        unless ( &get_db_data( $opts, 'host', $hostname ) ) {
            &add_db_data( $opts, 'host', $actref );
        }
    }

    &action_state_change( $opts, BA_ACTION_PXEWAIT, $actref );

    &update_db_mac_state( $opts, $mac, BA_ACTION_PXEWAIT );

    # for proper command history update we update
    if ( defined $chkref ) {
        &update_db_data( $opts, 'action', $actref );
    } else {
        &add_db_data( $opts, 'action', $actref );
    }

    debug "Inventory set\nNext pxeboot of %s will pxewait.\n",
        $hostname ne "" ? $hostname : $mac;

    $returnHash{mac} = $mac;
    $returnHash{hostname} = $hostname;
    $returnHash{action} = $command;
    $returnHash{result}   = '0';

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status '406';
        error "generic return error";
        return { code => "40", error => "generic return error" };
    }
}

sub do_norescue() {

}

sub do_rescue() {

}

sub do_wipe() {

    my $command = "wipe";
debug "DEBUG: in start of command=$command \n";

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $mac="";
    my $hostname="";
    my $autowipe = 0;

    $mac      = request->params->{mac}       if ( defined request->params->{mac} );
    $hostname = request->params->{hostname}  if ( defined request->params->{hostname} );
    $autowipe = request->params->{autowipe}  if ( defined request->params->{autowipe} );

    my %returnHash;
    my $macref;
    my $actref;
    my $chkref;

    $mac = &get_mac_by_hostname( $opts, 'host', $hostname );
    unless ( defined $mac ) {
        status '406';
        error "mac undefined";
        return { code => "40", error => "mac undefined" };
    }

    $macref = &check_add_db_mac( $opts, $macref, $mac );

    while ( my ($key, $val) = each %{$macref} ) {
        debug "macref:  $key => %s\n", defined ${val} ? ${val} : "";
    }

    $chkref = &get_db_data( $opts, 'action', $mac );
    if ( defined $chkref ) {
        while ( my ($key, $val) = each %{$chkref} ) {
            debug "actref:  $key => %s\n", defined ${val} ? ${val} : "";
        }
        # store a copy of the ref found for modification
        $actref = $chkref;
    }

    my $autostring = $autowipe ? "auto" : "";

    if ( defined $chkref and
         (defined $chkref->{autonuke} and $chkref->{autonuke} eq $autowipe ) and
         (defined $chkref->{pxenext}  and $chkref->{pxenext}  eq BA_ACTION_DISKWIPE ) ) {
        status '406';
        error "device already set to wipe disk";
        return { code => "40", error => "device already set to wipe disk" };
    }

    ##
    ## ALL CHECKS DONE - DO MODS

    $actref->{autonuke} = $autowipe;

    #$actref->{cmdline} = $cmdline;
    $actref->{cmdline} = "doh";
    $actref->{mac} = $mac;
    $actref->{storageid} = "";  # wipe the storageid info

    # if passed both mac and hostname create a host table entry
    if ( $hostname ne "" ) {
        $actref->{hostname} = $hostname;
        unless ( &get_db_data( $opts, 'host', $hostname ) ) {
            &add_db_data( $opts, 'host', $actref );
        }
    }

    &action_state_change( $opts, BA_ACTION_DISKWIPE, $actref );

    &update_db_mac_state( $opts, $mac, BA_ACTION_DISKWIPE );

    # for proper command history update we update
    if ( defined $chkref ) {
        &update_db_data( $opts, 'action', $actref );
    } else {
        &add_db_data( $opts, 'action', $actref );
    }

    debug "Wipe set.\nNext pxeboot the hardrive will be wiped.\n";

    $returnHash{mac} = $mac;
    $returnHash{hostname} = $hostname;
    $returnHash{action} = $command;
    $returnHash{result}   = '0';

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status '406';
        error "generic return error";
        return { code => "40", error => "generic return error" };
    }

}

sub do_list() {

}

1;
