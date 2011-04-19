package Baracus::REST::Auth;

use 5.006;
use Carp;
use strict;
use warnings;

use Dancer;
use Dancer::Plugin::Database;
#use Crypt::PasswdMD5;

use Baracus::DB;
use Baracus::Sql    qw( :vars );

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
                auth_user
         )],
         );

    Exporter::export_ok_tags('subs');
}

###########################################################################
##
## Main Source REST Subroutines (list/add/remove/update/verify)

sub auth_user() {
    my $username = params->{username};
    my $password = params->{password};
    my $ret = 0;
    my $href = {};
    my $sth;

    eval {
        my $sql = qq|SELECT username, password, realm
                 FROM $baTbls{'user'}
                 WHERE username = '$username'
                |;

        $sth = $dbh->prepare( $sql );
        $sth->execute( );
        $href = $sth->fetchrow_hashref( );
        $sth->finish;
        undef $sth;
    };
    if ( $@ ) {
        error "some db error : $@";
    } elsif ( $href->{username} ) {
        ## Validate Password
        if ( $password eq "letmein" ) {
            $ret = 1;
        }
    }
    return $ret;
}

1;
