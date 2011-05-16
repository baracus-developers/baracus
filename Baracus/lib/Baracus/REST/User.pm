package Baracus::REST::User;

use 5.006;
use Carp;
use strict;
use warnings;

use Dancer;
#use Dancer::Plugin::Database;

use Baracus::Aux qw( :subs );
use Baracus::User qw( :subs );
#use Baracus::DB;
#use Baracus::Sql    qw( :vars );

$| = 1; # flush STDOUT

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
                user_add
         )],
         );

    Exporter::export_ok_tags('subs');
}

###########################################################################
##
## Main Source REST Subroutines (list/add/remove/update/verify)

sub user_add {
    my $opts = vars->{opts};

    my $href = {};
    $href->{username} = params->{username};
    $href->{password} = params->{password};
    $href->{status} = 1;
    $href->{realm} = 1;

    if ( &add_db_user( $opts, $href ) == 1 ) {
        if ( request->{accept} =~ m|text/html| ) {
            return "User $href->{username} already exists<br>"
        } elsif ( request->{accept} eq "text/xml" ) {
            my @returnArray = ("User already exists", "$href->{username}");
            return \@returnArray;
        }
    }

    if ( request->{accept} =~ m|text/html| ) {
        return "Added $href->{username}<br>"
    } elsif ( request->{accept} eq "text/xml" ) {
        my @returnArray = ("Added User", "$href->{username}");
        return \@returnArray;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

#sub user_auth {
#    my $username = params->{username};
#    my $password = params->{password};
#    my $ret = 0;
#    my $href = {};
#    my $sth;
#
#    eval {
#        my $sql = qq|SELECT username, password, realm
#                 FROM $baTbls{'user'}
#                 WHERE username = '$username'
#                |;
#
#        $sth = $dbh->prepare( $sql );
#        $sth->execute( );
#        $href = $sth->fetchrow_hashref( );
#        $sth->finish;
#        undef $sth;
#    };
#    if ( $@ ) {
#        error "some db error : $@";
#    } elsif ( $href->{username} ) {
#        ## Validate Password
#        if ( $password eq "letmein" ) {
#            $ret = 1;
#        }
#    }
#    return $ret;
#}

1;
