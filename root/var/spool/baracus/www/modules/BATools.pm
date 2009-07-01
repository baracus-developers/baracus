
package BATools;

use XML::Simple;

our $profilePath = "/etc/baracus.d/profiles/";
our $poolPath = "/var/spool/baracus/www/htdocs/pool/";
our $baPath = "/var/spool/baracus/www";
our $baCGI = "baracus/ba";
our $baRoot = "baracus";
our	$debug = 0;

my $qsPath = "/usr/share/baracus/qs.xml";

sub hello_message
{
   return "Hello, World!";
}

###########################################################################################
# return an array of distributions
###########################################################################################
sub getDistrosXML
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
sub getDistros
{
	my $dcmd = "sudo baconfig list distro --quiet";
	
	my $dstring = `$dcmd`; 
	my @darray = split("\n", $dstring);
	foreach( @darray)
	{
		$_ = trim($_);
	}

	return @darray;
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
		if( length($val) > 1)
		{
			# If parameter was passed in make that hwtype selected and disable, otherwise select kvm
			if( length($_[0]) > 1) 
			{
				# FIX: This could potentially result in multiple selected items if they start with the same prefix 
				#		(example: kvm1, and kvm2 are in hardware list and kvm is passed)
				if( $hardware =~ m/^$val/)
				#if( $hardware eq $val)
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
				if( $val eq "default")
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
	my @hwarray = split("\n", $hwstring);
	foreach( @hwarray)
	{
		$_ = trim($_);
	}
	
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

sub getModuleListFromDir
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

sub getModuleList
{
	my $mcmd = "sudo baconfig list module --quiet";
	
	my $mstring = `$mcmd`; 
	my @marray = split("\n", $mstring);
	foreach( @marray)
	{
		$_ = trim($_);
	}
	
	return @marray;	
}

###########################################################################################
#  Get Currently Processing List              
###########################################################################################
sub getCurrentProcSelectionList
{
	my $disabled;

	my $current = $_[0];
	my $disable = $_[1];
	my $script = $_[2];
	
	my $r = "";
	my $firstLine = "";
	my $fName;
	
	$r = $r."<select name='current' $disable $script>\n";
	
	foreach( getCurrentProcList())
	{
	  	$fName = $poolPath.$_;
	  	open (FILE, $fName) || die "couldn't open the file!";
		$firstLine = <FILE>;
		close(FILE);
		$r = $r."<option value='$_'>".$firstLine."</option>\n";
	}
	$r = $r."</select>\n";
	return $r;
}

sub getCurrentProcList
{
	my @dots;
	my @filtered;

	opendir(DIR, $poolPath) || die "can't opendir $poolPath: $!";
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

###########################################################################################
#  Is string (parm1) in array (parm2) return 0 or 1              
###########################################################################################
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

###########################################################################################
# trim function to remove whitespace from the start and end of the string
###########################################################################################
sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

###########################################################################################
#  Return File As String              
###########################################################################################
sub readFile
{
	$fileName = $_[0];
	$message = $_[1] || "couldn't open file: $fileName";
	my $retString = "";
  	open (PROFILE, $fileName) || return $message;
	while (<PROFILE>)
	{
		$retString = $retString.$_;
	}
	close(PROFILE);
	return $retString;
}

########################################################################################################
#  Execute Command and return output
########################################################################################################
sub execute
{
	my $cmd = $_[0];	
	my $retString = "$cmd\n\n";
	$retString = `$cmd`;
	return $retString;
}

########################################################################################################
#  Get Tabs
########################################################################################################
sub getTabs(@@$$)
{
	my ($menu, $link, $cur, $reload) = @_;
				
	my $r = "";
	my $class = "";
	my $count = 0;
	my $found = 0;
	my $ifSrc = "";
	
	$r = $r."<ul id='menu'>\n";
	
	foreach( @ {$menu})
	{
		if( $_ eq $cur)
		{
			$class = "current";
			$found = 1;
			$ifSrc = (@ {$link})[$count];
		}
		else
		{
			$class = "";
		}
			
		$r = $r."<li><a href='$reload?op=$_' title='' class='$class'>$_</a></li>\n";
		++ $count;
	}
	$r = $r."</ul>\n";
	
	if( $found > -1)
	{
		$ifSrc = "/$BATools::baCGI/$ifSrc";
	}
	else
	{
		$ifSrc = "/$BATools::baRoot/uc.html";
	}

	$r = $r."<iframe src=$ifSrc id='tabContent' frameborder='0' scrolling='auto'>\n</iframe>\n";

	return $r;
}

1;
