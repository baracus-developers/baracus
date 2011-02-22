package BaracusStorage;

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

use lib "/usr/share/baracus/perl";

use BaracusSql   qw( :subs :vars );
use BaracusState qw( :vars );
use BaracusCore  qw( :subs );

=pod

=head1 NAME

B<BaracusStorage> - subroutines for managing images and network bootable targets

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
         vars =>
         [qw(
                %baStorageType
                BA_STORAGE_ISCSI
                BA_STORAGE_NFS
                BA_STORAGE_AOE
                BA_STORAGE_IMAGE
            )],
         subs   =>
         [qw(
                list_start_storage
                list_next_storage
                get_db_storage_uri
            )],
         );
    Exporter::export_ok_tags('subs');
    Exporter::export_ok_tags('vars');
}

our $VERSION = '0.01';

use vars qw( %baStorageType );

# Storage Type constants
use constant BA_STORAGE_ISCSI   => 1  ;
use constant BA_STORAGE_NFS     => 2  ;
use constant BA_STORAGE_AOE     => 3  ;
use constant BA_STORAGE_IMAGE   => 4  ;

=item hash baState

here we define a hash to make easy using the state constants easier

=cut

%baStorageType =
    (
     1              => 'iscsi' ,
     2              => 'nfs'   ,
     3              => 'aoe'   ,
     4              => 'image' ,

     'iscsi'        => BA_STORAGE_ISCSI ,
     'nfs'          => BA_STORAGE_NFS   ,
     'aoe'          => BA_STORAGE_AOE   ,
     'image'        => BA_STORAGE_IMAGE ,

     BA_STORAGE_ISCSI   => 'iscsi' ,
     BA_STORAGE_NFS     => 'nfs'   ,
     BA_STORAGE_AOE     => 'aoe'   ,
     BA_STORAGE_IMAGE   => 'image' ,
     );

# Subs

#
# get_db_storage_uri($dbh, $storageid)
#

sub get_db_storage_uri
{
    my $dbh      = shift;
    my $storageid = shift; ## netroot

    my $uri;
    my $sth;

    my $sql = qq|SELECT * FROM $baTbls{ storage } WHERE storageid = '$storageid' |;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    my $href = $sth->fetchrow_hashref();

    if ( $href->{type} == BA_STORAGE_NFS ) {
        $uri = "$href->{'storageip'}" . ":" . "$href->{'storage'}";
    } elsif ( $href->{type} == BA_STORAGE_ISCSI ) {
        $uri = "$baStorageType{ $href->{type} }" . ":" . "$href->{'storageip'}" . "::::" . "$href->{'storage'}";
    } elsif ( $href->{type} == BA_STORAGE_AOE ) {
        $uri = "$baStorageType{ $href->{type} }" . ":" . "$href->{'storage'}";
    } else {
        $uri = "null";
    }
    return $uri;
}

#
# list_start_storage($dbh, storageid)
#

sub list_start_storage
{
    my $dbh = shift;
    my $filter = shift;
    my $fkey;

    if ( $filter eq "" ) {
        $fkey = "name";
        $filter = "%";
    } else {
        ( $fkey, $filter ) = split ( /::/, $filter, 2 );
        $filter =~ s/\*/\%/g;
    }

    unless ( $fkey eq "storage" or $fkey eq "name" ) {
        print "Filter key not valid.\n";
        exit 1;
    }

    $fkey = "storageid" if $fkey eq "name";

    my $sql = qq|SELECT * FROM storage WHERE $fkey LIKE '$filter' ORDER BY storageid|;

    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth;
}

sub list_next_storage
{

    my $sth = shift;
    my $href;

    $href = $sth->fetchrow_hashref();

    unless ($href) {
        $sth->finish;
        undef $sth;
        undef $href;
    }

    return $href;
}

1;

__END__

=head1 AUTHOR

Daniel Westervelt, E<lt>dwestervelt@novellE<gt>
David Bahi, E<lt>dbahi@novellE<gt>

=cut
