package BaracusConfig;

use 5.006;
use Carp;
use strict;
use warnings;

use AppConfig;

=head1 NAME

BaracusConfig - load /etc/sysconfig/baracus and other settings

=head1 SYNOPSIS

In order to prevent the parsing of the same file in multiple places
and the generation of the other well know variables needed we provide
this solution.

baVars is a hash containing all the sysconfig variables

baDirs is a hash containing all the Baracus dirs of interest

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
       vars => [ qw( %baVar %baDir ) ]
       );
  Exporter::export_ok_tags('vars');
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
%baDir =
    (
     'root' => "$baracusdir",
     'data' => "/usr/share/baracus",
     );
foreach my $bd (@bdirs) {
    $baDir{ $bd } = "$baracusdir/$bd";
}


1;

__END__


=head1 AUTHOR

David Bahi, E<lt>dbahi@novellE<gt>

=cut
