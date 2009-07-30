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
# Get Distributions From Database
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
# Profile Data From Database
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

sub getProfileFromDB
{
	my $name = shift @_;
	my $cmd = "sudo baconfig detail profile $name";
	my $result = `$cmd`;
	return $result;
}

1;