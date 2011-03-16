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
              do_netboot
              do_rescue
              read_grubconf
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
        append initrd=http://$baVar->{serverip}/ba/$inventory_initrd install=exec:/usr/bin/baracus.register textmode=1 baracus=$baVar->{serverip} mac=$input->{mac} $args netwait=60 netdevice=eth0 udev.rule="mac=$lcmac,name=eth0" dhcptimeout=60
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
        append initrd=http://$baVar->{serverip}/ba/$pxewait_initrd install=exec:/usr/bin/pxewait textmode=1 baracus=$baVar->{serverip} mac=$input->{mac} $args netwait=60 netdevice=eth0 udev.rule="mac=$lcmac,name=eth0" dhcptimeout=60
|;

    print $cgi->header( -type => "text/plain", -content_length => length ($output)), $output;
    exit 0;
}

sub do_netboot_san() {
    my $cgi = shift;
    my $actref = shift;
    my $serverip = shift;
    my $output = qq|DEFAULT netboot
PROMPT 0
TIMEOUT 0
LABEL netboot
    kernel http://$serverip/ba/sanboot.c32
    append $actref->{storageuri}
|;

    print $cgi->header( -type => "text/plain", -content_length => length ($output)), $output;
    exit 0;
}

sub do_netboot_nfs() {
    my $cgi = shift;
    my $actref = shift;
    my $serverip = shift;

    my $output = qq|DEFAULT netboot_nfs
# NFS boot from: $actref->{storageid}
PROMPT 0
TIMEOUT 0
LABEL netboot_nfs
    kernel http://$serverip/ba/linux?mac=$actref->{mac}&nfsroot=$actref->{storageip}/$actref->{storage}
    append initrd=http://$serverip/ba/initrd?mac=$actref->{mac}&nfsroot=$actref->{storageip}/$actref->{storage} root=/dev/nfs nfsroot=$actref->{storageuri}
|;
    print $cgi->header( -type => "text/plain", -content_length => length ($output)), $output;
    exit 0;
}

sub do_netboot() {
    my $cgi = shift;
    my $actref = shift;
    my $serverip = shift;

    if ($actref->{type} == BA_STORAGE_NFS) {
        &do_netboot_nfs( $cgi, $actref, $serverip );
    } else {
        &do_netboot_san( $cgi, $actref, $serverip );
    }
}

sub read_grubconf() {

    my $nfsroot=shift;
    my $grubmenu=shift;
    my $reqfile=shift;
    my $fd;
    my $line = 0;
    my $g_default = 0;
    my $titleno = -1;
    my $g_name = undef;

    open ($fd, "<", "$nfsroot/$grubmenu");
	while(<$fd>) {
	    $line++;
#           if ($titleno != $g_default && m,^\s*title\s+(.*),i ) {
            if ( m,^\s*default\s+(.*),i ) {
		if ( defined $g_default ) {
#                  printlog "$input->{mac} - ignoring default $_\n";
		} else {
                    $g_default = $1;
#                    printlog "$input->{mac} - default boot: $g_default \n";
		}
		next;
	    }
	    if ( m,^\s*title\s+(.*),i ) {
		$titleno++;
#               printlog "$input->{mac} - title: $titleno: $1 \n";
	    }
	    if ( $titleno != $g_default ) {
		next;
	    }
	    if ( m,^\s*kernel\s+\(.*\)(\S*),i && (not defined $g_name) &&
		 ($reqfile eq "linux")) {
		    $g_name = "$nfsroot/$1";
		last;
	        
	    }
	    if ( m,^\s*initrd\s+\(.*\)(\S*),i && (not defined $g_name) && 
		($reqfile eq "initrd")) {
		$g_name = "$nfsroot/$1";
		last;
	    }
	}
    close $fd;

    return $g_name;
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
