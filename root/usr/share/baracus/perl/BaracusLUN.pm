package BaracusLUN;

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
         subs   =>
         [qw(

                list_start_lun
                list_next_lun
                add_db_lun
                remove_db_lun
                update_db_lun
                get_db_lun

            )],
         );
    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

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

    # no good w/o $opts passed in
#    print "list_start_lun key: $fkey filter: $filter\n" if $opts->{debug};

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

