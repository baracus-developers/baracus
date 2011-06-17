package Baracus::Power;

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

use Dancer qw( :syntax );
use Dancer::Plugin::Database;

use Baracus::Config qw( :vars :subs );

BEGIN {
  use Exporter ();
  use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
  @ISA         = qw(Exporter);
  @EXPORT      = qw();
  @EXPORT_OK   = qw();
  %EXPORT_TAGS =
      (
       subs   =>
       [qw(
              padd
              add_powerdb_entry
              premove
              poff
              pon
              pcycle
              pstatus
              get_power_mac_by_hostname
              get_bmc
              get_bmcref_req_args
          )]
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
           'vmware_ws'   => 'vmrun',
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
           'vmware_ws'   => \&vmware_ws,
           'apc'         => \&fence_apc,
           'wti'         => \&fence_ati,
           'egenera'     => \&fence_egenera,
           'mainframe'   => \&bazvmpower,
          );

sub padd() {

    my $opts = shift;
    my $bmc  = shift;

    my $result = $cmds{ add }( $opts, $bmc );

    return $result;
}

sub premove() {

    my $opts = shift;
    my $bmc  = shift;

    my $result = $cmds{ remove }( $opts, $bmc );

    return $result;
}

sub poff() {

    my $bmc = shift;

    my $result = $cmds{ $bmc->{'ctype'} }($bmc, "off");

    return $result;
}

sub pon() {

    my $bmc = shift;

    my $result = $cmds{ $bmc->{'ctype'} }($bmc, "on");

    return $result;
}


sub pcycle() {

    my $bmc = shift;

    my $result = $cmds{ $bmc->{'ctype'} }($bmc, "cycle");

    return $result;
}

sub pstatus() {

    my $bmc = shift;

    my $result = $cmds{ $bmc->{'ctype'} }($bmc, "status");
    return $result;
}

sub ipmi() {

    my $bmcref    = shift;
    my $operation = shift;

    my %action = (
                  'on'     => 'on',
                  'off'    => 'off',
                  'cycle'  => 'reboot',
                  'status' => 'status',
                  );


    my $command = "sudo $powermod{ $bmcref->{'ctype'} } -a $bmcref->{'bmcaddr'} -l $bmcref->{'login'} -p $bmcref->{'passwd'} -o $action{ $operation }";
    unless ($operation eq "status") { $command .= " >& /dev/null"; }
    my $result = `$command`;

    if ($action{ $operation } eq "status") {
        $result = (split / /, $result)[6];
        $result = (split /\n/, $result)[0];
    }

    return $result;

}

sub virsh() {

    my $bmcref    = shift;
    my $operation = shift;

    my $command;

    my %action = (
                  'on'     => 'start',
                  'off'    => 'destroy',
                  'cycle'  => 'reboot',
                  'status' => 'domstate',
                  );

    if ( $bmcref->{'ctype'} eq "virsh" ) {
        if ( ! defined $bmcref->{'bmcaddr'} ) {
            $bmcref->{'bmcaddr'} = "remote:///";
        } elsif ( $bmcref->{'bmcaddr'} =~ m|^(\d{1,3}\.){1,3}\d{1,3}$| ) {
            if ( defined $bmcref->{'login'}
                 and $bmcref->{'login'} ne "none"
                 and $bmcref->{'login'} ne "" ) {
                $bmcref->{'bmcaddr'} = "$bmcref->{'login'}\@$bmcref->{'bmcaddr'}";
            }
            $bmcref->{'bmcaddr'} = "remote+ssh://$bmcref->{'bmcaddr'}/";
        }
    }

    $command = "sudo $powermod{ $bmcref->{'ctype'} } --connect $bmcref->{'bmcaddr'} $action{ $operation } $bmcref->{'hostname'}";
    unless ($operation eq "status") { $command .= " >& /dev/null"; }

    my $result;
    if ( $operation eq "status") {
        my $olduid = $>;
        $> = 0;
        $result = `$command`;
        chomp $result;
#        print "Power status: $result";
        $> = $olduid;
    } else {
        $result = `$command`;
    }
    return $result;
}

sub drac() {

    my $bmcref    = shift;
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
    }

    return $result;

}

sub bladecenter() {

    my $bmcref    = shift;
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
    }

    return $result;

}

sub ilo() {

    my $bmcref    = shift;
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
    }

    return $result;

}

sub vmware() {

    my $bmcref    = shift;
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
    }

    return $result;

}

sub vmware_ws() {

    my $bmcref    = shift;
    my $operation = shift;

    my $status;
    my %action = (
                  'on'     => 'start',
                  'off'    => 'stop',
                  'cycle'  => 'reset',
                  'status' => 'list',
                  );

    my $command = "ssh $bmcref->{'login'}". "@" ."$bmcref->{'bmcaddr'} $powermod{ $bmcref->{'ctype'} } $action{ $operation } $bmcref->{'node'}";
    $command .= " nogui" if ( $action{ $operation } eq "start" );
    $command .= " hard" if  ( $action{ $operation } eq "stop" );
    unless ($operation eq "status") { $command .= " >& /dev/null"; }
    my $result = `$command`;

    if ($action{ $operation } eq "list") {
        $status = "not running";
        if ($result =~ m/$bmcref->{'node'}/) {
            $status = "running";
        } 
    }

    return $result;

}

sub bazvmpower() {

    my $bmcref    = shift;
    my $operation = shift;

    my $command = "curl -sSH 'Accept: text/x-yaml' http://$bmcref->{'bmcaddr'}:5000/power/$operation?node=$bmcref->{'node'}";
    unless ($operation eq "status") { $command .= " >& /dev/null"; }
    my $result = `$command`;

    if ($operation eq "status") {
        if ($result =~  m/status: (.*)/g) {
           return $1;
        } elsif ($result =~  m/Error (4\d+)/g) {
            error "Error $1\n";
        } else {
            error "Unknown error:\n$result\n";
        }
    }

}

###########################################################################
#
# helper subroutines
#
###########################################################################
sub get_power_mac_by_hostname() {

    my $opts     = shift;
    my $hostname= shift;

    my $sql = qq| SELECT mac
                  FROM power
                  WHERE hostname = '$hostname'
                |;

    my $href;

    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;
        $href = $sth->fetchrow_hashref();
        $sth->finish;
        undef $sth;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    my $mac = uc $href->{'mac'};
    return $mac;

}

sub get_bmc() {

    my $opts     = shift;
    my $type     = shift;
    my $deviceid = shift;

    unless ( defined $type ) {
        return 1;
    }

    ## lookup bmc info for device
    my $sql = qq| SELECT mac,
                         ctype,
                         hostname,
                         login,
                         passwd,
                         bmcaddr,
                         node,
                         other
                  FROM power
                  WHERE mac = '$deviceid'
                |;

    my $href;
    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;
        $href = $sth->fetchrow_hashref();
        $sth->finish;
        undef $sth;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    return $href;
}

sub check_powerdb_entry() {

    my $opts     = shift;
    my $deviceid = shift;

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
    my $sql = qq| SELECT $type
                  FROM power
                  WHERE $type = '$deviceid'
                |;

    my $href;

    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;
        $href = $sth->fetchrow_hashref();
        $sth->finish;
        undef $sth;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    if ($href->{$type}) {
	return 0;
    } else {
	return 1;
    }

}

sub add_powerdb_entry() {

    my $opts   = shift;
    my $bmcref = shift;

    unless ( defined $bmcref->{'ctype'} and
             exists  $powermod{ $bmcref->{'ctype'} } ) {
        error "Please use one of these ctypes:\n  ".join("\n  ", keys %powermod)."\n" ;
    }

    ## Check minimal required args
    foreach my $arg ( my @req_args = &get_bmcref_req_args( $bmcref ) ) {
        unless ( $bmcref->{$arg} ) {
            my $LASTERROR = "Required BMC args not provided (" .
                join(", ", @req_args) . ").\n";
            error $LASTERROR;
        }
    }

    unless ( &check_powerdb_entry( $opts, $bmcref->{mac} ) ) {
        error "deviceid: '$bmcref->{mac}' already exists\n";
    }

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

    eval {

        my $sth = database->prepare( $sql );

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

        $sth->execute;
        $sth->finish;
        undef $sth;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }    

    return 0;
}

sub remove_powerdb_entry() {

    my $opts   = shift;
    my $bmcref = shift;

    my $deviceid;
    my $type;

    unless ( ($bmcref->{'mac'}) || ($bmcref->{'hostname'}) ) {
        debug "Required BMC identifier not provided (mac or hostname). \n";
        return 1;
    }

    if ( $bmcref->{'mac'} ) {
        $deviceid = $bmcref->{'mac'};
        $type = 'mac';
    } else {
        $deviceid = $bmcref->{'hostname'};
        $type = 'hostname';
    }

    if ( &check_powerdb_entry( $opts, $deviceid ) ) {
        debug "deviceid: $deviceid does not exist\n";
        return 1;
    }

    my $sql = qq|DELETE FROM power
                 WHERE $type = '$deviceid'
                |;

    my $href;
    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;
        $sth->finish;
        undef $sth;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    return 0;

}

sub get_bmcref_req_args
{
    my $bmcref = shift;
    my @args = qw(ctype mac login passwd bmcaddr);

    if ( defined $bmcref->{'ctype'} ) {
        if ($bmcref->{'ctype'} eq "virsh") {
            @args = qw(ctype mac bmcaddr);
        } elsif ($bmcref->{'ctype'} eq "mainframe") {
            @args = qw(ctype hostname bmcaddr node);
        }
    }

    return @args;
}

1;
__END__
