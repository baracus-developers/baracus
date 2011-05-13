package Baracus::REST::Storage;

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
                storage_add
                storage_remove
                storage_list
                storage_detail
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
## Main Storage REST Subroutines (add/remove/list/detail)

sub storage_add() {

}

sub storage_remove() {

}

sub storage_list() {

}

sub storage_detail() {

}

1;
