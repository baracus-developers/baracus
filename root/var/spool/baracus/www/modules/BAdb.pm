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

sub getAllDistros
{
	my $arrayTmp = getAllDistrosFromDB( "*");
	my @darray;
	foreach( @$arrayTmp)
	{
		push( @darray, $_->[0]);
	}
	return @darray;
}

sub getDistros
{
		my $filter = shift @_;
		my @darray;
		my @curArray;
		my $arrayTmp = BAdb::getDistrosFromDB( "*");
		my $status;
		
		if( $filter eq "current")
		{
			foreach( @$arrayTmp)
			{
				push( @curArray, $_->[0]);
			}
			@darray = @curArray;
		}
		elsif( $filter eq "enabled" ||
				$filter eq "disabled")
		{
			if( $filter eq "enabled")
			{
				$status = 1;
			}
			else
			{
				$status = 2;
			}	
			foreach( @$arrayTmp)
			{
				if( $_->[1] eq $status)
				{
					push( @curArray, $_->[0]);
				}
			}
			@darray = @curArray;
		}
		elsif( $filter eq "nocurrent")
		{
			foreach( @$arrayTmp)
			{
				push( @curArray, $_->[0]);
			}
			my @allDistros = BAdb::getAllDistros();
			my $iter = 0;
			foreach $all ( @allDistros)
			{
				
				foreach $cur( @curArray)
				{
					if( $all eq $cur)
					{
						splice( @allDistros, $iter, 1);
					}
				}
				++ $iter;	
			}
			@darray = @allDistros;
				
		}
		else
		{
			push( @darray, "- FILTER ERROR -");
		}
		return @darray;
}

sub getDistrosFromDB
{

    my $os = shift @_;
    $os =~ s/\*/\%/g;

    my $dbname = "sqltftp";
    my $dbrole = "wwwrun";

    $dbh = BaracusDB::connect_db( $dbname, $dbrole );
        die BaracusDB::errstr unless( $dbh );

    my $sql = q|SELECT distro,
    					status
                FROM sqlfstable_reg
                WHERE distro LIKE ?|;

    my $sth = $dbh->prepare( $sql )
        or die "Cannot prepare sth: ",$dbh->errstr;

    $sth->execute($os)
        or die "Cannot execute sth: ",$sth->errstr;

    my $fetchall = $sth->fetchall_arrayref();

    die BaracusDB::errstr unless BaracusDB::disconnect_db( $dbh );

    return $fetchall;

}

sub getAllDistrosFromDB
{
    my $id = shift @_;
    $id =~ s/\*/\%/g;

    my $dbname = "baracus";
    my $dbrole = "wwwrun";
    my $type = "distro";

    $dbh = BaracusDB::connect_db( $dbname, $dbrole );
        die BaracusDB::errstr unless( $dbh );

    $sql = q|SELECT distroid as name, description
		       FROM distro_cfg
                WHERE distroid LIKE ?
              |;
 
    my $sth = $dbh->prepare( $sql )
        or die "Cannot prepare sth: ",$dbh->errstr;

    $sth->execute($id)
        or die "Cannot execute sth: ",$sth->errstr;

    my $fetchall = $sth->fetchall_arrayref();

    die BaracusDB::errstr unless BaracusDB::disconnect_db( $dbh );

    return $fetchall;
}

###########################################################################################
# Profile Functions
###########################################################################################

sub getProfileListFromDB
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


sub getProfileListAllFromDB
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

sub getProfileFromDB
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
sub removeProfileFromDB
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
	my $result = `$cmd`;
	return $result;	
}
sub updateModuleFromFile
{
	my $name = shift @_;
	my $file = shift @_;
	chomp( $file);
	chomp( $name);
	my $cmd = "sudo baconfig update module --name $name --file $file";
	my $result = `$cmd`;
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
	my $filter = shift @_;
	$filter = $filter eq "" ? "" : "--host='*$filter*'";
	my @hostArray;
	my $hostCmd = "sudo bahost list templates $filter --quiet";
	my $hosts = BATools::execute( $hostCmd);
	@hostArray = split("\n", $hosts);
	foreach( @hostArray)
	{
		$_ = BATools::trim($_);
	}
	return @hostArray;
}
sub getHostTemplate
{
	my $name = shift @_;
	my $hostCmd = "sudo bahost list templates --hostname='$name' --nolabels";
	my $data = BATools::execute( $hostCmd);
	return $data;
}

1;