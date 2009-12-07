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
       subs => [ qw(
        get_inventory
        do_localboot
        get_distro
        get_hardware
        get_tftpfile
        delete_tftpfile
        get_build
         ) ]
       );
  Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';


sub get_inventory() {
    my $cgi   = shift;
    my $baVar = shift;
    my $input = shift;
    my $output = qq|DEFAULT register
PROMPT 0
TIMEOUT 0

LABEL register
        kernel http://$baVar->{serverip}/ba/linux.baracus
        append initrd=http://$baVar->{serverip}/ba/initrd.baracus install=exec:/usr/bin/baracus.register textmode=1 baracus=$baVar->{serverip} mac=$input->{mac}
|;

    print $cgi->header( -type => "text/plain", -content_length => length ($output)), $output;
    exit 0;
}

sub do_localboot() {
    my $cgi = shift;
    my $output = q|DEFAULT localboot
PROMPT 0
TIMEOUT 0

LABEL localboot
        localboot 0
|;

    print $cgi->header( -type => "text/plain", -content_length => length ($output)), $output;
    exit 0;
}

sub get_distro() {
    my $dbh = shift;
    my $bref = shift;

    my $sql = qq|SELECT * FROM distro_cfg WHERE distroid = '$bref->{distroid}'|;
    my $sth;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute(  ) );

    return $sth->fetchrow_hashref( );
}

sub get_hardware() {
    my $dbh = shift;
    my $bref = shift;

    my $sql = qq|SELECT * FROM hardware_cfg WHERE hardwareid = '$bref->{hardwareid}'|;
    my $sth;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref( );
}

sub get_tftpfile() {
    my $tftph = shift;
    my $filename = shift;

    my $sql = qq|SELECT COUNT(id) as count, name FROM sqlfstable WHERE name = '$filename' GROUP BY name|;
    my $sth;

    die "$!\n$tftph->errstr" unless ( $sth = $tftph->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref( );
}

sub delete_tftpfile() {
    my $tftph = shift;
    my $filename = shift;

    my $sql = qq|DELETE FROM sqlfstable WHERE name = '$filename'|;
    my $sth;

    die "$!\n$tftph->errstr" unless ( $sth = $tftph->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    $sth->finish();
}

sub get_build() {
    my $dbh = shift;
    my $input = shift;

    my $sql = qq|SELECT * FROM build WHERE mac = '$input->{mac}'|;
    my $sth;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref( );
}


1;

__END__


=head1 AUTHOR

David Bahi, E<lt>dbahi@novellE<gt>

=cut
