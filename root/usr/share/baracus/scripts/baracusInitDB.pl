#!/usr/bin/perl
use 5.006;
use Carp;
use strict;
use warnings;
use File::Copy;

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
    system ( "basource prepdbwithxml" );
    system ( "/usr/share/baracus/scripts/baconfig_load_hardware" );
    system ( "/usr/share/baracus/scripts/baconfig_load_profile" );
    my $perl_reload = &add_apache2_perl();
    my $listen_reload = &apache2_listen_conf();
    system ( "service apache2 reload" ) if ( $perl_reload or $listen_reload );
    &add_www_sudoers();
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

    $status = BaracusDB::exists_role( $dbh, "wwwrun" );
    die BaracusDB::errstr unless( defined $status );
    unless( $status ) {
        die BaracusDB::errstr
            unless( BaracusDB::create_role( $dbh, "wwwrun", @args ));
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

sub add_apache2_perl
{
    my $sysconf_in  = "/etc/sysconfig/apache2.bk";
    my $sysconf_out = "/etc/sysconfig/apache2";
    my $mods;
    my $restart = 0;

    copy ($sysconf_out, $sysconf_in);
    open (SYSCONF_IN, "<$sysconf_in")
        or die "Unable to open $sysconf_in: $!\n";
    open (SYSCONF_OUT, ">$sysconf_out")
        or die "Unable to open $sysconf_out: $!\n";
    while (<SYSCONF_IN>) {
        if (m/^(\s*APACHE_MODULES\s*=\s*"\s*)([^"]*)(\s*"\s*)$/) {
            my $pre = $1;
            $mods = $2;
            my $post = $3;
            if ( ! ( $mods =~ m/\s*perl\s*/ ) ) {
                $mods .= " perl";
                $_ = $pre . $mods . $post ;
                $restart = 1;
            }
        }
        print SYSCONF_OUT $_;
    }
    close SYSCONF_IN;
    close SYSCONF_OUT;
    unlink $sysconf_in;
    return $restart;
}

sub apache2_listen_conf
{
    my $listenconf_in  = "/etc/apache2/listen.conf.bk";
    my $listenconf_out = "/etc/apache2/listen.conf";
    my $restart = 0;

    use AppConfig;
    my $sysconfigfile = '/etc/sysconfig/baracus';
    my $sysconfig = AppConfig->new( {CREATE => 1} );
    $sysconfig->define( 'server_ip=s' );
    $sysconfig->file( $sysconfigfile );
    my $mods = $sysconfig->get( 'server_ip' );

    # listen.conf support systems with more than one IP and use BUILDIP

    copy ($listenconf_out, $listenconf_in);
    open (LISTENCONF_IN, "<$listenconf_in")
        or die "Unable to open $listenconf_in: $!\n";
    open (LISTENCONF_OUT, ">$listenconf_out")
        or die "Unable to open $listenconf_out: $!\n";
    while (<LISTENCONF_IN>) {
        if (m|^(\s*[Ll]isten\s+)([0-9]+)$|) {
            $_ = $1 . $mods . ':' . $2 . "\n";
            $restart = 1;
        }
        print LISTENCONF_OUT $_;
    }
    close LISTENCONF_IN;
    close LISTENCONF_OUT;
    unlink $listenconf_in;
    return $restart;
}

sub add_www_sudoers
{
    my $www_search = qr|^\s*%www\s*ALL\s*=\s*\(\s*ALL\s*\)\s*NOPASSWD\s*:\s*ALL|;
    my $www_line = qq|\n%www	ALL=(ALL) NOPASSWD: ALL\n|;
    my $sudoers  = "/etc/sudoers";
    my $found = 0;

    open (SUDOERS, "+<$sudoers")
        or die "Unable to open $sudoers: $!\n";
    while (<SUDOERS>) {
        if (m/$www_search/) {
            $found = 1;
        }
    }
    if (not $found) {
        print SUDOERS $www_line;
    }
    close SUDOERS;
}

die "absolutely does not execute";

__END__
