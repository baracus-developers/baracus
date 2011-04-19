package Baracus::REST::Do;

use 5.006;
use Carp;
use strict;
use warnings;

use Baracus::DB;
use Baracus::Core   qw( :subs );
use Baracus::Config qw( :vars :subs );
use Baracus::State  qw( :vars :admin );
use Baracus::Source qw( :vars :subs );

use Baracus::REST::Aux qw( :subs );

use Dancer qw( :syntax );

BEGIN {
    use Exporter ();
    use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    @EXPORT_OK   = qw();
    %EXPORT_TAGS =
        (
         subs   =>
         [qw(
                do_build
                do_empty
                do_inventory
                do_localboot
                do_netboot
                do_norescue
                do_rescue
                do_wipe
         )],
         );

    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

my $opts = {
            verbose    => 0,
            quiet      => 0,
            all        => 0,
            nolabels   => 0,
            debug      => 0,
            execname   => "",
            LASTERROR  => "",
           };

my $dbname = "baracus";
my $dbrole = $dbname;

my $uid = Baracus::DB::su_user( $dbrole );
die Baracus::DB::errstr unless ( defined $uid );

my $dbh = Baracus::DB::connect_db( $dbname, $dbrole );
die Baracus::DB::errstr unless( $dbh );

$opts->{dbh}      = $dbh;

my $baXML = &baxml_load( $opts, "$baDir{'data'}/badistro.xml" );
$opts->{baXML}    = $baXML;


###########################################################################
##
## Main Do REST Subroutines (build/empty/inventory/localboot/netboot/norescue/rescue/wipe)

sub do_build() {

}

sub do_empty() {

}

sub do_inventory() {

}

sub do_localboot() {

}

sub do_netboot() {

}

sub do_norescue() {

}

sub do_rescue() {

}

sub do_wipe() {

}

1;
