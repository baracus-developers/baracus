package Baracus::REST::Host;

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
                host_list
                host_detail
                host_add
                host_remove
                host_enable
                host_disable
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
## Main Host REST Subroutines (list/detail/add/remove/enable/disable)

sub host_list() {

}

sub host_detail() {

}

sub host_add() {

}

sub host_remove() {

}

sub host_enable() {

}

sub host_disable() {

}

1;
