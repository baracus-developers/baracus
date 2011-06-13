package Baracus::REST::Host;

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

use Baracus::SqlFS;
use Baracus::Sql    qw( :subs :vars );
use Baracus::Host   qw( :subs );
use Baracus::Core   qw( :vars :subs );
use Baracus::Config qw( :vars :subs );
use Baracus::State  qw( :vars :subs :admin :actions );
use Baracus::Source qw( :vars :subs );
use Baracus::Aux    qw( :subs );


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
                host_list
                host_detail
                host_inventory
                host_add
                host_remove
                host_admin
         )],
         );

    Exporter::export_ok_tags('subs');
}

our $VERSION = '2.01';

#my $baXML = &baxml_load( $opts, "$baDir{'data'}/badistro.xml" );
#$opts->{baXML}    = $baXML;

###########################################################################
##
## Main Host REST Subroutines (list/detail/add/remove/enable/disable)

sub host_list() {

    my $command    = "list";
    my $filter     = params->{filter};
    my $type       = vars->{type}; 

    unless ( defined $filter ) { $filter = ""; }

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my %returnHash;

    my $sth = &db_list_start( $opts, $type, $filter );
    my $dbref;
    if ( $type eq "templates" ) {
        ## List build templates associated with nodes
        ##
        while ( $dbref = &db_list_next( $sth ) ) {
            my $mac = $dbref->{mac};
            $mac =~ s/://g;
            my $name = "<null>";
            my $auto = "none";

            $name = $dbref->{'hostname'}  if ( defined $dbref->{'hostname'} );
            $auto = $dbref->{'autobuild'} if ( defined $dbref->{'autobuild'} );
            $returnHash{$mac}{mac}  = $dbref->{mac};
            $returnHash{$mac}{name} = $name;
            $returnHash{$mac}{auto} = $auto;
        }
    }
    elsif ( $type eq "states" ) {
        ## List macs and show state and when time of that state
        ##
        while ( $dbref = &db_list_next( $sth ) ) {
            my $mac = $dbref->{mac};
            $mac =~ s/://g;
            my $active_str  = "" ;
            my $state_str   = "" ;
            my $pxecurr_str = "" ;
            my $pxenext_str = "" ;
            my $hostname    = "<null>" ;
            $hostname    = $dbref->{hostname} if $dbref->{hostname};
            $active_str  = $baState{ $dbref->{admin}   } if $dbref->{admin};
            $state_str   = $baState{ $dbref->{oper}    } if $dbref->{oper};
            $pxecurr_str = $baState{ $dbref->{pxecurr} } if $dbref->{pxecurr};
            $pxenext_str = $baState{ $dbref->{pxenext} } if $dbref->{pxenext};

            if ( $dbref->{active} and
                 $dbref->{active} ne BA_ADMIN_ENABLED and
                 $dbref->{active} ne BA_ADMIN_DISABLED ) {
                $active_str .= "*";
            }
            $returnHash{$mac}{mac} = $dbref->{mac};
            $returnHash{$mac}{hostname} = $hostname;
            $returnHash{$mac}{pxecurr_str} = $pxecurr_str;
            $returnHash{$mac}{pxenext_str} = $pxenext_str;
            $returnHash{$mac}{state_str} = $state_str;
            $returnHash{$mac}{active_str} = $active_str;
        }
    }
    elsif ( $type eq "nodes" ) {
        ## List macs and show nodes
        ##
        my $inventory = "";
        my $inventory_st = "";
        my $sel;
        my $bstate;

        while ( $dbref = &db_list_next( $sth ) ) {
            my $mac = $dbref->{mac};
            $mac =~ s/://g;
            $inventory = $dbref->{'mac'} . ".inventory";
            $sel = $opts->{sqlfsOBJ}->detail( $inventory );
            if ( defined $sel ) {
                $inventory_st = "yes";
            } else {
                $inventory_st = "no";
            }

                unless ( defined $dbref->{hostname} ) {
                    $dbref->{hostname} = "<null>";
                }
                if ( defined $dbref->{admin} ) {
                    $bstate = $baState{ $dbref->{admin} };
                } else {
                    $bstate = " ";
                }
                $returnHash{$mac}{mac} = $dbref->{mac};
                $returnHash{$mac}{hostname} = $dbref->{hostname};
                $returnHash{$mac}{inventory} = $inventory;
                $returnHash{$mac}{inventory_st} = $inventory_st;
                $returnHash{$mac}{bstate} = $bstate;
        }
    }
    &db_list_finish( $sth );

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub host_detail() {

    my $command  = "detail";
    my $type     = vars->{bytype};
    my $node;

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    if ( defined params->{mac} ) {
        $node = params->{mac};
    } elsif ( defined params->{host} ) {
        $node = params->{host};
    } else {
        error "either mac or host required";
    }

    my $mac;
    if ( $type eq "host" ) {
        $mac = &get_mac_by_hostname( $opts, $type, $node );
    } else {
        $mac = $node;
    }

    unless ( defined $mac ) {
        $opts->{LASTERROR} = "mac or hostname required \n";
        error $opts->{LASTERROR};
    }
    $mac = &check_mac( $mac );

    my $dbref;
    my $filter = "mac::" .$mac;
    my $sth = &db_list_start( $opts, 'node', $filter );

    unless( defined $sth ) {
        # $opts->{LASTERROR} returned from db_list_start
        return 1;
    }

    my %returnHash;
    while ( $dbref = &db_list_next( $sth ) ) {
        $returnHash{mac}      = $dbref->{mac};
        $returnHash{hostname} = $dbref->{hostname};
        $returnHash{ip}       = $dbref->{ip};
        $returnHash{oper}     = $dbref->{oper} if $dbref->{oper};
        $returnHash{admin}    = $dbref->{admin} if $dbref->{admin};
        $returnHash{pxecurr}  = $dbref->{pxecurr} if $dbref->{pxecurr};
        $returnHash{pxenext}  = $dbref->{pxenext} if $dbref->{pxenext};
        $returnHash{distro}   = $dbref->{distro} if $dbref->{distro};
        $returnHash{addons}   = $dbref->{addons} if $dbref->{addons};
        $returnHash{hardware_ver} = $dbref->{hardware_ver} if $dbref->{hardware_ver};
        $returnHash{hardware}     = $dbref->{hardware} if $dbref->{hardware};
        $returnHash{profile_ver}  = $dbref->{profile_ver} if $dbref->{profile_ver};
        $returnHash{profile}      = $dbref->{profile} if $dbref->{profile};
#        my $abuild = &get_db_data( $opts, 'actabld', $dbref->{mac});
#        if (defined $abuild) {
#            $returnHash{autobuild_ver} = $abuild->{autobuild_ver};
#            $returnHash{autobuild}     = $abuild->{autobuild};
#            $returnHash{vars}          = $abuild->{vars};
#        }
#        my $modules = &get_action_modules_hash( $opts, $dbref->{mac});
#        if (defined $modules) {
#            my @modarray;
#            while ( my ($mkey, $mver) = each( %{$modules} ) ) {
#                push @modarray, "$mkey $mver";
#            }
#            $returnHash{modules} = @modarray;
#        }
        $returnHash{storageid} = $dbref->{storageid} if $dbref->{storageid};
        $returnHash{mcastid}   = $dbref->{mcastid} if $dbref->{mcastid};
        $returnHash{loghost}   = $dbref->{loghost} if $dbref->{loghost};
        $returnHash{raccess}   = $dbref->{raccess} if $dbref->{raccess};
        $returnHash{autonuke}  = $dbref->{autonuke} if $dbref->{autonuke};
        $returnHash{creation}  = $dbref->{creation} if $dbref->{creation};
        $returnHash{change}    = $dbref->{change} if $dbref->{change};
    }
    &db_list_finish( $sth );

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub host_inventory() {

    my $command  = "inventory";
    my $node     = params->{node}; # Can be mac or hostname

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    # dynamic type checking for params->node
    my $type = &get_node_type( $node );
    if ( $type == BA_REF_ERR ) {
        error "invalid node type";
    }

    # convert parama->{node} to mac address
    my $mac;
    if ( $type != BA_REF_MAC ) {
        $mac = &get_mac_by_hostname( $opts, $type, $node );
    } else {
        $mac = $node;
    }

    unless ( defined $mac ) {
        $opts->{LASTERROR} = "mac or hostname required \n";
        error $opts->{LASTERROR};
    }
    $mac = &check_mac( $mac );

    my $data = "";
    my %returnHash;
    my $inventory = $mac . ".inventory";
    my $inventoryFH = $opts->{sqlfsOBJ}->readFH( $inventory );
    unless ( defined $inventoryFH ) {
        $opts->{LASTERROR} = "Unable to find $inventory\n";
        error $opts->{LASTERROR};
    }

    while ( <$inventoryFH> ) {
        $data = join '', $_;
    }

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        $returnHash{$mac} = $data;
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub host_add() {

    my $command  = "add";
    my $mac         = request->params->{mac};
    my $hostname    = request->params->{hostname};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    unless ( defined $mac ) {
        status 'error';
        return "mac required";
    }

    unless ( defined $hostname ) {
        $hostname = "";
    }

    my $hostref;
    my $macref;
    my $actref;
    my $chkref;

    my %returnHash;

    $macref = &get_db_data( $opts, 'mac', $mac );
    unless ( defined $macref ) {
        &add_db_mac( $opts, $mac, BA_ADMIN_ADDED );
    }

    $chkref = &get_db_data( $opts, 'action', $mac );
    if ( defined $chkref ) {
        if ( $opts->{debug} > 1 ) {
            while ( my ($key, $val) = each %{$chkref} ) {
                debug "check $key => " . $val eq "" ? "" : $val . "\n";
            }
        }
        # store a copy of the ref found for modification
        $actref = $chkref;
    }

#   $actref->{cmdline} = $cmdline;
    $actref->{cmdline} = "yikes";
    $actref->{mac} = $mac;

    # if passed both mac and hostname create a host table entry
    if ( $hostname ne "" ) {
        $actref->{hostname} = $hostname;
        unless ( &get_db_data( $opts, 'host', $hostname ) ) {
            &add_db_data( $opts, 'host', $actref );
        }
    }

    unless ( defined $chkref ) {
        $macref = &get_db_data( $opts, 'mac', $mac ) unless ( defined $macref );
        &admin_state_change( $opts, BA_ADMIN_ADDED, $macref, $actref );
        &add_db_data( $opts, 'action', $actref );
    }

    $returnHash{mac} = $mac;
    $returnHash{hostname} = $hostname;
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

sub host_remove() {

    my $command     = "remove";
    my $mac         = request->params->{mac}; 
    my $hostname    = request->params->{hostname};

    my %returnHash;

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    if ( ( defined $hostname ) and ( not defined $mac ) ) {
        # this routine checks for mac and hostname args
        # and if hostname passed finds related mac entry
        # returns undef on error (e.g., unable to find hostname)
        $mac = &get_mac_by_hostname( $opts, $mac, $hostname );
        unless ( defined $mac ) {
            $opts->{LASTERROR} = "mac required \n";
            error $opts->{LASTERROR};
        }
    }

    unless ( defined $hostname ) {
        my $href = &get_db_data_by( $opts, 'host', $mac, 'mac' );
        if ( defined $href->{hostname} ) {
            $hostname = $href->{hostname};
        } else {
            $hostname = "";
        }
    }

    &update_db_mac_state( $opts, $mac, BA_ADMIN_REMOVED );

    my $actref = &get_db_data( $opts, 'action', $mac );
    if ( defined $actref ) {
        &admin_state_change( $opts, BA_ADMIN_REMOVED, undef, $actref );
#       $actref->{cmdline} = $cmdline;
        $actref->{cmdline} = "zonks";
        &update_db_data( $opts, 'action', $actref );
        &remove_db_data( $opts, 'action', $mac );
    }

    # must come before removal of mac relation
    my $hostref = &get_db_data_by( $opts, 'host', $mac, 'mac' );
    if ( defined $hostref ) {
        &remove_db_data_by(  $opts, 'host', $mac, 'mac');
    }

    &remove_sqlFS_files( $opts, $mac );

    my $macref = &get_db_data( $opts, 'mac', $mac );
    if ( defined $macref ) {
       &remove_db_data( $opts, 'mac', $mac );
    }

    $returnHash{mac} = $mac;
    $returnHash{hostname} = $hostname;
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

sub host_admin()
{
    my $command  = request->params->{verb};
    my $mac      = request->params->{mac}      if ( defined request->params->{mac} );
    my $hostname = request->params->{hostname} if ( defined request->params->{hostname} );

    my %returnHash;

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    unless ( defined $hostname ) {
        $hostname = "";
    }

    my $macref;
    my $actref;
    my $chkref;

    if ( ( defined $hostname ) and ( not defined $mac ) ) {
        # this routine checks for mac and hostname args
        # and if hostname passed finds related mac entry
        # returns undef on error (e.g., unable to find hostname)
        $mac = &get_mac_by_hostname( $opts, $mac, $hostname );
        unless ( defined $mac ) {
            $opts->{LASTERROR} = "mac required \n";
            error $opts->{LASTERROR};
        }
    }

    $macref = &get_db_data( $opts, 'mac', $mac );
    unless ( defined $macref ) {
        &add_db_mac( $opts, $mac, BA_ADMIN_ADDED );
        $macref = &get_db_data( $opts, 'mac', $mac );
    }
    if ( $opts->{debug} > 1 ) {
        while ( my ($key, $val) = each %{$macref} ) {
            debug "mac $key => " . $val eq "" ? "" : $val . "\n";
        }
    }

    $chkref = &get_db_data( $opts, 'action', $mac );
    if ( defined $chkref ) {
        if ( $opts->{debug} > 1 ) {
            while ( my ($key, $val) = each %{$chkref} ) {
                debug "check $key => " . $val eq "" ? "" : $val . "\n";
            }
        }
        # store a copy of the ref found for modification
        $actref = $chkref;
    } else {
        # for creation of entry with enable/disable
        $actref->{oper}    = BA_ADMIN_ADDED;
        $actref->{pxecurr} = BA_ACTION_NONE;
        $actref->{pxenext} = BA_ACTION_INVENTORY;
    }
 
    my $admin = $command eq "enable" ? BA_ADMIN_ENABLED : BA_ADMIN_DISABLED;

    if ( defined $chkref and $chkref->{admin} eq $admin ) {
        $opts->{LASTERROR} = "device admin state already $baState{ $admin }\n";
        return 1;
    }
#    $actref->{cmdline} = $cmdline;
    $actref->{cmdline} = "double zonkers";

    my $state   = $command eq "enable" ? "ready" : "disabled";
    my $enabled = $command eq "enable" ? 1 : 0;  # tftp state is bool

    &admin_state_change( $opts, $admin, $macref, $actref );
    &update_db_mac_state( $opts, $mac, $admin );
    &update_db_data( $opts, 'action', $actref );

    if ( $opts->{verbose} ) {
        debug "State of %s host entry and related files now %s.\n",
            $hostname ne "" ? $hostname : $mac, $baState{ $admin };
    }

    $returnHash{mac}      = $mac;
    $returnHash{hostname} = $hostname;
    $returnHash{action}   = $command;
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


1;
