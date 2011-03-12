package SqlFS;

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

use DBI;

use lib "/usr/share/baracus/perl";

use BaracusConfig qw( :vars );

# for sql tftp db binary file chunking 1MB blobs
use constant BA_DBMAXLEN => 268435456; # 256 MB
#use constant BA_DBMAXLEN => 1048575;


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
    if ( defined $cfg{'debug'} ) {
        $debug = $cfg{'debug'};
        print "debug = $debug\n" if $debug;
    }

    # sql for file present check
    my $file_find = qq|SELECT COUNT (*)
                       FROM $cfg{'TableName'}
                       WHERE name = ?
                      |;

    # sql for file detail - cannot use sum(length(bin)) as 'text' its encoded
#    my $file_detail = qq|SELECT id, name, description, size, enabled, insertion, change, bin
    my $file_detail = qq|SELECT id, name, description, size, enabled, insertion, change
                         FROM $cfg{'TableName'}
                         WHERE name = ?
                        |;

    # sql for file list - had to hack / avg insertion times that vary with id ?
    my $file_list = qq|SELECT
                       COUNT( id ) as blobs, name, size, enabled,
                       TIMESTAMP 'epoch' + (AVG(EXTRACT(EPOCH FROM insertion)) * interval '1 second') as create
                       FROM $cfg{'TableName'}
                       WHERE name LIKE ?
                       GROUP BY name, size, enabled
                      |;

    # remove a file
    my $file_delete = qq|DELETE FROM $cfg{'TableName'} where name = ?|;

    my $file_store = qq|INSERT INTO $cfg{'TableName'}
                        (name, description, bin, size, enabled, insertion, change)
                        VALUES ( ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, NULL)
                       |;

    # select for fetch
    my $file_fetch = qq|SELECT bin, size
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

    # max_allowed_packets a mysql specific construct
    my $maxlen = BA_DBMAXLEN;

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
                   'sql_file_detail' => $file_detail,
                   'sql_file_list' => $file_list,
                   'sql_file_delete' => $file_delete,
                   'sql_file_store' => $file_store,
                   'sql_file_fetch' => $file_fetch,
                   'sql_file_find' => $file_find
                  }, $class;
}

sub clone_dhb_for_child()
{
    my $self = shift;

    my $child_dbh = $self->{dbh}->clone();

    $self->{dbh}->{InactiveDestroy} = 1;
    undef $self->{dbh};

    $self->{dbh} = $child_dbh;
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
        $LASTERROR = "Unable to prepare 'find' query.\n" . $self->{'dbh'}->errstr;
        return undef;
    }

    $name =~ s|.*/||;           # only the short name for the lookup
    if ( not $sth->execute( $name ) ) {
        $LASTERROR = "Unable to execute 'find' query\n" . $sth->err;
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
        $LASTERROR = "Unable to prepare 'detail' query.\n" .
            $self->{'dbh'}->errstr;
        return undef;
    }

    $name =~ s|.*/||;       # only the short name for the lookup
    #    print "fetching details for $name\n";

    if ( not $sth->execute( $name ) ) {
        $LASTERROR = "Unable to execute 'detail' query.\n" . $sth->err;
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
        my ($id, $nm, $des, $size, $ena, $idate, $cdate) = @{ $ar };
        if ( $flag_first == 1 ) {
            $flag_first = 0;
            $hash->{'rowcount'} = $size / BA_DBMAXLEN; + 1;
            $hash->{'rowcount'} += 1 if ( $size % BA_DBMAXLEN );
            $hash->{'name'} = $nm;
            $hash->{'binsize'} = $size;
            $hash->{'enabled'} = $ena;
            $hash->{'insertdate'} = $idate;
            $hash->{'changedate'} = $cdate;
            $hash->{'description'} = $des;
            last;
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
        $LASTERROR = "Unable to prepare 'list' query.\n" . $self->{'dbh'}->errstr;
        return undef;
    }

    if (defined $name) {
        $name =~ s|.*/||;       # only the short name for the lookup
        $name = "%" . $name . "%";
    } else {
        $name = "%";
    }

    if ( not $sth->execute( $name ) ) {
        $LASTERROR = "Unable to execute 'detail' query.\n" . $sth->err;
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
        $LASTERROR = "Unable to prepare 'remove' statement.\n" .
            $self->{'dbh'}->errstr;
        return 1;
    }

    $name =~ s|.*/||;           # only the short name for the lookup

    &remove_bigfile( $name );   # no size check - will remove if it exists

    if ( not $sth->execute( $name ) ) {
        $LASTERROR = "Unable to execute 'remove' statement.\n" . $sth->err;
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
    my $tmp = join '', <$fh>;
    my $size = length ( $tmp );
    close $fh;

    # size > bfsize then create a cache file in ~baracus/bfdir
    &add_bigfile( $name, $tmp ) if ( $size >= $bfsize );

    if (not open( $fh, "<", $name ) ) {
        $LASTERROR = "Unable to open $name: $!\n";
        return 1;
    }

    binmode $fh;

    $self->finishStore( $sth, $fh, $name, $description, $size, 1 );

    close $fh;

    $sth->finish;
    undef $sth;

    return 0;
}

=item update

update data portion of db entry with contents of file pointed to as an argument.
additional arguments may modify the description or the status of the entry.

this operation will refuse to add new entries (the name must already be in db).

return non-zero on error

=cut

sub update
{
    my $self = shift;
    my %hash = %{$_[0]};

    my $fh;
    my $sql;
    my $sth;
    my $href;
    my %save;

    my $name;
    my $file;

    if ( $debug ) {
        while ( my ($key, $value) = each %hash ) {
            print "update args: $key => $value\n";
        }
    }

    unless ( defined $hash{'name'} ) {
        $LASTERROR = "Parameter 'name' missing in call to update.\n";
        return 1;
    }

    $name = $hash{'name'};
    $name =~ s|.*/||;           # again only the short name for the db

    unless ( $sth = $self->{'dbh'}->prepare( $self->{ 'sql_file_detail' } ) ) {
        $LASTERROR = "Unable to prepare 'update detail' statement\n" .
            $self->{'dbh'}->errstr;
        return 1;
    }

    unless ( $sth->execute( $name ) ) {
        $LASTERROR = "Unable to execute 'update detail' statement\n" . $sth->err;
        return 1;
    }

    my $entry_data;
    my $rowcount = 0;
    my %id;

    # store off first entry
    while ( $href = $sth->fetchrow_hashref( ) ) {
        while ( my ($key, $val) = each %{$href} ) {
            print "update $rowcount - $href->{'id'} entry:  $key => $val\n" if $debug;
        }
        unless ( $rowcount ) {
            while ( my ($key, $val) = each %{$href} ) {
                if ( $key ne "bin" ) {
                $save{ $key } = $val;
                    if ( $debug and $val ) {
                        print "update entry:  $key => $val\n";
                    } elsif ( $debug ) {
                        print "update entry:  $key => \n";
                    }
                }
            }
        }
        $rowcount += 1;
        $id{ $href->{'id'} } = $href->{'id '};
        $entry_data .= &bytea_decode( $href->{'bin'} );
    }

    unless ( $rowcount ) {
        $LASTERROR = "Entry to be updated not found in db found: $name.\n";
        return 1;
    }

    my $desc_needed = 0;
    my $stat_needed = 0;

    if ( defined $hash{'description'} ) {
        if ( $save{'description'} ne $hash{'description'} ) {
            $save{'description'} = $hash{'description'};
            $desc_needed = 1;
            print "update description change needed\n" if $debug;
        }
    }

    if ( defined $hash{'enabled'} ) {
        if ( $save{'enabled'} ne $hash{'enabled'} ) {
            $save{'enabled'} = $hash{'enabled'};
            $stat_needed = 1;
            print "update enabled change needed\n" if $debug;
        }
    }

    if ( defined $hash{'file'} and  $hash{'file'} ne "" ) {
        $file = $hash{'file'};

        my $file_data;
        open (FILE, "<$file") || die "unable to open $file: $!\n";
        {
            undef $/;
            $file_data=<FILE>;   # slurp mode
            $/ = "\n";
        }
        close FILE;

        if ( $file_data eq $entry_data ) {
            $LASTERROR = "Reject updating file entry with duplicate data\n";
            return 1;
        }
        $file_data = $entry_data = ""; # free space

        print "update working file change\n" if $debug;

        unless ( open( $fh, "<", $file ) ) {
            $LASTERROR = "Unable to open $file: $!\n";
            return 1;
        }
        my $tmp = join '', <$fh>;
        my $size = length ( $tmp );
        close $fh;
        unless ( open( $fh, "<", $file ) ) {
            $LASTERROR = "Unable to open $file: $!\n";
            return 1;
        }

        # remove all entries before 'new' update
        $self->remove( $hash{ 'name' } );

        # will just overwrite - no need to remove tmp file and add
        &add_bigfile( $name, $tmp ) if ( $size >= $bfsize );

        # SELECT name, description, enabled, insertion, change, bin

        $sql = qq|INSERT INTO $self->{'TableName'}
                  (name, description, bin, enabled, insertion, change)
                  VALUES ( ?, ?, ?, ?, '$save{'insertion'}', CURRENT_TIMESTAMP)
                 |;

        print "update sql: $sql\n" if $debug;

        unless ( $sth = $self->{'dbh'}->prepare( $sql ) ) {
            $LASTERROR = "Unable to prepare 'update insert' statement" .
                $self->{'dbh'}->errstr;
            return 1;
        }

        $self->finishStore( $sth, $fh, $name,
                            $save{'description'}, $size, $save{'enabled'} );

        close $fh;

    } elsif ( $desc_needed == 1 || $stat_needed == 1 ) {

        print "update working description and/or status change\n" if $debug;

        # no file to play with so only updating the status, description, or both
        my $sql_cols;
        my $sql_vals;

        if ( $desc_needed == 1 ) {
            $sql_cols .= "description";
            $sql_vals .= "'$save{'description'}'";
        }
        if ( $stat_needed == 1 ) {
            $sql_cols .= "," if ( $sql_cols );
            $sql_vals .= "," if ( $sql_vals );
            $sql_cols .= "enabled";
            $sql_vals .= "'$save{'enabled'}'";
        }
        $sql_cols .= ",insertion,change";
        $sql_vals .= ",'$save{'insertion'}', CURRENT_TIMESTAMP";

        $sql = qq|UPDATE $self->{'TableName'}
                  SET ( $sql_cols ) = ( $sql_vals )
                  WHERE id = ?|;

        print "update $sql\n" if $debug;

        unless ( $sth = $self->{'dbh'}->prepare( $sql ) ) {
            $LASTERROR = "Unable to prepare 'update' statement\n" .
                $self->{'dbh'}->errstr;
            return 1;
        }

        foreach my $id ( sort keys %id ) {
            print "update id $id\n" if $debug;
            unless ( $sth->execute( $id ) ) {
                $LASTERROR = "Unable to execute 'update' statement\n" .
                    $sth->err;
                return 1;
            }
        }
    }

    $sth->finish;
    undef $sth;

    return 0;
}

=item internalDataCopy

copy data portion of src name to dst name db entry.

return non-zero on error

=cut

sub internalDataCopy
{
    my $self = shift;

    my $src = shift;
    my $dst = shift;

    my $fh;
    my $sth;
    my $href;

    my @data;
    my %src_save;
    my %dst_save;

    unless ( defined $src ) {
        $LASTERROR = "Parameter 'src' missing for internalDataCopy.\n";
        return 1;
    }

    my $sql = $self->{ 'sql_file_detail' } . " ORDER BY id";
    print "idc sql: $sql\n" if $debug;

    unless ( $sth = $self->{'dbh'}->prepare( $sql ) ) {
        $LASTERROR = "Unable to prepare 'idc detail' statement\n" .
            $self->{'dbh'}->errstr;
        return 1;
    }

    unless ( $sth->execute( $src ) ) {
        $LASTERROR = "Unable to execute 'idc detail' statement\n" . $sth->err;
        return 1;
    }

    my $data;
    my $rowcount = 0;
    # store off src data
    while ( $href = $sth->fetchrow_hashref( ) ) {
        unless ( $rowcount ) {
            while ( my ($key, $val) = each %{$href} ) {
                $src_save{ $key } = $val;
                if ( $key ne "bin" and $debug and $val ) {
                    print "idc src $key => $val\n";
                } elsif ( $key ne "bin" and $debug ) {
                    print "idc src $key => \n";
                }
            }
        }
        $rowcount += 1;
        push @data, $href->{'bin'};
    }

    unless ( $rowcount ) {
        $LASTERROR = "Source entry not found: $src.\n";
        return 1;
    }

    unless ( defined $dst ) {
        $LASTERROR = "Parameter 'dst' missing for internalDataCopy.\n";
        return 1;
    }

    unless ( $sth->execute( $dst ) ) {
        $LASTERROR = "Unable to execute 'idc detail' statement\n" . $sth->err;
        return 1;
    }

    $rowcount = 0;
    # store off dst entries before removal from db (to prep for new data add)
    while ( $href = $sth->fetchrow_hashref( ) ) {
        unless ( $rowcount ) {
            while ( my ($key, $val) = each %{$href} ) {
                $dst_save{ $key } = $val;
                if ( $key ne "bin" and $debug and $val ) {
                    print "idc dst $key => $val\n";
                } elsif ( $key ne "bin" and $debug ) {
                    print "idc dst $key => \n";
                }
            }
        }
        $rowcount += 1;
    }

    unless ( $rowcount ) {
        $LASTERROR = "Destination entry not found: $dst.\n";
        return 1;
    }

    # remove all entries before 'new' update
    $self->remove( $dst );

    # SELECT name, description, enabled, insertion, change, bin

    $sql = qq|INSERT INTO $self->{'TableName'}
              (name, description, bin, enabled, insertion, change)
              VALUES ( ?, ?, ?, ?, '$dst_save{'insertion'}', CURRENT_TIMESTAMP)
             |;

    print "idc sql2: $sql\n" if $debug;

    unless ( $sth = $self->{'dbh'}->prepare( $sql ) ) {
        $LASTERROR = "Unable to prepare 'update insert' statement\n" .
            $self->{'dbh'}->errstr;
        return 1;
    }

    my $pop;
    while ( scalar @data ) {
        $pop = pop @data;
        $sth->execute( $dst, $dst_save{ 'description' },
                       $pop, $dst_save{ 'enabled' } );
    }

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
    my $size = length( $refcontent );

    binmode $fh;

    $self->finishStore( $sth, $fh, $name, $description, $size, 1 );

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
        $LASTERROR = "Unable to prepare 'store' statement\n" .
            $self->{'dbh'}->errstr;
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
    my $size = shift;
    my $status = shift;

    $name =~ s|.*/||;           # again only the short name

    my $byteas;
    my $bytes = 1;
    my $chunk_size = $self->{'_maxlen_'};

    while ( $bytes ) {
        read $fh, $bytes, $chunk_size;
        $byteas = &bytea_encode( $bytes );
        $sth->execute( $name, $desc, $byteas, $size, $status)
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
        $LASTERROR = "Unable to prepare 'fetch' statement.\n" .
            $self->{'dbh'}->errstr;
        return undef;
    }

    $name =~ s|.*/||;           # only the short name for the lookup
    if ( not $sth->execute( $name ) ) {
        $LASTERROR = "Unable to execute 'fetch' statement.\n" . $sth->err;
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
