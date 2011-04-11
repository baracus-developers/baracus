package BaracusHost;

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

use lib "/usr/share/baracus/perl";

use BaracusSql   qw( :subs :vars );
use BaracusState qw( :vars :admin );
use BaracusCore  qw( :subs );
use BaracusAux   qw( :subs );

=pod

=head1 NAME

B<BaracusHost> - subroutines for managing Baracus host macs and templates

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
                add_db_mac
                get_mac_by_hostname
                check_host_action
                check_add_db_mac
                update_db_mac_state
                add_action_autobuild
                add_action_modules
                get_action_modules_hash
            )],
         );
    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';


# this routine checks for mac and hostname args
# and if hostname passed finds related mac entry
# returns undef on error (e.g., unable to find hostname)

sub get_mac_by_hostname
{
    my $opts     = shift;
    my $dbh      = shift;
    my $mac      = shift;
    my $hostname = shift;

    if ( $mac eq "" and  $hostname eq "" ) {
        $opts->{LASTERROR} = "Requires --mac or --hostname.\n";
        return undef;
    }

    my $mref;
    my $href;

    if ( $mac ne "" ) {
        $mac =  &check_mac( $mac );
        $mref = &get_db_data_by( $dbh, 'host', $mac, 'mac' );
    }
    if ( $hostname ne "" ) {
        if ( check_hostname ( $hostname ) ) {
            $opts->{LASTERROR} = "Need DNS formatted hostname, without domain.\n";
            return undef;
        }
        $href = &get_db_data( $dbh, 'host', $hostname );
    }

    if ( defined $mref ) {
        # mac found in host table
        if ( $hostname ne "" and
             $mref->{hostname} ne "" and
             $hostname ne $mref->{hostname} ) {
            # mac and hostname passed
            # but hostname passed differes from hostname in table
            $opts->{LASTERROR} = "MAC already bound to $mref->{hostname}\n";
            return undef;
        }
    }

    if ( defined $href ) {
        # hostname found in host table
        if ( $mac eq "" ) {

            # given hostname and no mac then here is where we get the mac
            # for all other actions.  entry for hostname passed was found

            $mac = $href->{mac};
        }
        elsif ( $mac ne $href->{mac} ) {
            # mac and hostname passed
            # but mac passed differs from mac in table
            $opts->{LASTERROR} = "Hostname already bound to $href->{mac}\n";
            return undef;
        }
    }
    else {
        # not defined $href
        if ( $mac eq "" ) {
            $opts->{LASTERROR } = "Unable to find hostname.  Try --mac\n";
            return undef;
        }
    }

    return $mac;
}

sub check_host_action
{
    my $opts   = shift;
    my $dbh    = shift;
    my $eref   = shift;
    my $chkref = shift;
    my $actref = shift;

    $eref->{mac} = &get_mac_by_hostname( $opts, $dbh,
                                         $eref->{mac},
                                         $eref->{hostname} );
    # $opts->{LASTERROR} set in subroutine
    return 1 unless ( defined $eref->{mac} );

    # hosts <=> mac relations checked in get_mac_by_hostname above
    # now get any existing action db entry

    # lookup by MAC
    $chkref = &get_db_data( $dbh, 'action', $eref->{mac} );
    if ( defined $chkref
         and defined $eref->{hostname}
         and defined $chkref->{hostname}
         and $eref->{hostname} ne ''
         and $eref->{hostname} ne $chkref->{hostname} ) {
        $opts->{LASTERROR} = "Attempt to create entry for $eref->{hostname} with mac identical to existing 'action' entry $chkref->{hostname}\n";
        return 1;
    }
    if ( $eref->{hostname} ne '' ) {
        # lookup by hostname
        $actref = get_db_data_by( $dbh, 'action', $eref->{hostname}, 'hostname' );
        if ( defined $actref
             and defined $actref->{mac}
             and $eref->{mac} ne $actref->{mac} ) {
            $opts->{LASTERROR} = "Attempt to create entry for $eref->{mac} with hostname identical to existing 'action' entry $actref->{mac}\n";
            return 1;
        }
    } else {
        # require hostname here or from entry
        if ( $eref->{hostname} eq ""
             and defined $chkref
             and $chkref->{hostname} ne "" ) {
            $eref->{hostname} = $chkref->{hostname};
        } else {
            $opts->{LASTERROR} = "Missing  --hostname\n";
            return 1;
        }
    }
    return 0;
}

sub check_add_db_mac
{
    my $opts   = shift;
    my $dbh    = shift;
    my $macref = shift;
    my $mac    = shift;

    $macref = get_db_data( $dbh, 'mac', $mac );
    unless ( defined $macref ) {
        &add_db_mac( $dbh, $mac, BA_ADMIN_ADDED );
        $macref = get_db_data( $dbh, 'mac', $mac );
    }
    return $macref;
}


# These _db_ entry routines collect the host template db table interface

###########################################################################
##
## MAC relation - for macaddr and global state (admin, actions, events) hist

sub add_db_mac
{
    my $dbh     = shift;
    my $mac     = shift;
    my $state   = shift;
    my $macref  = {};

    $macref->{mac} = $mac;
    $macref->{state} = $state;
    $macref->{$baState{ $state }} = "now()";
    &add_db_data( $dbh, 'mac', $macref );
}

sub update_db_mac_state
{
    my $dbh     = shift;
    my $mac     = shift;
    my $state   = shift;
    my $macref  = {};

    $macref->{mac} = $mac;
    $macref->{state} = $state;
    $macref->{$baState{ $state }} = "now()";
    &update_db_data( $dbh, 'mac', $macref );
}

###########################################################################
##
## HOST
##   relation - for mac, host, and at somepoint either the info in hardware
##   or at a minimum the hardware id for what the box is.

sub add_action_autobuild
{
    my $dbh  = shift;
    my $href = shift;
    my %Hash = %{$href};

    my $fields = lc get_cols( $baTbls{ actabld } );
    $fields =~ s/[ \t]*//g;
    my @fields;
    foreach my $field ( split( /,/, $fields ) ) {
        next if ( $field eq "creation" ); # not in this tbl but doesn't hurt
        next if ( $field eq "change"   ); # in case we decide to add them...
        push @fields, $field;
    }
    $fields = join(', ', @fields);
    my $values = join(', ', (map { $dbh->quote($_) } @Hash{@fields}));

    my $sql = qq|INSERT INTO $baTbls{ actabld } ( $fields ) VALUES ( $values )|;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish;
    undef $sth;
}

sub add_action_modules
{
    my $dbh  = shift;
    my $href = shift;
    my %Hash = %{$href};

    my $fields = lc get_cols( $baTbls{ actmod } );
    $fields =~ s/[ \t]*//g;
    my @fields;
    foreach my $field ( split( /,/, $fields ) ) {
        next if ( $field eq "creation" ); # not in this tbl but doesn't hurt
        next if ( $field eq "change"   ); # in case we decide to add them...
        push @fields, $field;
    }
    $fields = join(', ', @fields);
    my $values = join(', ', (map { $dbh->quote($_) } @Hash{@fields}));

    my $sql = qq|INSERT INTO $baTbls{ actmod } ( $fields ) VALUES ( $values )|;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish;
    undef $sth;
}

sub get_action_modules_hash
{
    my $dbh = shift;
    my $mac = shift;

    my $sql = qq|SELECT * FROM $baTbls{ actmod } WHERE mac = '$mac' |;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    my %modules;
    while ( my $href = $sth->fetchrow_hashref() ) {
        $modules{ $href->{module} }= $href->{module_ver};
    }
    return \%modules;
}


1;

__END__

=head1 AUTHOR

Daniel Westervelt, E<lt>dwestervelt@novellE<gt>
David Bahi, E<lt>dbahi@novellE<gt>

=cut
