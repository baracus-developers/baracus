package Baracus::Host;

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
use strict;
use warnings;

use Dancer qw( :syntax);
use Dancer::Plugin::Database;

use Baracus::Sql    qw( :vars :subs );
use Baracus::State  qw( :vars :admin );
use Baracus::Core   qw( :vars :subs );
use Baracus::Config qw( :vars :subs );
use Baracus::Aux    qw( :subs );

=pod

=head1 NAME

B<Baracus::Host> - subroutines for managing Baracus host macs and templates

=head1 SYNOPSIS

Another collection of routines used in Baracus

=cut

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
                get_mac_by_hostname
                add_db_mac
                check_host_action
                check_add_db_mac
                update_db_mac_state
                add_action_autobuild
                add_action_modules
                get_action_modules_hash
                db_list_start
                db_list_next
                db_list_finish
            )],
         );
    Exporter::export_ok_tags('subs');
}

our $VERSION = '2.01';

# this routine checks for mac and hostname args
# and if hostname passed finds related mac entry
# returns undef on error (e.g., unable to find hostname)

sub get_mac_by_hostname
{
    my $opts   = shift;
    my $type   = shift;
    my $nodeid = shift;

    my $mac;
    my $mref;
    my $href;

    if ( $type eq "mac" ) {
        $nodeid =  &check_mac( $nodeid );
        $mref = &get_db_data_by( $opts, 'host', $nodeid, 'mac' );
        if ( $nodeid ne $href->{mac} ) {
            $opts->{LASTERROR} = "Hostname already bound to $href->{mac}\n";
            error $opts->{LASTERROR};
        } else {
            $mac = $nodeid;
        }
    } elsif ( $type eq "host" ) {
        if ( &check_hostname ( $nodeid ) ) {
            $opts->{LASTERROR} = "Need DNS formatted hostname, without domain.\n";
            error $opts->{LASTERROR};
        }

        $href = &get_db_data( $opts, 'host', $nodeid );
        if ( defined $href ) {
            $mac = $href->{mac};
        } else {
            error "host id not found";
            send_error("host id not found", 406);
        }
    }

    if ( defined $mref ) {
        # mac found in host table
        if ( $nodeid ne "" and
             $mref->{hostname} ne "" and
             $nodeid ne $mref->{hostname} ) {
            # mac and hostname passed
            # but hostname passed differes from hostname in table
            $opts->{LASTERROR} = "MAC already bound to $mref->{hostname}\n";
            error $opts->{LASTERROR};
        }
    }

    return $mac;
}

sub check_host_action
{
    my $opts   = shift;
    my $eref   = shift;
    my $chkref = shift;
    my $actref = shift;

    unless ( defined $eref->{mac} ) {
        $eref->{mac} = &get_mac_by_hostname( $opts,
                                             'host',
                                             $eref->{hostname} );
        # $opts->{LASTERROR} set in subroutine
        return 1 unless ( defined $eref->{mac} );
    }

    # hosts <=> mac relations checked in get_mac_by_hostname above
    # now get any existing action db entry

    # lookup by MAC
    $chkref = &get_db_data( $opts, 'action', $eref->{mac} );
    if ( defined $chkref
         and defined $eref->{hostname}
         and defined $chkref->{hostname}
         and $eref->{hostname} ne ''
         and $eref->{hostname} ne $chkref->{hostname} ) {
        $opts->{LASTERROR} = "Attempt to create entry for $eref->{hostname} with mac identical to existing 'action' entry $chkref->{hostname}\n";
        error $opts->{LASTERROR};
    }
    if ( $eref->{hostname} ne '' ) {
        # lookup by hostname
        $actref = get_db_data_by( $opts, 'action', $eref->{hostname}, 'hostname' );
        if ( defined $actref
             and defined $actref->{mac}
             and $eref->{mac} ne $actref->{mac} ) {
            $opts->{LASTERROR} = "Attempt to create entry for $eref->{mac} with hostname identical to existing 'action' entry $actref->{mac}\n";
            error $opts->{LASTERROR};
        }
    } else {
        # require hostname here or from entry
        if ( $eref->{hostname} eq ""
             and defined $chkref
             and $chkref->{hostname} ne "" ) {
            $eref->{hostname} = $chkref->{hostname};
        } else {
            $opts->{LASTERROR} = "Missing  --hostname\n";
            error $opts->{LASTERROR};
        }
    }

    return 0;
}

sub check_add_db_mac
{
    my $opts   = shift;
    my $macref = shift;
    my $mac    = shift;

    $macref = get_db_data( $opts, 'mac', $mac );
    unless ( defined $macref ) {
        &add_db_mac( $opts, $mac, BA_ADMIN_ADDED );
        $macref = get_db_data( $opts, 'mac', $mac );
    }
    return $macref;
}


# These _db_ entry routines collect the host template db table interface

###########################################################################
##
## MAC relation - for macaddr and global state (admin, actions, events) hist

sub add_db_mac
{
    my $opts    = shift;
    my $mac     = shift;
    my $state   = shift;
    my $macref  = {};

    $macref->{mac} = $mac;
    $macref->{state} = $state;
    $macref->{$baState{ $state }} = "now()";
    &add_db_data( $opts, 'mac', $macref );
}

sub update_db_mac_state
{
    my $opts    = shift;
    my $mac     = shift;
    my $state   = shift;
    my $macref  = {};

    $macref->{mac} = $mac;
    $macref->{state} = $state;
    $macref->{$baState{ $state }} = "now()";
    &update_db_data( $opts, 'mac', $macref );
}

###########################################################################
##
## HOST
##   relation - for mac, host, and at somepoint either the info in hardware
##   or at a minimum the hardware id for what the box is.

sub add_action_autobuild
{
    my $opts = shift;
    my $href = shift;
    my %Hash = %{$href};

    my $sql;
    my $sth;

    eval {
        my $fields = lc get_cols( $baTbls{ actabld } );
        $fields =~ s/[ \t]*//g;
        my @fields;
        foreach my $field ( split( /,/, $fields ) ) {
            next if ( $field eq "creation" ); # not in this tbl but doesn't hurt
            next if ( $field eq "change"   ); # in case we decide to add them...
            push @fields, $field;
        }
        $fields = join(', ', @fields);
        my $values = join(', ', (map { database->quote($_) } @Hash{@fields}));

        $sql = qq|INSERT INTO $baTbls{ actabld } ( $fields ) VALUES ( $values )|;
        $sth = database->prepare( $sql );
        $sth->execute();
        $sth->finish;
        undef $sth;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }
}

sub add_action_modules
{
    my $opts  = shift;
    my $href = shift;
    my %Hash = %{$href};

    my $sql;
    my $sth;

    eval {
        my $fields = lc get_cols( $baTbls{ actmod } );
        $fields =~ s/[ \t]*//g;
        my @fields;
        foreach my $field ( split( /,/, $fields ) ) {
            next if ( $field eq "creation" ); # not in this tbl but doesn't hurt
            next if ( $field eq "change"   ); # in case we decide to add them...
            push @fields, $field;
        }
        $fields = join(', ', @fields);
        my $values = join(', ', (map { database->quote($_) } @Hash{@fields}));

        $sql = qq|INSERT INTO $baTbls{ actmod } ( $fields ) VALUES ( $values )|;
        $sth = database->prepare( $sql );
        $sth->execute();
        $sth->finish;
        undef $sth;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }
}

sub get_action_modules_hash
{
    my $opts = shift;
    my $mac = shift;

    my $sql = qq|SELECT * FROM $baTbls{ actmod } WHERE mac = '$mac' |;
    my $sth;
    my %modules;

    eval {
        $sth = database->prepare( $sql );
        $sth->execute;

        while ( my $href = $sth->fetchrow_hashref() ) {
            $modules{ $href->{module} }= $href->{module_ver};
        }

        $sth->finish;
        undef $sth;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    return \%modules;
}

sub db_list_start
{
    my $opts   = shift;
    my $type   = shift;
    my $filter = shift;

    my $sql;
    my $sth;
    my $fkey;

    if ( $filter eq "" ) {
        $fkey = "mac";
        $filter = "%";
    } else {
        if ( $filter =~ m/::/ ) {
            ( $fkey, $filter ) = split ( /::/, $filter, 2 );
        } else {
            $fkey = "mac";
        }
        if ( $filter =~ m{\*|\?} ) {
            $filter =~ s|\*|%|g;
            $filter =~ s|\?|_|g;
        }
    }

    unless ( $fkey eq "mac" or $fkey eq "hostname" ) {
        error "Filter key not valid.\n";
    }

    debug "db_list_start key: $fkey filter: $filter\n";

    if ( $type eq "templates" ) {

        $sql = qq|SELECT hostname, action.mac AS mac, action_autobuild.autobuild AS autobuild
                  FROM $baTbls{'action'} LEFT OUTER JOIN $baTbls{actabld}
                  ON ( action.mac = action_autobuild.mac )
                  WHERE action.$fkey LIKE ? |;

    } elsif ( $type eq "states" ) {

        $fkey= "action.$fkey";

        my $maccols = lc get_cols( $baTbls{'mac'} );
        $maccols = join "mac.", (split('\s', $maccols));

        $sql = qq|SELECT
                $maccols,
                action.pxecurr,
                action.pxenext,
                action.admin,
                action.oper,
                action.hostname
                FROM mac
                LEFT OUTER JOIN action
                ON mac.mac = action.mac
                WHERE $fkey LIKE ?
                ORDER BY $fkey |;
    } elsif ( $type eq "nodes" ) {

        $fkey= "action.$fkey";

        my $maccols = lc get_cols( $baTbls{'mac'} );
        $maccols = join "mac.", (split('\s', $maccols));

        $sql = qq|SELECT
                  $maccols,
                  action.hostname,
                  action.admin
                  FROM mac
                  LEFT OUTER JOIN action
                  ON mac.mac = action.mac
                  WHERE $fkey LIKE ?
                  ORDER BY $fkey |;

    } elsif ( $type eq "node" ) {

        $sql = qq|SELECT *
                  FROM $baTbls{'action'} 
                  WHERE mac LIKE ?|;

    }

    eval {
        $sth = database->prepare( $sql );
        $sth->execute( $filter );
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    return $sth;
}

sub db_list_next
{
    my $sth = shift;
    my $href;

    $href = $sth->fetchrow_hashref();

    unless ( defined $href ) {
        &list_finish_data( $sth );
    }

    return $href;
}

sub db_list_finish
{
    my $sth = shift;
    $sth->finish;
    undef $sth;
}


1;

__END__

=head1 AUTHOR

Daniel Westervelt, E<lt>dwestervelt@novellE<gt>
David Bahi, E<lt>dbahi@novellE<gt>

=cut
