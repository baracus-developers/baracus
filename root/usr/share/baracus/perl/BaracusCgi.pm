package BaracusCgi;

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

=head1 NAME

BaracusCgi - subroutines of use

=head1 SYNOPSIS

A collection of routines used in the baracus cgi

=cut

BEGIN {
  use Exporter ();
  use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
  @ISA         = qw(Exporter);
  @EXPORT      = qw();
  @EXPORT_OK   = qw();
  %EXPORT_TAGS =
      (
       subs =>
       [qw(
              get_inventory
              do_localboot
              do_pxewait
              do_netboot
              do_rescue
          )]
       );
  Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';


sub get_inventory() {
    my $cgi   = shift;
    my $baVar = shift;
    my $input = shift;
    my $args  = shift;
    $args = "" unless ( defined $args );
    my $output = qq|DEFAULT register
PROMPT 0
TIMEOUT 0

LABEL register
        kernel http://$baVar->{serverip}/ba/linux.baracus
        append initrd=http://$baVar->{serverip}/ba/initrd.baracus install=exec:/usr/bin/baracus.register textmode=1 baracus=$baVar->{serverip} mac=$input->{mac} $args |;

    print $cgi->header( -type => "text/plain", -content_length => length ($output)), $output;
    exit 0;
}

sub do_localboot() {
    my $cgi = shift;
    my $actref = shift;
    my $serverip = shift;
    my $output = qq|DEFAULT localboot
PROMPT 0
TIMEOUT 0

LABEL localboot
    kernel http://$serverip/ba/chain.c32
    append hd$actref->{disk} $actref->{partition}
|;

    print $cgi->header( -type => "text/plain", -content_length => length ($output)), $output;
    exit 0;
}

# without the timeout it should wait indefinitely
sub do_pxewait() {
    my $cgi = shift;
    my $output = qq|DEFAULT pxewait
PROMPT 1
LABEL pxewait
        localboot 0
|;

    print $cgi->header( -type => "text/plain", -content_length => length ($output)), $output;
    exit 0;
}

sub do_netboot() {
    my $cgi = shift;
    my $actref = shift;
    my $serverip = shift;
    my $output = qq|DEFAULT netboot

PROMPT 0
TIMEOUT 0
LABEL netboot
    kernel http://$serverip/ba/sanboot.c32
    append iscsi:$actref->{netbootip}::::$actref->{netboot}
|;

    print $cgi->header( -type => "text/plain", -content_length => length ($output)), $output;
    exit 0;
}

sub do_rescue() {
    my $cgi = shift;
    my $mac = shift;
    my $serverip = shift;
    my $args = shift;
    my $output = qq|DEFAULT rescue

PROMPT 0
TIMEOUT 0
LABEL rescue
    kernel http://${serverip}/ba/linux?mac=${mac}
    append initrd=http://${serverip}/ba/initrd?mac=${mac} $args
|;

    print $cgi->header( -type => "text/plain", -content_length => length ($output)), $output;
    exit 0;
}


1;

__END__


=head1 AUTHOR

David Bahi, E<lt>dbahi@novellE<gt>

=cut
