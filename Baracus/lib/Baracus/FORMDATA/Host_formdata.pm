package Baracus::FORMDATA::Host_formdata;

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
                host_formdata_add
                host_formdata_remove
                host_formdata_update
                host_formdata_enable
                host_formdata_disable
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

sub host_formdata_add() {

    my $distro = params->{distro};
    my $fdata = {};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    return $fdata;

}

sub host_formdata_remove() {

    my $fdata = {};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $sth = &list_start_data ( $opts, 'host', "" );
    while ( my $dbref = &list_next_data( $sth ) ) {
        $fdata->{$dbref->{mac}} = "$dbref->{mac} $dbref->{hostname}";
    }

    return $fdata;

}

sub host_formdata_update() {

    my $fdata = {};

     my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    return $fdata;
}

sub host_formdata_enable() {

    my $fdata = {};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $sth = &list_start_data ( $opts, 'action', "" );
    while ( my $dbref = &list_next_data( $sth ) ) {
        if ( $dbref->{admin} == 4 ) {
            $fdata->{$dbref->{mac}} = "$dbref->{mac} $dbref->{hostname}";
        }
    }

    return $fdata;
}

sub host_formdata_disable() {

    my $fdata = {};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $sth = &list_start_data ( $opts, 'action', "" );
    while ( my $dbref = &list_next_data( $sth ) ) {
        if ( $dbref->{admin} == 3 ) {
            $fdata->{$dbref->{mac}} = "$dbref->{mac} $dbref->{hostname}";
        }
    }

    return $fdata;
}

1;
