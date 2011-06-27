package Baracus::REST::Storage;

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
use Baracus::Core    qw( :subs );
use Baracus::Config  qw( :vars :subs );
use Baracus::State   qw( :vars :admin );
use Baracus::Storage qw( :vars :subs );
use Baracus::Sql     qw( :vars :subs );
use Baracus::Aux     qw( :subs );


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

our $VERSION = '2.01';


###########################################################################
##
## Main Storage REST Subroutines (add/remove/list/detail)

sub storage_add() {

    my $command     = "add";

    my $sref = {};
    $sref->{storageid}   = request->params->{storageid};
    $sref->{storage}     = request->params->{storage};
    $sref->{type}        = request->params->{type};
    $sref->{storageip}   = "";
    $sref->{username}    = request->params->{username}    if ( defined request->params->{username} );
    $sref->{passwd}      = request->params->{passwd}      if ( defined request->params->{passwd} );
    $sref->{description} = request->params->{description} if ( defined request->params->{description} );
    $sref->{size}        = request->params->{size}        if ( defined request->params->{size} );

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my %returnHash;
    my $result = 0;

    if ( defined $baStorageType{ $sref->{type} } ) {
        $sref->{type} = $baStorageType{ $sref->{type} };
    } else {
        $opts->{LASTERROR} = "Incorrect type: $sref->{type}\n";
        error $opts->{LASTERROR};
    }

    ## Verify Mandatory parameters
    ##
    if ( $sref->{'storageid'} eq "" ) {
        $opts->{LASTERROR} = "Missing storageid\n";
        error $opts->{LASTERROR};
    }
    if ( ( $sref->{storageip} eq "" ) and
         ( $sref->{type} != BA_STORAGE_IMAGE ) and
         ( $sref->{type} != BA_STORAGE_CLONE ) ) {
        $opts->{LASTERROR} = "Missing storageip\n";
        error $opts->{LASTERROR};
    }
    if ( $sref->{storage} eq "" ) {
        $opts->{LASTERROR} = "Missing storage\n";
        error $opts->{LASTERROR};
    }

    # exits on error
    &check_ip( $sref->{storageip} ) if ( $sref->{storageip} ne "" );

    # check for pre-exsisting name
    my $chkref = &get_db_data( $opts, 'storage', $sref->{storageid} );
    if ( defined $chkref ) {
        $opts->{LASTERROR} = "storage name already exists: $sref->{storageid}\n";
        error $opts->{LASTERROR};
    }

    if ( $sref->{type} eq BA_STORAGE_IMAGE ) {
        # make sure either storage or storage.gz exists
        # and generate md5sum for tamper checking
        if ( -f "$baDir{images}/$sref->{storage}" ) {
            ; # no-op
        } elsif ( $sref->{storage} !~ m/^.*\.gz$/ and
                  -f "$baDir{images}/$sref->{storage}.gz" ) {
            # user didn't spec .gz but it's there so use it
            $sref->{storage} = "$sref->{storage}.gz";
        } else {
            $opts->{LASTERROR} = "file not found in $baDir{images}: $sref->{storage}\n";
            error $opts->{LASTERROR};
        }
        debug "md5sum $sref->{storage}\n";
        $sref->{md5sum} = &get_md5sum( "$baDir{images}/$sref->{storage}" );

    } elsif ( $sref->{type} eq BA_STORAGE_CLONE ) {
        # make sure neither storage nor storage.gz exists
        if ( -f "$baDir{images}/$sref->{storage}" ) {
            $opts->{LASTERROR} = "\t$baDir{images}/$sref->{storage}\n";
        }
        if ( $sref->{storage} !~ m/^.*\.gz$/ ) {
            # clone generated .gz images so use the extension
            $sref->{storage} = "$sref->{storage}.gz";
            if ( -f "$baDir{images}/$sref->{storage}" ) {
                $opts->{LASTERROR} .= "\t$baDir{images}/$sref->{storage}\n";
            }
        }
        if ( $opts->{LASTERROR} ne "" ) {
            $opts->{LASTERROR} = "file(s) already found in $baDir{images}:\n" . $opts->{LASTERROR};
            error $opts->{LASTERROR};
        }
    }

    # done with all checking
    &add_db_data( $opts, 'storage', $sref );
    debug "storage added: $sref->{storageid}";

    $returnHash{action}    = $command;
    $returnHash{storageid} = $sref->{storageid};
    $returnHash{result}    = $result;

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub storage_remove() {

    my $command = "remove";
    my $storageid = params->{storageid};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my %returnHash;
    my $result;
 
    my $chkref = &get_db_data( $opts, 'storage', $storageid );
    if ( defined $chkref ) {
        &remove_db_data( $opts, 'storage', $storageid );
        $result = 0;
    } else {
        $result = 1;
    }

    $returnHash{action}    = $command;
    $returnHash{storageid} = $chkref->{storageid};
    $returnHash{result}    = $result;

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub storage_list() {

    my $command = "list";
    my $filter = params->{filter};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my %returnHash;

    my $sth = &list_start_data ( $opts, 'storage', $filter );

    my $sref;
    my $curi;
    while ( $sref = &list_next_data( $sth ) ) {
        $curi = &get_db_storage_uri( $opts, $sref->{storageid} );
        $returnHash{$sref->{storageid}}{uri}       = $curi;
        $returnHash{$sref->{storageid}}{storageid} = $sref->{storageid};
        $returnHash{$sref->{storageid}}{type}      = $baStorageType{ $sref->{type} };
        $returnHash{$sref->{storageid}}{storageip} = $sref->{storageip};
        $returnHash{$sref->{storageid}}{storage}   = $sref->{storage};
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

sub storage_detail() {

    my $command   = "detail";
    my $storageid = params->{storageid};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my %returnHash;

    my $sref = &get_db_data( $opts, 'storage', $storageid );
    unless ( defined $sref ) {
        $opts->{LASTERROR} = "No storage found with storage id: $storageid\n";
        error $opts->{LASTERROR};
    }

    $returnHash{storageid}   = $sref->{storageid};
    $returnHash{type}        = $baStorageType{ $sref->{type} };
    $returnHash{storageip}   = $sref->{storageip} ;
    $returnHash{storage}     = $sref->{storage} ;
    $returnHash{uri}         = &get_db_storage_uri( $opts, $sref->{storageid} ) ;
    $returnHash{size}        = $sref->{size};
    $returnHash{description} = $sref->{description};
    $returnHash{username}    = $sref->{username};
    $returnHash{username}    = "*****";

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
