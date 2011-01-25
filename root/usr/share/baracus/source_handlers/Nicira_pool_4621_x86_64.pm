package Nicira_pool_4621_x86_64;

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

B<nicira-pool-4621-x86_64.pm> - nicira-pool-4621-x86_64.pm source handler

=head1 SYNOPSIS

source handler for nicira-pool-4621-x86_64

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

    my $switch = shift;
    my $ret = 0;
    my $status = 0;

    ## source_handler to generate required debian mirror
    ## mirror created via unionfs mouting 5 DVDs
    my $basepath = "/var/spool/baracus/builds/nicira-pool/4621/x86_64";

    ## check for loaded fuse module and insert if needed
    unless ( system("lsmod | grep fuse &> /dev/null") ) { system("modprobe -a fuse &> /dev/null"); }

    SWITCH: for ($switch) {
        /init/   && do {
                       open(MTAB, "</etc/mtab") or die $!;
                       my $mtab = join '', <MTAB>;
                       close(MTAB);
                       unless ( $mtab =~ m/$basepath\/mirror\/pool/ ) { 
                           $ret = system("funionfs -o dirs=$basepath/dvds/dvd/pool/=RO: NONE $basepath/mirror/pool -o nonempty -o allow_other");
                           $status = 1 if ( $ret > 0 );
                       }

                       unless ( $mtab =~ m/$basepath\/mirror\/dists\/lenny/ ) {
                           $ret = system("funionfs -o dirs=$basepath/dvds/dvd/dists/lenny/=RW: NONE $basepath/mirror/dists/lenny -o nonempty -o allow_other");
                           $status = 1 if ( $ret > 0 );
                       }

                       last SWITCH;
                    };

        /add/    && do {
                        # create 5 dvd pool union
                        mkdir "$basepath/mirror";
                        mkdir "$basepath/mirror/pool";
                        $ret = system("funionfs -o dirs=$basepath/dvds/dvd/pool/=RO: NONE $basepath/mirror/pool -o nonempty -o allow_other");
                        $status = 1 if ( $ret > 0 );

                        # create dists/lenny union
                        mkdir "$basepath/mirror/dists";
                        mkdir "$basepath/mirror/dists/lenny";
                        $ret = system("funionfs -o dirs=$basepath/dvds/dvd/dists/lenny/=RW: NONE $basepath/mirror/dists/lenny -o nonempty -o allow_other");
                        $status = 1 if ( $ret > 0 );

                        # create symlink
                        $ret = system("ln -s $basepath/mirror/dists/lenny $basepath/mirror/dists/stable");
                        $status = 1 if ( $ret > 0 );
 
                        last SWITCH;
                    };
    
        /remove/ && do {
                        $ret = system("umount $basepath/mirror/pool/");
                        $status = 1 if ( $ret > 0 );
                        rmdir("$basepath/mirror/pool/");

                        unlink("$basepath/mirror/dists/stable");
                        $ret = system("umount $basepath/mirror/dists/lenny");
                        $status = 1 if ( $ret > 0 );   
                        rmdir("$basepath/mirror/dists/lenny");
                        rmdir("$basepath/mirror/dists");
                        rmdir("$basepath/mirror");
 
                        last SWITCH;
                    };

        print "function: $switch not defined\n";

    }

    return $status;
}

1;

__END__
