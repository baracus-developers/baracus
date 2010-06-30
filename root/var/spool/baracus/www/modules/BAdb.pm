package BAdb;


use strict;
use warnings;

use Apache::DBI ();
use DBI ();

use lib "/usr/share/baracus/perl";
use BaracusDB;
use BaracusSql qw( :vars );
use BaracusAux qw( get_certs_hash get_version_or_enabled redundant_data );

use lib '/var/spool/baracus/www/modules';
use BATools;

my $dbh = DBI->connect
    ("DBI:Pg:dbname=baracus;port=5162",
     "wwwrun",
     "",
     {
      PrintError => 1,          # warn() on errors
      RaiseError => 0,          # don't die on error
      AutoCommit => 1,          # commit executes
      # immediately
      }
     );

my $tftph = DBI->connect
    ("DBI:Pg:dbname=sqltftp;port=5162",
     "wwwrun",
     "",
     {
      PrintError => 1,          # warn() on errors
      RaiseError => 0,          # don't die on error
      AutoCommit => 1,          # commit executes
      # immediately
      }
     );

################################################################################
# Helper Functions
################################################################################

sub cmd2array
{
    my $cmd = shift;
    my $string = BATools::execute( $cmd );
    my @array = split("\n", $string);
    foreach ( @array) {
        $_ = BATools::trim($_);
    }
    return @array;
}

sub getVersionStatus
{
    # returns list of versions for a given type and name
    # if enabled is "yes" then "version/status" is returned

    my $name    = shift;
    my $enabled = shift;
    my $type    = shift;

    my @list_in = &cmd2array( "sudo baconfig list $type $name -a -n 2>&1" );

    my @list_out;

    foreach ( @list_in ) {
        my (undef, $ver, $sts, undef ) = split( /\s+/, $_, 4);
        if ( $enabled eq "yes" ) {
            push( @list_out, "${ver}/${sts}");
        } else {
            push( @list_out, "${ver}");
        }
    }
    return @list_out
}

sub configEnableDisable
{
    my $name = shift;
    my $ver  = shift;
    my $type = shift;
    my $mode = shift;

    my $version = "";

    if ( $ver ne -1 && $ver ne "") {
        $version = "--version $ver";
    }
    my $cmd = "sudo baconfig update $type --name $name $version --${mode} 2>&1";
    my $result = `$cmd`;
    return $result;
}

sub getCerts
{
    my $type = shift;
    my $name = shift;

    my $opts = { debug => 0, LASTERROR => "" };

    # this returns a hash where the keys are distros
    # and the value is '0' for non-mandatory
    # and '1' if the mandatory flag has been set
    return get_certs_hash( $opts, $dbh, $type, $name );
}

################################################################################
# Profile Functions
################################################################################

sub getProfile
{
    my $name = shift;
    my $ver = shift;
    my $labels = shift;
    if ( $labels eq "no") {
        $labels = "--nolabels";
    } else {
        $labels = "";
    }
    my $cmd = "sudo baconfig detail profile $name $labels 2>&1";
    if ( $ver ne -1 && $ver ne "" && $ver ne "undefined") {
        $cmd = $cmd." --version $ver";
    }
    my $result = `$cmd`;
    return $result;
}

sub addProfileFromFile
{
    my $name = shift;
    my $file = shift;
    chomp( $file);
    chomp( $name);
    my $cmd = "sudo baconfig add profile --name $name --file $file 2>&1";
    my $result = `$cmd`;
    return $result;
}
sub updateProfileFromFile
{
    my $name = shift;
    my $file = shift;
    chomp( $file);
    chomp( $name);
    my $cmd = "sudo baconfig update profile --name $name --file $file 2>&1";
    my $result = `$cmd`;
    return $result;
}
sub removeProfile
{
    my $name = shift;
    my $ver = shift;
    my $version = "";
    if ( $ver ne -1 && $ver ne "") {
        $version = "--version $ver";
    }

    my $cmd = "sudo baconfig remove profile $name $version 2>&1";
    my $result = `$cmd`;
    return $result;
}

sub enableProfile
{
    my $name = shift;
    my $ver  = shift;

    return &configEnableDisable( $name, $ver, "profile", "enable" );
}

sub disableProfile
{
    my $name = shift;
    my $ver  = shift;

    return &configEnableDisable( $name, $ver, "profile", "disable" );
}

sub getProfileList
{
    return &cmd2array( "sudo baconfig list profile -q -n 2>&1" );
}

sub getProfileListAll
{
    my $filter = shift;
    $filter = "\"*$filter*\"" unless ( $filter eq "" );
    return &cmd2array( "sudo baconfig list profile $filter -a -q -n | uniq" );
}

sub getProfileVersionList
{
    my $name    = shift;
    my $enabled = shift;

    return &getVersionStatus( $name, $enabled, "profile" );
}

################################################################################
# Module Functions
################################################################################

sub getModule
{
    my $name = shift;
    my $ver = shift;
    my $labels = shift;
    if ( $labels eq "no") {
        $labels = "--nolabels";
    } else {
        $labels = "";
    }
    my $cmd = "sudo baconfig detail module $name $labels 2>&1";
    if ( $ver ne -1 && $ver ne "" && $ver ne "undefined") {
        $cmd = $cmd." --version $ver";
    }
    my $result = `$cmd`;
    return $result;
}

sub addModuleFromFile
{
    my $name = shift;
    my $file = shift;
    chomp( $file);
    chomp( $name);
    my $cmd = "sudo baconfig add module --name $name --file $file 2>&1";
    my $result = `$cmd`;
    return $result;
}

sub addModuleFromFileWithCerts
{
    my $name     = shift;
    my $file     = shift;
    my $certs    = shift;
    my $mancerts = shift;

    if ( $certs ne "") {
        $certs = qq|--cert "$certs" |;
    }

    if ( $mancerts ne "") {
        $certs .= qq|--mancert "$mancerts" |;
    }
    chomp( $file);
    chomp( $name);
    my $cmd = "sudo baconfig add module --name $name $certs --file $file 2>&1";
    my $result = `$cmd`;
#   my $result = $cmd;
    return $result;
}

sub updateModuleFromFile
{
    my $name = shift;
    my $file = shift;
    chomp( $file);
    chomp( $name);
    my $cmd = "sudo baconfig update module --name $name --file $file 2>&1";
    my $result = `$cmd`;
    return $result;
}

sub updateModuleFromFileWithCerts
{
    my $name     = shift;
    my $file     = shift;
    my $addcerts = shift;  # certify module for use with named distro
    my $rmcerts  = shift;  # remove non-mandatory cert for module
    my $mancerts = shift;  # modify cert so that module is required with dist
    my $optcerts = shift;  # modify cert so that module is not required

    my $certs = "";

    chomp( $file);
    chomp( $name);

    if ( $file ne "" ) {
        $file = "--file $file ";
    }

    if ( defined $addcerts and $addcerts ne "") {
        $certs .= qq|--addcert "$addcerts" |;
    }

    if ( defined $mancerts and $mancerts ne "") {
        $certs .= qq|--mancert "$mancerts" |;
    }

    if ( defined $optcerts and $optcerts ne "") {
        $certs .= qq|--optcert "$optcerts" |;
    }

    if ( defined $rmcerts and $rmcerts ne "") {
        $certs .= qq|--rmcert "$rmcerts" |;
    }

    my $cmd = "sudo baconfig update module --name $name $certs $file 2>&1";
#   my $result = `$cmd`;
    my $result = $cmd;
    return $result;
}

sub removeModule
{
    my $name = shift;
    my $ver = shift;
    my $version = "";
    if ( $ver ne -1 && $ver ne "") {
        $version = "--version $ver";
    }

    my $cmd = "sudo baconfig remove module $name $version 2>&1";
    my $result = `$cmd`;
    return $result;
}

sub enableModule
{
    my $name = shift;
    my $ver  = shift;

    configEnableDisable( $name, $ver, "module", "enable");
}

sub disableModule
{
    my $name = shift;
    my $ver  = shift;

    configEnableDisable( $name, $ver, "module", "disable");
}

sub getModuleList
{
    return &cmd2array( "sudo baconfig list module -q -n 2>&1" );
}

sub getModuleListAll
{
    my $filter = shift;
    $filter = "\"*$filter*\"" unless ( $filter eq "" );
    return &cmd2array( "sudo baconfig list module $filter -a -q -n | uniq" );
}

sub getModuleVersionList
{
    my $name     = shift;
    my $enabled  = shift;

    return &getVersionStatus( $name, $enabled, "module" );
}

################################################################################
# Autobuild Functions
################################################################################

sub getAutobuild
{
    my $name   = shift;
    my $ver    = shift;
    my $labels = shift;

    if ( $labels eq "no") {
        $labels = "--nolabels";
    } else {
        $labels = "";
    }
    my $cmd = "sudo baconfig detail autobuild $name $labels 2>&1";

    if ( $ver ne -1 && $ver ne "" && $ver ne "undefined") {
        $cmd = $cmd." --version $ver";
    }
    my $result = `$cmd`;
    return $result;
}

sub addAutobuildFromFile
{
    my $name = shift;
    my $file = shift;
    chomp( $file);
    chomp( $name);
    my $cmd = "sudo baconfig add autobuild --name $name --file $file 2>&1";
    my $result = `$cmd`;
    return $result;
}

sub addAutobuildFromFileWithCerts
{
    my $name  = shift;
    my $file  = shift;
    my $certs = shift;

    if ( $certs ne "") {
        $certs = qq|--cert "$certs" |;
    }

    chomp( $file);
    chomp( $name);
    my $cmd = "sudo baconfig add autobuild --name $name $certs --file $file 2>&1";
    my $result = `$cmd`;
    return $result;
}

sub updateAutobuildFromFile
{
    my $name = shift;
    my $file = shift;
    chomp( $file);
    chomp( $name);
    my $cmd = "sudo baconfig update autobuild --name $name --file $file 2>&1";
    my $result = `$cmd`;
    return $result;
}

sub updateAutobuildFromFileWithCerts
{
    my $name = shift;
    my $file = shift;
    my $addcerts = shift;  # certify module for use with named distro
    my $rmcerts  = shift;  # remove non-mandatory cert for module

    my $certs = "";

    chomp( $file);
    chomp( $name);

    if ( $file ne "" ) {
        $file = "--file $file ";
    }

    if ( defined $addcerts and $addcerts ne "") {
        $certs .= qq|--addcert "$addcerts" |;
    }

    if ( defined $rmcerts and $rmcerts ne "") {
        $certs .= qq|--rmcert "$rmcerts" |;
    }

    my $cmd = "sudo baconfig update autobuild --name $name $certs $file 2>&1";
    my $result = `$cmd`;
    return $result;
}

sub removeAutobuild
{
    my $name = shift;
    my $ver  = shift;
    my $version = "";
    if ( $ver ne -1 && $ver ne "") {
        $version = "--version $ver";
    }

    my $cmd = "sudo baconfig remove autobuild $name $version 2>&1";
    my $result = `$cmd`;
    return $result;
}


sub enableAutobuild
{
    my $name = shift;
    my $ver  = shift;

    configEnableDisable( $name, $ver, "autobuild", "enable");
}

sub disableAutobuild
{
    my $name = shift;
    my $ver  = shift;

    configEnableDisable( $name, $ver, "autobuild", "disable");
}

sub getAutobuildList
{
    return &cmd2array( "sudo baconfig list autobuild -q -n 2>&1" );
}

sub getAutobuildListAll
{
    my $filter = shift;
    $filter = "\"*$filter*\"" unless ( $filter eq "" );
    return &cmd2array( "sudo baconfig list autobuild $filter -a -q -n | uniq" );
}

sub getAutobuildVersionList
{
    my $name     = shift;
    my $enabled  = shift;

    return &getVersionStatus( $name, $enabled, "autobuild" );
}


################################################################################
# Hardware Functions
################################################################################

sub getHardware
{
    my $name = shift;
    my $ver = shift;

    my $opts = { debug => 0, LASTERROR => "" };
    return get_version_or_enabled( $opts, $dbh, "hardware", $name, $ver );
}

sub addHardwareFromFields
{
    my $name = shift;
    my $fields = shift;
    my $args = "";
    while ( my ($key, $val) = each %{$fields} ) {
        $args .= qq|--${key} "$val" | if ( $val ne "" );
    }
    chomp( $name);
    my $cmd = "sudo baconfig add hardware --name $name $args 2>&1";
    my $result = `$cmd`;
    return $result;
}

sub addHardwareFromFieldsWithCerts
{
    my $name  = shift;
    my $certs = shift;
    my $fields = shift;
    my $args = "";

    if ( defined $fields ) {
        while ( my ($key, $val) = each %{$fields} ) {
            $args .= qq|--${key} "$val" | if ( $val ne "" );
        }
    }
    if ( $certs ne "") {
        $certs = qq|--cert "$certs" |;
    }

    chomp( $name);
    my $cmd = "sudo baconfig add hardware --name $name $certs $args 2>&1";
    my $result = `$cmd`;
    return $result;
}

sub updateHardwareFromFields
{
    my $name = shift;
    my $fields = shift;
    my $args = "";
    while ( my ($key, $val) = each %{$fields} ) {
        $args .= qq|--${key} "$val" |;
    }
    chomp( $name);
    my $cmd = "sudo baconfig update hardware --name $name $args 2>&1";
    my $result = `$cmd`;
    return $result;
}

sub updateHardwareFromFieldsWithCerts
{
    my $name     = shift;
    my $fields   = shift;
    my $addcerts = shift;
    my $rmcerts  = shift;
    my $args     = "";
    my $certs    = "";

    while ( my ($key, $val) = each %{$fields} ) {
        $args .= qq|--${key} "$val" |;
    }

    if ( defined $addcerts and $addcerts ne "") {
        $certs .= qq|--addcert "$addcerts" |;
    }

    if ( defined $rmcerts and $rmcerts ne "") {
        $certs .= qq|--rmcert "$rmcerts" |;
    }
    chomp( $name);
    my $cmd = "sudo baconfig update hardware --name $name $certs $args 2>&1";
    my $result = `$cmd`;
    return $result;
}

sub removeHardware
{
    my $name = shift;
    my $ver  = shift;
    my $version = "";
    if ( $ver ne -1 && $ver ne "") {
        $version = "--version $ver";
    }

    my $cmd = "sudo baconfig remove hardware $name $version 2>&1";
    my $result = `$cmd`;
    return $result;
}

sub enableHardware
{
    my $name = shift;
    my $ver  = shift;

    return configEnableDisable( $name, $ver, "hardware", "enable");
}

sub disableHardware
{
    my $name = shift;
    my $ver  = shift;

    return configEnableDisable( $name, $ver, "hardware", "disable");
}

sub getHardwareList
{
    return &cmd2array( "sudo baconfig list hardware -q -n 2>&1" );
}

sub getHardwareListAll
{
    my $filter = shift;
    $filter = "\"*$filter*\"" unless ( $filter eq "" );
    return &cmd2array( "sudo baconfig list hardware $filter -a -q -n | uniq" );
}

sub getHardwareVersionList
{
    my $name     = shift;
    my $enabled  = shift;

    return &getVersionStatus( $name, $enabled, "hardware" );
}

################################################################################

sub getHostTemplates
{
    my $filter = shift;
    return getHostList( $filter, "templates");
}

sub getHostNodes
{
    my $filter = shift;
    return getHostList( $filter, "nodes");
}

sub getHostStates
{
    my $filter = shift;
    return getHostList( $filter, "states -n");
}

sub getHostList
{
    my $filter   = shift;
    my $listType = shift;

    return &cmd2array( "sudo bahost list $listType $filter -q -n" );
}

sub getNodeDetail
{
    my $mac = shift;
    my $hostCmd = "sudo bahost detail node --mac='$mac' -q -n";
    my $data = BATools::execute( $hostCmd);
    return $data;
}
sub getHostTemplate
{
    my $name = shift;
    my $hostCmd = "sudo bahost list templates --hostname='$name' -n";
    my $data = BATools::execute( $hostCmd);
    return $data;
}

sub getNodeInventory
{
    my $mac = shift;
    my $cmd = "sudo baconfig list tftp $mac.inventory -q 2>&1";
    my $data = `$cmd`;
    return $data;
}

sub checkRedundant
{
    my $type = shift;
    my $name = shift;
    my $data = shift;

    my $opts = { debug => 0, LASTERROR => "" };
    my $redundant = &redundant_data( $opts, $dbh, $type, $name, $data );

    return $opts->{LASTERROR};
}

################################################################################
# Source Functions
################################################################################

sub getSourceStatus
{
    my $distro = shift;
    my $cmd = "sudo basource list -a -n --distro $distro";
    my $data = BATools::execute( $cmd);
    my @oneArray = split( " ", $data);
    return BATools::trim($oneArray[1]);
}

sub enableSource
{
    my $distro = shift;
    my $cmd = "sudo basource enable --distro $distro";
    return BATools::execute( $cmd);
}

sub disableSource
{
    my $distro = shift;
    my $cmd = "sudo basource disable --distro $distro";
    return BATools::execute( $cmd);
}

################################################################################
# Distribution Functions
################################################################################

sub getAddonsForDistro
{
    my $distro = shift;
    my $flag   = shift;
    my $status = shift;

    my $quiet;
    $quiet = $flag =~ m/q/ ? "-q" : "";

    if ( $status) {
        $quiet = "";
        $status = "| grep $status";
    } else {
        $status = "";
    }

    # notice that, in the command string, $status MUST COME LAST
    my $cmd = "sudo basource list addon --distro $distro -a -n $quiet $status";

    my $list = BATools::execute( $cmd);
    return split("\n", $list);
}

sub getDistros
{
    my $filter = shift;
    my $status = shift;
    my $catagory = shift;

    $filter = "*" if ( !$filter || $filter eq "");

    return BAdb::getDistrosFromCL( $filter, $status, $catagory);
}

sub getDistrosFromCL
{
    my $filter = shift;
    my $status = shift;
    my $catagory = shift;
    my @darray;
    my @tmpArray;
    my $name;
    my $value;
    my $all;

    if ( $status eq "current") {
        $all = "";
        $status = "";
    } elsif ( $status eq "enabled") {
        $status = "| grep enabled";
    } elsif ( $status eq "disabled") {
        $status = "| grep disabled";
    } elsif ( $status eq "removed") {
        $status = "| grep removed";
    } elsif ( $status eq "none") {
        $status = "| grep none";
    } else {
        $status = "";
    }

    # notice that, in the command string, $status MUST COME LAST
    return &cmd2array("sudo basource list $catagory --distro='*$filter*' -a -n $status");
}

sub getDistro
{
    my $name = shift;
    return BATools::execute( "sudo basource verify --distro $name" );
}

sub getDistroStatus
{
    my $name = shift;
    my $cmd = "sudo basource list -a -n --distro $name";
    my $data = BATools::execute( $cmd);
    my $r = "";

    foreach ( @BATools::statusList) {
        if ( $data =~ m/$_/) {
            return $_;
        }
    }
    return "NONE";
}

################################################################################
# Power Functions
################################################################################

sub getPowerList
{
    my $filter = shift;
    my $sql = qq| SELECT *
                  FROM $baTbls{'power'}
                  WHERE mac LIKE '$filter%'
               |;

    my $sth;
    my $href;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute() );

    $href = $sth->fetchall_hashref('hostname');

    return $href;

}

################################################################################
# Repository Functions
################################################################################

sub getRepoList
{
    my $filter = shift;

    return &cmd2array( "sudo barepo list \"$filter\" -q" );
}

sub getRepoDetail
{
    my $repo = shift;
    my $cmd = "sudo barepo detail $repo -q";
    my $data = BATools::execute( $cmd );
    my @detailArray = split( "\n", $data);
    foreach ( @detailArray) {
        $_ = BATools::trim($_);
    }
    return @detailArray;
}

################################################################################
# Storage Functions
################################################################################

sub getStorageList
{
    return cmd2array( "sudo bastorage list -q" );
}

sub getStorageListDb
{
    my $filter = shift;

    my $sql = qq| SELECT *
                  FROM $baTbls{'lun'}
                  WHERE targetid LIKE '$filter%'
               |;

    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute() );

    my $href = $sth->fetchall_hashref('targetid');

    return $href;
}

sub getStorageDetail
{
    my $targetid = shift;
    my $sql = qq| SELECT *
                  FROM $baTbls{'lun'}
                  WHERE targetid = '$targetid'
               |;

    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute() );

    my $href = $sth->fetchrow_hashref();

    return $href;
}

################################################################################
# Log Functions
################################################################################

sub getCommandLog
{
    my $mac = shift;
    my $cmd = "sudo balog list commands --filter \"mac\:\:${mac}\" --verbose";
    my $log = BATools::execute( $cmd);
    return $log
}

sub getStateLog
{
    my $mac = shift;
    my $cmd = "sudo balog list states --filter \"mac\:\:$mac\" ";
    my $log = BATools::execute( $cmd);
    return $log
}

1;
