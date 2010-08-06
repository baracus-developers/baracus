#!/usr/bin/perl -w

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

use strict;
use warnings;

use Getopt::Long qw( :config pass_through );
use Pod::Usage;

use lib "/usr/share/baracus/perl";

use BaracusDB;
use BaracusSql qw( :vars :subs );
use BaracusCore qw( :subs );
use BaracusSource qw( :subs );

=pod

=head1 NAME

B<baracusInitSources> - baracus tool for mounting and exporting

=head1 SYNOPSIS

B<baracusInitSources> [options]head1 SYNOPSIS

Where E<lt>optionE<gt> is

  --export    export all active baracus nfs shares
  --mount     mount all active baracus isos

Use 'man' or 'help <command>' for more details.

=head1 DESCRIPTION

This tool is meant to re-init nfs shares and iso mounts
maintained by bracus

=head1 OPTIONS

=over 4

=item -v --verbose  Be verbose with output

=back

=cut

our $LASTERROR="";

my $debug   = 0;
my $mount   = 0;
my $export  = 0;

GetOptions(
           'debug'      => \$debug,
           'mount'      => \$mount,
           'export'     => \$export,
           );

my $dbname = "baracus";
my $dbrole = $dbname;

my $uid = BaracusDB::su_user( $dbrole );
die BaracusDB::errstr unless ( defined $uid );

my $dbh = BaracusDB::connect_db( $dbname, $dbrole );
die BaracusDB::errstr unless( $dbh );

my $status;
if ( $mount )  { $status = &mounter; }
if ( $export ) { $status = &exporter; }

die BaracusDB::errstr unless BaracusDB::disconnect_db( $dbh );

print $LASTERROR if $status;

exit $status;

die "DOES NOT EXECUTE";

###############################################################################
#
# subroutines
#

sub mounter
{
    my $opts;
    $opts->{'debug'} = $debug;
    my @mount;
    my $ret = 0;
    my $iso_location_hashref = &get_iso_locations( $opts );

    my $sql = qq| SELECT mntpoint, iso
                  FROM $baTbls{'iso'}
                  WHERE is_loopback = 't'
               |;

    my $sth;
    my $href;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute() );

    while ( $href = $sth->fetchrow_hashref() ) {
        if ( ! -d $href->{'mntpoint'} ) {
            unless ( mkpath $href->{'mntpoint'} ) {
                $LASTERROR = "Unable to create directory\n$!";
                return 1;
            }
        }
        my $is_mounted = 0;
        my @mount = qx|mount| or die ("Can't get mount status: ".$!);
        foreach( @mount ) {
            if(/$href->{'mntpoint'}/){
                print "$iso_location_hashref->{$href->{'iso'}} already mounted\n" if ( $debug );
                $is_mounted = 1;
             }
        }
        if ( $is_mounted ) { next; }
        print "mounting $iso_location_hashref->{ $href->{'iso'} } at $href->{'mntpoint'} \n" if ( $debug );
        $ret = system("mount -o loop $iso_location_hashref->{ $href->{'iso'} } $href->{'mntpoint'}");
        if ( $ret > 0 ) {
            $LASTERROR = "Mount failed\n$!";
            return 1;
        }
    }
  return 0;
}

sub exporter
{
    my @mount;
    my $ret = 0;

    my $sql = qq| SELECT mntpoint
                  FROM $baTbls{'iso'}
                  WHERE sharetype = '1'
               |;

    my $sth;
    my $href;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute() );

    while ( $href = $sth->fetchrow_hashref() ) {
        if ( ! -d $href->{'mntpoint'} ) {
            $LASTERROR = "directory does not exist\n$!";
            return 1;
        }
        my $is_shared = 0;
        my @share = qx|showmount -e localhost| or die ("Can't get share status: ".$!);
        foreach( @share ) {
            if(/$href->{'mntpoint'}/){
                print "$href->{'mntpoint'} already exported\n" if ( $debug );
                $is_shared = 1;
            }
        }
        if ( $is_shared ) { next; }
        print "exporting $href->{'mntpoint'} \n" if ( $debug );
        $ret = system("exportfs -o ro,root_squash,insecure,sync,no_subtree_check *:$href->{'mntpoint'}");
        if ( $ret > 0 ) {
            $LASTERROR = "Mount failed\n$!";
            return 1;
        }
    }
  return 0;
}
