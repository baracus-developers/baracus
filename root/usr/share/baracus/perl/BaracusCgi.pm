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
        add_mac
        get_mac
        update_mac_state
        get_build
        get_templateid
        get_templateid_by_mac
        update_templateid_state
        update_templateid_pxestate
        check_ip
        check_mac
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

sub add_mac() {
    my $dbh = shift;
    my $input = shift;
    my $statestr = shift;
    my $state = shift;

    my $fields = "mac,state,$statestr";
    my $values = qq|'$input->{mac}',$state,CURRENT_TIMESTAMP(0)|;
    my $sql = qq|INSERT INTO mac ( $fields ) VALUES ( $values )|;
    my $sth;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    $sth->finish();
}

sub get_mac() {
    my $dbh = shift;
    my $input = shift;

    my $sql = qq|SELECT * FROM mac WHERE mac = '$input->{mac}' |;
    my $sth;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref( );
}

sub update_mac_state() {
    my $dbh = shift;
    my $input = shift;
    my $statestr = shift;
    my $state = shift;

    my $fields = "state,$statestr";
    my $values = qq|'$state',CURRENT_TIMESTAMP(0)|;
    my $sql = qq|UPDATE mac SET ( $fields ) = ( $values ) WHERE mac = '$input->{mac}'|;
    my $sth;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
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

sub get_templateid() {
    my $dbh = shift;
    my $bref = shift;

    my $sql = qq|SELECT * FROM templateid WHERE hostname = '$bref->{hostname}'|;
    my $sth;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref( );
}

sub get_templateid_by_mac() {
    my $dbh = shift;
    my $input = shift;

    my $sql = qq|SELECT * FROM templateid WHERE mac = '$input->{mac}'|;
    my $sth;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref( );
}

sub update_templateid_state() {
    my $dbh = shift;
    my $input = shift;
    my $state = shift;

    my $fields = "state,change";
    my $values = qq|'$state',CURRENT_TIMESTAMP(0)|;
    my $sql = qq|UPDATE templateid SET ($fields) = ($values) WHERE mac = '$input->{mac}'|;
    my $sth;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    $sth->finish();
}

sub update_templateid_pxestate() {
    my $dbh = shift;
    my $hostref = shift;

    my $fields = "pxestate,change";
    my $values = qq|'$hostref->{pxestate}',CURRENT_TIMESTAMP(0)|;
    my $sql = qq|UPDATE templateid SET ($fields) = ($values) WHERE hostname = '$hostref->{hostname}'|;
    my $sth;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    $sth->finish();
}

sub check_ip
{
    my $ip = shift;

    # check for ip format or 'dhcp' string
    if ( $ip =~ m/(\d+).(\d+).(\d+).(\d+)/ ) {
        # check for valid ip address range values
        if ( ( $1 < 1 or $1 > 254 or $1 == 127 ) ||
             ( $2 < 0 or $2 > 254 ) ||
             ( $3 < 0 or $3 > 254 ) ||
             ( $4 < 1 or $4 > 254 ) ) {
            print "Invalid IP address value given: $ip\n";
            exit 1;
        }
    } elsif ( $ip ne "dhcp" ) {
        print "Invalid IPv4 address format or missing 'dhcp' string.\n";
        exit 1;
    }
}

sub check_mac
{
    my $mac = shift;

    $mac = uc $mac;
    $mac =~ s|[-.]|:|g;
    # check for mac format - normalize to %02X: format
    unless ( $mac =~ m|([0-9A-F]{1,2}:?){6}| ) {
        print "Invalid MAC address format or value string.\n";
        exit 1;
    }
    $mac =~ m|([0-9A-F]{1,2}):([0-9A-F]{1,2}):([0-9A-F]{1,2}):([0-9A-F]{1,2}):([0-9A-F]{1,2}):([0-9A-F]{1,2})|;
    $mac = sprintf "%02s:%02s:%02s:%02s:%02s:%02s",$1,$2,$3,$4,$5,$6 ;
}



1;

__END__


=head1 AUTHOR

David Bahi, E<lt>dbahi@novellE<gt>

=cut
