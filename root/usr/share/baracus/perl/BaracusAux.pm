package BaracusAux;

use 5.006;
use Carp;
use strict;
use warnings;

=pod

=head1 NAME

B<BaracusAux> - data generators and entry validation and manipulation

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
                get_uuid
                get_rundate
                check_ip
                check_mac
                macback
                bootmac
                automac
            )],
         );
    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';


# aux info routines

sub get_uuid() {

    ## Generate a new UUID
    ##
    use Data::UUID;

    my $ug = new Data::UUID;

    return $ug->to_string( $ug->create() );
}

sub get_rundate() {
    use POSIX qw/strftime/;

    ## Generate timestamp for run
    ##
    my $now = time;
    my $rundate=strftime "%Y-%m-%d %H:%M:%S", localtime($now);
    return $rundate;

}


# data validation routines

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
            croak "Invalid IP address value given: $ip\n";
        }
    } elsif ( $ip ne "dhcp" ) {
        croak "Invalid IPv4 address format or missing 'dhcp' string.\n";
    }
}

sub check_mac
{
    my $mac = shift;

    $mac = uc $mac;
    $mac =~ s|[-.]|:|g;
    # check for mac format - normalize to %02X: format
    unless ( $mac =~ m|([0-9A-F]{1,2}:){5}[0-9A-F]{1,2}| ) {
        croak "Invalid MAC address format or value string.\n";
    }
    $mac =~ m|([0-9A-F]{1,2}):([0-9A-F]{1,2}):([0-9A-F]{1,2}):([0-9A-F]{1,2}):([0-9A-F]{1,2}):([0-9A-F]{1,2})|;
    $mac = sprintf "%02s:%02s:%02s:%02s:%02s:%02s",$1,$2,$3,$4,$5,$6 ;
    return $mac;
}


# mac manipulations

sub macback {
    # get mac back from tftp file name
    &_boot_auto_mac_( "tftp", @_ );
}
sub bootmac {
    &_boot_auto_mac_( "boot", @_ );
}
sub automac {
    &_boot_auto_mac_( "auto", @_ );
}
sub _boot_auto_mac_ {
    my $type = shift;
    my $mac  = shift;

    if ( $type eq "tftp" ) {
        $mac =~ s|^0\d-||;
        $mac =~ s|-|:|g;
    }
    else {
        $mac =~ s|:|-|g;
        if ($type eq "boot") {
            $mac = "01-" . $mac;
        } elsif ($type eq "auto") {
            $mac = "02-" . $mac;
        }
    }
    return $mac;
}

1;

__END__
