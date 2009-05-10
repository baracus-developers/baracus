package SqlFS;

use 5.006;
use Carp;
use strict;
use warnings;

use DBI;

=head1 NAME

SqlFS - rudimentary filesystem in a DBI fronted database

=head1 SYNOPSIS

SqlFS provides a frontend to a database with filesystem primitives
like read and write, all hiding the sql and chunking of larger files.

Arguments for this database are the same as that to connect to a
database.  Which is what this object does with a new invocation.

What's more is that the database is created and table defined but
nothing about it need be made public.  The whole point of this
module is to provide filesystem like open, read, write, ls, rm like
view of the files stored within the database.

=cut

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration   use SqlFS ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = (
                    'all' => [ ]
                    );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw( );

our $VERSION = '0.01';

=item new

With a new SqlFS object a new connection is made to the datasource
provided using the username and password optionally passed.

  my $sqlfsOBJ = SqlFS->new(   'DataSource' => 'DBI:dbtype:file;etc',
                             [ 'User'       => 'DBI db username' ],
                             [ 'Password'   => 'db password'     ],
                             [ 'TableName'  => 'db tablename'    ]
                           );

where the key,value pairs in square brackets are optional.

=cut

my $debug;

our $LASTERROR;

sub new
{
    # create the SqlFS object
    my $self = shift;
    my $class = ref($self) || $self;
    my $dbh;

    # read parameters
    my %cfg = @_;

    # setting defaults
    $cfg{'DataSource'} or croak "\nUsage: \$sqlfsOBJ = SqlFS->new( 'DataSource' => 'dbi data source url' [, 'TableName' => 'default is sqlfstable' ] [, ...] );";
    $cfg{'User'} or $cfg{'User'} = "";
    $cfg{'Password'} or $cfg{'Password'} = "";
    $cfg{'TableName'} or $cfg{'TableName'} = "sqlfstable";

    # BLOB stands for Binary Large Object. It is a field that can
    # store a large amount of data. Its size depends on the
    # implementation. MySQL defines 4 types of BLOB.
    #
    # type         max size
    # ------------ -------------
    # TINYBLOB               255
    # BLOB                65_535
    # MEDIUMBLOB      16_777_215
    # LARGEBLOB    4_294_967_295

    # no BLOB in Pg so we use BYTEA... or uuendoce and TEXT

    # sql to check for instance of table
    my $exists_table = qq|SELECT COUNT(*)
        FROM pg_catalog.pg_tables WHERE tablename = ?|;

    #         id INTEGER NOT NULL PRIMARY KEY is sqlite AUTO_INCREMENT
    #        ( id INTEGER NOT NULL PRIMARY KEY,

    #         KEY name( name )                this additional info not
    #         UNIQUE KEY idname ( id, name )  supported by sqlite syntax

    #         no AUTO_INCREMENT in pg - we have to create a sequence
    #         we'll be explicit as SERIAL has 'warnings'

    # sql to create a sequence - for autoincrement of 'id'
#    my $create_sequence = qq|CREATE SEQUENCE $cfg{'TableName'}_id_seq|;

    #   was  ( id INT DEFAULT NEXTVAL($cfg{'TableName'}_id_seq) PRIMARY KEY,

    # sql to create the table
    my $create_table = qq|CREATE TABLE $cfg{'TableName'}
                          ( id SERIAL PRIMARY KEY,
                            name VARCHAR(64) NOT NULL,
                            description VARCHAR(32),
                            bin VARCHAR,
                            enabled INTEGER,
                            insertion TIMESTAMP,
                            change TIMESTAMP
                          ) |;

    # sql to drop the sequence
#    my $destroy_sequence = qq|DROP SEQUENCE $cfg{'TableName'}_id_seq|;

    # sql to drop the table
    my $destroy_table = qq|DROP TABLE $cfg{'TableName'}|;

    # sql for file present check
    my $file_find = qq|SELECT COUNT (*)
                       FROM $cfg{'TableName'}
                       WHERE name = ?
                      |;

    # sql for file detail - cannot use sum(length(bin)) as 'text' its encoded
    my $file_detail = qq|SELECT name, description, enabled, insertion, change, bin
                         FROM $cfg{'TableName'}
                         WHERE name = ?
                        |;

    # sql for file list - had to hack / avg insertion times that vary with id ?
    my $file_list = qq|SELECT
                       COUNT( id ) as blobs, name, enabled,
                       TIMESTAMP 'epoch' + (AVG(EXTRACT(EPOCH FROM insertion)) * interval '1 second') as create
                       FROM $cfg{'TableName'}
                       WHERE name LIKE ?
                       GROUP BY name, enabled
                      |;

    # remove a file
    my $file_delete = qq|DELETE FROM $cfg{'TableName'} where name = ?|;

    # insert a file
    #    my $file_store = qq|INSERT INTO $cfg{'TableName'}
    #                        (name, description, bin, enabled, insertion, change)
    #                        VALUES ( ?, ?, ?, ?, DATETIME('now'), NULL)
    #                       |;

    my $file_store = qq|INSERT INTO $cfg{'TableName'}
                        (name, description, bin, enabled, insertion, change)
                        VALUES ( ?, ?, ?, ?, CURRENT_TIMESTAMP, NULL)
                       |;

    # select for fetch
    my $file_fetch = qq|SELECT bin
                        FROM $cfg{'TableName'}
                        WHERE name = ?
                        ORDER BY id
                       |;


    # connect to the DBI data source passed
    if (not $dbh = DBI->connect( "$cfg{'DataSource'}",
                                 "$cfg{'User'}",
                                 "$cfg{'Password'}" ) ) {
        carp("Error connecting to database $cfg{'DataSource'} : $DBI::errstr : $@\n");
        return undef;
    }

    $dbh->{'RaiseError'} = 1;

    # logic to check that the table we want to store files in is avail
    my $sth;
    my $row = 0;
    if ( not ( $sth = $dbh->prepare( $exists_table ) ) ) {
        $LASTERROR = "Unable to prepare 'exists' query: ", $dbh->errstr;
        return undef;
    }
    if ( not $sth->execute( $cfg{'TableName'} ) ) {
        $LASTERROR = "Unable to execute 'exists' query: ", $sth->err;
        return undef;
    }
    $sth->bind_columns( \$row );
    $sth->fetch();
    $sth->finish;
    undef $sth;
    if ( $row == 0 ) {
#        if (not $dbh->do( $create_sequence ) ) {
#            carp("Error creating sequence ",$dbh->errstr, $@,"\n");
#            return undef;
#        }
        if (not $dbh->do( $create_table ) ) {
            carp("Error creating table ",$dbh->errstr, $@,"\n");
            return undef;
        }
    }
    # max_allowed_packets a mysql specific construct
    my $maxlen = 1048575;

    #    my $max_pkts = qq|SHOW VARIABLES LIKE "max_allowed_packets"|;
    #    my $rows = $dbh->selectall_arrayref( $max_pkts );
    #    for (@$rows) {
    #        # max_allowed_packet minus a safely calculated size
    #        print $_->[1];
    #        $maxlen = $_->[1] - 100000;
    #    }

    return bless { %cfg,
                   'dbh' => $dbh,
                   '_maxlen_' => $maxlen,
#                   'sql_create_sequence' => $create_sequence,
#                   'sql_destroy_sequence' => $destroy_sequence,
                   'sql_create_table' => $create_table,
                   'sql_destroy_table' => $destroy_table,
                   'sql_file_detail' => $file_detail,
                   'sql_file_list' => $file_list,
                   'sql_file_delete' => $file_delete,
                   'sql_file_store' => $file_store,
                   'sql_file_fetch' => $file_fetch,
                   'sql_file_find' => $file_find
                  }, $class;
}

sub discard {
    # disconnect
    my $self  = shift;

    $self->{'dbh'}->disconnect()
        || warn "disconnect failure: ", $self->{'dbh'}->errstr ;

    undef $self
}


=item bytea_encode

encode bytestream for VARCHAR storage

=cut

sub bytea_encode
{
    my ($in, $out);
    $in = shift;
    $out = pack( 'u', $in);
    return $out;
}

=item bytea_decode

decode bytestream for VARCHAR storage

=cut

sub bytea_decode
{
    my ($in,$out);
    $in = shift;
    $out = unpack( 'u', $in );
    return $out;
}

=item destroy

destroy provides a method to remove all files in the database. use with caution.
return non-zero on error

=cut

sub destroy
{
    my $self  = shift;

    if (not $self->{'dbh'}->do( $self->{'sql_destroy_table'} ) ) {
        $LASTERROR = "Error table drop on destroy $self->{'dbh'}->errstr: $@\n";
        return 1;
    }
#    if (not $self->{'dbh'}->do( $self->{'sql_destroy_sequence'} ) ) {
#        $LASTERROR = "Error sequence drop on destroy $self->{'dbh'}->errstr: $@\n";
#        return 1;
#    }
#    if (not $self->{'dbh'}->do( $self->{'sql_create_sequence'} ) ) {
#        $LASTERROR = "Error re-creating sequence $self->{'dbh'}->errstr: $@\n";
#        return 1;
#    }
    if (not $self->{'dbh'}->do( $self->{'sql_create_table'} ) ) {
        $LASTERROR = "Error re-creating empty table $self->{'dbh'}->errstr: $@\n";
        return 1;
    }
    return 0;
}

=item find

return 0 if no filename found
return <rowcount> if filename found

   sqlfsOBJ->find( $name )

=cut

sub find
{
    my $self = shift;
    my $name = shift;
    my $row = 0;
    my $sth;

    if ( not ( $sth = $self->{'dbh'}->prepare( $self->{'sql_file_find'} ) ) ) {
        $LASTERROR = "Unable to prepare 'find' query: $self->{'dbh'}->errstr";
        return undef;
    }

    $name =~ s|.*/||;           # only the short name for the lookup
    if ( not $sth->execute( $name ) ) {
        $LASTERROR = "Unable to execute 'find' query: $sth->err";
        return undef;
    }

    $sth->bind_columns( \$row );
    $sth->fetch();

    $sth->finish;
    undef $sth;

    return $row;
}

=item detail

get files details from the database
return undef on error or return a hashref of key,value pairs using keys:

   name, description, enabled, insertdate, changedate, rowcount, binsize

=cut

sub detail
{
    my $self  = shift;
    my $name  = shift;
    my $hash  = {};
    my $sth;

    if ( not ( $sth = $self->{'dbh'}->prepare( $self->{'sql_file_detail'} ) ) ) {
        $LASTERROR = "Unable to prepare 'detail' query: $self->{'dbh'}->errstr";
        return undef;
    }

    $name =~ s|.*/||;       # only the short name for the lookup
    #    print "fetching details for $name\n";

    if ( not $sth->execute( $name ) ) {
        $LASTERROR = "Unable to execute 'detail' query: $sth->err";
        return undef;
    }

    my $array_lol = $sth->fetchall_arrayref( );

    if (not scalar @{ $array_lol } ) {
        if ($debug) {
            carp "File $name not found in SqlFS db\n";
        }
        return undef;
    }

    $hash->{'rowcount'} = 0;
    $hash->{'binsize'} = 0;
    my $flag_first = 1;
    foreach my $ar ( @{ $array_lol } ) {
        my ($nm, $des, $ena, $idate, $cdate, $bin) = @{ $ar };
        $hash->{'rowcount'} += 1;
        $hash->{'binsize'} += length &bytea_decode( $bin );
        if ( $flag_first == 1 ) {
            $flag_first = 0;
            $hash->{'name'} = $nm;
            $hash->{'enabled'} = $ena;
            $hash->{'insertdate'} = $idate;
            $hash->{'changedate'} = $cdate;
            $hash->{'description'} = $des;
        }
    }

    $sth->finish;
    undef $sth;

    return $hash;
}

=item list_start list_next list_finish

list the files like the name passed, or all if none

list_start takes a string (none, partial, full name), returns a stmt handle
list_next takes the stmt handle, returns a hash of match details or undef
list_finish takes the stmt handle, no return

=cut

sub list_start
{
    my $self  = shift;
    my $name  = shift;
    my $sth;

    if ( not ( $sth = $self->{'dbh'}->prepare( $self->{'sql_file_list'} ) ) ) {
        $LASTERROR = "Unable to prepare 'list' query: $self->{'dbh'}->errstr";
        return undef;
    }

    if (defined $name) {
        $name =~ s|.*/||;       # only the short name for the lookup
        $name = "%" . $name . "%";
    } else {
        $name = "%";
    }

    if ( not $sth->execute( $name ) ) {
        $LASTERROR = "Unable to execute 'detail' query: $sth->err";
        return undef;
    }

    return $sth;
}

sub list_next
{
    my $self = shift;
    my $sth  = shift;

    return $sth->fetchrow_hashref();
}

sub list_finish
{
    my $self = shift;
    my $sth  = shift;
    $sth->finish;
    undef $sth;
}

=item remove

remove the file matching the name passed from the database.

note only the filename without pathing information is used as the key,
so unique pathing to same filename can cause collisions.

return non-zero on failure

=cut

sub remove
{
    my $self  = shift;
    my $name  = shift;
    my $sth;

    if ( not ( $sth = $self->{'dbh'}->prepare( $self->{'sql_file_delete'} ) ) ) {
        $LASTERROR = "Unable to prepare 'remove' statement: $self->{'dbh'}->errstr";
        return 1;
    }

    $name =~ s|.*/||;           # only the short name for the lookup
    if ( not $sth->execute( $name ) ) {
        $LASTERROR = "Unable to execute 'remove' statement: $sth->err";
        return 1;
    }

    $sth->finish;
    undef $sth;

    return 0;
}


=item store

load file pointed to as an argument with fully qualified path into database.
storage name is truncated down to the filename alone without pathing info.
this operation will refuse to overwrite existing files.

return non-zero on error

=cut

sub store
{
    my $self = shift;
    my ($name, $description) = @_;

    my $sth;

    if (not defined ( $sth = $self->setupStore( $name ) ) ) {
        return 1;
    }

    my $fh;
    if (not open( $fh, "<", $name ) ) {
        $LASTERROR = "Unable to open $name: $!\n";
        return 1;
    }

    binmode $fh;

    $self->finishStore( $sth, $fh, $name, $description );

    close $fh;

    $sth->finish;
    undef $sth;

    return 0;
}

=item writeFH

not implemented

=cut

sub writeFH
{
    return undef;
}

=item storeScalar

allow storage of a scalar value (passed by reference) using given name
return non-zero on failure

  sqlfsOBJ->storeScalar ( $name, \$content, [ $description ] );

=cut

sub storeScalar
{
    my $self = shift;
    my $name = shift;
    my $refcontent = shift;
    my $description = shift;

    my $sth;

    if (not defined ( $sth = $self->setupStore( $name ) ) ) {
        return 1;
    }

    my $fh;
    if (not open( $fh, "<", $refcontent ) ) {
        $LASTERROR = "Unable to open $name: $!\n";
        return 1;
    }

    binmode $fh;

    $self->finishStore( $sth, $fh, $name, $description );

    close $fh;

    $sth->finish;
    undef $sth;

    return 0;
}

sub setupStore
{
    my $self  = shift;
    my $name  = shift;

    my $sth;

    if ( $self->find( $name ) ) {
        $LASTERROR = "Refusing overwrite of db file found: $name.\n";
        return undef;
    }

    if ( not ( $sth = $self->{'dbh'}->prepare( $self->{'sql_file_store'} ) ) ) {
        $LASTERROR = "Unable to prepare 'store' statement: $self->{'dbh'}->errstr";
        return undef;
    }

    return $sth;
}

sub finishStore
{
    my $self = shift;
    my $sth  = shift;
    my $fh   = shift;
    my $name = shift;
    my $desc = shift;

    $name =~ s|.*/||;           # again only the short name

    my $byteas;
    my $bytes = 1;
    my $chunk_size = $self->{'_maxlen_'};

    while ( $bytes ) {
        read $fh, $bytes, $chunk_size;
        $byteas = &bytea_encode( $bytes );
        $sth->execute( $name, $desc, $byteas, 1)
            if ( $bytes );
    }
}

=item fetch

fetch a file from database with transparent chunking. use only filename
without pathing information for the look up but write it out to the fully
qualified path and filename provided as an argument.

=cut

sub fetch
{
    my $self  = shift;
    my $name  = shift;

    my $sth;

    if (not defined ( $sth = $self->setupFetch( $name ) ) ) {
        return 1;
    }

    if ( -e $name ) {
        $LASTERROR = "Not going to overwrite existing file with same name: $name.\n";
        return 1;
    }

    my $fh;
    if (not open( $fh, ">", $name ) ) {
        $LASTERROR = "Unable to open $name for writing: $!\n";
        return 1;
    }

    binmode $fh;

    while ( my @row = $sth->fetchrow_array() ) {
        syswrite $fh, &bytea_decode( $row[0] );
    }

    close $fh;

    $sth->finish;
    undef $sth;

    return 0;
}

=item readFH

open a filehandle for reading the binary blob stored in db under name passed

=cut

sub readFH
{
    my $self = shift;
    my $name = shift;

    my $sth;

    if (not defined ( $sth = $self->setupFetch( $name ) ) ) {
        return undef;
    }

    my $bin;
    while ( my @row = $sth->fetchrow_array() ) {
        $bin .= &bytea_decode( $row[0] );
    }

    my $fh;
    if (not open( $fh, "<", \$bin ) ) {
        $LASTERROR = "Unable to open filehandle for readFH: $!\n";
        return undef;
    }

    binmode $fh;

    #    print "readFH: returning filehandle $fh\n";

    $sth->finish;
    undef $sth;

    return $fh
}

sub setupFetch
{
    my $self  = shift;
    my $name  = shift;

    my $sth;

    unless ( $self->find( $name ) ) {
        $LASTERROR = "$name not found in the db for retrevial\n";
        return undef;
    }

    if ( not ( $sth = $self->{'dbh'}->prepare( $self->{'sql_file_fetch'} ) ) ) {
        $LASTERROR = "Unable to prepare 'fetch' statement: $self->{'dbh'}->errstr";
        return undef;
    }

    $name =~ s|.*/||;           # only the short name for the lookup
    if ( not $sth->execute( $name ) ) {
        $LASTERROR = "Unable to execute 'fetch' statement: $sth->err";
        return undef;
    }

    return $sth;
}

=item closeFH

close readFH or writeFH filehandle

=cut

sub closeFH
{
    my $self = shift;
    my $fh = shift;

    close $fh;
}

=item error

return the string holding the last error message

=cut

sub error
{
    return $LASTERROR;
}

1;
__END__


=head1 AUTHOR

David Bahi, E<lt>dbahi@novellE<gt>

=cut
