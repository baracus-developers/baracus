package BaracusLUN;

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
use BaracusLUN   qw( :vars );

=pod

=head1 NAME

B<BaracusLUN> - subroutines for managing Baracus network bootable targets

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
                %baLunType
                BA_LUN_ISCSI 
                BA_LUN_NFS
                BA_LUN_AOE
                BA_LUN_IMAGE
            )],
         subs   =>
         [qw(

                list_start_lun
                list_next_lun
                add_db_lun
                remove_db_lun
                update_db_lun
                get_db_lun
                get_db_lun_uri

            )],
         );
    Exporter::export_ok_tags('subs');
    Exporter::export_ok_tags('vars');
}

our $VERSION = '0.01';

use vars qw( %baLunType );

# LUN Type constants
use constant BA_LUN_ISCSI         => 1  ;
use constant BA_LUN_NFS           => 2  ;
use constant BA_LUN_AOE           => 3  ;
use constant BA_LUN_IMAGE         => 4  ;

=item hash baState

here we define a hash to make easy using the state constants easier

=cut

%baLunType =
    (
     1              => 'iscsi' ,
     2              => 'nfs'   ,
     3              => 'aoe'   ,
     4              => 'image' ,

     'iscsi'        => BA_LUN_ISCSI ,
     'nfs'          => BA_LUN_NFS   ,
     'aoe'          => BA_LUN_AOE   ,
     'image'        => BA_LUN_IMAGE ,

     BA_LUN_ISCSI   => 'iscsi' ,
     BA_LUN_NFS     => 'nfs'   ,
     BA_LUN_AOE     => 'aoe'   ,
     BA_LUN_IMAGE   => 'image' ,
     );

# Subs

#
# add_db_lun($dbh, $hashref)
#

sub add_db_lun
{
    my $dbh     = shift;
    my $hostref = shift;
    my %Hash    = %{$hostref};

    my $fields = lc get_cols( $baTbls{ lun  } );
    $fields =~ s/[ \t]*//g;
    my @fields = split( /,/, $fields );
    my $values = join(', ', (map { $dbh->quote($_) } @Hash{@fields}));

    my $sql = qq|INSERT INTO $baTbls{ lun } ( $fields ) VALUES ( $values )|;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish;
    undef $sth;
}

#
# remove_db_lun($dbh, $targetid)
#

sub remove_db_lun
{
    my $dbh = shift;
    my $targetid = shift;

    my $sql = qq|DELETE FROM $baTbls{'lun'} WHERE targetid='$targetid'|;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish();
    undef $sth;
}

#
# update_db_lun
#

sub update_db_lun
{
    my $dbh    = shift;
    my $lunref = shift;
    my %Hash   = %{$lunref};

    my $fields = lc get_cols( $baTbls{ lun } );
    $fields =~ s/[ \t]*//g;
    my @fields;

    foreach my $field ( split( /,/, $fields ) ) {
        next if ( $field eq "targetid" );  # skip key
        push @fields, $field;
    }
    $fields = join(', ', @fields);
    my $values = join(', ', (map { $dbh->quote($_) } @Hash{@fields}));

    my $sql = qq|UPDATE $baTbls{ lun }
                SET ( $fields ) = ( $values )
                WHERE targetid = '$lunref->{targetid}' |;

    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
}

#
# get_db_lun($dbh, $targetid)
#

sub get_db_lun
{
    my $dbh      = shift;
    my $targetid = shift;

    my $sql = qq|SELECT * FROM $baTbls{ lun } WHERE targetid = '$targetid' |;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref();
}

#
# get_db_lun_uri($dbh, $targetid)
#

sub get_db_lun_uri
{
    my $dbh      = shift;
    my $targetid = shift; ## netroot

    my $uri;
    my $sth;

    my $sql = qq|SELECT * FROM $baTbls{ lun } WHERE targetid = '$targetid' |;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    my $href = $sth->fetchrow_hashref();
    
    if ( $baLunType{ $href->{type} } eq "nfs" ) {
        $uri = "$href->{'targetip'}" . ":" . "$href->{'target'}";
    } elsif ( $baLunType{ $href->{type} } eq "iscsi" ) {
        $uri = "$baLunType{ $href->{type} }" . ":" . "$href->{'targetip'}" . "::::" . "$href->{'target'}";
    } elsif ( $baLunType{ $href->{type} } eq "aoe" ) {
        $uri = "$baLunType{ $href->{type} }" . ":" . "$href->{'target'}";
    } else {
        $uri = "null";
    }
    return $uri;
}

#
# list_start_lun($dbh, targetid)
#

sub list_start_lun
{
    my $dbh = shift;
    my $filter = shift;
    my $fkey;

    if ( $filter eq "" ) {
        $fkey = "id";
        $filter = "%";
    } else {
        ( $fkey, $filter ) = split ( /::/, $filter, 2 );
        $filter =~ s/\*/\%/g;
    }

    unless ( $fkey eq "id" or $fkey eq "name" ) {
        print "Filter key not valid.\n";
        exit 1;
    }

    $fkey = "targetid" if $fkey eq "id";

    my $sql = qq|SELECT * FROM lun WHERE $fkey LIKE '$filter' ORDER BY targetid|;

    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth;
}

sub list_next_lun
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

