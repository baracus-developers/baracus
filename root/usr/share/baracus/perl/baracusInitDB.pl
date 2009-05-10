#!/usr/bin/perl
use 5.006;
use Carp;
use strict;
use warnings;

use DBI;

my $debug = 1;
our $LASTERROR = "";

my $reverse_flag = $ARGV[0];

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

    my $pg_user = 'postgres';
    my $pg_db = 'postgres';
    my $pg_ds = "DBI:Pg:dbname=$pg_db";

    my $role = "baracus";
    my @args = qw( LOGIN SUPERUSER );

    my $db_baracus = "baracus";
    my $db_sqltftp = "sqltftp";

    $oldid = &su_user( $pg_user );
    die $LASTERROR unless ( defined $oldid );

    $dbh = &connect_to_db( $pg_ds, $pg_user );
    die $LASTERROR unless( $dbh );

    $status = &exists_role( $dbh, $role );
    die $LASTERROR unless( defined $status );
    unless( $status ) {
        die $LASTERROR unless( &create_role( $dbh, $role, @args ));
    }

    $status = &exists_database( $dbh, $db_baracus);
    die $LASTERROR unless ( defined $status );
    unless( $status ) {
        die $LASTERROR unless( &create_database( $dbh, $db_baracus, $role));
    }

    $status = &exists_database( $dbh, $db_sqltftp );
    die $LASTERROR unless( defined $status );
    unless( $status ) {
        die $LASTERROR unless( &create_database( $dbh, $db_sqltftp, $role));
    }

    die $LASTERROR unless &disconnect_from_db( $dbh );
}

sub niam {

    my $status;
    my $oldid;
    my $dbh;

    my $pg_user = 'postgres';
    my $pg_db = 'postgres';
    my $pg_ds = "DBI:Pg:dbname=$pg_db";

    my $role = "baracus";
    my @args = qw( LOGIN SUPERUSER );

    my $db_baracus = "baracus";
    my $db_sqltftp = "sqltftp";

    $oldid = &su_user( $pg_user );
    die $LASTERROR unless ( defined $oldid );

    $dbh = &connect_to_db( $pg_ds, $pg_user );
    die $LASTERROR unless( $dbh );

    $status = &exists_database( $dbh, $db_baracus);
    die $LASTERROR unless ( defined $status );
    if ( $status ) {
        die $LASTERROR unless( &drop_database( $dbh, $db_baracus ));
    }

    $status = &exists_database( $dbh, $db_sqltftp );
    die $LASTERROR unless( defined $status );
    if ( $status ) {
        die $LASTERROR unless( &drop_database( $dbh, $db_sqltftp, $role));
    }

    $status = &exists_role( $dbh, $role );
    die $LASTERROR unless( defined $status );
    if ( $status ) {
        die $LASTERROR unless( &drop_role( $dbh, $role ));
    }

    die $LASTERROR unless &disconnect_from_db( $dbh );
}


=item su_user

switch id to user passed
useful for ident sameuser with postgres
return old id on success or undef on fail

=cut

sub su_user {
    my $user  = shift;
    my $oldid = $>;
    my $uid;

    print "su_user: \$user $user \$uid $oldid\n" if $debug;
    unless ( $uid = ( getpwnam( $user ))[2] ) {
        $LASTERROR = "Failed to find passwd entry for $user\n";
        return undef;
    }
    $> = $uid;
    print "\$uid now $uid\n" if $debug;

    return $oldid;
}

=item exists_role

lookup via dbh handle the role passed
return 1 on successful find or '' and undef on failure

=cut

sub exists_role {
    my $dbh = shift;
    my $role = shift;

    print "exists_role: \$dbh $dbh \$role $role\n" if $debug;

    my $row = 0;

    my $exists_role = qq|SELECT COUNT(*) FROM pg_roles WHERE rolname = ?|;

    my $sth = $dbh->prepare( $exists_role );
    unless( $sth ) {
        $LASTERROR = "Unable to prepare exists role query:\n" . $dbh->errstr;
        return undef;
    }
    unless( $sth->execute( $role ) ) {
        $LASTERROR = "Unable to execute exists role statement\n" . $sth->errstr;
        return undef;
    }
    $sth->bind_columns( \$row );
    $sth->fetch();

    $sth->finish;
    undef $sth;

    print "\$row $row\n" if $debug;
    unless( $row ) {
        $LASTERROR = "exists role query returned 0 results";
        return '';
    }

    return $row;
}

=item create_role

create via the dbh handle the role passed
use the remaining args as role options
  SUPERUSER LOGIN etc...
return 1 on successful creation or '' on fail

=cut

sub create_role {
    my $dbh  = shift;
    my $role = shift;
    my $args = join(" ", @_);

    print "create_role: \$dbh $dbh \$role $role \$args $args\n" if $debug;

    my $create_role = qq|CREATE ROLE $role $args|;
    unless( $dbh->do( $create_role )) {
        $LASTERROR = "Unable to create role $role with attribs: $args\n" .
            $dbh->errstr;
        return '';
    }
    return 1;
}

=item drop_role

drop via the dbh handle the role passed
return 1 on successful creation or '' on fail

=cut

sub drop_role {
    my $dbh  = shift;
    my $role = shift;

    print "drop_role: \$dbh $dbh \$role $role\n" if $debug;

    my $drop_role = qq|DROP ROLE $role|;
    unless( $dbh->do( $drop_role )) {
        $LASTERROR = "Unable to drop role $role\n" . $dbh->errstr;
        return '';
    }
    return 1;
}

=item exists_database

lookup database passed
return 1 on successful find or '' on fail

=cut

sub exists_database {
    my $dbh = shift;
    my $dbase = shift;

    print "exists_database: \$dbh $dbh \$dbase $dbase\n" if $debug;

    my $row = 0;

	my $exists_database = qq|SELECT COUNT(*) 
            FROM pg_catalog.pg_database WHERE datname = ?|;

    my $sth = $dbh->prepare( $exists_database );
    unless( $sth ) {
        $LASTERROR = "Unable to prepare exists database query\n" . $dbh->errstr;
        return undef;
    }
    unless( $sth->execute( $dbase )) {
        $LASTERROR = "Unable to execute exists database statement\n" . $sth->errstr;
        return undef;
    }
    $sth->bind_columns( \$row );
    $sth->fetch();

    $sth->finish;
    undef $sth;

    print "\$row $row\n" if $debug;
    unless( $row ) {
        $LASTERROR = "exists database query returned 0 results";
        return '';
    }

    return $row;
}

=item create_database

create via handle the database with owner passed
return 1 on successful creation or '' on fail

=cut

sub create_database {
    my $dbh = shift;
    my $dbase = shift;
    my $owner = shift;

    print "create_database: \$dbh $dbh \$dbase $dbase \$owner $owner\n" if $debug;

    # sql to create instance of database - syntax has issues with ?
    my $create_database = qq|CREATE DATABASE $dbase OWNER $owner|;
    unless( $dbh->do( $create_database )) {
		$LASTERROR = "Unable to create database $dbase with owner $owner\n" .
            $dbh->errstr;
        return '';
    }
    return 1;
}

=item drop_database

drop via handle the database
return 1 on successful creation or '' on fail

=cut

sub drop_database {
    my $dbh = shift;
    my $dbase = shift;

    print "drop_database: \$dbh $dbh \$dbase $dbase\n" if $debug;

    # sql to drop instance of database
    my $drop_database = qq|DROP DATABASE $dbase|;
    unless( $dbh->do( $drop_database )) {
		$LASTERROR = "Unable to drop database $dbase\n" . $dbh->errstr;
        return '';
    }
    return 1;
}

=item connect_to_db

connect to datasource as user passed
return handle on success or '' on fail

=cut

sub connect_to_db
{
    my $datasource = shift;
    my $user = shift;
    my $pass = shift;

    printf "\$datasource $datasource \$user %s \$pass %s\n",
        defined $user ? $user : "",
            defined $pass ? $pass : "";

    my $dbh = DBI->connect( $datasource, $user, $pass );
    unless( $dbh ) {
	    $LASTERROR = sprintf "Error connecting to db $datasource %s %s \n$DBI::errstr",
            defined $user ? $user : "",
                defined $pass ? $pass : "";
        return '';
    }
    return $dbh;
}

=item disconnect_from_db

disconnect from db handle passed
return 1 on success and '' on failure

=cut

sub disconnect_from_db
{
    my $dbh = shift;

	unless( $dbh->disconnect() ) {
	    $LASTERROR = "disconnect failure\n" . $dbh->errstr;
        return '';
    }
    return 1;
}


