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

use BaracusConfig qw( :vars );
use BaracusStorage qw( :vars :subs );
use BaracusAux qw( :subs );

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
              get_arch_linux
              get_arch_initrd
              get_inventory
              do_localboot
              do_pxewait
              do_menu_lst
              do_rescue
              is_inventory_still_required
          )]
       );
  Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

my $linux_baracus = "linux.baracus";
my $linux_baracus_xen = "linux-xen.baracus";
my $initrd_baracus = "initrd.baracus";
my $initrd_xen_baracus = "initrd-xen.baracus";

sub get_arch_linux {
    my $input = shift;
    if ( defined $input->{arch} and
         $input->{arch} =~ m/xen/i ) {
        return $linux_baracus_xen;
    } else {
        return $linux_baracus;
    }
}

sub get_arch_initrd {
    my $input = shift;
    if ( defined $input->{arch} and
         $input->{arch} =~ m/xen/i ) {
        return $initrd_xen_baracus;
    } else {
        return $initrd_baracus;
    }
}

sub get_inventory() {
    my $cgi   = shift;
    my $baVar = shift;
    my $input = shift;
    my $args  = shift;
    $args = "acpi=off selinux=0 apm=off" unless ( defined $args && "$args" ne "" );
    $args .= " ipmi=true" if ( $baVar{ipmi} eq "true" );
    $args .= " ipmilan=true" if ( $baVar{ipmilan} eq "true" );

    my $lcmac = lc $input->{mac};
    my $inventory_linux=get_arch_linux($input);
    my $inventory_initrd=get_arch_initrd($input);

    my $output = qq|DEFAULT register
PROMPT 0
TIMEOUT 0
LABEL register
        kernel http://$baVar->{serverip}/ba/$inventory_linux
        append initrd=http://$baVar->{serverip}/ba/$inventory_initrd install=exec:/usr/bin/baracus.register textmode=1 baracus=$baVar->{serverip} mac=$input->{mac} $args netwait=60 netdevice=eth0 udev.rule="mac=$lcmac,name=eth0" dhcptimeout=60 nosmp
|;

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

# without a timeout it would wait indefinitely
# now we invoke a pxewait shell script
# for Baracus/node interaction
sub do_pxewait() {
    my $cgi = shift;
    my $baVar = shift;
    my $input = shift;
    my $args  = shift;
    $args = "acpi=off selinux=0 apm=off" unless ( defined $args && "$args" ne "");

    my $lcmac = lc $input->{mac};
    my $pxewait_linux=get_arch_linux($input);
    my $pxewait_initrd=get_arch_initrd($input);

    my $output = qq|DEFAULT pxewait
PROMPT 0
TIMEOUT 0
LABEL pxewait
        kernel http://$baVar->{serverip}/ba/$pxewait_linux
        append initrd=http://$baVar->{serverip}/ba/$pxewait_initrd install=exec:/usr/bin/pxewait textmode=1 baracus=$baVar->{serverip} mac=$input->{mac} $args netwait=60 netdevice=eth0 udev.rule="mac=$lcmac,name=eth0" dhcptimeout=60 nosmp
|;

    print $cgi->header( -type => "text/plain", -content_length => length ($output)), $output;
    exit 0;
}

sub do_menu_lst() {
    my $cgi = shift;
    my $actref = shift;
    my $serverip = shift;
    my $mntpoint = shift;

    my $output = "";

    if ( $actref->{distro} =~ /solaris-10/ ) {
        $output =  qq|default menu.lst
timeout 4

label menu.lst
        title Baracus Solaris10 Jumpstart
        kernel multiboot kernel/unix - verbose install dhcp http://$serverip/ba/jumpstart.tar?mac=$actref->{mac} -B install_media=$serverip:$mntpoint
        module x86.miniroot
|;
    } elsif ( $actref->{distro} =~ /solaris-11/ ) {
        $output = qq|default menu.lst
timeout 4

label menu.lst
        title Baracus Solaris11 Jumpstart
        kernel\$ kernel/amd64/unix -B install=true,console=ttya \
        install_media=$serverip:$mntpoint \
        install_boot=$serverip:$mntpoint/boot
        module\$ boot_archive
|;
    }

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

sub is_inventory_still_required
{
    my $opts   = shift;
    my $tftph  = shift;
    my $input  = shift;
    my $macref = shift;

    my $filename = $input->{mac} . ".inventory";
    my $href = &find_tftpfile( $opts, $tftph, $filename );
    if (not defined $href               or
        $href->{name} ne $filename      or
        not defined $macref->{register} or
        $macref->{register} eq ""       )
    {
        return 1;
    }
    return 0;
}

1;

__END__


=head1 AUTHOR

David Bahi, E<lt>dbahi@novellE<gt>

=cut
