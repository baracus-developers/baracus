package BaracusCore;

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

use Pod::Usage;

=pod

=head1 NAME

B<BaracusCore> - data generators and entry validation and manipulation

=head1 SYNOPSIS

Core collection of routines for Baracus

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
                main
                help
                man
                check_command
                get_uuid
                get_rundate
                check_ip
                check_mac
                check_hostname
                check_rootid
                macback
                bootmac
                automac
            )],
         );
    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';


sub main
{
    my $opts    = shift;
    my $cmds    = shift;
    my $command = shift;

    $command = lc $command;
    &check_command( $opts, $cmds, $command );

    printf "Executing $command with \"@_\".\n" if ( $opts->{debug} );

    $cmds->{ $command }( @_ );
}

sub help
{
    my $opts    = shift;
    my $cmds    = shift;
    my $command = shift;
    my $type    = shift;

    unless ( defined $command ) {
        pod2usage( -verboase   => 0,
                   -exitstatus => 0 );
    }

    $command = lc $command;
    &check_command( $opts, $cmds, $command );

    # if type was passed caller supports extended perl doc
    # 'execname help command type' for some or all sub-commands
    # callback to see which are allowed - true if 'type' help avail else false
    if ( defined $type and &main::check_type_help( $opts, $command, $type ) ) {
        $type = lc $type;
        # and another callback to make sure type is valid - should exit if not
        &main::check_type( $opts, $command, $type );

        pod2usage( -msg        => "$opts->{execname} $command $type ...\n",
                   -verbose    => 99,
                   -sections   => "COMMANDS/${command} ${type}.*",
                   -exitstatus => 0 );
    } else {
        pod2usage( -msg        => "$opts->{execname} $command ...\n",
                   -verbose    => 99,
                   -sections   => "COMMANDS/${command}.*",
                   -exitstatus => 0 );
    }
}

sub man
{
    pod2usage( -verbose    => 2,
               -sections   => "NAME|SYNOPSIS|DESCRIPTION|OPTIONS|COMMANDS",
               -noperldoc  => 1,
               -exitstatus => 0 );
}

sub check_command
{
    my $opts    = shift;
    my $cmds    = shift;
    my $command = shift;

    my $list = join ', ', (sort keys %{$cmds});
    unless ( defined $command ) {
        print "Requires <command> (e.g. $list)\n";
        &help( $opts, $cmds );
    }

    unless ( defined $cmds->{ $command } ) {
        print "Invalid <command> '$command' please use:  $list\n";
        exit 1;
    }
}

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
    unless ( $mac =~ m|^([0-9A-F]{1,2})(:([0-9A-F]){1,2}){5}$| ) {
        print "Invalid MAC address format or value string.\n";
        exit 1;
#        return undef;
    }
    $mac = sprintf '%02X:%02X:%02X:%02X:%02X:%02X', map hex, split ':', $mac;
    return $mac;
}


##     RFC 1034 (standard)
##     Section 3.5. Preferred name syntax
##
## The following syntax will result in fewer problems with many
## applications that use domain names (e.g., mail, TELNET).
##
## <domain> ::= <subdomain> | " "
##
## <subdomain> ::= <label> | <subdomain> "." <label>
##
## <label> ::= <letter> [ [ <ldh-str> ] <let-dig> ]
##
## <ldh-str> ::= <let-dig-hyp> | <let-dig-hyp> <ldh-str>
##
## <let-dig-hyp> ::= <let-dig> | "-"
##
## <let-dig> ::= <letter> | <digit>
##
## <letter> ::= any one of the 52 alphabetic characters A through Z in
## upper case and a through z in lower case
##
## <digit> ::= any one of the ten digits 0 through 9
##
## Note that while upper and lower case letters are allowed in domain
## names, no significance is attached to the case.  That is, two names with
## the same spelling but different case are to be treated as if identical.
##
## The labels must follow the rules for ARPANET host names.  They must
## start with a letter, end with a letter or digit, and have as interior
## characters only letters, digits, and hyphen.  There are also some
## restrictions on the length.  Labels must be 63 characters or less.
##
## For example, the following strings identify hosts in the Internet:
##
## A.ISI.EDU  XX.LCS.MIT.EDU  SRI-NIC.ARPA

## To simplify implementations, the total number of octets that represent a
## domain name (i.e., the sum of all label octets and label lengths) is
## limited to 255.

sub check_hostname
{
    my $name = shift;

    my $l   = '[a-zA-Z]';
    my $ld  = '[a-zA-Z0-9]';
    my $ldh = '[-a-zA-Z0-9]';

#    return 0 if (length($name) < 256 && $name =~ m/^(?:$l(?:(($ldh){1,61})$ld)?)(.(?:$l(?:(($ldh){1,61})$ld)?)){0,80}$/);
    return 0 if ( $name =~ m/^(?:$l(?:(($ldh){1,61})$ld)?)$/);
    return 1;
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
