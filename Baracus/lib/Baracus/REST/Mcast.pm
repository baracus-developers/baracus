package Baracus::REST::Mcast;

###########################################################################
#
# Baracus build and boot management framework
#
# Copyright (C) 2010 Novell, Inc, 404 Wyman Street, Waltham, MA 02451, USA.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the Artistic License 2.0, as published
# by the Perl Foundation, or the GNU General Public License 2.0
# as published by the Free Software Foundation; your choice.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  Both the Artistic
# Licesnse and the GPL License referenced have clauses with more details.
#
# You should have received a copy of the licenses mentioned
# along with this program; if not, write to:
#
# FSF, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110, USA.
# The Perl Foundation, 6832 Mulderstraat, Grand Ledge, MI 48837, USA.
#
###########################################################################

use 5.006;
use Carp;
use strict;
use warnings;

use Dancer qw( :syntax);
use Dancer::Plugin::Database;

use Baracus::DB;
use Baracus::Core   qw( :vars :subs );
use Baracus::Config qw( :vars :subs );
use Baracus::State  qw( :vars :admin );
use Baracus::Source qw( :vars :subs );
use Baracus::Storage qw( :vars :subs );
use Baracus::Host   qw( :subs );
use Baracus::Power  qw( :subs );
use Baracus::Aux    qw( :subs );
use Baracus::Mcast  qw( :subs );


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
                mcast_add
                mcast_remove
                mcast_list
                mcast_detail
                mcast_admin
                mcast_enable
                mcast_disable
                mcast_init
                mcast_destroy
         )],
         );

    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

###########################################################################
##
## Main Multicast Channerl REST Subroutines (add/remove/list/detail/enable/disable)

sub mcast_add() {

    my $command = "add";
    my $mcastref;
    $mcastref->{mcastid}   = params->{mcastid};
    $mcastref->{storageid} = params->{storageid};
    $mcastref->{dataip}    = params->{dataip};
    $mcastref->{rdvip}     = params->{rdvip};
    $mcastref->{interface} = params->{interface};
    $mcastref->{ratemx}    = params->{ratemx};
    $mcastref->{mrecv}     = params->{mrecv};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status '406';
        error "internal variables not properly initialized";
        return { code => "7", error => "internal variables not properly initialized" };
    }

    my @required = ( "mcastid", "storageid", "dataip", "rdvip", "interface", "ratemx", "mrecv" );

    foreach my $opt ( @required ) {
        unless ( $mcastref->{$opt} ) {
            status '406';
            error "missing required argument: $opt";
            return { code => "5", error => "missing required argument: $opt" };
        }
    }

    my $chkref = &get_db_data( $opts, 'mcast', $mcastref->{mcastid} );
    if ( defined $chkref ) {
        status '406';
        error "mcastid: $mcastref->{mcastid} already exists";
        return { code => "54", error => "mcastid: $mcastref->{mcastid} already exists" };
    }

    &check_ip( $mcastref->{dataip} );  # exits on error
    &check_ip( $mcastref->{rdvip} ); # exits on error

    # check for pre-exsisting id
    my $imgref;
    $imgref = &get_db_data( $opts, 'storage', $mcastref->{storageid} );
    unless ( defined $imgref ) {
        status '406';
        error "storageid: $mcastref->{storageid} does not exist";
        return { code => "55", error => "storageid: $mcastref->{storageid} does not exist" };
    }
    if ( $imgref->{type} != BA_STORAGE_IMAGE ) {
        status '406';
        error "storageid: $mcastref->{storageid} not of type image";
        return { code => "56", error => "storageid: $mcastref->{storageid} not of type image" };
    }

    # test if image exists 
    unless ( -e "$baDir{images}/$imgref->{storage}" ) {
        status '406';
        error "image: $imgref->{target} does not exist in image directory";
        return { code => "57", error => "image: $imgref->{target} does not exist in image directory" };
    }

    # Get next available port
    $mcastref->{port} = &get_free_mcast_port( $opts, 'mcast' );

    # done with all checking
    # begin loading of hash used for remainder of processing command

    # set status to enabled
    &add_db_data( $opts, 'mcast', $mcastref );
    my $pid = &start_mchannel( $opts, $mcastref->{mcastid} );
    if ( $pid == 1 ) {
        $mcastref->{status} = 0;
        $mcastref->{pid} = "0";
    } else {
        $mcastref->{status} = 1;
        $mcastref->{pid} = $pid;
    }
    &update_db_data( $opts, 'mcast' , $mcastref );

    if ( $opts->{verbose} )
    {
        debug "mcast: $mcastref->{mcastid} added\n";
    }

    my $result = 0;

    my %returnHash;
    $returnHash{mcastid}  = $mcastref->{mcastid};
    $returnHash{action}   = $command;
    $returnHash{result}   = $result;

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub mcast_remove() {

    my $command = "remove";
    my $mcastid   = params->{mcastid};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    unless ( defined $mcastid ) {
        status '406';
        error "missing required argument: mcastid";
        return { code => "5", error => "missing required argument: mcastid" };
    }

    my $chkref = &get_db_data( $opts, 'mcast', $mcastid );
    if ( defined $chkref ) {
       if ( &stop_mchannel( $opts, $mcastid ) == 0 ) {
            &remove_db_data( $opts, 'mcast', $mcastid );
       } else {
           status '406';
           error "unable to remove mchannel, error stopping $mcastid";
           return { code => "6", error => "unable to remove mchannel, error stopping $mcastid" };
       }
    } else {
        status '406';
        error "mcastid: $mcastid no registered";
        return { code => "6", error => "mcastid: $mcastid no registered" };
    }

    my $result = 0;

    my %returnHash;
    $returnHash{mcastid}  = $mcastid;
    $returnHash{action}   = $command;
    $returnHash{result}   = $result;

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub mcast_list() {

    my $command = "list";
    my $filter  = params->{filter};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my %returnHash;

    unless ( defined $filter ) { $filter = ""; }

    my %mcastStatus = (
                        0   => 'disabled',
                        1   => 'enabled',
                      );

    my $sth = &list_start_data( $opts, 'mcast', $filter );

    unless( defined $sth ) {
        status 'error';
    }

    my $dbref;
    
    while ( $dbref = &list_next_data( $sth ) ) {
        $returnHash{$dbref->{mcastid}}{mcastid}   = $dbref->{mcastid};
        $returnHash{$dbref->{mcastid}}{storageid} = $dbref->{storageid};
        $returnHash{$dbref->{mcastid}}{status}    = $mcastStatus{ $dbref->{status} };
    }   

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub mcast_detail() {

    my $command  = "detail";
    my $mcastid  = params->{mcastid};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my %returnHash;

    unless ( defined $mcastid ) { 
        status '406';
        error "missing required argument: mcastid";
        return { code => "5", error => "missing required argument: mcastid" };
    }

    my $mcastref = &get_db_data( $opts, 'mcast', $mcastid );
    unless ( defined $mcastref ) {
        status '406';
        error "No multicast channel found with id: $mcastid";
        return { code => "6", error => "No multicast channel found with id: $mcastid" };
    }

    %returnHash = %$mcastref;

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub mcast_admin() {

    my %action_to_take = (
        'enable'   => \&mcast_enable,
        'disable'  => \&mcast_disable,
        'init'     => \&mcast_init,
        'destroy'  => \&mcast_destroy,
    );

    if ( defined $action_to_take{ request->params->{verb} }) {
        $action_to_take{ request->params->{verb} }( @_ )  ;
    } else {
        status '406';
        error "invalid admin action";
        return { code => "41", error => "invalid do action" };
    }
}

sub mcast_enable() {
 
    my $command  = "enable";
    my $mcastid = params->{mcastid};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $mcastref = &get_db_data( $opts, 'mcast', $mcastid );
    if ( defined $mcastref ) {
        if ( $mcastref->{status} == 0 ) {
            ## start channel
            my $pid = &start_mchannel( $opts, $mcastid );
            if ( $pid != 1 ) {
                $mcastref->{status} = 1;
                $mcastref->{pid} = $pid;
                &update_db_data( $opts, 'mcast', $mcastref);
            } else {
                debug "status not updated \n";
            }
        } elsif ( $mcastref->{status} == 0 ) {
            status '406';
            error "mcastid: $mcastid already enabled";
            return { code => "41", error => "mcastid: $mcastid already enabled" };
        } else {
            status '406';
            error "mcastid: $mcastid status error";
            return { code => "41", error => "mcastid: $mcastid status error" };
        }
     } else {
        status '406';
        error "mcastid: $mcastid not registered";
        return { code => "41", error => "mcastid: $mcastid not registered" };
    }

    my %returnHash;

    my $result = 0;

    $returnHash{mcastid} = $mcastid;
    $returnHash{action}  = $command;
    $returnHash{result}  = $result;

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }
}

sub mcast_disable() {

    my $command  = "disable";
    my $mcastid = params->{mcastid};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $mcastref = &get_db_data( $opts, 'mcast', $mcastid );
    if ( defined $mcastref ) {
        if ( $mcastref->{status} == 1 ) {
            if ( &stop_mchannel( $opts, $mcastid ) == 0 ) {
                $mcastref->{status} = 0;
                $mcastref->{pid} = "0";
                &update_db_data( $opts, 'mcast', $mcastref);
            }
        } elsif ( $mcastref->{status} == 0 ) {
            status '406';
            error "mcastid: $mcastid already disabled";
            return { code => "41", error => "mcastid: $mcastid already disabled" };

        } else {
            status '406';
            error "mcastid: $mcastid status error";
            return { code => "41", error => "mcastid: $mcastid status error" };
        }
     } else {
        status '406';
        error "mcastid: $mcastid not registered";
        return { code => "41", error => "mcastid: $mcastid not registered" };
     } 

    my %returnHash;

    my $result = 0;

    $returnHash{mcastid} = $mcastid;
    $returnHash{action}  = $command;
    $returnHash{result}  = $result;

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub mcast_init() {

    my $command  = "init";

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    &bamstart( $opts );
#    my $sth = &list_start_data ( $opts, 'mcast', "" );
#    while ( my $dbref = &list_next_data( $sth ) ) {
#        if ( $dbref->{status} ) {
#            ## start the mchannel
#            debug "Starting mchannel id: $dbref->{mcastid} \n";
#            my $mcastref = &get_db_data( $opts, 'mcast', $dbref->{mcastid} );
#            $mcastref->{pid} = &start_mchannel( $opts, $dbref->{mcastid} );
#            &update_db_data( $opts, 'mcast', $mcastref);
#        }
#    }

    my %returnHash;

    my $result = 0;

    $returnHash{action} = $command;
    $returnHash{result}  = $result;

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub mcast_destroy() {

    my $command  = "destroy";

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    &bamstop( $opts );
#    my $sth = &list_start_data ( $opts, 'mcast', "" );
#    while ( my $dbref = &list_next_data( $sth ) ) {
#        if ( $dbref->{status} ) {
#            ## start the mchannel
#            print "Stopping mchannel id: $dbref->{mcastid} \n";
#            my $ret = &stop_mchannel( $opts, $dbref->{mcastid} );
#            if ( $ret == 1 ) {
#                status '406';
#                error "error stopping $dbref->{mcastid}";
#                return { code => "6", error => "error stopping $dbref->{mcastid}" };
#             }
#        }
#    }

    my %returnHash;

    my $result = 0;

    $returnHash{action} = $command;
    $returnHash{result}  = $result;

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

1;
