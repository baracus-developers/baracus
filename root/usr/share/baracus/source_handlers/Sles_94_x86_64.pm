package Sles_94_x86_64;

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

###########################################################################
## Required Perl package code
## Do not edit this section
## BEGIN ##################################################################

use 5.006;
use Carp;
use strict;
use warnings;

use Pod::Usage;

=pod

=head1 NAME

B<sles-9.4-x86_64> - sles-9.4-x86_64 source handler

=head1 SYNOPSIS

source handler for sles-9.4-x86_64

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
                external_source_handler
         )],
        );
    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

## END ####################################################################

sub external_source_handler() {

## Do not edit the following section 
## BEGIN ##################################################################

    my $switch  = shift;
    my $opts    = shift;
    my $distro  = shift;
    my $ret = 0;
    my $status = 0;

    use lib "/usr/share/baracus/perl";
    use BaracusSource qw( :vars :subs );

## END ####################################################################

## User defined included
## BEGIN ##################################################################

    use File::Find;
    use File::Path;
    use File::Copy;

## END ####################################################################

    SWITCH: for ($switch) {
        /init/       && do {
                               last SWITCH;
                           };

        /preadd/     && do {
                               my $dh = &baxml_distro_gethash( $opts, $distro );
                               my $bh = $dh->{basedisthash};
                               my $share = $bh->{distpath};
                               my %yasthash;


                               ## Create yast/instorder and yast/order
                               my $first  = "Service-Pack";
                               my $second = "SUSE-SLES";
                               my $third  = "SUSE-CORE";

                               my @order = ( $first, $second, $third );
                               my @products = &baxml_products_getlist( $opts, $distro );

                       PORDER: foreach my $product ( @products ) {
                                   for (my $count = 0; $count < 3; $count++ ) {
                                       print "ordering $product -- test $order[$count]\n" if $opts->{debug};
                                       if ( $product =~ m/$order[$count]/ ) {
                                           $yasthash{ $order[$count] } = $product;
                                           print "ordered $product -- $order[$count]\n" if $opts->{debug};
                                           ++$count;
                                           $yasthash{ $first  } = $product if ( $product =~ m/$first/  );
                                           $yasthash{ $second } = $product if ( $product =~ m/$second/ );
                                           $yasthash{ $third  } = $product if ( $product =~ m/$third/  );
                                           next PORDER;
                                       }
                                   }
                               }

                               ## Write out order and instorder files
                               print "Creating ORDER files for sles-9\n$share/yast/instorder\n$share/yast/order\n" if $opts->{debug};
                               mkpath "$share/yast" || die ("Cannot create yast directory\n");
                               open(IORDER, ">$share/yast/instorder") || die ("Cannot open file\n");
                               open(ORDER, ">$share/yast/order") || die ("Cannot open file\n");
                               foreach my $order ( @order ) {
                                   if ( defined $yasthash{$order} ) {
                                       print IORDER "/$yasthash{$order}/CD1\n";
                                       print ORDER "/$yasthash{$order}/CD1\t/$yasthash{$order}/CD1\n";
                                   }
                               }
                               print IORDER "/\n";
                               print ORDER "/\n";
                               close(IORDER);
                               close(ORDER);

                               ## Create necessary links (this is sles9 logic)
                               ##
                               chdir($share);
                               symlink("$yasthash{$second}/CD1/boot","boot");
                               symlink("$yasthash{$second}/CD1/content","content");
                               symlink("$yasthash{$second}/CD1/control.xml","control.xml");
                               symlink("$yasthash{$second}/CD1/media.1","media.1");

                               if ( defined $yasthash{$first} ) {
                                   symlink("$yasthash{$first}/CD1/linux","linux");
                                   symlink("$yasthash{$first}/CD1/driverupdate","driverupdate");
                               } else {
                                   symlink("$yasthash{$second}/CD1/linux","linux");
                                   symlink("$yasthash{$second}/CD1/driverupdate","driverupdate");
                               }

                               ## Nasty things needed to get info.txt removed from CD iso
                               ##
                               mkpath "$share/tmpfs/SUSE-SLES-Version-9" || die ("Cannot create sles9 directory\n");
                               mkpath "$share/tmpfs/SUSE-SLES-9-Service-Pack-Version-4" || die ("Cannot create sles9 directory\n");

                               $ret = system("mount -t ramfs -o size=5MB ramfs $share/tmpfs/SUSE-SLES-Version-9");
                               $status = 1 if ( $ret > 0 );

                               $ret = system("mount -t ramfs -o size=5MB ramfs $share/tmpfs/SUSE-SLES-9-Service-Pack-Version-4");
                               $status = 1 if ( $ret > 0 );
       
                               $ret = system ("cp $share/SUSE-SLES-9-Service-Pack-Version-4/CD1/media.1/* $share/tmpfs/SUSE-SLES-9-Service-Pack-Version-4/");
                               $status = 1 if ( $ret > 0 );
       
                               $ret = system ("cp $share/SUSE-SLES-Version-9/CD1/media.1/* $share/tmpfs/SUSE-SLES-Version-9/");
                               $status = 1 if ( $ret > 0 );
       
                               $ret = system("funionfs -o dirs=$share/tmpfs/SUSE-SLES-Version-9/=RW: NONE $share/SUSE-SLES-Version-9/CD1/media.1 -o nonempty -o allow_other");
                               $status = 1 if ( $ret > 0 );
       
                               $ret = system("funionfs -o dirs=$share/tmpfs/SUSE-SLES-9-Service-Pack-Version-4/=RW: NONE $share/SUSE-SLES-9-Service-Pack-Version-4/CD1/media.1 -o nonempty -o allow_other");
                               $status = 1 if ( $ret > 0 );
       
                               unlink("$share/SUSE-SLES-Version-9/CD1/media.1/info.txt");
                               $status = 1 if ( $ret > 0 );
       
                               unlink("$share/SUSE-SLES-9-Service-Pack-Version-4/CD1/media.1/info.txt");
                               $status = 1 if ( $ret > 0 );
       
                               mkpath "$share/install" || die ("Cannot create sles9 directory\n");
                               
                               $ret = system("funionfs -o dirs=$share/=RO: NONE $share/install -o nonempty -o allow_other");
                               $status = 1 if ( $ret > 0 );

                               last SWITCH;
                           };

        /postadd/    && do {
                               last SWITCH;
                           };
    
        /preremove/  && do {
                               my $dh = &baxml_distro_gethash( $opts, $distro );
                               my $bh = $dh->{basedisthash};
                               my $share = $bh->{distpath};

                               my @marray = ("$share/tmpfs/SUSE-SLES-9-Service-Pack-Version-4",
                                             "$share/tmpfs/SUSE-SLES-Version-9",
                                             "$share/SUSE-SLES-Version-9/CD1/media.1",
                                             "$share/SUSE-SLES-9-Service-Pack-Version-4/CD1/media.1",
                                             "$share/install");

                               foreach my $mount ( @marray ) {
                                   $ret = system("umount $mount");
                                   $status = 1 if ( $ret > 0 );
                               }

                               my @cleanup = ("$share/install",
                                              "$share/tmpfs",
                                              "$share/boot",
                                              "$share/content",
                                              "$share/control.xml",
                                              "$share/media.1",
                                              "$share/linux",
                                              "$share/driverupdate",
                                              "$share/yast/order");

                               foreach my $clean ( @cleanup ) {
                                   unlink("$clean");
                               }

                               last SWITCH;
                           };

        /postremove/ && do {
                               last SWITCH;
                           };

        print "function: $switch not defined\n";

    }

    return $status;
}

1;

__END__
