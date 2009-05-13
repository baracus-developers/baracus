package BaracusDB;

use 5.006;
use Carp;
use strict;
use warnings;
use DBI;

# not a traditional module for object encapsulation
# but more a collection of subroutines to interface
# the database so that we can deal with highlevel
# operations consistently (role, database, table).

my $debug;
my $dsprefix = "DBI:Pg:dbname";

our $LASTERROR;

=item errstr

return the string holding the last error message

=cut

sub errstr
{
    return $LASTERROR;
}

=item su_user

switch id to user passed
useful for ident sameuser with postgres
return id on success or undef on fail

=cut

sub su_user {
    my $user  = shift;
    my $uid = $>;

    unless( defined $user ) {
        $LASTERROR = "Invalid su_user usage: username is required\n";
        return '';
    }

    print "su_user: \$user $user \$uid $uid\n" if $debug;
    unless ( $uid = ( getpwnam( $user ))[2] ) {
        $LASTERROR = "Failed to find passwd entry for $user\n";
        return undef;
    }
    $> = $uid;
    print "\$uid now $uid\n" if $debug;

    return $uid;
}

=item connect_db

connect to datasource as user passed
return handle on success or '' on fail

=cut

sub connect_db
{
    my $dbase = shift;
    my $user = shift;
    my $pass = shift;

    unless( defined $dbase ) {
        $LASTERROR = "Invalid connect_db usage: database name is required\n";
        return '';
    }

    my $datasource = "$dsprefix=$dbase";

    printf "\$datasource $datasource \$user %s \$pass %s\n",
        defined $user ? $user : "",
            defined $pass ? $pass : "" if $debug;

    my $dbh = DBI->connect( $datasource, $user, $pass );
    unless( $dbh ) {
	    $LASTERROR = sprintf "Error connecting to db $datasource %s %s \n$DBI::errstr",
            defined $user ? $user : "",
                defined $pass ? $pass : "";
        return '';
    }
    return $dbh;
}

=item disconnect_db

disconnect from db handle passed
return 1 on success and '' on failure

=cut

sub disconnect_db
{
    my $dbh = shift;

    unless( defined $dbh ) {
        $LASTERROR = "Invalid disconnect usage: database handle required\n";
        return '';
    }

	unless( $dbh->disconnect() ) {
	    $LASTERROR = "disconnect failure\n" . $dbh->errstr;
        return '';
    }
    return 1;
}

=item exists_role

lookup via dbh handle the role passed
return 1 on successful find or '' and undef on failure

=cut

sub exists_role {
    my $dbh = shift;
    my $role = shift;

    unless( defined $dbh ) {
        $LASTERROR = "Invalid exists_role usage: database handle required\n";
        return undef;
    }

    unless( defined $role ) {
        $LASTERROR = "Invalid exists_role usage: role is required\n";
        return undef;
    }

    print "exists_role: \$dbh $dbh \$role $role\n" if $debug;

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
    my $row;
    $sth->bind_columns( \$row );
    $sth->fetch();

    $sth->finish;
    undef $sth;

    print "\$row $row\n" if $debug;
    unless( $row ) {
        $LASTERROR = "Exists role query returned 0 results\n";
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

    unless( defined $dbh ) {
        $LASTERROR = "Invalid create_role usage: database handle required\n";
        return '';
    }
    unless( defined $role ) {
        $LASTERROR = "Invalid create_role usage: role is required\n";
        return '';
    }
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

    unless( defined $dbh ) {
        $LASTERROR = "Invalid drop_role usage: database handle required\n";
        return '';
    }
    unless( defined $role ) {
        $LASTERROR = "Invalid drop_role usage: role is required\n";
        return '';
    }
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
return 1 on successful find or '' on not found and undef on failure

=cut

sub exists_database {
    my $dbh = shift;
    my $dbase = shift;

    unless( defined $dbh ) {
        $LASTERROR = "Invalid exists_database usage: database handle required\n";
        return undef;
    }
    unless( defined $dbase ) {
        $LASTERROR = "Invalid exists_database usage: database name required\n";
        return undef;
    }
    print "exists_database: \$dbh $dbh \$dbase $dbase\n" if $debug;

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
    my $row;
    $sth->bind_columns( \$row );
    $sth->fetch();

    $sth->finish;
    undef $sth;

    print "\$row $row\n" if $debug;
    unless( $row ) {
        $LASTERROR = "Exists database query returned 0 results\n";
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

    unless( defined $dbh ) {
        $LASTERROR = "Invalid create_database usage: database handle required\n";
        return '';
    }
    unless( defined $dbase ) {
        $LASTERROR = "Invalid create_database usage: database name required\n";
        return '';
    }
    unless( defined $owner ) {
        $LASTERROR = "Invalid create_database usage: database owner required\n";
        return '';
    }
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
return 1 on successful drop or '' on fail

=cut

sub drop_database {
    my $dbh = shift;
    my $dbase = shift;

    unless( defined $dbh ) {
        $LASTERROR = "Invalid drop_database usage: database handle required\n";
        return '';
    }
    unless( defined $dbase ) {
        $LASTERROR = "Invalid drop_database usage: database name required\n";
        return '';
    }
    print "drop_database: \$dbh $dbh \$dbase $dbase\n" if $debug;

    # sql to drop instance of database
    my $drop_database = qq|DROP DATABASE $dbase|;
    unless( $dbh->do( $drop_database )) {
		$LASTERROR = "Unable to drop database $dbase\n" . $dbh->errstr;
        return '';
    }
    return 1;
}

=item exists_table

lookup table name passed
return 1 on successful find or '' on not found and undef on lookup failure

=cut

sub exists_table
{
    my $dbh = shift;
    my $tbl = shift;

    unless( defined $dbh ) {
        $LASTERROR = "Invalid exists_table usage: database handle required\n";
        return undef;
    }
    unless( defined $tbl ) {
        $LASTERROR = "Invalid exists_table usage: table name required\n";
        return undef;
    }
    print "exists_table: \$dbh $dbh \$tbl $tbl\n" if $debug;

    my $exist_table = qq|SELECT count(*)
        FROM pg_catalog.pg_tables WHERE tablename = ?|;

    my $sth = $dbh->prepare( $exist_table );
    unless( $sth ) {
        $LASTERROR = "Unable to prepare exists table query\n" . $dbh->errstr;
        return undef;
    }
    unless( $sth->execute( $tbl )) {
        $LASTERROR = "Unable to execute exists table statement\n" . $sth->errstr;
        return undef;
    }
    my $row;
    $sth->bind_columns( \$row );
    $sth->fetch();

    $sth->finish;
    undef $sth;

    print "\$row $row\n" if $debug;
    unless( $row ) {
        $LASTERROR = "Exists table query returned 0 results\n";
        return '';
    }

    return $row;
}


=item create_table

create via handle the table with columns/schema passed
return 1 on successful creation or '' on fail

=cut

sub create_table
{
    my $dbh = shift;
    my $tbl = shift;
    my $col = shift;

    unless( defined $dbh ) {
        $LASTERROR = "Invalid create_table usage: database handle required\n";
        return '';
    }
    unless( defined $tbl ) {
        $LASTERROR = "Invalid create_table usage: table name required\n";
        return '';
    }
    unless( defined $col ) {
        $LASTERROR = "Invalid create_table usage: table columns required\n";
        return '';
    }
    print "create_table: \$dbh $dbh \$tbl $tbl \$col $col\n" if $debug;

    my $create_table = qq|CREATE TABLE $tbl ( $col )|;

    unless( $dbh->do( $create_table ) ) {
		$LASTERROR = "Unable to create table $tbl with columns $col\n" .
            $dbh->errstr;
        return '';
    }
    return 1;
}

=item drop_table

drop via handle the table passed
return 1 on successful creation or '' on fail

=cut

sub drop_table
{
    my $dbh = shift;
    my $tbl = shift;

    unless( defined $dbh ) {
        $LASTERROR = "Invalid drop_database usage: database handle required\n";
        return '';
    }
    unless( defined $tbl ) {
        $LASTERROR = "Invalid drop_database usage: table name required\n";
        return '';
    }
    print "drop_table: \$dbh $dbh \$tbl $tbl\n" if $debug;

    my $drop_table = qq|DROP TABLE $tbl|;

    unless( $dbh->do( $drop_table )) {
		$LASTERROR = "Unable to drop table $tbl\n" . $dbh->errstr;
        return '';
    }
    return 1;
}

=item exists_language

lookup language passed
return 1 on successful find or '' on not found and undef on failure

=cut

sub exists_language {
    my $dbh = shift;
    my $lang = shift;

    unless( defined $dbh ) {
        $LASTERROR = "Invalid exists_language usage: database handle required\n";
        return undef;
    }
    unless( defined $lang ) {
        $LASTERROR = "Invalid exists_language usage: language name required\n";
        return undef;
    }
    print "exists_language: \$dbh $dbh \$lang $lang\n" if $debug;

	my $exists_language = qq|SELECT COUNT(*)
        FROM pg_catalog.pg_language WHERE lanname = ?|;

    my $sth = $dbh->prepare( $exists_language );
    unless( $sth ) {
        $LASTERROR = "Unable to prepare exists language query\n" . $dbh->errstr;
        return undef;
    }
    unless( $sth->execute( $lang )) {
        $LASTERROR = "Unable to execute exists language statement\n" . $sth->errstr;
        return undef;
    }
    my $row;
    $sth->bind_columns( \$row );
    $sth->fetch();

    $sth->finish;
    undef $sth;

    print "\$row $row\n" if $debug;
    unless( $row ) {
        $LASTERROR = "Exists language query returned 0 results\n";
        return '';
    }

    return $row;
}

=item create_language

create via handle the language
return 1 on successful creation or '' on fail

=cut

sub create_language {
    my $dbh = shift;
    my $lang = shift;

    unless( defined $dbh ) {
        $LASTERROR = "Invalid create_language usage: database handle required\n";
        return '';
    }
    unless( defined $lang ) {
        $LASTERROR = "Invalid create_language usage: language name required\n";
        return '';
    }
    print "create_language: \$dbh $dbh \$lang $lang\n" if $debug;

    # sql to create instance of language - syntax has issues with ?
    my $create_language = qq|CREATE LANGUAGE $lang |;
    unless( $dbh->do( $create_language )) {
		$LASTERROR = "Unable to create language $lang\n" . $dbh->errstr;
        return '';
    }
    return 1;
}

=item drop_language

drop via handle the language
return 1 on successful drop or '' on fail

=cut

sub drop_language {
    my $dbh = shift;
    my $lang = shift;

    unless( defined $dbh ) {
        $LASTERROR = "Invalid drop_language usage: database handle required\n";
        return '';
    }
    unless( defined $lang ) {
        $LASTERROR = "Invalid drop_language usage: language name required\n";
        return '';
    }
    print "drop_language: \$dbh $dbh \$lang $lang\n" if $debug;

    # sql to drop instance of language
    my $drop_language = qq|DROP LANGUAGE $lang|;
    unless( $dbh->do( $drop_language )) {
		$LASTERROR = "Unable to drop language $lang\n" . $dbh->errstr;
        return '';
    }
    return 1;
}

=item create_or_replace_function

create the functions needed for triggers

=cut

sub create_or_replace_function {
    my $dbh = shift;
    my $func = shift;
    my $def = shift;
    my $create_or_replace_function = qq|CREATE OR REPLACE FUNCTION $func $def|;
    unless( $dbh->do( $create_or_replace_function )) {
        $LASTERROR = "Unable to create/replace function $func\n" .
            "with definition\n $def\n" . $dbh->errstr;
        return '';
    }
    return 1;
}

=item exists_trigger

lookup via dbh handle the trigger passed
return 1 on successful find or '' and undef on failure

=cut

sub exists_trigger {
    my $dbh = shift;
    my $trigger = shift;

    unless( defined $dbh ) {
        $LASTERROR = "Invalid exists_trigger usage: database handle required\n";
        return undef;
    }

    unless( defined $trigger ) {
        $LASTERROR = "Invalid exists_trigger usage: trigger is required\n";
        return undef;
    }

    print "exists_trigger: \$dbh $dbh \$trigger $trigger\n" if $debug;

    my $exists_trigger = qq|SELECT COUNT(*) FROM pg_catalog.pg_trigger WHERE tgname = ?|;

    my $sth = $dbh->prepare( $exists_trigger );
    unless( $sth ) {
        $LASTERROR = "Unable to prepare exists trigger query:\n" . $dbh->errstr;
        return undef;
    }
    unless( $sth->execute( $trigger ) ) {
        $LASTERROR = "Unable to execute exists trigger statement\n" . $sth->errstr;
        return undef;
    }
    my $row;
    $sth->bind_columns( \$row );
    $sth->fetch();

    $sth->finish;
    undef $sth;

    print "\$row $row\n" if $debug;
    unless( $row ) {
        $LASTERROR = "Exists trigger query returned 0 results\n";
        return '';
    }

    return $row;
}

=item create_trigger

create via the dbh handle the trigger passed
return 1 on successful creation or '' on fail

=cut

sub create_trigger {
    my $dbh  = shift;
    my $trigger = shift;
    my $sql = shift;

    unless( defined $dbh ) {
        $LASTERROR = "Invalid create_trigger usage: database handle required\n";
        return '';
    }
    unless( defined $trigger ) {
        $LASTERROR = "Invalid create_trigger usage: trigger is required\n";
        return '';
    }
    unless( defined $sql ) {
        $LASTERROR = "Invalid create_trigger usage: sql is required\n";
        return '';
    }
    print "create_trigger: \$dbh $dbh \$trigger $trigger \$sql $sql\n" if $debug;

    my $create_trigger = qq|CREATE TRIGGER $trigger $sql|;
    unless( $dbh->do( $create_trigger )) {
        $LASTERROR = "Unable to create trigger $trigger with sql $sql\n" .
            $dbh->errstr;
        return '';
    }
    return 1;
}

=item drop_trigger

drop via the dbh handle the trigger passed
return 1 on successful creation or '' on fail

=cut

sub drop_trigger {
    my $dbh  = shift;
    my $trigger = shift;

    unless( defined $dbh ) {
        $LASTERROR = "Invalid drop_trigger usage: database handle required\n";
        return '';
    }
    unless( defined $trigger ) {
        $LASTERROR = "Invalid drop_trigger usage: trigger is required\n";
        return '';
    }
    print "drop_trigger: \$dbh $dbh \$trigger $trigger\n" if $debug;

    my $drop_trigger = qq|DROP TRIGGER $trigger|;
    unless( $dbh->do( $drop_trigger )) {
        $LASTERROR = "Unable to drop trigger $trigger\n" . $dbh->errstr;
        return '';
    }
    return 1;
}

1;
__END__
