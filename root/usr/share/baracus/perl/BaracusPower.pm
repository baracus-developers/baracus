package BaracusPower;

use 5.006;
use Carp;
use strict;
use warnings;

BEGIN {
  use Exporter ();
  use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
  @ISA         = qw(Exporter);
  @EXPORT      = qw();
  @EXPORT_OK   = qw();
  %EXPORT_TAGS =
      (
       subs => [ qw(
        off
        on
        cycle
        status
        get_bmc
        get_mac
         ) ]
       );
  Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

my %powermod = (
           'ipmi'        => 'fence_ipmilan',
           'bladecenter' => 'fence_bladecenter',
           'ilo'         => 'fence_ilo',
           'drac'        => 'fence_drac',
           'vmware'      => 'fence_vmware',
           'apc'         => 'fence_apc',
           'wti'         => 'fence_ati',
           'egenera'     => 'fence_egenera',
          );

my %cmds = (
           'ipmi'        => \&ipmi,
           'bladecenter' => \&bladecenter,
           'ilo'         => \&ilo,
           'drac'        => \&fence_drac,
           'vmware'      => \&fence_vmware,
           'apc'         => \&fence_apc,
           'wti'         => \&fence_ati,
           'egenera'     => \&fence_egenera,
          );

sub off(){

    my $bmc = shift;

    my $result = $cmds{ $bmc->{'ctype'} }($bmc, "off");

    return $result;
}

sub on() {

    my $bmc = shift;

    my $result = $cmds{ $bmc->{'ctype'} }($bmc, "on");

    return $result;
}


sub cycle() {

    my $bmc = shift;

    my $result = $cmds{ $bmc->{'ctype'} }($bmc, "cycle");

    return $result;
}

sub status() {

    my $bmc = shift;

    my $result = $cmds{ $bmc->{'ctype'} }($bmc, "status");

    return $result;
}

sub ipmi() {

    my $bmcref = shift;
    my $operation = shift;

    my %action = (
                  'on'     => 'on',
                  'off'    => 'off',
                  'cycle'  => 'reboot',
                  'status' => 'status',
                  );


    my $command = "$powermod{ $bmcref->{'ctype'} } -a $bmcref->{'bmcaddr'} -l $bmcref->{'login'} -p $bmcref->{'passwd'} -o $action{ $operation }";
    unless ($operation eq "status") { $command .= " >& /dev/null"; }
    my $result = `$command`;

    if ($action{ $operation } eq "status") {
        $result = (split / /, $result)[6];
        $result = (split /\n/, $result)[0];
        print "Power Status: $result\n";
    }

    return 0;

}

###########################################################################
#
# helper subroutines
#
###########################################################################
sub get_mac() {

    my $deviceid = shift;
    my $type = shift;
    my $dbh = shift;

    my $sql;

    if ($type eq "hostname") {
        $sql = qq| SELECT mac
                   FROM build
                   WHERE hostname = ?
                  |;
    } elsif ($type eq "ip") {
        ## handle IP case
    }
    

    my $sth;
    my $href;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) ); 
    die "$!$sth->err\n" unless ( $sth->execute( $deviceid ) );

    $href = $sth->fetchrow_hashref();

    $sth->finish;

    my $mac = uc $href->{'mac'};

    return $mac;

}

sub get_bmc() {

    my $deviceid = shift;
    my $dbh = shift;
    
    my $mac;

    ## Is deviceid a mac address, if not get mac
    if ($deviceid  =~ m|([0-9A-F]{1,2}:?){6}|) {
        $mac = $deviceid;
    } elsif ($deviceid  =~ m|(\d{1,3}\.){3}\d{1,3}|) {
        $mac = &get_mac($deviceid, "ip");
    } else {
        $mac = &get_mac($deviceid, "hostname");
    }

    ## lookup bmc info for device
    my $sth;
    my $href;

    my $sql = qq| SELECT ctype,
                         login,
                         passwd,
                         bmcaddr,
                         node,
                         other
                  FROM power_cfg
                  WHERE mac = ?
                |;

   die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
   die "$!$sth->err\n" unless ( $sth->execute( $mac ) );

    $href = $sth->fetchrow_hashref();
    $sth->finish;

    return $href;
}

sub check_powerdb_entry() {

    my $deviceid = shift;
    my $dbh = shift;

    ## lookup to make sure entry does not already exist
    my $sth;
    my $href;

    my $sql = qq| SELECT mac,
                  FROM power_cfg
                  WHERE mac = ?
                |;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( $deviceid ) );

    $href = $sth->fetchrow_hashref();

    if ($href->{'mac'}) {
        die "bmc entry for $deviceid already exists\n";
    }

    $sth->finish;

    return 0;
}

sub add_powerdb_entry() {

    my $bmcref = shift;
    my $dbh = shift;

    my $sth;
    my $href;

    my $sql = qq| INSERT into power_cfg,
                  ( ctype,
                    bmcaddr,
                    mac,
                    login,
                    passwd,
                    node,
                    other,
                  )
                 VALUES ( ?, ?, ?, ?, ?, ?, ? )
                |;

    return 0;
}

1;
__END__
