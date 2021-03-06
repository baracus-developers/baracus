#!/usr/bin/perl -w

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

use Getopt::Long qw( :config pass_through );
use Pod::Usage;

use lib "/usr/share/baracus/perl";

use BaracusDB;
use SqlFS;

=pod

=head1 NAME

B<directSqlFS> - example tool to excercise the SqlFS database API

=head1 SYNOPSIS

B<directSqlFS> [--source=E<lt>sqlite|pgsqlE<gt>] E<lt>commandE<gt> [options and arguments]

Where E<lt>commandE<gt> is

    help    Usage summary message.
    man     Detailed man page.
    drop    Destroy filesystem database table.
    list    List files in database table.
    add     Copy to database table from file in specified location.
    fetch   Copy from database table to file in specified location.
    detail  Display all details about file in the database table.
    remove  Delete file specified from database table.


=head1 DESCRIPTION

This tool allows files to be added to, removed from, detailed, fetched
from an SqlFS database filesystem.  Additionally, the database can be
wiped clean, or all its files contains listed.

In cases where the commands will only interact with the SqlFS,
e.g. detail and remove, filename arguments are required but path
information will be ignored. And in cases where the commands will read
or write to a file outside the SqlFS, e.g. add and fetch, pathing
information is required to locate the file external to the SqlFS.

=cut

# what DBI schema and database are we using
my $source = "pgsql"; # default to postgres
my $dbname = "sqltftp";
my $datasource;
my $user;

our $LASTERROR="";

my $man   = 0;
my $help  = 0;
my $debug = 0;

my @cmds = ('help', 'man', 'drop', 'list', 'add', 'fetch', 'detail', 'remove');

my %cmds = (
            'help'   => \&help,
            'man'    => \&man,
            'drop'   => \&drop,
            'list'   => \&list,
            'add'    => \&add,
            'fetch'  => \&fetch,
            'detail' => \&detail,
            'remove' => \&remove
            );

GetOptions(
           'help|?'         => \$help,
           'man'            => \$man,
           'debug|verbose+' => \$debug,
           'source=s'       => \$source
           );

&man() if $man;

&help() if (( $help ) or ( not scalar @ARGV ));

$source = lc $source;

if ( "$source" eq "sqlite" ) {
    $datasource = "dbi:SQLite:dbname=$ENV{'HOME'}/$dbname";
    $user = "";
}
else {
    $datasource = "dbi:Pg:dbname=$dbname";
    $user = "baracus";
}

$oldid = BaracusDB::su_user( $user );
die BaracusDB::errstr unless ( defined $oldid );

$fs = newSqlFS();
my $status = &main(@ARGV);
deleteSqlFS();

print $LASTERROR if $status;

exit $status;

die "DOES NOT EXECUTE";

###########################################################################

=head1 OPTIONS AND ARGUMENTS

More details on options and the individual commands follow

=over 4

=item --source | -s E<lt>sqlite|pgsqlE<gt>

    Specify which underlying database to use.  This is a faux option
    to more flexibly connect to the SqlFS and match the method it is
    using.  SqlFS will have SQL that works for one database or the
    other so you can flip this switch to match the underlying SQL in
    SqlFS.

    Default: pgsql

=cut

sub main
{
    my $command = shift;
    my @params = @_;

    $command = lc $command;

    if ( not defined $cmds{ $command } ) {
        &help();
    }

    printf "Executing $command with \"@params\".\n" if $debug;

    $cmds{ $command }( @params );
}

sub help
{
    pod2usage( -verboase => 0,
               -exitstatus => 0 );
}

sub man
{
    pod2usage( -verbose    => 99,
               -sections   => "NAME|SYNOPSIS|DESCRIPTION|OPTIONS AND ARGUMENTS",
               -exitstatus => 0 );
}

=item drop

    Takes no arguments.
    CAUTION: All files in database will be permenately removed.

=cut

sub drop
{
    my @params = @_;

    if ( scalar @params ) {
        &help();
    }
    $fs->destroy();
    return 0;
}


=item list

    Takes no arguments.
    Lists all files in the SqlFS filesystem.

=cut

sub list
{
    my $pattern = shift;

    my @params = @_;
    if ( scalar @params ) {
        &help();
    }

    $pattern = "" unless( defined $pattern );

    my $sth = $fs->list_start( $pattern );

    unless( defined $sth ) {
        $LASTERROR = "Unable to create db stmt handle for search: $pattern\n";
        return 1;
    }

#2345678901234567890123456789012345678901324567890123456789012345678901234567890
#        1         2         3         4         5         6         7         8
print <<HEAD;
--------------------------------------------------------------------------------
blk name                                           01 insertion time (approx.)
--------------------------------------------------------------------------------
HEAD

    while( my $hash = $fs->list_next( $sth ) ) {
        # blobs, name, enabled, insertion
        printf "%3s %-46s %2d %-10s\n",
            $hash->{'blobs'},
            $hash->{'name'},
#            (defined $hash{'description'}) ? $hash{'description'} : "",
            $hash->{'enabled'},
            $hash->{'create'}
#            (defined $hash{'change'}) ? $hash{'change'} : "";
    }
    $fs->list_finish( $sth );

    return 0;
}

=item add [--file sqlfsfile] E<lt>path/filenameE<gt>

    Takes fully qualified location of file as argument.
    Copies the specified file into the SqlFS filesystem.
    Will not overwrite 'filename' already in SqlFS filesystem.

    Option

    -f  store as 'sqlfsfile' in the sqlfs database instead of
        using just using filename as passed with path.

=cut

sub add
{
    my $asfile = "";
    @ARGV = @_;
    GetOptions(
               'file=s' => \$asfile
               );
    my @params = @ARGV;
    my $file = $params[0];
    if (not defined $file) {
        &help();
    }
    elsif (not (-e $file)) {
        $LASTERROR = "File $file not found - $!\n";
        return 1;
    }
    if ( $asfile ) {
        die "underlying API not yet in place. cp $file /tmp/asfile and then add that.\n";
        $fs->store( $file, $asfile );
    }
    else {
        $fs->store( $file );
    }
    return 0;
}

=item fetch [--alt|-a] [--file sqlfsfile] E<lt>path/filenameE<gt>

    Takes fully qualified location of file as argument.
    Copies from the SqlFS filesystem to specified file.
    Will not overwrite 'path/filename' in SqlFS filesystem.

    Options

    -a  specifies this command is to excersise an alternative
        internal method, e.g. with exposed filehandles.

    -f  lookup 'sqlfsfile' in the sqlfs database instead of
        filename and if found store in the local (non-sqlfs)
        filesystem in the <path/filename> specified.

=cut

sub fetch
{
    my $alt = 0;
    my $asfile = '';
    @ARGV=@_;
    GetOptions(
               'alt'    => \$alt,
               'file=s' => \$asfile
               );
    my @params = @ARGV;
    my $file = $params[0];
    # make sure the file we're going to overwrite doesn't exist
    if ( not defined $file ) {
        &help();
    }
    elsif ( -e $file ) {
        $LASTERROR = "File $file already exists\n";
        return 1;
    }
    &fetch_alt( $file, $asfile ) if $alt;
    if ( $asfile ) {
        die "underlying API not yet in place. try using --alt.\n";
        $fs->fetch( $asfile, $file );
    }
    else {
        $fs->fetch( $file );
    }
    return 0;
}

sub fetch_alt
{
    my $file = shift;
    my $asfile = shift;
    # make sure the file we're going to overwrite doesn't exist
    if ( not defined $file ) {
        &help();
    }
    elsif ( -e $file) {
        $LASTERROR = "File $file already exists\n";
        return 1;
    }

    $asfile = $file if (not defined $asfile);
    open( my $outfh, ">", $file );
    my $infh = $fs->readFH( $asfile );
    if (not defined $infh) {
        $LASTERROR = "File $asfile not found in db\n";
        return 1;
    }
    while ( <$infh>) {
        print $outfh $_;
    }
    $fs->closeFH( $infh );
    close $outfh;
    return 0;
}

=item detail E<lt>filenameE<gt>

    Takes a filename as argument.
    Fetch and display the details about the file specified.

=cut

sub detail
{
    my @params = @_;
    my $file = $params[0];
    if ( not defined $file ) {
        &help();
    }
    my $hash = $fs->detail( $file );
    if (not defined $hash) {
        $LASTERROR = "File $file not found in SqlFS\n";
        deleteSqlFS();
        return 1;
    }
    while ( my ($key,$value) = each ( %$hash ) ) {
        print "$key => $value\n" if ( defined $value );
    }
    return 0;
}

=item remove E<lt>filenameE<gt>

    Takes a filename as argument.
    Removes the file specified from the SqlFS filesystem.

=cut

sub remove
{
    my @params = @_;
    my $file = $params[0];
    if ( not defined $file ) {
        &help();
    }
    $fs->remove( $file );
    return 0;
}

=back

=cut

###########################################################################

sub newSqlFS
{
    my $fs = SqlFS->new( 'DataSource' => "$datasource",
                         'User'       => "$user" )
        or die "Unable to create new instance of SqlFS\n";

    return $fs;
}

sub deleteSqlFS
{
    # disconnect and destroy
    $fs->discard();
    undef $fs;
}

die "ABSOLUTELY DOES NOT EXECUTE";

__END__
