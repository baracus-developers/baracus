#!/usr/bin/perl -w

use Getopt::Long qw(GetOptionsFromArray :config pass_through);
use Pod::Usage;

use lib "/usr/share/baracus/perl";

use SqlFS;

# what DBI schema and database are we using
my $datasource;
my $user;

our $LASTERROR="";

my $man   = 0;
my $help  = 0;
my $debug = 0;

my $source = "pgsql"; # default to postgres

my $pname = $1 if $0 =~ m|.*/([^/].*)|;

my @cmds = ('help', 'man', 'drop', 'list', 'add', 'fetch', 'detail', 'delete');

my %cmds = (
            'help'   => \&help,
            'man'    => \&man,
            'drop'   => \&drop,
            'list'   => \&list,
            'add'    => \&add,
            'fetch'  => \&fetch,
            'detail' => \&detail,
            'delete' => \&delete
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
    $datasource = "dbi:SQLite:dbname=$ENV{'HOME'}/sqlftfp";
    $user = "";
}
else {
    $datasource = "dbi:Pg:dbname=sqlftfp";
    $user = "baracus";
}

my $status = &main(@ARGV);

print $LASTERROR if $status;

exit $status;

die "DOES NOT EXECUTE";

###########################################################################

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
    delete  Remove file specified from database table.

=head1 DESCRIPTION

This tool allows files to be added to, removed from, detailed, fetched from
an SqlFS database filesystem.  Additionally, the database can be wiped clean,
or all its files contains listed.

In cases where the commands will only interact with the SqlFS, e.g. detail and delete, filename arguments are required but path information will be ignored. And in cases where the commands will read or write to a file outside the SqlFS, e.g. add and fetch, pathing information is required to locate the file external to the SqlFS.

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

    my $fs = newSqlFS();
    $fs->destroy();
    return 0;
}


=item list

    Takes no arguments.
    Lists all files in the SqlFS filesystem.

=cut

sub list
{
    my @params = @_;
    if ( scalar @params ) {
        &help();
    }
    $LASTERROR = "Not yet instrumented in SqlFS\n";
    return 1;
}

=item add [--file sqlfsfile] E<lt>path/filenameE<gt>

    Takes fully qualified location of file as argument.
    Copies the specified file into the SqlFS filesystem.
    Will not overwrite 'filename' already in SqlFS filesystem.

    Option

    -f  store as 'sqlfsfile' in the sqlfs database instead of
        using just filename as passed with path.

=cut

sub add
{
    my $asfile = "";

    GetOptionsFromArray( \@_,
                         'file=s' => \$asfile
                        );

    my @params = @_;

    my $file = $params[0];

    if (not defined $file) {
        &help();
    }
    elsif (not -e $file) {
        $LASTERROR = "File $file not found\n";
        return 1;
    }

    my $fs = newSqlFS();

    if ( $asfile ) {
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
    my $tofile = '';

    GetOptionsFromArray( \@_,
                         'alt'    => \$alt,
                         'file=s' => \$tofile
                        );

    my @params = @_;

    my $file = $params[0];

    # make sure the file we're going to overwrite doesn't exist
    if ( defined $tofile and -e $tofile) {
        $LASTERROR = "File $tofile already exists\n";
        return 1;
    }
    elsif ( not defined $file ) {
        &help();
    }
    elsif ( -e $file ) {
        $LASTERROR = "File $file already exists\n";
        return 1;
    }

    &fetch_alt( @params, $tofile ) if $alt;

    my $fs = newSqlFS();

    if ( $tofile ) {
        $fs->fetch( $file, $tofile );
    }
    else {
        $fs->fetch( $file );
    }
    return 0;
}

sub fetch_alt
{
    my @params = @_;

    my $file = $params[0];
    my $tofile = $params[1];

    # make sure the file we're going to overwrite doesn't exist
    if ( defined $tofile and -e $tofile) {
        $LASTERROR = "File $tofile already exists\n";
        return 1;
    }
    elsif ( not defined $file ) {
        &help();
    }
    elsif ( -e $file ) {
        $LASTERROR = "File $file already exists\n";
        return 1;
    }

    $tofile = $file if (not defined $tofile);

    my $fs = newSqlFS();

    open( my $outfh, ">", $tofile );
    my $infh = $fs->readFH( $file );
    if (not defined $infh) {
        $LASTERROR = "File $file not found in db\n";
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

    my $fs = newSqlFS();

    my $hash = $fs->detail( $file );

    if (not defined $hash) {
        $LASTERROR = "File $file not found in SqlFS\n";
        return 1;
    }
    while ( my ($key,$value) = each ( %$hash ) ) {
        print "$key => $value\n" if ( defined $value );
    }

    return 0;
}

=item delete E<lt>filenameE<gt>

    Takes a filename as argument.
    Removes the file specified from the SqlFS filesystem.

=cut

sub delete
{
    my @params = @_;

    my $file = $params[0];

    if ( not defined $file ) {
        &help();
    }

    my $fs = newSqlFS();

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


die "ABSOLUTELY DOES NOT EXECUTE";

__END__
