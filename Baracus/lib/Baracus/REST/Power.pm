package Baracus::REST::Power;

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
use Baracus::Core   qw( :vars :subs );
use Baracus::Config qw( :vars :subs );
use Baracus::State  qw( :vars :admin );
use Baracus::Source qw( :vars :subs );
use Baracus::Host   qw( :subs );
use Baracus::Power  qw( :subs );
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
                power_off
                power_on
                power_cycle
                power_status
                power_remove
                power_add
                power_list
         )],
         );

    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

###########################################################################
##
## Main power REST Subroutines (off/on/cycle/status/remove/add/list)

sub power_off() {

    my $command = "off";
    my $node    = params->{node};

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

    my $bmcref = &get_bmc( $opts, 'mac', $mac );
    unless ( $bmcref ) {
        $opts->{LASTERROR} = "Unable to find entry for device with id: $mac\n";
        error $opts->{LASTERROR};
    }

    my $result = &poff( $bmcref );

    my %returnHash;
    $returnHash{mac}      = $bmcref->{mac}      if ( defined $bmcref->{mac} );
    $returnHash{hostname} = $bmcref->{hostname} if ( defined $bmcref->{hostname} );
    $returnHash{action}   = $command;
    $returnHash{result}   = $result;

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub power_on() {

    my $command = "on";
    my $node    = params->{node};

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

    my $bmcref = &get_bmc( $opts, 'mac', $mac );
    unless ( $bmcref ) {
        $opts->{LASTERROR} = "Unable to find entry for device with id: $mac\n";
        error $opts->{LASTERROR};
    }

    my $result = &pon( $bmcref );

    my %returnHash;
    $returnHash{mac}      = $bmcref->{mac}      if ( defined $bmcref->{mac} );
    $returnHash{hostname} = $bmcref->{hostname} if ( defined $bmcref->{hostname} );
    $returnHash{action}   = $command;
    $returnHash{result}   = $result;

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub power_cycle() {

    my $command = "cycle";
    my $node    = params->{node};

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

    my $bmcref = &get_bmc( $opts, 'mac', $mac );
    unless ( $bmcref ) {
        $opts->{LASTERROR} = "Unable to find entry for device with id: $mac\n";
        error $opts->{LASTERROR};
    }

    my $result = &pcycle( $bmcref );

    my %returnHash;
    $returnHash{mac}      = $bmcref->{mac}      if ( defined $bmcref->{mac} );
    $returnHash{hostname} = $bmcref->{hostname} if ( defined $bmcref->{hostname} );
    $returnHash{action}   = $command;
    $returnHash{result}   = $result;

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub power_status() {

    my $command = "status";
    my $node    = params->{node};

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

    my $bmcref = &get_bmc( $opts, 'mac', $mac );
    unless ( $bmcref ) {
        $opts->{LASTERROR} = "Unable to find entry for device with id: $mac\n";
        error $opts->{LASTERROR};
    }

    my $result = &pstatus( $bmcref );

    my %returnHash;
    $returnHash{mac}      = $bmcref->{mac}      if ( defined $bmcref->{mac} );
    $returnHash{hostname} = $bmcref->{hostname} if ( defined $bmcref->{hostname} );
    $returnHash{action}   = $command;
    $returnHash{result}   = $result;

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub power_remove() {

    my $command = "remove";
    my $node    = params->{node};

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

    my $bmcref = &get_bmc( $opts, 'mac', $mac );
    unless ( $bmcref ) {
        $opts->{LASTERROR} = "Unable to find entry for device with id: $mac\n";
        error $opts->{LASTERROR};
    }

    my $result = &premove( $opts, $bmcref );

    my %returnHash;
    $returnHash{mac}      = $bmcref->{mac}      if ( defined $bmcref->{mac} );
    $returnHash{hostname} = $bmcref->{hostname} if ( defined $bmcref->{hostname} );
    $returnHash{action}   = $command;
    $returnHash{result}   = $result;

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub power_add() {

    my $command = "add";
    my $bmcref = {};
    $bmcref->{mac}      = params->{mac}      if ( defined params->{mac} );
    $bmcref->{hostname} = params->{hostname} if ( defined params->{hostname} );
    $bmcref->{ctype}    = params->{ctype}    if ( defined params->{ctype} );
    $bmcref->{login}    = params->{login}    if ( defined params->{login} );
    $bmcref->{passwd}   = params->{passwd}   if ( defined params->{passwd} );
    $bmcref->{bmcaddr}  = params->{bmcaddr}  if ( defined params->{bmcaddr} );
    $bmcref->{node}     = params->{node}     if ( defined params->{node} );
    $bmcref->{other}    = params->{other}    if ( defined params->{other} );
    ## Need to add better arg checking to make sure we get enough info to add

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $result = &padd( $opts, $bmcref );

    my %returnHash;
    $returnHash{mac}      = $bmcref->{mac}      if ( defined $bmcref->{mac} );
    $returnHash{hostname} = $bmcref->{hostname} if ( defined $bmcref->{hostname} );
    $returnHash{action}   = $command;
    $returnHash{result}   = $result;

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub power_list() {

    my $command = "list";
    my $filter  = params->{filter};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    unless ( defined $filter ) {
        $filter = "all";
    }

    my %returnHash;
    my $sth = &list_start_data( $opts, 'power', $filter );
    my $dbref;
    while ( $dbref = &list_next_data( $sth ) ) {
        my $macid = $dbref->{mac};
        $macid =~ s/://g;
        $returnHash{$macid}{mac}      = $dbref->{mac};
        $returnHash{$macid}{hostname} = $dbref->{hostname};
        $returnHash{$macid}{ctype}    = $dbref->{ctype};
        $returnHash{$macid}{bmcaddr}  = $dbref->{bmcaddr};
        $returnHash{$macid}{node}     = $dbref->{node};
        $returnHash{$macid}{other}    = $dbref->{other};
    }

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
