#!/usr/bin/perl
use 5.006;
use Carp;
use strict;
use warnings;

use lib "/usr/share/baracus/perl";

use BaracusDB;
use BaracusSql;

# creates ROLES, DATABASES, TABLES, LANGUAGES for baracus
# to be called on database startup - by baracusdb service

my $reverse_flag = $ARGV[0];

my $pg_user = 'postgres';
my $pg_db = 'postgres';

my $role = "baracus";
my @args = qw( LOGIN SUPERUSER );

my $db_baracus = "baracus";
my $db_sqltftp = "sqltftp";

my $plpg = "plpgsql";

if ( defined $reverse_flag ) {
    &niam();
} else {
    &main();
    system ( "/usr/share/baracus/perl/baconfig_load_distro" );
    system ( "/usr/share/baracus/perl/baconfig_load_hardware" );
}

exit 0;

die "does not execute";

sub main {

    my $status;
    my $uid;
    my $dbh;

    # save current uid

    my $suid = $>;

    # switch to user postgres and connect

    $uid = BaracusDB::su_user( $pg_user );
    die BaracusDB::errstr unless ( defined $uid );

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

    # finished working as user postgres

    $> = $suid;

    # switch to user baracus

    # connect to sqltftp database

    $uid = BaracusDB::su_user( $role );
    die BaracusDB::errstr unless ( defined $uid );

    $dbh = BaracusDB::connect_db( $db_sqltftp, $role );
    die BaracusDB::errstr unless( $dbh );

    my $hashoftbls;

    $hashoftbls = BaracusSql::get_sqltftp_tables();

    while( my ($tbl, $col) = each %{ $hashoftbls } ) {
        $status = BaracusDB::exists_table( $dbh, $tbl );
        die BaracusDB::errstr unless( defined $status );
        unless( $status ) {
            print STDOUT "user $role creating $tbl in db $db_sqltftp\n";
            die BaracusDB::errstr
                unless( BaracusDB::create_table( $dbh, $tbl,
                BaracusSql::hash2columns( $col )));
        }
    }

    die BaracusDB::errstr unless BaracusDB::disconnect_db( $dbh );

    # connect to baracus database

    $dbh = BaracusDB::connect_db( $db_baracus, $role );
    die BaracusDB::errstr unless( $dbh );

    $hashoftbls = BaracusSql::get_baracus_tables();

    while( my ($tbl, $col) = each %{ $hashoftbls } ) {
        $status = BaracusDB::exists_table( $dbh, $tbl );
        die BaracusDB::errstr unless( defined $status );
        unless( $status ) {
            print STDOUT "user $role creating $tbl in db $db_baracus\n";
            die BaracusDB::errstr
                unless( BaracusDB::create_table( $dbh, $tbl,
                BaracusSql::hash2columns( $col )));
        }
    }


    # make sure the language we define functions in is loaded

    $status = BaracusDB::exists_language( $dbh, $plpg );
    die BaracusDB::errstr unless( defined $status );
    unless( $status ) {
        die BaracusDB::errstr
            unless( BaracusDB::create_language( $dbh, $plpg ));
    }

    # create/replace the functions for use by our triggers

    my $hashoffuncs = BaracusSql::get_baracus_functions();
    while( my ($name, $def) = each %{ $hashoffuncs } ) {
        die BaracusDB::errstr
            unless( BaracusDB::create_or_replace_function( $dbh, $name, $def ));
    }

    # add the triggers

    my $hashoftgs = BaracusSql::get_baracus_triggers();

    while( my ($tg, $sql) = each %{ $hashoftgs } ) {
        $status = BaracusDB::exists_trigger( $dbh, $tg );
        die BaracusDB::errstr unless( defined $status );
        unless( $status ) {
            die BaracusDB::errstr
                unless( BaracusDB::create_trigger( $dbh, $tg, $sql ));
        }
    }

    die BaracusDB::errstr unless BaracusDB::disconnect_db( $dbh );

    # finished working as user baracus

    $> = $suid;
}

sub niam {

    my $status;
    my $uid;
    my $dbh;

    # switch to user postgres and connect

    $uid = BaracusDB::su_user( $pg_user );
    die BaracusDB::errstr unless ( defined $uid );

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

