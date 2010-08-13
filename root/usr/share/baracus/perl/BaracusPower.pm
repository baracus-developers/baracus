package BaracusPower;

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

BEGIN {
  use Exporter ();
  use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
  @ISA         = qw(Exporter);
  @EXPORT      = qw();
  @EXPORT_OK   = qw();
  %EXPORT_TAGS =
      (
       subs => [ qw(
        add
        remove
        list_start
        list_next
        off
        on
        cycle
        status
        get_bmc
        get_bmcref_req_args
         ) ]
       );
  Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

my %powermod = (
           'ipmi'        => 'fence_ipmilan',
           'virsh'       => 'virsh',
           'bladecenter' => 'fence_bladecenter',
           'ilo'         => 'fence_ilo',
           'drac'        => 'fence_drac',
           'vmware'      => 'fence_vmware',
           'apc'         => 'fence_apc',
           'wti'         => 'fence_ati',
           'egenera'     => 'fence_egenera',
           'mainframe'   => 'mainframe',
          );

my %cmds = (
           'add'         => \&add_powerdb_entry,
           'remove'      => \&remove_powerdb_entry,
           'ipmi'        => \&ipmi,
           'virsh'       => \&virsh,
           'bladecenter' => \&bladecenter,
           'ilo'         => \&ilo,
           'drac'        => \&fence_drac,
           'vmware'      => \&vmware,
           'apc'         => \&fence_apc,
           'wti'         => \&fence_ati,
           'egenera'     => \&fence_egenera,
           'mainframe'   => \&bazvmpower,
          );

sub add() {

    my $bmc = shift;

    if ($bmc->{'ctype'} eq "virsh" && ! defined($bmc->{'bmcaddr'})) {
	$bmc->{'bmcaddr'} = "qemu:///system";
    }

    my $result = $cmds{ add }($bmc);

    return $result;
}

sub remove() {

    my $bmc = shift;

    my $result = $cmds{ remove }($bmc);

    return $result;
}

sub off() {

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

sub list_start() {

    my $bmcref = shift;
    my $dbh = $bmcref->{ 'dbh' };
    my $deviceid;


    if ( ($bmcref->{'mac'}) && ($bmcref->{'hostname'}) ) {
        print "--mac and --hostname not allowed together\n";
    }

    if ( $bmcref->{'mac'} ) {
        $deviceid = $bmcref->{ 'mac' };
    } elsif ( $bmcref->{'hostname'} ) {
        $deviceid = $bmcref->{ 'hostname' };
    } else {
        $deviceid = "%";
    }

    $deviceid =~ s/\*/\%/g;

    ## lookup bmc info for device
    my $sth;

    my $sql = qq|SELECT ctype,
                         mac,
                         hostname,
                         bmcaddr,
                         login,
                         node,
                         other
                  FROM power
                |;
    $sql .= qq|WHERE mac LIKE ?| if $bmcref->{ 'mac' };
    $sql .= qq|WHERE hostname LIKE ?| if $bmcref->{ 'hostname' };
    $sql .= qq|WHERE mac LIKE ?| unless ( ($bmcref->{ 'hostname' }) || ($bmcref->{ 'mac' }) );

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( $deviceid ) );

    return $sth;

}

sub list_next() {

    my $sth = shift;
    my $href;

    $href = $sth->fetchrow_hashref();

    unless ($href) {
        $sth->finish;
        undef $sth;
        $href = "null";
    }

    return $href;

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

sub virsh() {

    my $bmcref = shift;
    my $operation = shift;

    my $command;

    my %action = (
                  'on'     => 'start',
                  'off'    => 'destroy',
                  'cycle'  => 'reboot',
                  'status' => 'domstate',
                  );


    $command = "$powermod{ $bmcref->{'ctype'} } --connect $bmcref->{'bmcaddr'} $action{ $operation } $bmcref->{'hostname'}";
    unless ($operation eq "status") { $command .= " >& /dev/null"; }


    my $result;
    if ( $operation eq "status") {
        my $olduid = $>;
        $> = 0;
        $result = `$command`;
        chomp $result;
        print "Power status: $result";
        $> = $olduid;
    } else {
        $result = `$command`;
    }

    return 0;
}

sub drac() {

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

sub bladecenter() {

    my $bmcref = shift;
    my $operation = shift;

    my %action = (
                  'on'     => 'on',
                  'off'    => 'off',
                  'cycle'  => 'reboot',
                  'status' => 'status',
                  );


    my $command = "$powermod{ $bmcref->{'ctype'} } -a $bmcref->{'bmcaddr'} -l $bmcref->{'login'} -p $bmcref->{'passwd'} -o $action{ $operation }";
    if ( $bmcref->{'node'} ) { $command .= " -n $bmcref->{'node'}"; }
    unless ($operation eq "status") { $command .= " >& /dev/null"; }
    my $result = `$command`;

    if ($action{ $operation } eq "status") {
        $result = (split / /, $result)[6];
        $result = (split /\n/, $result)[0];
        print "Power Status: $result\n";
    }

    return 0;

}

sub ilo() {

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

sub vmware() {

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

sub bazvmpower() {

    my $bmcref = shift;
    my $operation = shift;

    my $command = "curl -sSH 'Accept: text/x-yaml' http://$bmcref->{'bmcaddr'}:5000/power/$operation?node=$bmcref->{'node'}";
    unless ($operation eq "status") { $command .= " >& /dev/null"; }
    my $result = `$command`;

    if ($operation eq "status") {
	if ($result =~  m/status: (.*)/g) {
	    print "Power Status: $1\n";
	} elsif ($result =~  m/Error (4\d+)/g) {
	    print "Error $1\n";
	    return 1;
	} else {
	    print "Unknown error:\n$result\n";
	    return 1;
	}
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
    my $dbh = shift;
    my $sql;

    $sql = qq| SELECT mac
               FROM power
               WHERE hostname = ?
             |;

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
    my $type;

    ## Is deviceid a mac address, if not get mac
    if ($deviceid  =~ m|([0-9A-F]{1,2}:?){6}|) {
	$type = "mac";
    } elsif ($deviceid  =~ m|(\d{1,3}\.){3}\d{1,3}|) {
	$type = "ip";
    } else {
	$type = "hostname";
    }

    ## lookup bmc info for device
    my $sth;
    my $href;

    my $sql = qq| SELECT ctype,
                         hostname,
                         login,
                         passwd,
                         bmcaddr,
                         node,
                         other
                  FROM power
                  WHERE $type = ?
                |;

   die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
   die "$!$sth->err\n" unless ( $sth->execute( $deviceid ) );

    $href = $sth->fetchrow_hashref();
    $sth->finish;

    return $href;
}

sub check_powerdb_entry() {

    my $deviceid = shift;
    my $dbh = shift;
    my $type;

    ## Is deviceid a mac address, if not get mac
    if ($deviceid  =~ m|([0-9A-F]{1,2}:?){6}|) {
	$type = "mac";
    } elsif ($deviceid  =~ m|(\d{1,3}\.){3}\d{1,3}|) {
	$type = "ip";
    } else {
	$type = "hostname";
    }

    ## lookup to make sure entry does not already exist
    my $sth;
    my $href;

    my $sql = qq| SELECT $type
                  FROM power
                  WHERE $type = ?
                |;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( $deviceid ) );

    $href = $sth->fetchrow_hashref();

    $sth->finish;

    if ($href->{$type}) {
	return 0;
    } else {
	return 1;
    }

}

sub add_powerdb_entry() {

    my $bmcref = shift;
    my $dbh = $bmcref->{ 'dbh' };
    my $deviceid;

    $deviceid = $bmcref->{'mac'} ? $bmcref->{'mac'} : $bmcref->{'hostname'};

    unless ( &check_powerdb_entry( $deviceid, $dbh ) ) {
	die "deviceid: '$deviceid' already exists\n";
    }

    my $sth;

    my $sql = qq|INSERT INTO power
                  ( mac,
                    ctype,
                    login,
                    passwd,
                    bmcaddr,
                    node,
                    other,
                    hostname
                  )
                 VALUES ( ?, ?, ?, ?, ?, ?, ?, ? )
                |;

    die "ctype: $bmcref->{ 'ctype'} is note supported\n" unless exists $powermod{ $bmcref->{ 'ctype'} };


    $sth = $dbh->prepare( $sql )
            or die "Cannot prepare sth: ",$dbh->errstr;

    if ( defined $bmcref->{mac} ){
         $sth->bind_param( 1, $bmcref->{mac} );
    } else {
         $sth->bind_param( 1, 'NULL');
    }
    if ( defined $bmcref->{ctype} ) {
        $sth->bind_param( 2, $bmcref->{ctype} );
    } else {
        $sth->bind_param( 2, 'NULL');
    }
    if ( defined $bmcref->{login} ) {
        $sth->bind_param( 3, $bmcref->{login} );
    } else {
        $sth->bind_param( 3, 'NULL');
    }
    if ( defined $bmcref->{passwd} ) {
        $sth->bind_param( 4, $bmcref->{passwd} );
    } else {
        $sth->bind_param( 4, 'NULL' );
    }
    if ( defined $bmcref->{bmcaddr} ) {
        $sth->bind_param( 5, $bmcref->{bmcaddr} );
    } else {
        $sth->bind_param( 5, 'NULL' );
    }
    if ( defined $bmcref->{node} ) {
        $sth->bind_param( 6, $bmcref->{node} );
    } else {
        $sth->bind_param( 6, 'NULL' );
    }
    if ( defined $bmcref->{other} ) {
        $sth->bind_param( 7, $bmcref->{other} );
    } else {
        $sth->bind_param( 7, 'NULL' );
    }
    if ( defined $bmcref->{hostname} ) {
        $sth->bind_param( 8, $bmcref->{hostname} );
    } else {
        $sth->bind_param( 8, 'NULL' );
    }

    $sth->execute()
            or die "Cannot execute sth: ", $sth->errstr;

    return 0;
}

sub remove_powerdb_entry() {

    my $bmcref = shift;
    my $dbh = $bmcref->{ 'dbh' };

    unless ( ($bmcref->{'mac'}) || ($bmcref->{'hostname'}) ) {
        print "Required BMC identifier not provided (mac or hostname). \n";
        return 1;
    }

    if ( ($bmcref->{'mac'}) && ($bmcref->{'hostname'}) ) {
        print "--mac and --hostname not allowed together\n";
        return 1;
    }

    my $deviceid;
    my $type;
    if ( defined $bmcref->{'mac'} ) {
	$deviceid = $bmcref->{'mac'};
	$type = 'mac';
    } else {
	$deviceid = $bmcref->{'hostname'};
	$type = 'hostname';
    }

    if ( &check_powerdb_entry( $deviceid, $dbh ) ) {
        print "deviceid: $deviceid does not exist\n";
        return 1;
    }

    my $sth;

    my $sql = qq|DELETE FROM power
                 WHERE $type = ?
                |;

    $sth = $dbh->prepare( $sql )
            or die "Cannot prepare sth: ",$dbh->errstr;

    $sth->execute( $deviceid )
            or die "Cannot execute sth: ", $sth->errstr;

    return 0;

}

sub get_bmcref_req_args
{
    my $bmcref = shift;
    my @args = qw(ctype mac login passwd bmcaddr);

    if ($bmcref->{'ctype'} eq "virsh") {
	@args = qw(ctype mac);
    } elsif ($bmcref->{'ctype'} eq "mainframe") {
	@args = qw(ctype hostname bmcaddr node);
    }

    return @args;
}

1;
__END__
