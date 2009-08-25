package BATools;

use lib '/var/spool/baracus/www/modules';
use BAdb qw(:standard);
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
	my $filter = $_[0];
	my @darray;
	my $arrayTmp;
	
	if( $filter)
	{
		@darray = BAdb::getDistros( $filter);
	}
	else
	{
		@darray = BAdb::getAllDistros();
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
	my $filter = $_[3];
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

	@distros = getDistros( $filter);
	
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

	@hwarray = BAdb::getHardwareList();

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
					$isSelected = "no2";
			}
			
			$option = "<option value='$val' $isSelected>$val</option>\n";	
			$retString = $retString.$option;
		}
	}
	
	$retString = $retString."</select><br>\n";
	
	return $retString;	
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

	my @dots = BAdb::getModuleList();	
 
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
	$string =~ s/\r|\n//g;
	
	return $string;
}

sub removeQuotes($)
{
	my $string = shift;
	$string =~ s/"//g;
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
  	open ( FILE, $fileName) || return $message;
	while( <FILE>)
	{
		$retString = $retString.$_;
	}
	close( FILE);
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
	my ($menu, $link, $cur, $sub, $reload) = @_;
				
	my $r = "";
	my $class = "";
	my $count = 0;
	my $found = 0;
	my $ifSrc = "";
	my $mitem = "";
	my $mcount = 0;
	my $tmpLink = "";
	my @marray;
	my @larray;
	
	$r = $r."<div class='menu'>\n";
	$r = $r."<ul>\n";
	
	foreach( @ {$menu})
	{
		@marray = split( "/", $_);
		$mitem = @marray[0];
			
		if( $mitem eq $cur)
		{
			$class = "current";
			$found = 1;
			$tmpLink = (@ {$link})[$count];
			@larray = split( "/", $tmpLink);
			$ifSrc = @larray[0];
		}
		else
		{
			$class = "outer";
		}
			
		$r = $r."<li>\n";
		$r = $r."<a href='$reload?op=$mitem' title='' class='$class'>$mitem</a>\n";

		if( @marray > 1)
		{
			$r = $r."<div class='submenu'>\n";
			$mcount = 0;
			foreach( @marray)
			{
				if( !($mcount))
				{
					++ $mcount;
					next;
				}
				if( $_ eq $sub)
				{
					$ifSrc = @larray[$mcount];
				}
				$r = $r."<a href='$reload?op=$mitem&sub=$_'>$_</a>\n";
				++ $mcount;
			}
			$r = $r."</div>\n";
		}
		$r = $r."</li>\n";

		++ $count;
	}
	$r = $r."</ul>\n";
	$r = $r."</div>\n";
	
	if( $found > -1)
	{
		$ifSrc = "/$BATools::baCGI/$ifSrc";
	}
	else
	{
		$ifSrc = "/$BATools::baRoot/uc.html";
	}

	$r = "<iframe frameborder='0' border='0' src=$ifSrc id='tabContent'></iframe>\n.$r";
	return $r;
}

1;
