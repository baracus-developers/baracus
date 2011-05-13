package Baracus::REST::Aux;

use 5.006;
use Carp;
use strict;
use warnings;

use Baracus::Core   qw( :subs );
use Baracus::Config qw( :vars :subs );
use Baracus::State  qw( :vars :admin );
use Baracus::Source qw( :vars :subs );

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
                normalize_verb
         )],
         );

    Exporter::export_ok_tags('subs');
}


###########################################################################
##
## Main Source REST Subroutines (list/add/remove/update/verify)

sub normalize_verb() {
    my $verb = shift;
    $verb =~ s/\.xml//g;
    return $verb;
}

sub session_logout() {
    my $session_id = "";
    unlink $session_id;

}

1;
