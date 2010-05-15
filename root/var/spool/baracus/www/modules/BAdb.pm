package BAdb;

use lib "/usr/share/baracus/perl";
use lib '/var/spool/baracus/www/modules';
use BaracusDB;
use BATools;

my %tbl = (
           'distro'   => 'distro_cfg',
           'hardware' => 'hardware_cfg',
           'module'   => 'module_cfg',  
           'profile'  => 'profile_cfg', 
           'oscert'   => 'hardwareid',  
           );

###########################################################################################
# Distribution Functions
###########################################################################################

sub getAddonsForDistro
{
        my $distro = shift @_;
        my $flag = shift @_;
        my $status = shift @_;
        
		my $quiet;
		$quiet = $flag =~ m/q/ ? "-q" : "";
		
		if( $status)
		{
			$quiet = "";
			$status = "| grep $status";
		}
		else
		{
			$status = "";
		}

        $cmd = "sudo basource list -a -n $quiet addon --distro $distro $status";

        my $list = BATools::execute( $cmd);
        return split("\n", $list);
}

sub getDistros
{
		my $filter = shift @_;
		my $status = shift @_;
		my $catagory = shift @_;
		my @darray;
		
		if( !$filter || $filter eq "")
		{
			$filter = "*";
		}

		my @darray = BAdb::getDistrosFromCL( $filter, $status, $catagory);

		return @darray;
}

sub getDistrosFromCL
{
	my $filter = shift @_;
	my $status = shift @_;
	my $catagory = shift @_;	
	my @darray;
	my @tmpArray;
	my $name;
	my $value;
		
	if( $status eq "current")
	{
		$all = "";
		$status = "";
	}
	elsif( $status eq "enabled")
	{
		$status = "| grep enabled";
	}
	elsif( $status eq "disabled")
	{
		$status = "| grep disabled";
	}
	elsif( $status eq "removed")
	{
		$status = "| grep removed";
	}
	else
	{
		$status = "";
	}

	$cmd = "sudo basource list -a -n $catagory --distro='*$filter*' $status";

	my $list = BATools::execute( $cmd);
	@darray = split("\n", $list);
	return @darray;
}

sub getDistro
{
	my $name = shift @_;
	my $cmd = "sudo basource detail --distro $name";
	my $data = BATools::execute( $cmd);
	return $data;
}

sub getDistroStatus
{
	my $name = shift @_;
	my $cmd = "sudo basource list -a -n --distro $name";
	my $data = BATools::execute( $cmd);
	my $r = "";
	
	foreach( @BATools::statusList)
	{
		if( $data =~ m/$_/)
		{
			return $_;
		}
	}
	return "NONE";
}

###########################################################################################
# Profile Functions
###########################################################################################

sub getProfileList
{
	my $cmd = "sudo baconfig list profile --quiet";
	my $result = `$cmd`;
	my @array = split( "\n", $result);
	
	foreach( @array)
	{
		$_ = BATools::trim($_);
	}
	return @array;
}


sub getProfileListAll
{
	my $cmd = "sudo baconfig list profile -all --quiet | uniq";
	my $result = `$cmd`;
	my @array = split( "\n", $result);
	
	foreach( @array)
	{
		$_ = BATools::trim($_);
	}
	return @array;
}

sub getPofileVersionCount
{
	my $name = shift @_;
	my $cmd = "sudo baconfig list profile $name --all --quiet";
	my $result = `$cmd`;
	my $count = split( "\n", $result);
	return $count;
}

#Retrieve an array of versions for profile $name.  If $enabled return version/enabled
sub getPofileVersionList
{
	my $name = shift @_;
	my $enabled = shift @_;
	my $cmd = "sudo baconfig list profile $name --all";
	my @vArray;
	my $count = 0;
	open( RSLT, "$cmd |") || die "Failed: $!\n";
	
	while( $line = <RSLT>)
	{
		++ $count;	
		if( $count > 3)
		{
			my @items = split( " ", $line);
			my $pushVer =  @items[1];
			if( $enabled eq "yes")
			{
				$pushVer = @items[1]."/".@items[2];
			}
			push( @vArray, $pushVer);
		}
	}
	return @vArray;
}

sub getProfile
{
	my $name = shift @_;
	my $ver = shift @_;
	my $labels = shift @_;
	if( $labels eq "no")
	{
		$labels = "--nolabels";
	}
	else
	{
		$labels = "";
	}
	my $cmd = "sudo baconfig detail profile $name $labels";
	if( $ver ne -1 && $ver ne "" && $ver ne "undefined")
	{
		$cmd = $cmd." --version $ver";
	}
	my $result = `$cmd`;
	return $result."\n\n";
}
sub addProfileFromFile
{
	my $name = shift @_;
	my $file = shift @_;
	chomp( $file);
	chomp( $name);
	my $cmd = "sudo baconfig add profile --name $name --file $file";
	my $result = `$cmd`;
	return $result;	
}
sub updateProfileFromFile
{
	my $name = shift @_;
	my $file = shift @_;
	chomp( $file);
	chomp( $name);
	my $cmd = "sudo baconfig update profile --name $name --file $file";
	my $result = `$cmd`;
	return $result;	
}
sub removeProfile
{
	my $name = shift @_;
	my $ver = shift @_;
	my $version = "";
	if( $ver ne -1 && $ver ne "")
	{
		$version = "--version $ver";
	}
	
	my $cmd = "sudo baconfig remove profile $name $version";
	my $result = `$cmd`;
	return $result;	
}

sub enableProfile
{
	my $name = shift @_;
	my $ver = shift @_;
	my $version = "";
	if( $ver ne -1 && $ver ne "")
	{
		$version = "--version $ver";
	}
	
	my $cmd = "sudo baconfig update profile --name $name $version --enable";
	my $result = `$cmd`;
	return $result;	
}

sub disableProfile
{
	my $name = shift @_;
	my $ver = shift @_;
	my $version = "";
	if( $ver ne -1 && $ver ne "")
	{
		$version = "--version $ver";
	}
	
	my $cmd = "sudo baconfig update profile --name $name $version --noenable";
	my $result = `$cmd`;
	return $result;	
}

###########################################################################################
# Module Functions
###########################################################################################

sub getModule
{
	my $name = shift @_;
	my $ver = shift @_;
	my $labels = shift @_;
	if( $labels eq "no")
	{
		$labels = "--nolabels";
	}
	else
	{
		$labels = "";
	}
	my $cmd = "sudo baconfig detail module $name $labels";
	if( $ver ne -1 && $ver ne "" && $ver ne "undefined")
	{
		$cmd = $cmd." --version $ver";
	}
	my $result = `$cmd`;
	return $result."\n\n";
}
sub addModuleFromFile
{
	my $name = shift @_;
	my $file = shift @_;
	chomp( $file);
	chomp( $name);
	my $cmd = "sudo baconfig add module --name $name --file $file";
#	my $result = `$cmd`;
	my $result = $cmd;
	return $result;	
}

sub addModuleFromFileWithCerts
{
	my $name = shift @_;
	my $file = shift @_;
	my $cert = shift @_;
	my $mand = shift @_;
	
	if( $cert && $cert ne "")
	{
		$cert = "--cert $cert";
	}
	
	if( $mand && $mand ne "")
	{
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
	my $name = shift @_;
	my $file = shift @_;
	chomp( $file);
	chomp( $name);
	my $cmd = "sudo baconfig update module --name $name --file $file";
#	my $result = `$cmd`;
	my $result = $cmd;
	return $result;	
}

sub updateModuleFromFileWithCerts
{
	my $name = shift @_;
	my $file = shift @_;
	my $cert = shift @_;
	my $mand = shift @_;	

	if( $cert && $cert ne "")
	{
		$cert = "--cert $cert";
	}
	
	if( $mand && $mand ne "")
	{
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
	my $name = shift @_;
	my $ver = shift @_;
	my $version = "";
	if( $ver ne -1 && $ver ne "")
	{
		$version = "--version $ver";
	}
	
	my $cmd = "sudo baconfig remove module $name $version";
	my $result = `$cmd`;
	return $result;	
}

sub enableModule
{
	my $name = shift @_;
	my $ver = shift @_;
	my $version = "";
	if( $ver ne -1 && $ver ne "")
	{
		$version = "--version $ver";
	}
	
	my $cmd = "sudo baconfig update module --name $name $version --enable";
	my $result = `$cmd`;
	return $result;	
}

sub disableModule
{
	my $name = shift @_;
	my $ver = shift @_;
	my $version = "";
	if( $ver ne -1 && $ver ne "")
	{
		$version = "--version $ver";
	}
	
	my $cmd = "sudo baconfig update module --name $name $version --noenable";
	my $result = `$cmd`;
	return $result;	
}

sub getModuleList
{
	my $mcmd = "sudo baconfig list module --quiet";
	
	my $mstring = `$mcmd`; 
	my @marray = split("\n", $mstring);
	foreach( @marray)
	{
		$_ = BATools::trim($_);
	}
	
	return @marray;	
}

sub getModuleListAll
{
	my $cmd = "sudo baconfig list module -all --quiet | uniq";
	my $result = `$cmd`;
	my @array = split( "\n", $result);
	
	foreach( @array)
	{
		$_ = BATools::trim($_);
	}
	return @array;
}

sub getModuleVersionList
{
	my $name = shift @_;
	my $enabled = shift @_;
	my $cmd = "sudo baconfig list module $name --all";
	my @vArray;
	my $count = 0;
	open( RSLT, "$cmd |") || die "Failed: $!\n";
	
	while( $line = <RSLT>)
	{
		++ $count;	
		if( $count > 3)
		{
			my @items = split( " ", $line);
			my $pushVer =  @items[1];
			if( $enabled eq "yes")
			{
				$pushVer = @items[1]."/".@items[2];
			}
			push( @vArray, $pushVer);
		}
	}
	return @vArray;
}


###########################################################################################
# Storage Functions
###########################################################################################

sub getStorageList
{
	my $storecmd = "sudo bastorage list --quiet";
	
	my $string = `$storecmd`; 
	my @array = split("\n", $string);
	foreach( @array)
	{
		$_ = BATools::trim($_);
	}
	
	return @array;
}

###########################################################################################
# Hardware Functions
###########################################################################################

sub getHardwareList
{
	my $hwcmd = "sudo baconfig list hardware --quiet";
	
	my $hwstring = `$hwcmd`; 
	my @hwarray = split("\n", $hwstring);
	foreach( @hwarray)
	{
		$_ = BATools::trim($_);
	}
	
	return @hwarray;
}
sub getHardware
{
	my $name = shift @_;
	$cmd = "sudo baconfig detail hardware $name";
	return `$cmd`;
}

sub getHostTemplates
{
	$filter = shift @_;
	return getHostList( $filter, "templates");
}

sub getHostNodes
{
	$filter = shift @_;
	return getHostList( $filter, "nodes");
}

sub getHostStates
{
	$filter = shift @_;
	return getHostList( $filter, "states -n");
}

sub getHostList
{
	my $filter = shift @_;
	my $listType = shift @_;
	#$filter = $filter eq "" ? "" : "--host='*$filter*'";
	my @hostArray;
	my $hostCmd = "sudo bahost list $listType $filter --quiet";
	my $hosts = BATools::execute( $hostCmd);
	@hostArray = split("\n", $hosts);
	foreach( @hostArray)
	{
		$_ = BATools::trim($_);
	}
	#push( @hostArray, $hostCmd);
	return @hostArray;
}

sub getNodeDetail
{
	my $mac = shift @_;
	my $hostCmd = "sudo bahost detail node --mac='$mac' -q";
	my $data = BATools::execute( $hostCmd);
	return $data;
}
sub getHostTemplate
{
	my $name = shift @_;
	my $hostCmd = "sudo bahost list templates --hostname='$name' --nolabels";
	my $data = BATools::execute( $hostCmd);
	return $data;
}

sub getNodeInventory
{
	my $mac = shift @_;
	my $cmd = "sudo baconfig list tftp $mac.inventory -q";
	my $data = `$cmd`;
	return $data;
}

###########################################################################################
# Source Functions
###########################################################################################

sub getSourceStatus
{
	my $distro = shift @_;
	my $cmd = "sudo basource list --all -nolabels --distro $distro";
	my $data = BATools::execute( $cmd);
	my @oneArray = split( " ", $data);
	return BATools::trim(@oneArray[1]);
}

sub enableSource
{
	my $distro = shift @_;
	my $cmd = "sudo basource enable --distro $distro";
	return BATools::execute( $cmd);
}

sub disableSource
{
	my $distro = shift @_;
	my $cmd = "sudo basource disable --distro $distro";
	return BATools::execute( $cmd);
}

###########################################################################################
# Power Functions
###########################################################################################

sub getPowerList
{
	my $filter = shift @_;
	#$filter = $filter eq "" ? "" : "--host='*$filter*'";
	my @hostArray;
	my $hostCmd = "sudo bapower list $filter --quiet";
	my $hosts = BATools::execute( $hostCmd);
	@hostArray = split("\n", $hosts);
	foreach( @hostArray)
	{
		$_ = BATools::trim($_);
	}
	return @hostArray;
}

###########################################################################################
# Log Functions
###########################################################################################

sub getCommandLog
{
	my $mac = shift @_;
	my $cmd = "sudo balog list commands --filter mac\:\:$mac --verbose";
	my $log = BATools::execute( $cmd);
	return $log	
}

sub getStateLog
{
	my $mac = shift @_;
	my $cmd = "sudo balog list states --filter mac\:\:$mac";
	my $log = BATools::execute( $cmd);
	return $log	
}
1;
