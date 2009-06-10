package BATools;

use XML::Simple;

our $baPath = "/var/spool/baracus/www";
our $baCGI = "baracus/ba";
our $baRoot = "baracus";

my $qsPath = "/usr/share/baracus/qs.xml";

sub hello_message
{
   return "Hello, World!";
}

###########################################################################################
# return an array of distributions
###########################################################################################
sub getDistros
{
	my @distros;
	
	# create object
	$xml = new XML::Simple;
	
	# read XML file
	$data = $xml->XMLin("$qsPath");
	
	foreach (@{$data->{distribution}})
	{
		push( @distros, $_->{os});
	}
	return @distros;
}

###########################################################################################
#  Generate distro selection list from $distro_path xml file      
#  param1: selected item
#  param2: 1=disable selected 0=do not disable 
###########################################################################################
sub getDistroSelectionList
{
	my $disabled;
	my $select = $_[0];
	my $disable = $_[1];
	my $script = $_[2];
	my $isSelected;

	chomp($select);

	if( $disable)
	{
		$disabled = "disabled";
	}
	else
	{
		$disabled = "";
	}
		
	$retString = "<select name='distro' $disabled $script>\n";

	@distros = getDistros();
	
	foreach (@distros)
	{
			$val = $_;
			chomp($val);
			if( $val eq $select)
			{
				$isSelected = "selected";
			}
			else
			{
				$isSelected = "";
			}			
			$option = "<option value='$val' $isSelected>$val</option>\n";	
			$retString = $retString.$option;
	}
	
	$retString = $retString."</select><br>\n";
	
	return $retString;
}

###########################################################################################
#  Generate hardware selection list for form based on hwcmd from create_install_host      #        
###########################################################################################
sub getHardwareSelectionList
{
	my $disabled;
	my $hardware = $_[0];
	my $disable = $_[1];
	my $script = $_[2];
	
	if( $disable)
	{
		$disabled = "disabled";
	}
	else
	{
		$disabled = "";
	}

	$retString = "<select name='hardware' enabled $script>\n";

	@hwarray = getHardware();

	foreach $val (@hwarray)
	{
		chop($val);
		if( length($val) > 1)
		{
			# If parameter was passed in make that hwtype selected and disable, otherwise select kvm
			if( length($_[0]) > 1) 
			{
				# FIX: This could potentially result in multiple selected items if they start with the same prefix 
				#		(example: kvm1, and kvm2 are in hardware list and kvm is passed)
				#if( $hardware =~ m/^$val/)
				if( $hardware eq $val)
				{
					$isSelected = "selected";
					$retString =~ s/enabled/$disabled/;	
				}
				else
				{
					$isSelected = "no";
				}
			}
			else
			{
				if( $val eq "kvm-hda")
				{
					$isSelected = "selected";
				}
				else
				{
					$isSelected = "no2";
				}
			}
			
			$option = "<option value='$val' $isSelected>$val</option>\n";	
			$retString = $retString.$option;
		}
	}
	
	$retString = $retString."</select><br>\n";
	
	return $retString;	
}

sub getHardware
{
	my $hwcmd = "sudo baconfig list hardware --quiet";
	
	my $hwstring = `$hwcmd`; 
	my @hwarray = split("\n", $hwstring, -1);
	return @hwarray;
}


###########################################################################################
#  Generate Random String              
###########################################################################################
sub generate_random_string
{
	my $length_of_randomstring=12;

	my @chars=('a'..'z','A'..'Z','0'..'9','_');
	my $random_string;
	foreach (1..$length_of_randomstring) 
	{
		# rand @chars will generate a random 
		# number between 0 and scalar @chars
		$random_string.=$chars[rand @chars];
	}
	return $random_string;
}

###########################################################################################
#  Generate Modules Selection List (multi selection)              
###########################################################################################
sub getModuleSelectionList
{
	my $retString = "";

	my @dots = getModuleList();	
 
	foreach (@dots)
	{
		$retString = $retString."<option>$_ </option>\n";
	}	

	return $retString;
}

sub getModuleList
{
	my @dots;
	my @filtered;
	my $modulePath = "/var/spool/baracus/modules/";

	opendir(DIR, $modulePath) || die "can't opendir $modulePath: $!";
	@dots = readdir(DIR);
	foreach (@dots)
	{
		# If file is not ., .., and does not end with ~
		if( $_ ne "." && $_ ne ".." && $_ !~ m/~\Z/)
		{
			push(@filtered, $_);
		}
	}	
			
	closedir DIR;
	return @filtered;
}

sub isInArray
{
	my($myString, @myArray) = @_;
	
	foreach $item ( @myArray)
	{
		if( $myString eq $item)
		{
			return 1;		
		}
	}

	return 0;
}

1;