package Solaris_108_x86_64;

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
use File::Path;

=pod

=head1 NAME

B<Solaris_108_x86_64> - Solaris_10.8_x86_64 source handler

=head1 SYNOPSIS

source handler for Solaris-10.8-x86_64

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

    my $basepath = "/var/spool/baracus/builds/solaris/10.8/x86_64/dvd";
    my $rootpath = "/var/lib/nfs/v4-root";
    my $nfspath  = $rootpath . $basepath;

    SWITCH: for ($switch) {
        /init/      && do {
                               last SWITCH;
                           };

        /preadd/     && do {
                               last SWITCH;
                           };

        /postadd/    && do {
                               last SWITCH;
                           };
    
        /preremove/ && do {
                               $ret = system("exportfs -u *:$nfspath");

                               $ret = system("umount $basepath");
                               $ret = system("umount $nfspath");
                               $status = 1 if ( $ret > 0 );
                               rmdir("$basepath");
                               last SWITCH;
                           };

        /postremove/ && do {
                               rmtree("$rootpath/var/spool/baracus/builds/solaris/10.8") || die "Cannot remove directory\n";
                               last SWITCH;
                           };

        print "function: $switch not defined\n";

    }

    return $status;
}

1;

__END__
