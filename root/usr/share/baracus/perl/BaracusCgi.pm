package BaracusCgi;

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
    my $output = qq|DEFAULT localboot
PROMPT 0
TIMEOUT 0

LABEL localboot
        localboot 0
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
    kernel http://$serverip/baracus/sanboot.c32
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
