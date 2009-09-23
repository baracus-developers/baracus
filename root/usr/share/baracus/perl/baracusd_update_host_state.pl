#!/usr/bin/perl -w

use strict;

use Getopt::Long qw( :config pass_through );
use AppConfig;

use lib "/usr/share/baracus/perl";

use BaracusDB;
use BaracusSql;

my $debug = 0;
my $hostname = "";
my $ip;
my $uuid;
my $mac;

# get the sysconfig option settings
my $sysconfigfile = '/etc/sysconfig/baracus';
my $sysconfig = AppConfig->new( {CREATE => 1} );
$sysconfig->define( 'baracusd_options=s',
                    'autodisablepxe=s',
                   );
$sysconfig->file( $sysconfigfile );
my $baracusd_options = $sysconfig->get( 'baracusd_options' );
my $autodisablepxe   = $sysconfig->get( 'autodisablepxe'   );

$debug = 1 if ( defined $baracusd_options and $baracusd_options =~ m|debug| );

my %tbl  = (
            'host'       => 'templateid',
            );

my %cmds = (
            'endofbuild' => \&endofbuild, # -> built or spoofed
            'endofwipe'  => \&endofwipe,  # -> wiped or error ?
            'pxeserved'  => \&pxeserved,  # -> building or wiping
            );

GetOptions (
            'debug+'     => \$debug,
            'hostname=s' => \$hostname,
            'ip=s'       => \$ip,
            'uuid=s'     => \$uuid,
            'mac=s'      => \$mac,
            );

my $dbname = "baracus";
my $dbrole = $dbname;

my $uid = BaracusDB::su_user( $dbrole );
die BaracusDB::errstr unless ( defined $uid );

my $dbh = BaracusDB::connect_db( $dbname, $dbrole );
die BaracusDB::errstr unless( $dbh );

&main(@ARGV);

die BaracusDB::errstr unless BaracusDB::disconnect_db( $dbh );

exit 0;

die "DOES NOT EXECUTE";

###########################################################################

sub main
{
    my $command = shift;

    $command = lc $command;
    &check_command( $command );

    printf "Executing $command with \"@_\".\n" if $debug;

    $cmds{ $command }( @_ );
}

#
# build completed have ip address of tftp client uuid and hostname (maybe mac)
#   from any non-wipe state to built or spoofed

sub endofbuild {
    # get host template entry if any
    my $href = &get_db_host_entry( );
    unless( defined $href ) {
        print "unable to find template for $hostname\n";
        return 1;
    }
    # check mac and uuid (and ip if template not dhcp) match or state is 3:spoofed
    my $state = BaracusSql::BA_BUILT;
    # check for spoofing of url access
    if (( "$uuid" ne "$href->{'uuid'}" ) or
        (( "$ip"  ne "$href->{'ip'}"  ) and
         ( "dhcp" ne "$href->{'ip'}"  ))) {
        $state = BaracusSql::BA_SPOOFED;
    }

    if ( defined $mac and "$mac" ne "$href->{'mac'}" ) {
        $state = BaracusSql::BA_SPOOFED;
    }

    # check that the last change time greater than delta
    my $minutes = 8;
    my $delta = 60 * $minutes;
    if ( ( &less_than_delta( $href->{'change'}, $delta ) ) and
         ( $href->{'state'} == $state ) ) {
        return 2;  # ignore
    }

    $href->{'state'} = $state;

    # update the host template entry
    &update_db_host_entry( $href );

    unless ( $state == BaracusSql::BA_BUILT ) {
        return 1;
    }
    return 0;
}

# wipe completed have ip address of client and ...
#   from any wipe state to wiped
sub endofwipe {
    return 0
}

sub pxeserved {
    # get host template entry if any
    my $href = &get_db_host_by_mac( );
    unless( defined $href ) {
        print "unable to find template for $mac\n";
        return 1;
    }
    # served up a pxeboot file
    #   ready -> building
    #   diskwipe -> wiping

    my $state;

    if ( $href->{state} eq BaracusSql::BA_READY or
         $href->{state} eq BaracusSql::BA_BUILT or
         $href->{state} eq BaracusSql::BA_SPOOFED or
         $href->{state} eq BaracusSql::BA_UPDATED or
         $href->{state} eq BaracusSql::BA_BUILT ) {
        $state = BaracusSql::BA_BUILDING;
    }

    if ( $href->{state} eq BaracusSql::BA_DISKWIPE or
         $href->{state} eq BaracusSql::BA_WIPED ) {
        $state = BaracusSql::BA_WIPING;
    }

    # BA_FOUND BA_DISABLED BA_DELETED # these shouldn't be served

    $href->{'state'} = $state;

    # update the host template entry
    &update_db_host_entry( $href );


    # now handle pxe autodisable
    if ( defined $autodisablepxe and $autodisablepxe eq "yes" ) {
        print "post_pxe_deliver_passed called but autodisablepxe flag == 'yes'\n"
            if $debug;

        my $pxename = $mac;
        $pxename =~ s|:|-|g;
        $pxename = "01-" . $pxename;

        my $description = "delivered and auto-disabled";

        print "baconfig update tftp --name $pxename --noenable --description \"$description\"" if $debug;

        my $status = system("baconfig update tftp --name $pxename --noenable --description \"$description\"");
    }

    return 0;
}

###########################################################################

sub get_db_host_entry() {

    my $cols = lc get_cols( 'host' );

    my $sql = qq|SELECT $cols FROM $tbl{ host } WHERE hostname = ? |;

    print $sql . "and hostname is $hostname \n" if $debug;

    my $sth = $dbh->prepare( $sql )
        or die "Cannot prepare select statement\n" . $dbh->errstr;
    $sth->execute( $hostname )
        or die "Cannot execute select statement\n" . $sth->err;

    return $sth->fetchrow_hashref();
}

sub get_db_host_by_mac() {

    my $cols = lc get_cols( 'host' );

    my $sql = qq|SELECT $cols FROM $tbl{ host } WHERE mac = ? |;

    print $sql . "and mac is $mac \n" if $debug;

    my $sth = $dbh->prepare( $sql )
        or die "Cannot prepare select statement\n" . $dbh->errstr;
    $sth->execute( $mac )
        or die "Cannot execute select statement\n" . $sth->err;

    return $sth->fetchrow_hashref();
}

sub update_db_host_entry() {

    my $href = shift;  # entry passed in with any needed mods

    my $sql_cols = lc get_cols( 'host' );
    $sql_cols =~ s/[ \t]*//g;
    my @cols = split( /,/, $sql_cols );
    $sql_cols ="";
    my $sql_vals = "";
    foreach my $col ( @cols ) {
        next if ( $col eq "hostname" );  # skip the key
        next if ( $col eq "change" );    # skip update col if present
        if ( defined $href->{ $col } ) {
            $sql_cols .= "$col,";
            $sql_vals .= "'$href->{ $col }',";
        }
    }
    $sql_cols .= "change";
    $sql_vals .= "CURRENT_TIMESTAMP(0)";

    my $sql = qq|UPDATE $tbl{ host }
                SET ( $sql_cols ) = ( $sql_vals )
                WHERE hostname = ?
                |;

    print $sql . "and hostname is $href->{ hostname }\n" if $debug;

    my $sth = $dbh->prepare( $sql )
        or die "Cannot prepare update statement\n" . $dbh->errstr;

    $sth->execute( $href->{hostname} )
        or die "Cannot execute update statement\n" . $sth->err;

    $sth->finish;
    undef $sth;
}

sub less_than_delta {

    use Time::Local;
 
    my $change = shift;   # string like 2009-05-13 14:01:02.08 _localtime_
    my $delta  = shift;
    my $now    = time();  # UTC... gah

    # remove fractions of seconds
    $change =~ s|\..*||;
    my @emit = split( /[-:\s]+/, $change);
    # rebase month for '0' offset from january
    --$emit[1];

    my $then = timelocal( reverse( @emit ));

    $change = $now - $then;
    return ( $change < $delta ) ? 1 : 0;
}

sub get_cols
{
    my $tbl = shift;
    my $baracustbls = BaracusSql::get_baracus_tables()->{ $tbl{ $tbl } };
    if ( defined $baracustbls ) {
        return BaracusSql::keys2columns( $baracustbls );
    }
    else {
        die "Internal database table/name usage error.\n";
    }
}

sub check_command
{
    my $command = shift;

    my $cmd_list = join ', ', (sort keys %cmds);
    unless ( defined $command ) {
        print "Requires <command> (e.g. $cmd_list)\n";
        exit 1;
    }

    unless ( defined $cmds{ $command } ) {
        print "Invalid <command> '$command' please use:  $cmd_list\n";
        exit 1;
    }
}
