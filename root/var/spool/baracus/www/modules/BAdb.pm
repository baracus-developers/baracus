package BAdb;


use strict;
use warnings;

use Apache::DBI ();
use DBI ();

use lib "/usr/share/baracus/perl";
use BaracusSql qw( :vars );

use lib '/var/spool/baracus/www/modules';
use BaracusDB;
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

###########################################################################################
# Helper Functions
###########################################################################################

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

	my @list_in = &cmd2array( "sudo baconfig list $type $name -a -n" );

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
	my $cmd = "sudo baconfig update $type --name $name $version --${mode}";
	my $result = `$cmd`;
	return $result;
}

###########################################################################################
# Profile Functions
###########################################################################################

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
	my $cmd = "sudo baconfig detail profile $name $labels";
	if ( $ver ne -1 && $ver ne "" && $ver ne "undefined") {
		$cmd = $cmd." --version $ver";
	}
	my $result = `$cmd`;
	return $result."\n\n";
}

sub addProfileFromFile
{
	my $name = shift;
	my $file = shift;
	chomp( $file);
	chomp( $name);
	my $cmd = "sudo baconfig add profile --name $name --file $file";
	my $result = `$cmd`;
	return $result;
}
sub updateProfileFromFile
{
	my $name = shift;
	my $file = shift;
	chomp( $file);
	chomp( $name);
	my $cmd = "sudo baconfig update profile --name $name --file $file";
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

	my $cmd = "sudo baconfig remove profile $name $version";
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
	return &cmd2array( "sudo baconfig list profile -q -n" );
}

sub getProfileListAll
{
	return &cmd2array( "sudo baconfig list profile -a -q -n | uniq" );
}

sub getProfileVersionList
{
    my $name    = shift;
    my $enabled = shift;

	return &getVersionStatus( $name, $enabled, "profile" );
}

###########################################################################################
# Module Functions
###########################################################################################

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
	my $cmd = "sudo baconfig detail module $name $labels";
	if ( $ver ne -1 && $ver ne "" && $ver ne "undefined") {
		$cmd = $cmd." --version $ver";
	}
	my $result = `$cmd`;
	return $result."\n\n";
}

sub addModuleFromFile
{
	my $name = shift;
	my $file = shift;
	chomp( $file);
	chomp( $name);
	my $cmd = "sudo baconfig add module --name $name --file $file";
    #	my $result = `$cmd`;
	my $result = $cmd;
	return $result;
}

sub addModuleFromFileWithCerts
{
	my $name = shift;
	my $file = shift;
	my $cert = shift;
	my $mand = shift;

	if ( $cert && $cert ne "") {
		$cert = "--cert $cert";
	}

	if ( $mand && $mand ne "") {
		$mand = "--mancert $mand";
	}
	chomp( $file);
	chomp( $name);
	my $cmd = "sudo baconfig add module --name $name $cert $mand --file $file";
    #	my $result = `$cmd`;
	my $result = $cmd;
	return $result;
}

sub updateModuleFromFile
{
	my $name = shift;
	my $file = shift;
	chomp( $file);
	chomp( $name);
	my $cmd = "sudo baconfig update module --name $name --file $file";
    #	my $result = `$cmd`;
	my $result = $cmd;
	return $result;
}

sub updateModuleFromFileWithCerts
{
	my $name = shift;
	my $file = shift;
	my $cert = shift;
	my $mand = shift;

	if ( $cert && $cert ne "") {
		$cert = "--cert $cert";
	}

	if ( $mand && $mand ne "") {
		$mand = "--mancert $mand";
	}

	chomp( $file);
	chomp( $name);
	my $cmd = "sudo baconfig update module --name $name $cert $mand --file $file";
    #	my $result = `$cmd`;
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

	my $cmd = "sudo baconfig remove module $name $version";
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
	return &cmd2array( "sudo baconfig list module -q -n" );
}

sub getModuleListAll
{
	return &cmd2array( "sudo baconfig list module -a -q -n | uniq" );
}

sub getModuleVersionList
{
    my $name     = shift;
    my $enabled  = shift;

	return &getVersionStatus( $name, $enabled, "module" );
}

###########################################################################################
# Autobuild Functions
###########################################################################################

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
	my $cmd = "sudo baconfig detail autobuild $name $labels";

	if ( $ver ne -1 && $ver ne "" && $ver ne "undefined") {
		$cmd = $cmd." --version $ver";
	}
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
    return &cmd2array( "sudo baconfig list autobuild -q -n" );
}

sub getAutobuildListAll
{
    return &cmd2array( "sudo baconfig list autobuild -a -q -n | uniq" );
}

sub getAutobuildVersionList
{
    my $name     = shift;
    my $enabled  = shift;

	return &getVersionStatus( $name, $enabled, "autobuild" );
}

###########################################################################################
# Hardware Functions
###########################################################################################

sub getHardware
{
	my $name = shift;
	my $ver = shift;
	my $labels = shift;
	if ( $labels eq "no") {
		$labels = "--nolabels";
	} else {
		$labels = "";
	}
	my $cmd = "sudo baconfig detail hardware $name $labels";
	if ( $ver ne -1 && $ver ne "" && $ver ne "undefined") {
		$cmd = $cmd." --version $ver";
	}
	my $result = `$cmd`;
	return $result."\n\n";
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
    return &cmd2array( "sudo baconfig list hardware -q -n" );
}

sub getHardwareListAll
{
	return &cmd2array( "sudo baconfig list hardware -a -q -n | uniq" );
}

sub getHardwareVersionList
{
    my $name     = shift;
    my $enabled  = shift;

	return &getVersionStatus( $name, $enabled, "hardware" );
}

###########################################################################################
#
###########################################################################################

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
	my $cmd = "sudo baconfig list tftp $mac.inventory -q";
	my $data = `$cmd`;
	return $data;
}

###########################################################################################
# Source Functions
###########################################################################################

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

###########################################################################################
# Distribution Functions
###########################################################################################

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

###########################################################################################
# Power Functions
###########################################################################################

sub getPowerList
{
	my $filter = shift;

	return &cmd2array( "sudo bapower list \"$filter\" -q" );
}

###########################################################################################
# Repository Functions
###########################################################################################

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

###########################################################################################
# Storage Functions                                                                       #
###########################################################################################

sub getStorageList
{
    return cmd2array( "sudo bastorage list -q" );
}

###########################################################################################
# Storage Functions
###########################################################################################

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

###########################################################################################
# Log Functions
###########################################################################################

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
