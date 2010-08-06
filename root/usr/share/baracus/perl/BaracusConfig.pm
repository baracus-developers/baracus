package BaracusConfig;

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
use Carp;
use strict;
use warnings;

use AppConfig;

=head1 NAME

BaracusConfig - load /etc/sysconfig/baracus, other settings, and multiarg handler

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
          )],
       subs =>
       [qw(
              multiarg_handler
          )],
       );
  Exporter::export_ok_tags('vars');
  Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

use vars qw( %baVar %baDir );

# get the sysconfig option settings

my $sysconfig = AppConfig->new( {CREATE => 1} );

$sysconfig->define
    (
     'base_dir=s',
     'server_ip=s',
     'share_type=s',
     'share_ip=s',
     'baracusd_options=s',
     'auto_disable_pxe=s',
     'remote_logging=s',
     );

my $sysconfigfile = '/etc/sysconfig/baracus';

$sysconfig->file( $sysconfigfile );

my $baracusdir        =  $sysconfig->get( 'base_dir'         );
my $serverip          =  $sysconfig->get( 'server_ip'        );
my $sharetype         =  $sysconfig->get( 'share_type'       );
my $shareip           =  $sysconfig->get( 'share_ip'         );
my $bdoptions         =  $sysconfig->get( 'baracusd_options' );
my $autodisablepxe    =  $sysconfig->get( 'auto_disable_pxe' );
my $rlogging          =  $sysconfig->get( 'remote_logging'   );

%baVar =
    (
     baracusdir       => $baracusdir       ,
     serverip         => $serverip         ,
     sharetype        => $sharetype        ,
     shareip          => $shareip          ,
     bdoptions        => $bdoptions        ,
     autodisablepxe   => $autodisablepxe   ,
     rlogging         => $rlogging         ,

     base_dir         => $baracusdir       ,
     server_ip        => $serverip         ,
     share_type       => $sharetype        ,
     share_ip         => $shareip          ,
     baracusd_options => $bdoptions        ,
     auto_disable_pxe => $autodisablepxe   ,
     remote_logging   => $rlogging         ,
     );
#
#if ($bdoptions =~ m|debug|) {
#    while( my ($key, $val) = each %baVar ) {
#        print "baConfig $key => $val\n";
#    }
#}

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
my @bdirs = qw( builds byum hooks isos logs pgsql templates www );
foreach my $bd (@bdirs) {
    $baDir{ $bd } = "$baracusdir/$bd";
}
$baDir{ root } = $baracusdir;
$baDir{ data } = "/usr/share/baracus";
$baDir{ buildroot } = $baDir{builds};


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
        $value = lc $value;
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

###########################################################################

1;

__END__


=head1 AUTHOR

David Bahi, E<lt>dbahi@novellE<gt>

=cut
