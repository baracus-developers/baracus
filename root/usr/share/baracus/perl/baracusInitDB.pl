#!/usr/bin/perl
use 5.006;
use Carp;
use strict;
use warnings;

use lib "/usr/share/baracus/perl";

use BaracusDB;

my $reverse_flag = $ARGV[0];

my $pg_user = 'postgres';
my $pg_db = 'postgres';

my $role = "baracus";
my @args = qw( LOGIN SUPERUSER );

my $db_baracus = "baracus";
my $db_sqltftp = "sqltftp";

if ( defined $reverse_flag ) {
    &niam();
} else {
    &main();
}

exit 0;

die "does not execute";

sub main {

    my $status;
    my $oldid;
    my $dbh;

    $oldid = BaracusDB::su_user( $pg_user );
    die BaracusDB::errstr unless ( defined $oldid );

    $dbh = BaracusDB::connect_db( $pg_db, $pg_user );
    die BaracusDB::errstr unless( $dbh );

    $status = BaracusDB::exists_role( $dbh, $role );
    die BaracusDB::errstr unless( defined $status );
    unless( $status ) {
        die BaracusDB::errstr
            unless( BaracusDB::create_role( $dbh, $role, @args ));
    }

    $status = BaracusDB::exists_database( $dbh, $db_baracus);
    die BaracusDB::errstr unless ( defined $status );
    unless( $status ) {
        die BaracusDB::errstr
            unless( BaracusDB::create_database( $dbh, $db_baracus, $role));
    }

    $status = BaracusDB::exists_database( $dbh, $db_sqltftp );
    die BaracusDB::errstr unless( defined $status );
    unless( $status ) {
        die BaracusDB::errstr
            unless( BaracusDB::create_database( $dbh, $db_sqltftp, $role));
    }

    die BaracusDB::errstr unless BaracusDB::disconnect_db( $dbh );
}

sub niam {

    my $status;
    my $oldid;
    my $dbh;

    $oldid = BaracusDB::su_user( $pg_user );
    die BaracusDB::errstr unless ( defined $oldid );

    $dbh = BaracusDB::connect_db( $pg_db, $pg_user );
    die BaracusDB::errstr unless( $dbh );

    $status = BaracusDB::exists_database( $dbh, $db_baracus);
    die BaracusDB::errstr unless ( defined $status );
    if ( $status ) {
        die BaracusDB::errstr
            unless( BaracusDB::drop_database( $dbh, $db_baracus ));
    }

    $status = BaracusDB::exists_database( $dbh, $db_sqltftp );
    die BaracusDB::errstr unless( defined $status );
    if ( $status ) {
        die BaracusDB::errstr
            unless( BaracusDB::drop_database( $dbh, $db_sqltftp, $role));
    }

    $status = BaracusDB::exists_role( $dbh, $role );
    die BaracusDB::errstr unless( defined $status );
    if ( $status ) {
        die BaracusDB::errstr
            unless( BaracusDB::drop_role( $dbh, $role ));
    }

    die BaracusDB::errstr unless BaracusDB::disconnect_db( $dbh );
}


die "absolutely does not execute";

__END__
