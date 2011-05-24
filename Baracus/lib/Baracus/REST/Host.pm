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

use Baracus::DB;
use Baracus::SqlFS;
use Baracus::Sql    qw( :subs :vars );
use Baracus::Host   qw( :subs );
use Baracus::Core   qw( :subs );
use Baracus::Config qw( :vars :subs );
use Baracus::State  qw( :vars :subs :admin );
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
                host_add
                host_remove
                host_enable
                host_disable
         )],
         );

    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

#my $baXML = &baxml_load( $opts, "$baDir{'data'}/badistro.xml" );
#$opts->{baXML}    = $baXML;


###########################################################################
##
## Main Host REST Subroutines (list/detail/add/remove/enable/disable)

sub host_list() {

    my $command    = "list";
    my $subcommand = params->{listtype};
    my $filter     = params->{filter};
    unless ( defined $filter ) {  $filter = ""; }

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $returnList = "";
    my %returnHash;

    $subcommand = lc $subcommand;

    my $sth = &db_list_start( $opts, $subcommand, $filter );

    unless( defined $sth ) {
     #   return 1;
    }

    my $dbref;

    if ( $subcommand eq "templates" ) {
        ## List build templates associated with nodes
        ##
        while ( $dbref = &db_list_next( $sth ) ) {
            my $name;
            my $auto = "none";

            $name = $dbref->{'hostname'}  if ( defined $dbref->{'hostname'} );
            $auto = $dbref->{'autobuild'} if ( defined $dbref->{'autobuild'} );
            $returnList .= "$dbref->{mac} $name $auto <br>";
            $returnHash{$dbref->{mac}}{name} = $name;
            $returnHash{$dbref->{mac}}{auto} = $auto;
        }
    }
    elsif ( $subcommand eq "states" ) {
        ## List macs and show state and when time of that state
        ##
        while ( $dbref = &db_list_next( $sth ) ) {

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
            $returnList .= "$dbref->{ $state_str } $dbref->{'mac'} $hostname $pxecurr_str $pxenext_str $state_str $active_str <br>";
            $returnHash{$dbref->{mac}}{hostname} = $hostname;
            $returnHash{$dbref->{mac}}{pxecurr_str} = $pxecurr_str;
            $returnHash{$dbref->{mac}}{pxenext_str} = $pxenext_str;
            $returnHash{$dbref->{mac}}{state_str} = $state_str;
            $returnHash{$dbref->{mac}}{active_str} = $active_str;
        }
    }
    elsif ( $subcommand eq "nodes" ) {
        ## List macs and show nodes
        ##
        my $inventory = "";
        my $inventory_st = "";
        my $sel;
        my $bstate;

        while ( $dbref = &db_list_next( $sth ) ) {
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
                $returnList .= "$dbref->{'mac'} $dbref->{hostname} $inventory $inventory_st $bstate <br>";
                $returnHash{$dbref->{mac}}{hostname} = $dbref->{hostname};
                $returnHash{$dbref->{mac}}{inventory} = $inventory;
                $returnHash{$dbref->{mac}}{inventory_st} = $inventory_st;
                $returnHash{$dbref->{mac}}{bstate} = $bstate;
        }
    }
    &db_list_finish( $sth );

    if ( request->{accept} =~ m|text/html| ) {
        return $returnList;
    } elsif ( ( request->{accept} eq 'text/xml' ) or ( request->{accept} eq 'application/json' ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub host_detail() {

}

sub host_add() {

    my $command  = "list";
    my $mac      = params->{mac};
    my $hostname = params->{hostname};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $hostref;
    my $macref;
    my $actref;
    my $chkref;

    my $returnList = "";
    my %returnHash;

     # this routine checks for mac and hostname args
    # and if hostname passed finds related mac entry
    # returns undef on error (e.g., unable to find hostname)
    $mac = &get_mac_by_hostname( $opts, $mac, $hostname );
    unless ( defined $mac ) {
        $opts->{LASTERROR} = "mac required";
        error $opts->{LASTERROR};
    }

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

#    $actref->{cmdline} = $cmdline;
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

    if ( request->{accept} =~ m|text/html| ) {
            return "Added $mac<br>";
    } elsif ( ( request->{accept} eq 'text/xml' ) or ( request->{accept} eq 'application/json' ) ) {
        my @returnArray = ("Added", "$mac");
        return \@returnArray;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub host_remove() {

}

sub host_enable() {

}

sub host_disable() {

}

1;
