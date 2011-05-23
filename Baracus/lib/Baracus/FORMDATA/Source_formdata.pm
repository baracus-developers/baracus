package Baracus::FORMDATA::Source_formdata;

use 5.006;
use strict;
use warnings;

use Dancer qw( :syntax);

use Baracus::State  qw( :vars :admin );
use Baracus::Source qw( :vars :subs );
use Baracus::Config qw( :vars :subs );
use Baracus::Services qw( :subs );
use Baracus::Aux qw( :subs );

#use Baracus::REST::Aux qw( :subs );

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
                source_formdata_add
                source_formdata_remove
                source_formdata_update
                source_formdata_enable
                source_formdata_disable
         )],
         );

    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

###########################################################################
##
## Source REST data helper Subroutines (list/add/remove/update/verify)
## for returning GET data necessary for dynammic template form population
##
## template passed $source_verbs_get->{$verb}( @_ ) which is the hashref
## returned from these subroutines

sub source_formdata_add() {

    my $distro = params->{distro};
    my $fdata = {};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    foreach my $distroid ( &get_inactive_distro_list ) {
        $fdata->{$distroid} = $distroid;
    }

    return $fdata;

}

sub source_formdata_remove() {

    my $distro = params->{distro};
    my $fdata = {};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    foreach my $distroid ( &get_enabled_disabled_distro_list( $opts, '3' ) ) {
        $fdata->{$distroid} = $distroid;
    }

    return $fdata;

}

sub source_formdata_update() {
    my $distro = params->{distro};
    my $fdata = {};

     my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    foreach my $distroid ( &get_enabled_disabled_distro_list( $opts, '3' ) ) {
        $fdata->{$distroid} = $distroid;
    }
    
    return $fdata;
}

sub source_formdata_enable() {
    my $distro = params->{distro};
    my $fdata = {};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    foreach my $distroid ( &get_enabled_disabled_distro_list( $opts, '4' ) ) {
        $fdata->{$distroid} = $distroid;
    }

    return $fdata;
}

sub source_formdata_disable() {
    my $distro = params->{distro};
    my $fdata = {};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    foreach my $distroid ( &get_enabled_disabled_distro_list( $opts, '3' ) ) {
        $fdata->{$distroid} = $distroid;
    }

    return $fdata;
}

1;
