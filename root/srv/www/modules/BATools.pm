package BATools;

use XML::Simple;

my $qsPath = "/usr/share/baracus/qs.xml";
my $hwcmd = "sudo create_install_host list hardware";

sub hello_message
{
   return "Hello, World!";
}

###########################################################################################
# return an array of distributions
###########################################################################################
sub get_distros
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
sub get_distro_selection_list
{
	$select = $_[0];
	$disable = $_[1];
	$script = $_[2];
	
	if($disable)
	{
		$disabled = "disabled";
	}
	else
	{
		$disabled = "";
	}
	
	$retString = "<select name='distro' enabled $script>\n";

	@distros = get_distros();
	
	foreach (@distros)
	{
			$val = $_;
			if( $val eq $select)
			{
				$isSelected = "selected";
				$retString =~ s/enabled/$disabled/;	
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
#  Generate hardware selection list for form based on hwcmd from create_install_host              
###########################################################################################
sub get_hardware_selection_list
{
	$hardware = $_[0];
	$disable = $_[1];
	if( $disable)
	{
		$disabled = "disabled";
	}
	else
	{
		$disabled = "";
	}

	$retString = "<select name='hardware' enabled>\n";

	@hwarray = get_hardware();

	foreach (@hwarray)
	{
		if( length($_) > 1)
		{
			@pair = split("\t", $_, 2);
			$val = substr( @pair[1], 3); 
			chop($val);
			
			# If parameter was passed in make that hwtype selected and disable, otherwise select kvm
			if( length($_[0]) > 1) 
			{
				# FIX: This could potentially result in multiple selected items if they start with the same prefix 
				#		(example: kvm1, and kvm2 are in hardware list and kvm is passed)
				if( $hardware =~ m/^@pair[0]/)
				{
					$isSelected = "selected";
					$retString =~ s/enabled/$disabled/;	
				}
				else
				{
					$isSelected = "";
				}
			}
			else
			{
				if( @pair[0] eq "kvm-hda")
				{
					$isSelected = "selected";
				}
				else
				{
					$isSelected = "";
				}
			}
			
			$option = "<option value='@pair[0]' $isSelected>$val</option>\n";	
			$retString = $retString.$option;
		}
	}
	
	$retString = $retString."</select><br>\n";
	
	return $retString;	
}

sub get_hardware
{
	$hwstring = `$hwcmd`; 
	@hwarray = split("\n", $hwstring, -1);
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



1;