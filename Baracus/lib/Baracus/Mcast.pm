package Baracus::Mcast;

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

use Dancer qw( :syntax );
use Dancer::Plugin::Database;

use Baracus::Sql   qw( :subs :vars );
use Baracus::State qw( :vars );
use Baracus::Core  qw( :subs );
use Baracus::Config qw( :vars );
use Baracus::Aux   qw( :subs );

=pod

=head1 NAME

B<Baracus::Mcast> - subroutines for managing multicat channels

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
                get_free_mcast_port
                start_mchannel
                stop_mchannel
                bamstart
                bamstop
            )],
         );
    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

my $tbl = 'mcast';

# Subs

#
# get_free_mcast_port ( $opts, 
#

sub get_free_mcast_port
{
    my $opts = shift;
    my $tbl  = shift;

    my $sth = &list_start_data ( $opts, $tbl, "" );

    my $port = "9000";
    my $dbref;
    while ( $dbref = &list_next_data( $sth )  ) {
        if ( $dbref->{port} > $port ) {
            $port = $dbref->{port};
        }
    }
    $port = $port + 2;

    return $port;
}

#
# start_mchannel( $opts, $mcastid )
#

sub start_mchannel
{
    my $opts    = shift;
    my $mcastid = shift;

    my $udpsender = qx|which udp-sender| or die ("Can't find udp-sender : ".$!);
    chomp $udpsender;

    unless ( -e "$udpsender" ) {
        print "error: udpcast package missing\n";
        exit 1;
    }

    my $mcastref = &get_db_data( $opts, $tbl, $mcastid );
    # get storage hash to supply image filename
    my $imgref = &get_db_data( $opts, 'storage', $mcastref->{storageid} );

    # exec the udp-sender
    #
    # example raw cmdline: 
    #
    # udp-sender --file ~baracus/images/Baracus_SLES_11_SP1.x86_64-1.7.2.raw.gz --min-receivers=2 \
    #            --full-duplex --mcast-data-address=224.0.0.14 --mcast-rdv-address=224.0.0.13     \
    #            --interface=br0 --max-bitrate=25M --daemon --nokbd &
    #
    my $pid = fork();
        die "unable to fork: $!" unless defined($pid);
    if ( not defined $pid ) {
        warn "resource not available \n";
    } elsif ( $pid == 0 ) {
        open STDERR, '>', '/dev/null' or die "Cannot open STDERR\n";
        exec("sudo", "$udpsender", "--file=$baDir{images}/$imgref->{storage}", "--min-receivers=$mcastref->{mrecv}", "--full-duplex",
                           "--mcast-data-address=$mcastref->{dataip}", "--mcast-rdv-address=$mcastref->{rdvip}",
                           "--interface=$mcastref->{interface}", "--portbase=$mcastref->{port}",
                           "--max-bitrate=$mcastref->{ratemx}", "--daemon", "--nokbd");
        exit(0);
    }

    if ( defined $pid ) {
        return $pid;
    } else {
        print "unable to start mchannel\n";
        return 1;
    }
}

#
# stop_channel( $opts, 4mcastid )
#

sub stop_mchannel
{
    my $opts    = shift;
    my $mcastid = shift;

    my $mcastref = &get_db_data( $opts, $tbl, $mcastid ); 
    if ( defined $mcastref->{pid} ) {
        my $ret = `sudo kill $mcastref->{pid}`;
    } else {
        status '406';
        error "error stopping mcast channel id: $mcastid";
        return { code => "6", error => "error stopping mcast channel id: $mcastid" };
    }

    return 0;
}

sub bamstart
{
    my $opts = shift;

    my $sth = &list_start_data ( $opts, 'mcast', "*" );
    while ( my $dbref = &list_next_data( $sth ) ) {
        if ( $dbref->{status} ) {
            ## start the mchannel
            debug "Starting mchannel id: $dbref->{mcastid} \n";
            my $mcastref = &get_db_data( $opts, 'mcast', $dbref->{mcastid} );
            $mcastref->{pid} = &start_mchannel( $opts, $dbref->{mcastid} );
            &update_db_data( $opts, 'mcast', $mcastref);
        }
    }
}

sub bamstop
{
    my $opts = shift;

    my $sth = &list_start_data ( $opts, 'mcast', "*" );
    while ( my $dbref = &list_next_data( $sth ) ) {
        if ( $dbref->{status} ) {
            ## start the mchannel
            debug "Stopping mchannel id: $dbref->{mcastid} \n";
            my $ret = &stop_mchannel( $opts, $dbref->{mcastid} );
            if ( $ret == 1 ) {
                status '406';
                error "error stopping $dbref->{mcastid}";
                return { code => "6", error => "error stopping $dbref->{mcastid}" };
             }
        }
    }
}

1;

__END__

=head1 AUTHOR

Daniel Westervelt, E<lt>dwestervelt@novellE<gt>
David Bahi, E<lt>dbahi@novellE<gt>

=cut

