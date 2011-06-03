package Baracus::FORMDATA::Power_formdata;

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
                power_formdata_add
                power_formdata_remove
                power_formdata_on
                power_formdata_off
                power_formdata_cycle
                power_formdata_status
         )],
         );

    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

###########################################################################
##
## Power REST data helper Subroutines (add/remove/on/off/cycle/status)
## for returning GET data necessary for dynammic template form population
##
## template passed $power_verbs_get->{$verb}( @_ ) which is the hashref
## returned from these subroutines

sub power_formdata_add() {

    my $fdata = {};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    return $fdata;

}

sub power_formdata_remove() {

    my $fdata = {};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $sth = &list_start_data ( $opts, 'power', "all" );
    while ( my $dbref = &list_next_data( $sth ) ) {
        $fdata->{$dbref->{mac}} = "$dbref->{mac} $dbref->{hostname}";
    }

    return $fdata;

}

sub power_formdata_on() {

    my $fdata = {};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $sth = &list_start_data ( $opts, 'power', "all" );
    while ( my $dbref = &list_next_data( $sth ) ) {
        $fdata->{$dbref->{mac}} = "$dbref->{mac} $dbref->{hostname}";
    }

    return $fdata;
}

sub power_formdata_off() {

    my $fdata = {};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $sth = &list_start_data ( $opts, 'power', "all" );
    while ( my $dbref = &list_next_data( $sth ) ) {
        $fdata->{$dbref->{mac}} = "$dbref->{mac} $dbref->{hostname}";
    }

    return $fdata;
}

sub power_formdata_cycle() {

    my $fdata = {};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $sth = &list_start_data ( $opts, 'power', "all" );
    while ( my $dbref = &list_next_data( $sth ) ) {
        $fdata->{$dbref->{mac}} = "$dbref->{mac} $dbref->{hostname}";
    }

    return $fdata;
}

sub power_formdata_status() {

    my $fdata = {};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $sth = &list_start_data ( $opts, 'power', "all" );
    while ( my $dbref = &list_next_data( $sth ) ) {
        $fdata->{$dbref->{mac}} = "$dbref->{mac} $dbref->{hostname}";
    }

    return $fdata;
}

1;
