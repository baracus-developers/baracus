package Baracus::DB;

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
use strict;
use warnings;
use DBI;

use Dancer qw( :syntax );
use Dancer::Plugin::Database;

# not a traditional module for object encapsulation
# but more a collection of subroutines to interface
# the database so that we can deal with highlevel
# operations consistently (role, database, table).

sub init_baracus_db {

}

=item errstr

return the string holding the last error message

=cut

sub errstr
{
    return (session('opts'))->{LASTERROR};
}

=item su_user

switch id to user passed
useful for ident sameuser with postgres
return id on success or undef on fail

=cut

sub su_user {
    my $user  = shift;
    my $olduid = $>;
    my $uid;

    my $opts = session('opts');

    unless( defined $user ) {
        $opts->{LASTERROR} = "Invalid su_user usage: username is required\n";
        return '';
    }

    debug "su_user: \$user $user \$uid $uid\n" if $opts->{debug};
    unless ( $uid = ( getpwnam( $user ))[2] ) {
        $opts->{LASTERROR} = "Failed to find passwd entry for $user\n";
        return undef;
    }
    $> = $uid;
    debug "\$uid now $uid\n" if $opts->{debug};

    return $olduid;
}

# creates ROLES, DATABASES, TABLES, LANGUAGES for baracus
# to be called on database startup - by baracusdb service

sub startup {

    my $opts = vars->{opts};

    use Baracus::Source qw( :subs );
    use Baracus::Services qw( :subs );
    use Baracus::Mcast qw( :subs );

    my $status = 1;

    my $reverse_flag = $ARGV[0];

    my $pg_user = 'postgres';
    my $pg_db = 'postgres';

    my @args = qw( LOGIN SUPERUSER );


    eval {
        if ( defined $reverse_flag ) {
            &apocalypse( $pg_user, $pg_db, @args );
        } else {
            &genesis( $pg_user, $pg_db, @args );

            $status = Baracus::Source::init_mounter( $opts );
            error "$opts->{LASTERROR} : mount failure\n" if ( $status == 0 ) and die;

            $status = Baracus::Source::init_exporter( $opts );
            error "$opts->{LASTERROR} : export failure\n" if ( $status == 0 ) and die;

            $status = Baracus::Source::prepdbwithxml( $opts );
            error "$opts->{LASTERROR} : prep xml failure\n" if ( $status == 0 ) and die;

            $status = Baracus::Mcast::bamstart( $opts, database, "mcast", "" );
            error "$opts->{LASTERROR} : mcast init failure\n" if ( $status != 0 ) and die;

#            system ( "$baDir{data}/scripts//baconfig_load_autobuild" ) == 0 or die;
#            system ( "$baDir{data}/scripts//baconfig_load_hardware" ) == 0 or die;
#            system ( "$baDir{data}/scripts//baconfig_load_profile" ) == 0 or die;

#            my $cifs_reload = &add_cifs_perl();
#            my $modperl_reload = &add_apache2_perl();
#            if ( $cifs_reload ) {
#                start_or_reload_service( $opts, "smb" );
#            }
#            if ( $modperl_reload ) {
#                start_or_reload_service( $opts, "http" );
#            }
#            &add_www_sudoers();
        }
    };
    if ( $@ ) {
        $opts->{LASTERROR} = $@;
        error $opts->{LASTERROR};
        return 0;
    }
    return 1;
}

sub genesis {
    my $pg_user = shift;
    my $pg_db   = shift;
    my @args = @_;

    my $plpg = "plpgsql";

    my $role = "baracus";
    my $db_baracus = "baracus";

    my $status;
    my $uid;
    my $dbh;

    # save current uid

#    my $suid = $>;

    # switch to user postgres and connect

#    $uid = su_user( $pg_user );
#    die errstr unless ( defined $uid );

    $dbh = database; #connect_db( $pg_db, $pg_user );
    die errstr unless( defined $dbh );

    $status = exists_role( $dbh, $role );
    die errstr unless( defined $status );
    unless( $status ) {
        die errstr
            unless( create_role( $dbh, $role, @args ));
    }

#    $status = exists_role( $dbh, "wwwrun" );
#    die errstr unless( defined $status );
#    unless( $status ) {
#        die errstr
#            unless( create_role( $dbh, "wwwrun", @args ));
#    }

    $status = exists_database( $dbh, $db_baracus);
    die errstr unless ( defined $status );
    unless( $status ) {
        die errstr
            unless( create_database( $dbh, $db_baracus, $role));
    }

#    die errstr unless disconnect_db( $dbh );

    # finished working as user postgres

#    $> = $suid;

    # switch to user baracus

    # connect to sqltftp database

#    $suid = su_user( $role );
#    die errstr unless ( defined $suid );

#    $dbh = connect_db( $db_sqltftp, $role );
#    die errstr unless( $dbh );

    my $hashoftbls;

    $hashoftbls = Baracus::Sql::get_sqltftp_tables();

    while( my ($tbl, $col) = each %{ $hashoftbls } ) {
        $status = exists_table( $dbh, $tbl );
        die errstr unless( defined $status );
        unless( $status ) {
            debug "user $role creating $tbl in db $db_baracus\n";
            die errstr
                unless( create_table( $dbh, $tbl,
                Baracus::Sql::hash2columns( $col )));
        }
    }

#    die errstr unless disconnect_db( $dbh );

    # connect to baracus database

#    $dbh = connect_db( $db_baracus, $role );
#    die errstr unless( $dbh );

    $hashoftbls = Baracus::Sql::get_baracus_tables();

    while( my ($tbl, $col) = each %{ $hashoftbls } ) {
        $status = exists_table( $dbh, $tbl );
        die errstr unless( defined $status );
        unless( $status ) {
            debug "user $role creating $tbl in db $db_baracus\n";
            die errstr
                unless( create_table( $dbh, $tbl,
                Baracus::Sql::hash2columns( $col )));
        }
    }


    # make sure the language we define functions in is loaded

    $status = exists_language( $dbh, $plpg );
    die errstr unless( defined $status );
    unless( $status ) {
        die errstr
            unless( create_language( $dbh, $plpg ));
    }

    # create/replace the functions for use by our triggers

    my $hashoffuncs = Baracus::Sql::get_baracus_functions();
    while( my ($name, $def) = each %{ $hashoffuncs } ) {
        die errstr
            unless( create_or_replace_function( $dbh, $name, $def ));
    }

    # add the triggers

    my $hashoftgs = Baracus::Sql::get_baracus_triggers();

    while( my ($tg, $sql) = each %{ $hashoftgs } ) {
        $status = exists_trigger( $dbh, $tg );
        die errstr unless( defined $status );
        unless( $status ) {
            die errstr
                unless( create_trigger( $dbh, $tg, $sql ));
        }
    }

#    die errstr unless disconnect_db( $dbh );

    # finished working as user baracus

#    $> = $suid;
}

sub apocalypse {
    my $pg_user = shift;
    my $pg_db   = shift;
    my @args = @_;

    my $plpg = "plpgsql";

    my $role = "baracus";
    my $db_baracus = "baracus";

    my $status;
    my $uid;
    my $dbh;

    # switch to user postgres and connect

#    $uid = su_user( $pg_user );
#    die errstr unless ( defined $uid );

    $dbh = database; #connect_db( $pg_db, $pg_user );
    die errstr unless( $dbh );

    $status = exists_database( $dbh, $db_baracus);
    die errstr unless ( defined $status );
    if ( $status ) {
        die errstr
            unless( drop_database( $dbh, $db_baracus ));
    }

#    $status = exists_database( $dbh, $db_sqltftp );
#    die errstr unless( defined $status );
#    if ( $status ) {
#        die errstr
#            unless( drop_database( $dbh, $db_sqltftp, $role));
#    }

    $status = exists_role( $dbh, $role );
    die errstr unless( defined $status );
    if ( $status ) {
        die errstr
            unless( drop_role( $dbh, $role ));
    }

#    die errstr unless disconnect_db( $dbh );

    # finished working as user postgres

#    $> = $uid;
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

    my $opts = session('opts');

    unless( defined $dbase ) {
        $opts->{LASTERROR} = "Invalid connect_db usage: database name is required\n";
        return undef;
    }

    my $datasource = "DBI:Pg:dbname=$dbase;port=5162";

    my $str = sprintf "\$datasource $datasource \$user %s \$pass %s\n",
        defined $user ? $user : "",
            defined $pass ? $pass : "";

    debug $str if $opts->{debug};

    my $dbh = DBI->connect( $datasource, $user, $pass );
    unless( $dbh ) {
	    $opts->{LASTERROR} = sprintf "Error connecting to $str: $!";
        error $opts->{LASTERROR};
        return undef;
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid disconnect usage: database handle required\n";
        return undef;
    }

	unless( $dbh->disconnect() ) {
	    $opts->{LASTERROR} = "disconnect failure\n" . $dbh->errstr;
        return undef;
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid exists_role usage: database handle required\n";
        return undef;
    }

    unless( defined $role ) {
        $opts->{LASTERROR} = "Invalid exists_role usage: role is required\n";
        return undef;
    }

    debug "exists_role: \$dbh $dbh \$role $role\n" if $opts->{debug};

    my $exists_role = qq|SELECT COUNT(*) FROM pg_roles WHERE rolname = ?|;

    my $sth = $dbh->prepare( $exists_role );
    unless( $sth ) {
        $opts->{LASTERROR} = "Unable to prepare exists role query:\n" . $dbh->errstr;
        return undef;
    }
    unless( $sth->execute( $role ) ) {
        $opts->{LASTERROR} = "Unable to execute exists role statement\n" . $sth->errstr;
        return undef;
    }
    my $row;
    $sth->bind_columns( \$row );
    $sth->fetch();

    $sth->finish;
    undef $sth;

    debug "\$row $row\n" if $opts->{debug};
    unless( $row ) {
        $opts->{LASTERROR} = "Exists role query returned 0 results\n";
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid create_role usage: database handle required\n";
        return '';
    }
    unless( defined $role ) {
        $opts->{LASTERROR} = "Invalid create_role usage: role is required\n";
        return '';
    }
    debug "create_role: \$dbh $dbh \$role $role \$args $args\n" if $opts->{debug};

    my $create_role = qq|CREATE ROLE $role $args|;
    unless( $dbh->do( $create_role )) {
        $opts->{LASTERROR} = "Unable to create role $role with attribs: $args\n" .
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid drop_role usage: database handle required\n";
        return '';
    }
    unless( defined $role ) {
        $opts->{LASTERROR} = "Invalid drop_role usage: role is required\n";
        return '';
    }
    debug "drop_role: \$dbh $dbh \$role $role\n" if $opts->{debug};

    my $drop_role = qq|DROP ROLE $role|;
    unless( $dbh->do( $drop_role )) {
        $opts->{LASTERROR} = "Unable to drop role $role\n" . $dbh->errstr;
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid exists_database usage: database handle required\n";
        return undef;
    }
    unless( defined $dbase ) {
        $opts->{LASTERROR} = "Invalid exists_database usage: database name required\n";
        return undef;
    }
    debug "exists_database: \$dbh $dbh \$dbase $dbase\n" if $opts->{debug};

	my $exists_database = qq|SELECT COUNT(*)
        FROM pg_catalog.pg_database WHERE datname = ?|;

    my $sth = $dbh->prepare( $exists_database );
    unless( $sth ) {
        $opts->{LASTERROR} = "Unable to prepare exists database query\n" . $dbh->errstr;
        return undef;
    }
    unless( $sth->execute( $dbase )) {
        $opts->{LASTERROR} = "Unable to execute exists database statement\n" . $sth->errstr;
        return undef;
    }
    my $row;
    $sth->bind_columns( \$row );
    $sth->fetch();

    $sth->finish;
    undef $sth;

    debug "\$row $row\n" if $opts->{debug};
    unless( $row ) {
        $opts->{LASTERROR} = "Exists database query returned 0 results\n";
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid create_database usage: database handle required\n";
        return '';
    }
    unless( defined $dbase ) {
        $opts->{LASTERROR} = "Invalid create_database usage: database name required\n";
        return '';
    }
    unless( defined $owner ) {
        $opts->{LASTERROR} = "Invalid create_database usage: database owner required\n";
        return '';
    }
    debug "create_database: \$dbh $dbh \$dbase $dbase \$owner $owner\n" if $opts->{debug};

    # sql to create instance of database - syntax has issues with ?
    my $create_database = qq|CREATE DATABASE $dbase OWNER $owner|;
    unless( $dbh->do( $create_database )) {
		$opts->{LASTERROR} = "Unable to create database $dbase with owner $owner\n" .
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid drop_database usage: database handle required\n";
        return '';
    }
    unless( defined $dbase ) {
        $opts->{LASTERROR} = "Invalid drop_database usage: database name required\n";
        return '';
    }
    debug "drop_database: \$dbh $dbh \$dbase $dbase\n" if $opts->{debug};

    # sql to drop instance of database
    my $drop_database = qq|DROP DATABASE $dbase|;
    unless( $dbh->do( $drop_database )) {
		$opts->{LASTERROR} = "Unable to drop database $dbase\n" . $dbh->errstr;
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid exists_table usage: database handle required\n";
        return undef;
    }
    unless( defined $tbl ) {
        $opts->{LASTERROR} = "Invalid exists_table usage: table name required\n";
        return undef;
    }
    debug "exists_table: \$dbh $dbh \$tbl $tbl\n" if $opts->{debug};

    my $exist_table = qq|SELECT count(*)
        FROM pg_catalog.pg_tables WHERE tablename = ?|;

    my $sth = $dbh->prepare( $exist_table );
    unless( $sth ) {
        $opts->{LASTERROR} = "Unable to prepare exists table query\n" . $dbh->errstr;
        return undef;
    }
    unless( $sth->execute( $tbl )) {
        $opts->{LASTERROR} = "Unable to execute exists table statement\n" . $sth->errstr;
        return undef;
    }
    my $row;
    $sth->bind_columns( \$row );
    $sth->fetch();

    $sth->finish;
    undef $sth;

    debug "\$row $row\n" if $opts->{debug};
    unless( $row ) {
        $opts->{LASTERROR} = "Exists table query returned 0 results\n";
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid create_table usage: database handle required\n";
        return '';
    }
    unless( defined $tbl ) {
        $opts->{LASTERROR} = "Invalid create_table usage: table name required\n";
        return '';
    }
    unless( defined $col ) {
        $opts->{LASTERROR} = "Invalid create_table usage: table columns required\n";
        return '';
    }
    debug "create_table: \$dbh $dbh \$tbl $tbl \$col $col\n" if $opts->{debug};

    my $create_table = qq|CREATE TABLE $tbl ( $col )|;

    unless( $dbh->do( $create_table ) ) {
		$opts->{LASTERROR} = "Unable to create table $tbl with columns $col\n" .
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid drop_database usage: database handle required\n";
        return '';
    }
    unless( defined $tbl ) {
        $opts->{LASTERROR} = "Invalid drop_database usage: table name required\n";
        return '';
    }
    debug "drop_table: \$dbh $dbh \$tbl $tbl\n" if $opts->{debug};

    my $drop_table = qq|DROP TABLE $tbl|;

    unless( $dbh->do( $drop_table )) {
		$opts->{LASTERROR} = "Unable to drop table $tbl\n" . $dbh->errstr;
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid exists_language usage: database handle required\n";
        return undef;
    }
    unless( defined $lang ) {
        $opts->{LASTERROR} = "Invalid exists_language usage: language name required\n";
        return undef;
    }
    debug "exists_language: \$dbh $dbh \$lang $lang\n" if $opts->{debug};

	my $exists_language = qq|SELECT COUNT(*)
        FROM pg_catalog.pg_language WHERE lanname = ?|;

    my $sth = $dbh->prepare( $exists_language );
    unless( $sth ) {
        $opts->{LASTERROR} = "Unable to prepare exists language query\n" . $dbh->errstr;
        return undef;
    }
    unless( $sth->execute( $lang )) {
        $opts->{LASTERROR} = "Unable to execute exists language statement\n" . $sth->errstr;
        return undef;
    }
    my $row;
    $sth->bind_columns( \$row );
    $sth->fetch();

    $sth->finish;
    undef $sth;

    debug "\$row $row\n" if $opts->{debug};
    unless( $row ) {
        $opts->{LASTERROR} = "Exists language query returned 0 results\n";
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid create_language usage: database handle required\n";
        return '';
    }
    unless( defined $lang ) {
        $opts->{LASTERROR} = "Invalid create_language usage: language name required\n";
        return '';
    }
    debug "create_language: \$dbh $dbh \$lang $lang\n" if $opts->{debug};

    # sql to create instance of language - syntax has issues with ?
    my $create_language = qq|CREATE LANGUAGE $lang |;
    unless( $dbh->do( $create_language )) {
		$opts->{LASTERROR} = "Unable to create language $lang\n" . $dbh->errstr;
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid drop_language usage: database handle required\n";
        return '';
    }
    unless( defined $lang ) {
        $opts->{LASTERROR} = "Invalid drop_language usage: language name required\n";
        return '';
    }
    debug "drop_language: \$dbh $dbh \$lang $lang\n" if $opts->{debug};

    # sql to drop instance of language
    my $drop_language = qq|DROP LANGUAGE $lang|;
    unless( $dbh->do( $drop_language )) {
		$opts->{LASTERROR} = "Unable to drop language $lang\n" . $dbh->errstr;
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
    my $opts = session('opts');

    my $create_or_replace_function = qq|CREATE OR REPLACE FUNCTION $func $def|;
    unless( $dbh->do( $create_or_replace_function )) {
        $opts->{LASTERROR} = "Unable to create/replace function $func\n" .
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid exists_trigger usage: database handle required\n";
        return undef;
    }

    unless( defined $trigger ) {
        $opts->{LASTERROR} = "Invalid exists_trigger usage: trigger is required\n";
        return undef;
    }

    debug "exists_trigger: \$dbh $dbh \$trigger $trigger\n" if $opts->{debug};

    my $exists_trigger = qq|SELECT COUNT(*) FROM pg_catalog.pg_trigger WHERE tgname = ?|;

    my $sth = $dbh->prepare( $exists_trigger );
    unless( $sth ) {
        $opts->{LASTERROR} = "Unable to prepare exists trigger query:\n" . $dbh->errstr;
        return undef;
    }
    unless( $sth->execute( $trigger ) ) {
        $opts->{LASTERROR} = "Unable to execute exists trigger statement\n" . $sth->errstr;
        return undef;
    }
    my $row;
    $sth->bind_columns( \$row );
    $sth->fetch();

    $sth->finish;
    undef $sth;

    debug "\$row $row\n" if $opts->{debug};
    unless( $row ) {
        $opts->{LASTERROR} = "Exists trigger query returned 0 results\n";
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid create_trigger usage: database handle required\n";
        return '';
    }
    unless( defined $trigger ) {
        $opts->{LASTERROR} = "Invalid create_trigger usage: trigger is required\n";
        return '';
    }
    unless( defined $sql ) {
        $opts->{LASTERROR} = "Invalid create_trigger usage: sql is required\n";
        return '';
    }
    debug "create_trigger: \$dbh $dbh \$trigger $trigger \$sql $sql\n" if $opts->{debug};

    my $create_trigger = qq|CREATE TRIGGER $trigger $sql|;
    unless( $dbh->do( $create_trigger )) {
        $opts->{LASTERROR} = "Unable to create trigger $trigger with sql $sql\n" .
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

    my $opts = session('opts');

    unless( defined $dbh ) {
        $opts->{LASTERROR} = "Invalid drop_trigger usage: database handle required\n";
        return '';
    }
    unless( defined $trigger ) {
        $opts->{LASTERROR} = "Invalid drop_trigger usage: trigger is required\n";
        return '';
    }
    debug "drop_trigger: \$dbh $dbh \$trigger $trigger\n" if $opts->{debug};

    my $drop_trigger = qq|DROP TRIGGER $trigger|;
    unless( $dbh->do( $drop_trigger )) {
        $opts->{LASTERROR} = "Unable to drop trigger $trigger\n" . $dbh->errstr;
        return '';
    }
    return 1;
}

true;

__END__
