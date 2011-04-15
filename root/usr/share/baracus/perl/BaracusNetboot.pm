package BaracusNetboot;

###########################################################################
#
# Baracus build and boot management framework
#
# Copyright (C) 2011 Novell, Inc, 404 Wyman Street, Waltham, MA 02451, USA.
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

use File::Path;

use BaracusConfig qw( :vars );
use BaracusStorage qw( :vars :subs );
use BaracusAux qw( :subs );

=head1 NAME

BaracusNetboot - subroutines of use

=head1 SYNOPSIS

A collection of routines used in the baracus netboot cgi

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
              do_netboot
              mount_nfs
              umount_nfs
              readfile
              read_grubconf
          )]
       );
  Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

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

sub mount_nfs() {
    my $baref=shift;
    my $sref=shift;
    my $sysrc;
    
    my $localpath="$baref->{nfsroot}/$sref->{storageip}/$sref->{storage}";
    
    system ("/usr/bin/sudo", "/bin/mkdir", "-p", $localpath);

    $sysrc = system ("/usr/bin/sudo", "/bin/mount", 
		     "-t", "nfs",
		     "-o", "soft,async",
                     "$sref->{storageip}:$sref->{storage}", $localpath);
    
    return $sysrc;
}

sub umount_nfs() {
    my $baref=shift;
    my $sref=shift;
    my $sysrc;
    
    my @args = ("/usr/bin/sudo", "/bin/umount", 
		"$baref->{nfsroot}/$sref->{storageip}/$sref->{storage}");
    $sysrc = system(@args);

    return $sysrc;
}

sub readfile() {
    my $fn = shift;
    my $fd;
    my $fdata;
    
    if (not ((-f $fn) && (-r $fn))) {
	return;
    }

    open ($fd, "<", $fn) || return;
            {
            binmode($fd);
            undef $/;
            $fdata=<$fd>;
            $/ = "\n";
            }
    close $fd;
    return $fdata;
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
		    $g_name = $1;
		last;
	        
	    }
	    if ( m,^\s*initrd\s+\(.*\)(\S*),i && (not defined $g_name) && 
		($reqfile eq "initrd")) {
		$g_name = $1;
		last;
	    }
	}
    close $fd;

    return $g_name;
}

1;

__END__


=head1 AUTHOR

Sven-Thorsten Dietrich E<lt>sdietrich@novellE<gt>
David Bahi, E<lt>dbahi@novellE<gt>

=cut
