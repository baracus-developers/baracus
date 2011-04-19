package Baracus::Config;

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

use Config::General;
use Dancer qw( :syntax );

=head1 NAME

B<Baracus::Config> - load /etc/sysconfig/baracus, other settings, and multiarg handler

=head1 SYNOPSIS

In order to prevent the parsing of the same file in multiple places
and the generation of the other well know variables needed we provide
this solution.

baVars is a hash containing all the sysconfig variables

baDirs is a hash containing all the Baracus dirs of interest

The subroutine -- multiarg_handler -- is used in the getops calls for
args/opts that allow multiple invocations

=cut

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

BEGIN {
  use Exporter ();
  use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
  @ISA         = qw(Exporter);
  @EXPORT      = qw();
  @EXPORT_OK   = qw();
  %EXPORT_TAGS =
      (
       vars =>
       [qw(
              %baVar
              %baDir
              %multiarg
              $bfsize
          )],
       subs =>
       [qw(
              multiarg_handler
              get_xml_filelist
          )],
       );
  Exporter::export_ok_tags('vars');
  Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

use vars qw( %baVar %baDir $bfsize );

$bfsize = 104857600; # 100M

# get the sysconfig option settings

my $sysconfigfile = '/etc/sysconfig/baracus';

my $conf = new Config::General
    (
     -ConfigFile => $sysconfigfile,
     -AllowMultiOptions => "no",
     -LowerCaseNames => 1,
     );

my %keymap =
    (
#    FOUND IN FILE          USED IN BARACUS

     'base_dir'         =>  'baracusdir',
     'server_ip'        =>  'serverip',
     'share_type'       =>  'sharetype',
     'share_ip'         =>  'shareip',
     'baracusd_options' =>  'bdoptions',
     'remote_logging'   =>  'rlogging',
     'ipmi'             =>  'ipmi',
     'ipmi_lan'         =>  'ipmilan',
     'ipmi_passwd'      =>  'ipmipasswd',
     );

%baVar =
    (
     baracusdir       => "" ,
     serverip         => "" ,
     sharetype        => "" ,
     shareip          => "" ,
     bdoptions        => "" ,
     rlogging         => "" ,

     base_dir         => "" ,
     server_ip        => "" ,
     share_type       => "" ,
     share_ip         => "" ,
     baracusd_options => "" ,
     remote_logging   => "" ,

     ipmi             => "" ,
     ipmi_lan         => "" ,
     ipmi_passwd      => "" ,
     );

my %tmpHash = $conf->getall;

# load from file and assign to baVar by both keys

while ( my ($key, $value) = each %tmpHash ) {
    if (ref($value) eq "ARRAY") {
        print "$key has more than one entry or value specified\n";
        print "Such ARRAYs are not supported.\n";
        exit(1);
        #           foreach my $avalue (@{$aref->{$key}}){
        #               print "$avalue\n";
        #           }
    }
    if (defined $value) {
        $baVar{ $key }           = $value;
        $baVar{ $keymap {$key} } = $value;
    }
}

if ( length($baVar{serverip}) == 0) {

    use IO::Interface::Simple;
    my @interfaces = IO::Interface::Simple->interfaces;
    my $serverip = "";

    for my $if (@interfaces) {
        if ($if->is_loopback) {
            next;
        }
        if (!defined($if->address) || !$if->is_running) {
            next;
        }

        $serverip = $if->address;
        last;
    }

    if ( $serverip ne "" ) {
        $baVar{serverip}  = $serverip;
        $baVar{server_ip} = $serverip;
     }
}
if ( length($baVar{shareip}) == 0 ) {

    if ( $baVar{serverip} ne "" ) {
        $baVar{shareip}  = $baVar{serverip};
        $baVar{share_ip} = $baVar{serverip};
    }
}


if ($baVar{ bdoptions } =~ m|debug|i) {
    while( my ($key, $val) = each %baVar ) {
        printf "sysconfig $key => %s\n", defined $val ? $val : "";
    }
}

my $baracusdir =  $baVar{ 'base_dir' };

# ~baracus is default base_dir
if ( $baracusdir =~ m|^~([^/]*)| ) {
    my $prepath="";
    if ( "$1" eq "" ) {
        $prepath = $ENV{HOME}
    } else {
        unless ($prepath = (getpwnam($1))[7]) {
            die "BASE_DIR has bad use of ~ or non-existent user in $sysconfigfile\n";
        }
    }
    $baracusdir =~ s|^~([^/]*)|$prepath|;
}
# remove trailing slash or spaces
$baracusdir =~ s|/*\s*$||;

# store baracus well know directories in global hash 'bdir'
my @bdirs = qw( builds byum bfdir hooks images isos logs pgsql www cache nfsroot );

my (undef,undef,$uid,$gid) = getpwnam( 'baracus' );
foreach my $bd (@bdirs) {
    $baDir{ $bd } = "$baracusdir/$bd";
    unless ( -d $baDir{ $bd } ) {
        mkdir $baDir{ $bd }, 0755 ;
        chown $uid, $gid, $baDir{ $bd };
    }
}
$baDir{ root } = $baracusdir;
$baDir{ buildroot } = $baDir{builds};

$baDir{ data } = setting('appdir');
$baDir{ templates } =  "$baDir{ data }/templates";
$baDir{ scripts } =  "$baDir{ data }/scripts";

my $baconfigdir = "/etc/baracus";
$baDir{ bcdir } = $baconfigdir;

my @bcdirs = qw( distros.d repos.d );
foreach my $bd (@bcdirs) {
    $baDir{ $bd } = "$baconfigdir/$bd";
}
$baDir{ config } = $baconfigdir;


###########################################################################


use vars qw( %multiarg ); # used for processing repeatable getoptions

# this arg handling will parse many variations
# --module=doOne,doTwo --module doThree --module "doFour,doFive doSix"
# --vars=doOne=hey,doTwo=there --vars "doThree=love,doFour=or doFive=not"
sub multiarg_handler() {
    my $option = $_[0];
    my $value  = $_[1];
    my @values;
    if ( $value ne '' ) {
        # arg specified - push into array
        @values = split(/[,\s*]/,$value);
    } else {
        # no value profided and no defaults
        # with ':s' should not get here
        # we could 'die("FINISH")'
        # but for now just return
        return;
    }
    foreach $value (@values) {
        if ( $option eq "vars" ) {
            # special check for key=value assignment syntax
            die("FINISH") if ( $value !~ m/=/ );
        }
        if (not defined $multiarg{ $option } ){
            # initialize
            $multiarg{ $option } = "$value";
        }
        elsif ( $multiarg{ $option } !~ m/$value/ ) {
            # append if not already present
            $multiarg{ $option } .= " $value";
        }
    }
}

# return array of FQN files with '.xml' extension in and below xmldir passed

sub get_xml_filelist
{
    use File::Find;

    my $opts    = shift;
    my $xmldir  = shift;
    my @xmlfiles;

    find ( { wanted =>
             sub {
                 if ($_ =~ m/^.*\.xml$/ ) {
                     print "found $File::Find::name\n" if $opts->{debug};
                     push @xmlfiles, $File::Find::fullname;
                 }
             },
             follow => 1
            },
           $xmldir );

    return @xmlfiles;
}

###########################################################################

1;

__END__


=head1 AUTHOR

David Bahi, E<lt>dbahi@novellE<gt>

=cut
