package Baracus::Source;

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
use strict;
use warnings;

use Dancer qw( :syntax);
use Dancer::Plugin::Database;

use File::Temp qw/ tempdir /;
use File::Find;
use File::Path;
use File::Copy;

use Baracus::DB;
use Baracus::Sql qw( :vars :subs ); # %baTbls && get_cols
use Baracus::Config qw( :vars :subs );
use Baracus::State qw( :vars :states ); # %aState  && BA_ states
use Baracus::Services qw( :subs );
use Baracus::Core qw( :subs );
use Baracus::Aux qw( :subs );

=pod

=head1 NAME

B<Baracus::Source> - subroutines for managing Baracus source distros and repos

=head1 SYNOPSIS

Another collection of routines used in Baracus

=cut

BEGIN {
    use Exporter ();
    use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    @EXPORT_OK   = qw();
    %EXPORT_TAGS =
        (
         vars   =>
         [qw(
                %badistroType
                %badistroStatus
                BA_SOURCE_BASE
                BA_SOURCE_SDK
                BA_SOURCE_ADDON
                BA_SOURCE_DUD
            )],
         subs   =>
         [qw(
                get_db_source_entry
                add_db_source_entry
                update_db_source_entry
                update_db_iso_entry
                sqlfs_getstate
                sqlfs_store
                sqlfs_storeScalar
                sqlfs_remove
                prepdbwithxml
                purgedbofxml
                baxml_distros_getlist
                baxml_distro_gethash
                baxml_products_getlist
                baxml_product_gethash
                baxml_isos_getlist
                baxml_iso_gethash
                baxml_load
                baxml_load_distros
                download_iso
                get_iso_locations
                verify_iso
                make_paths
                add_bootloader_files
                add_dud_initrd
                remove_dud_initrd
                remove_bootloader_files
                add_build_service
                remove_build_service
                check_service_product
                source_register
                is_loopback
                get_mntcheck
                get_distro_includes
                get_distro_share
                list_installed_extras
                check_either
                check_distro
                check_extras
                check_extra
                is_extra_dependant
                is_source_installed
                init_exporter
                init_mounter
                get_enabled_disabled_distro_list  
                get_inactive_distro_list
                solaris_nfs_waround
            )],
         );

    Exporter::export_ok_tags('vars');
    Exporter::export_ok_tags('subs');
}

our $VERSION = '2.01';

use vars qw ( %badistroType %badistroStatus );

# Source Type constants
use constant BA_SOURCE_BASE  => 1;
use constant BA_SOURCE_SDK   => 2;
use constant BA_SOURCE_ADDON => 3;
use constant BA_SOURCE_DUD   => 4;

use constant BA_SOURCE_NULL     => 1;
use constant BA_SOURCE_REMOVED  => 2;
use constant BA_SOURCE_ENABLED  => 3;
use constant BA_SOURCE_DISABLED => 4;

my %stypes =
    (
     'nfs'  => '1',
     'http' => '2',
     'cifs' => '3',
     );

%badistroType =
    (
     1     => 'base',
     2     => 'sdk',
     3     => 'addon',
     4     => 'dud',

     'base'  => BA_SOURCE_BASE,
     'sdk'   => BA_SOURCE_SDK,
     'addon' => BA_SOURCE_ADDON,
     'dud'   => BA_SOURCE_DUD,

     BA_SOURCE_BASE  => 'base',
     BA_SOURCE_SDK   => 'sdk',
     BA_SOURCE_ADDON => 'addon',
     BA_SOURCE_DUD   => 'dud',
     );

%badistroStatus =
    (
     1        => 'null',
     2        => 'removed',
     3        => 'enabled',
     4        => 'disabled',

     'null'     => BA_SOURCE_NULL,
     'removed'  => BA_SOURCE_REMOVED,
     'enabled'  => BA_SOURCE_ENABLED,
     'disabled' => BA_SOURCE_DISABLED,

     BA_SOURCE_NULL     => 'null',
     BA_SOURCE_REMOVED  => 'removed',
     BA_SOURCE_ENABLED  => 'enabled',
     BA_SOURCE_DISABLED => 'disabled',
     );

###########################################################################
##
##  DATABASE RELATED ADD/READ - no update or delete provided?

sub get_db_iso_entry
{
    my $opts   = shift;
    my $distro = shift;

    my $sth;
    my $href = undef;

    my $sql = qq|SELECT *
                 FROM $baTbls{ 'iso' }
                 WHERE distroid = '$distro' |;

    eval {
        $sth = database->prepare( $sql );
        $sth->execute();
        $href = $sth->fetchrow_hashref();
        $sth->finish;
        undef $sth;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }
    return $href;
}

sub get_db_source_entry
{
    my $opts   = shift;
    my $distro = shift;

    my $sth;
    my $href = undef;

    my $sql = qq|SELECT *
                 FROM $baTbls{ 'distro' }
                 WHERE distroid = '$distro' |;

    eval {
        $sth = database->prepare( $sql );
        $sth->execute();
        $href = $sth->fetchrow_hashref();
        $sth->finish;
        undef $sth;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }
    return $href;
}

sub add_db_source_entry
{
    my $opts   = shift;
    my $distro = shift;

    debug "Registering source: $distro $baVar{shareip} $baDir{root} $baVar{sharetype}\n" if $opts->{verbose};

    my $status = 1;
    my $sql;
    my $sth;

    eval {
        my $dh = &baxml_distro_gethash( $opts, $distro );
        my ($shares,undef) = get_distro_share( $opts, $distro );
        my $dbref = &get_db_source_entry( $opts, $distro );
	    my $share = @$shares[0];
        if ( defined $dbref ) {
            $sql = qq|UPDATE $baTbls{ 'distro' }
                  SET creation=CURRENT_TIMESTAMP(0),
                      change=NULL,
                      shareip=?,
                      sharetype=?,
                      basepath=?,
                      status=?
                  WHERE distroid=?|;

            $sth = database->prepare( $sql );
            $sth->bind_param( 1, $baVar{shareip}    );
            $sth->bind_param( 2, $baVar{sharetype}  );
            $sth->bind_param( 3, $share      );
            $sth->bind_param( 4, BA_ENABLED  );
            $sth->bind_param( 5, $distro     );
            $sth->execute( );
            $sth->finish;
            undef $sth;
        } else {
            $sql = qq|INSERT INTO $baTbls{ 'distro' }
                  ( distroid,
                    os,
                    release,
                    arch,
                    description,
                    type,
                    addos,
                    addrel,
                    shareip,
                    sharetype,
                    basepath,
                    status,
                    creation,
                    change
                  )
                  VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                           CURRENT_TIMESTAMP(0), NULL ) |;

            $sth = database->prepare( $sql );
            $sth->bind_param( 1, $distro        );
            $sth->bind_param( 2, $dh->{os}      );
            $sth->bind_param( 3, $dh->{release} );
            $sth->bind_param( 4, $dh->{arch}    );
            $sth->bind_param( 5, $dh->{description} );
            if ( defined $dh->{addos} and $dh->{addos} ) {
                $sth->bind_param( 6, 1 );
                $sth->bind_param( 7, $dh->{addos} );
                if ( defined $dh->{addrel} and $dh->{addrel} ) {
                    $sth->bind_param( 8, $dh->{addrel} );
                } else {
                    $sth->bind_param( 8, 'NULL' );
                }
            } else {
                $sth->bind_param( 6, 0 );
                $sth->bind_param( 7, 'NULL' );
                $sth->bind_param( 8, 'NULL' );
            }
            $sth->bind_param( 9,  $baVar{shareip}    );
            $sth->bind_param( 10, $baVar{sharetype}  );
            $sth->bind_param( 11, $share      );

            $sth->bind_param( 12, BA_ENABLED );
            $sth->execute( );
            $sth->finish;
            undef $sth;
        }
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }
    return $status;
}

sub update_db_source_entry
{
    my $opts      = shift;
    my $sharetype = shift;
    my $shareip   = shift;
    my $distro    = shift;

    debug "Updating source: $distro to $sharetype\n" if $opts->{verbose};

    my $status = 1;
    my $sql;
    my $sth;

    eval {
        my $dbref = &get_db_source_entry( $opts, $distro );

        my $fields = "change";
        my $values = "CURRENT_TIMESTAMP(0)";

        if ( defined $dbref ) {

            if ( $sharetype ne "" ) {
                $fields .= ",sharetype";
                $values .= "," . database->quote( $sharetype );
            }
            if ( $shareip ne "" ) {
                $fields .= ",shareip";
                $values .= "," . database->quote( $shareip );
            }

            $sql = qq|UPDATE $baTbls{ distro }
                  SET ( $fields ) = ( $values )
                  WHERE distroid='$distro'|;

            $sth = database->prepare( $sql );
            $sth->execute();
            $sth->finish;
            undef $sth;
        } else {
            $opts->{LASTERROR} = subroutine_name." : $distro not available for updating\n";
            warning $opts->{LASTERROR};
            $status = 0;
        }
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }

    return $status;
}

sub add_db_iso_entry
{
    my $opts        = shift;
    my $distro      = shift;
    my $iso         = shift;
    my $mntpoint    = shift;
    my $is_loopback = shift;
    my $sharetype   = $baVar{sharetype};

    my $is_local = 1;           ## force local for now

    debug "Registering iso: $iso for $distro\n" if $opts->{verbose};

    my $status = 1;
    my $sql;
    my $sth;

    eval {
        my $dh = &baxml_distro_gethash( $opts, $distro );
        my $dbref = &get_db_source_entry( $opts, $distro );

        if ( defined $dbref ) {
            $sharetype = $dbref->{sharetype};
        } else {
            if ( $dh->{'sharetype'} ) {
                $sharetype = $dh->{'sharetype'};
            }
        }

        $dbref = &get_db_iso_entry( $opts, $iso, $distro );

        if ( defined $dbref ) {
            $sql = qq|UPDATE $baTbls{ 'iso' }
                  SET (is_loopback,change) = (?,CURRENT_TIMESTAMP(0))
                  WHERE distroid='$distro'|;

            $sth = database->prepare( $sql );
            $sth->bind_param( 1, $dbref->{is_loopback} );
            $sth->execute();
            $sth->finish;
            undef $sth;

        } else {
            $sql = qq|INSERT INTO $baTbls{ 'iso' }
                  ( iso,
                    distroid,
                    is_loopback,
                    mntpoint,
                    sharetype,
                    is_local,
                    creation,
                    change
                  )
                  VALUES ( ?, ?, ?, ?, ?, ?,
                           CURRENT_TIMESTAMP(0), NULL ) |;

            $sth = database->prepare( $sql );
            $sth->bind_param( 1, $iso                        );
            $sth->bind_param( 2, $distro                     );
            $sth->bind_param( 3, $is_loopback                );
            $sth->bind_param( 4, $mntpoint                   );
            $sth->bind_param( 5, $stypes{$sharetype}         );
            $sth->bind_param( 6, $is_local                   );
            $sth->execute();
            $sth->finish;
            undef $sth;
        }
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }

    return $status;
}

sub update_db_iso_entry
{
    my $opts        = shift;
    my $distro      = shift;
    my $sharetype   = shift;
    my $status      = 1;

    debug "Updating sharetype $sharetype iso entry for: $distro\n" if $opts->{verbose};

    my $sql;
    my $sth;

    eval {
        my $dbref = &get_db_iso_entry( $opts, $distro );

        if ( defined $dbref ) {
            $sql = qq|UPDATE $baTbls{ 'iso' }
                  SET (change,sharetype) = (CURRENT_TIMESTAMP(0),?)
                  WHERE distroid='$distro'|;

            $sth = database->prepare( $sql );
            $sth->bind_param( 1, $stypes{$sharetype} );
            $sth->execute();
            $sth->finish;
            undef $sth;
        } else {
            $opts->{LASTERROR} = subroutine_name." : iso for $distro not currently available\n";
            error $opts->{LASTERROR};
            $status = 0;
        }
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }

    return $status;
}


###########################################################################
# sqlfsOBJ - sqlfstable - file db

# write db file out to fs - 0 ok - 1 on err (unix like)
sub sqlfs_fetch
{
    my $opts = shift;
    my $file = shift;

    #    print "setting uid to $opts->{dbrole}\n" if ($opts->{debug} > 2);
    #    my $uid = Baracus::DB::su_user( $opts->{dbrole} );

    my $sel; 

    eval {
        $sel = $opts->{sqlfsOBJ}->fetch( $file );
    };
    if ( $@ ) {
	    $opts->{LASTERROR} = subroutine_name ." : ". $@;
        error $opts->{LASTERROR};
        $sel = undef;
    }

    #    print "setting uid back to $uid\n" if ($opts->{debug} > 2);
    #    $> = $uid;

    return $sel;
}

# lookup file - -1 missing, 0 error, 1 enabled, 2 disabled
sub sqlfs_getstate
{
    my $opts = shift;
    my $file = shift;
    my $state = -1;

    eval {
        #        debug "setting uid to $opts->{dbrole}\n" if ($opts->{debug} > 2);
        #        my $uid = Baracus::DB::su_user( $opts->{dbrole} );
        my $sel = $opts->{sqlfsOBJ}->detail( $file );
        if ( defined $sel ) {
            if ( $sel->{'enabled'} ) {
                $state = 1;
            } else {
                $state = 2;
            }
        }
        #        debug "setting uid back to $uid\n" if ($opts->{debug} > 2);
        #        $> = $uid;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $state = 0;
    }

    return $state;
}

# store a file located on disk
# return 1 on success or 0 on failure
sub sqlfs_store
{
    my $opts = shift;
    my $file = shift;
    my $status = 1;

    eval {
        #        debug "setting uid to $opts->{dbrole}\n" if ($opts->{debug} > 2);
        #        my $uid = Baracus::DB::su_user( $opts->{dbrole} );
        $status = $opts->{sqlfsOBJ}->store( $file );
        error "Store failed to store $file in sqlfs\n" if ( $status );
        #        debug "setting uid back to $uid\n" if ($opts->{debug} > 2);
        #        $> = $uid;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }
    return $status;
}

# store contents of scalar var ref
sub sqlfs_storeScalar
{
    my $opts = shift;
    my $file = shift;
    my $ref  = shift;
    my $desc = shift;
    my $status = 1;

    eval {
        #        debug "setting uid to $opts->{dbrole}\n" if ($opts->{debug} > 2);
        #        my $uid = Baracus::DB::su_user( $opts->{dbrole} );
        $status = $opts->{sqlfsOBJ}->storeScalar( $file, $ref, $desc );
        error "StoreScalar failed to store $file in sqlfs\n" if ( $status );
        #        debug "setting uid back to $uid\n" if ($opts->{debug} > 2);
        #        $> = $uid;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }
    return $status;
}

# remove a file located in sqlfs tftp relation
sub sqlfs_remove
{
    my $opts = shift;
    my $file = shift;
    my $status = 1;

    eval {
        #        debug "setting uid to $opts->{dbrole}\n" if ($opts->{debug} > 2);
        #        my $uid = Baracus::DB::su_user( $opts->{dbrole} );
        $status = $opts->{sqlfsOBJ}->remove( $file );
        error "Unable to remove $file from sqlfs\n" if ( $status );
        #        debug "setting uid back to $uid\n" if ($opts->{debug} > 2);
        #        $> = $uid;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }
    #    print "setting uid back to $uid\n" if ($opts->{debug} > 2);
    #    $> = $uid;
    return $status;
}

###########################################################################
##
## XML INIT DB ROUTINES

sub prepdbwithxml
{
    my $opts  = shift;
    my $baXML = $opts->{baXML};
    my $status = 1;

    my %entry;

    my $sql_cols = lc get_cols( 'distro' );
    $sql_cols =~ s/[ \t]*//g;
    my @cols = split( /,/, $sql_cols );
    my $sql_vals = "?," x scalar @cols; chop $sql_vals;

    my $sth;
    my $sql = qq|INSERT INTO $baTbls{ distro } ( $sql_cols ) VALUES ( $sql_vals ) |;

    eval {
        $sth = database->prepare( $sql );

        foreach my $distro ( keys %{$baXML->{distro}} ) {
            my $dh = $baXML->{distro}->{$distro};

            my ($shares, $name) = &get_distro_share( $opts, $distro );
            my $share = @$shares[0];

            $entry{'distroid'   } = $distro;
            $entry{'os'         } = $dh->{os};
            $entry{'release'    } = $dh->{release};
            $entry{'arch'       } = $dh->{arch};
            $entry{'description'} = $dh->{description};

            if ( defined $dh->{sharetype} ) {
                $entry{'sharetype'  } = $dh->{sharetype};
            } else {
                $entry{'sharetype'  } = $baVar{sharetype};
            }

            $entry{'shareip'    } = $baVar{shareip};
            $entry{'basepath'   } = $share;
            $entry{'type'       } = $badistroType{ $dh->{type} };

            if ( defined $dh->{'requires'} ) {
                $entry{'addos'  } = $dh->{addos};
                $entry{'addrel' } = $dh->{addrel} if ( defined $dh->{addrel} );
            } else {
                $entry{'addos'  } = "";
                $entry{'addrel' } = "";
            }

            if ( $opts->{debug} > 1 ) {
                while (my ($key, $val) = each %entry) {
                    debug "  entry $key => $val\n";
                }
            }

            my $dbref = &get_db_source_entry( $opts, $distro );
            if ( defined $dbref and defined $dbref->{distroid} ) {
                debug "Entry already exists:  distro $entry{'distroid'}.\n" if ( $opts->{debug} > 2 );
                next;
            } else {
                debug "Adding entry for:  distro $entry{'distroid'}.\n" if ( $opts->{debug} > 2 );
            }

            my $paramidx = 0;
            foreach my $col (@cols) {
                $paramidx += 1;
                $sth->bind_param( $paramidx, $entry{ $col } );
            }

            $sth->execute( );
        }
        $sth->finish;
        undef $sth;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }

    return $status;
}

sub purgedbofxml
{
    my $opts  = shift;
    my $baXML = $opts->{baXML};
    my $status = 1;

    my $sql = qq|DELETE FROM $baTbls{ 'distro' } WHERE distroid = ?|;

    eval {
        my $sth = database->prepare( $sql );

        foreach my $distro ( keys %{$baXML->{distro}} ) {
            debug "Removing $distro entry\n" if ($opts->{debug});
            $sth->execute( $distro );
        }
        $sth->finish;
        undef $sth;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }

    return $status;
}

###########################################################################
#
#  xml config helpers - for more formatting info refer to
#
#      /usr/share/baracus/badistro.xml
#      /usr/share/baracus/perl/badistro_check_xml.pl

#
#  All baxml_* helpers try to abstract the deep referencing of the
#  xml.  The goals are to contain the required code changes, if the
#  xml is modified, to these subroutines (probably have not achieved
#  this goal yet), and to reduce typo or incorrect referencing.
#  perhaps a module interface next release. dhb
#

# returns an array of distro names
sub baxml_distros_getlist
{
    my $opts  = shift;
    my $baXML = $opts->{baXML};
    return keys %{$baXML->{'distro'}};
}

# returns a hash reference to the distro attribs
sub baxml_distro_gethash
{
    my $opts  = shift;
    my $baXML = $opts->{baXML};
    return $baXML->{'distro'}->{$_[0]};
}

# returns an array of product names for the given distro
sub baxml_products_getlist
{
    my $opts  = shift;
    my $baXML = $opts->{baXML};
    return keys %{$baXML->{'distro'}->{$_[0]}->{'product'}};
}

# returns a hash reference to the distro's product attribs
sub baxml_product_gethash
{
    my $opts  = shift;
    my $baXML = $opts->{baXML};
    return $baXML->{'distro'}->{$_[0]}->{'product'}->{$_[1]};
}

# returns an array of product names for the given distro
sub baxml_isos_getlist
{
    my $opts  = shift;
    my $baXML = $opts->{baXML};
    return keys %{$baXML->{'distro'}->{$_[0]}->{'product'}->{$_[1]}->{'iso'}};
}

# returns a hash reference to the distro's product's iso attribs
sub baxml_iso_gethash
{
    my $opts  = shift;
    my $baXML = $opts->{baXML};
    return $baXML->{'distro'}->{$_[0]}->{'product'}->{$_[1]}->{'iso'}->{$_[2]};
}

sub baxml_load
{
    use XML::Simple;

    my $opts    = shift;
    my $xmlfile = shift;

    my $xs = XML::Simple->new
        ( SuppressEmpty => 1,
          ForceArray =>
          [ qw
            ( distro
              product
              iso
              sharefile
            )
           ],
          KeyAttr =>
          {
           distro    => 'name',
           product   => 'name',
           iso       => 'name',
           sharefile => 'name',
           },
         );
    my $baXML = $xs->XMLin( $xmlfile );

    # sanity checking
    # and promote some items to base for direct access
    # and other helper info to struct just created by xml

    debug "XML post-processing xml struct\n" if ($opts->{debug} > 2);
    foreach my $distro ( keys %{$baXML->{distro}} ) {
        my $dh = $baXML->{distro}->{$distro};
        my @baseparts = ( $dh->{os}, $dh->{release}, $dh->{arch} );
        $dh->{basedist} = join "-", @baseparts;
        unless ( $baXML->{distro}->{ $dh->{basedist} } ) {
            die "Malformed $xmlfile\nMissing entry for distro $dh->{basedist} required by $distro\n";
        }
        debug "XML working with distro $distro\n" if ($opts->{debug} > 2);
        debug "XML described as $dh->{description}\n" if ($opts->{debug} > 2);
        $dh->{basedisthash} = $baXML->{distro}->{ $dh->{basedist} };

        # start all pathing below the ~baracus/bulids/os/version/arch
        $dh->{distpath} = join "/", $baDir{'builds'}, @baseparts;

        # add-ons have 'requires' specifiers
        # this no longer describes the base distro needed - it's just a flag
        if ( defined $dh->{'requires'} ) {
            if ( $distro eq $dh->{basedist} ) {
                die "Malformed $xmlfile\nAdd-on $distro (has 'requires') only has base components as part of its name\n";
            }
            debug "XML distro is addon for base $dh->{basedist}\n" if ($opts->{debug} > 2);

            # addons are placed in sub directories of the base distro
            # ~baracus/bulids/os/version/arch/product/addos[/addrel]
            $dh->{distpath} = join "/", $dh->{distpath}, $dh->{addos};
            $dh->{distpath} = join "/", $dh->{distpath}, $dh->{addrel}
                if ( defined $dh->{addrel} );

            # append distro to base addons list
            debug "XML add $distro to $dh->{basedist} addon array\n" if ($opts->{debug} > 2);
            push @{$dh->{basedisthash}->{addons}}, $distro;
        } elsif ( $dh != $dh->{basedisthash}) {
            die "non-addon $distro hash $dh not equal to $dh->{basedisthash} ?!\n";
        }
        debug "XML distro path $dh->{distpath}\n" if ($opts->{debug} > 2);

        # every non-addon distro needs one product of type "base"
        # basefound indicates that <type>base</type> was found in product
        # but we also set this flag for addon that 'requires' a base
        # because it should be found thru that product.
        my $basefound = 0;
        $basefound = 1 if ( $dh->{type} eq $badistroType{ BA_SOURCE_BASE } ); # spoof check for addons

        # a distro with base product needs one iso with "kernel" and "initrd"
        # the loaderfound flag indicates that these files have been found
        # in one, and there can only be one with these, iso of the product
        my $loaderfound = 0;

        foreach my $product ( keys %{$dh->{product}} ) {
            my $ph = $dh->{product}->{$product};

            # product name becomes part of the path for the mount / cp point
            # typically this is 'dvd' but can be more elaborate (as for sles 9)
            $ph->{prodpath} = join "/", $dh->{distpath}, $product;
            debug "XML working with product $product\n" if ($opts->{debug} > 2);
            debug "XML product path $ph->{prodpath}\n" if ($opts->{debug} > 2);

            # set the base product information for every distro
            $dh->{baseprod} = $product;
            $dh->{baseprodhash} = $ph;
            $dh->{baseprodpath} = $ph->{prodpath};

            debug "XML base prod path $dh->{baseprodpath}\n" if ($opts->{debug} > 2);

            foreach my $iso ( keys %{$ph->{iso}} ) {
                # iso specific info for mounting, copying
                # and extracting files to network shares

                # hash pointing to struct at iso level and below
                # we add our own helper key/value pairs here
                my $ih = $ph->{iso}->{$iso};

                # iso path starts with product path and adds any iso specific
                $ih->{isopath} = $ph->{prodpath};
                $ih->{isopath} = join "/", $ih->{isopath}, $ih->{'path'}
                    if ( defined $ih->{'path'} );
                debug "XML iso path $ih->{isopath}\n" if ($opts->{debug} > 2);
                if ( ( $dh->{type} eq $badistroType{ BA_SOURCE_BASE } ) and ( defined $ih->{sharefiles} ) ) {
                    if ( $loaderfound ) {
                        die "Malformed $xmlfile\nDistro $distro product $product has more than one iso with <kernel> and <initrd>\n";
                    }

                    # distro 1:n products n:m isos
                    # at most 1 product is <addon>base</addon>
                    # at most 1 iso has loader files <kernel> and <initrd>
                    # and it is expected that iso is a member of the base prod
                    # so this info can be bubbled up for a base distro 
                    $loaderfound = 1 ;
                    $dh->{baseiso} = $iso;
                    $dh->{baseisohash} = $ih;
                    $dh->{baseisopath} = $ih->{isopath};

                    # new method of describing more generically 
                    # multiple files for network installs
                    # and the method required for making them available
                    if ( defined $ih->{sharefiles} ) {
                        foreach my $sname ( keys %{$ih->{sharefiles}->{sharefile}} ) {
                            my $sh = $ih->{sharefiles}->{sharefile}->{$sname};

                            # iso path or builds relative if starts with '/'
                            if ( $sh->{file} =~ m|^/| ) {
                                $dh->{baseshares}->{$sname}->{file} = $baDir{builds} . $sh->{file};
                            } else {
                                $dh->{baseshares}->{$sname}->{file} = join "/", $ih->{isopath}, $sh->{file};
                            }
                            $dh->{baseshares}->{$sname}->{sharetype} = $sh->{sharetype};
                            debug "XML sharefile $sname $sh->{sharetype}  $dh->{baseshares}->{$sname}->{file}\n" if ($opts->{debug} > 2);
                        }
                    }

                    # isopath will get us to the mount / cp point of the iso
                    # the kernel and initrd values have pathing info embedded
                    # (relative to the root of the iso)

                    debug "XML base iso path $dh->{baseisopath}\n" if ($opts->{debug} > 2);

                    my $path = "";
                    $path .= $ih->{path} . "/" if ( defined $ih->{'path'} );

                    if ( defined $dh->{baseshares}->{kernel} ) {
                        $dh->{baselinux}  = $dh->{baseshares}->{kernel}->{file};
                        $dh->{basekernelsubpath} = "${path}$dh->{baseshares}->{kernel}->{file}";
                        debug "XML linux $dh->{baselinux}\n" if ($opts->{debug} > 2);
                        debug "XML sub $dh->{basekernelsubpath}\n" if ($opts->{debug} > 2);
                    }
                    if ( defined $dh->{baseshares}->{initrd} ) {
                        $dh->{baseinitrd} = $dh->{baseshares}->{initrd}{file};
                        $dh->{baseinitrdsubpath} = "${path}$dh->{baseshares}->{initrd}->{file}";
                        debug "XML initrd $dh->{baseinitrd}\n" if ($opts->{debug} > 2);
                        debug "XML sub $dh->{baseinitrdsubpath}\n" if ($opts->{debug} > 2);
                    }
                }
            }
            if ( $dh->{type} eq $badistroType{ BA_SOURCE_BASE } ) {
                unless ( $loaderfound ) {
                    die "Malformed $xmlfile\nEntry $distro is missing an iso containing both <kernel> and <initrd>\n";
                }
            }
        }
        debug "\n" if ($opts->{debug} > 2);
    }

    return $baXML;
}

sub baxml_load_distros
{
    use Clone qw( clone );

    my $opts = shift;

    my $baXML;

    # bind the distro to a class (N:1 associations) in baXML hash
    # from data store in hierarchy (1:N compact and less duplication)
    # for faster distro->class lookup
    # though if this just lives for usage once same cost / speed

    # we load hierarchy xml here instead of per file in baxml_load call

    my $xsclass = XML::Simple->new
        ( SuppressEmpty => 1,
          ForceArray =>
          [ qw
            (
                class
                os
            )
           ],
          KeyAttr =>
          {
           class => 'name',
           os    => 'name',
           },
         );

    my $classXML = $xsclass->XMLin("$baDir{bcdir}/hierarchy.xml");

    my @xmlfiles = &get_xml_filelist( $opts, $baDir{'distros.d'} );

    for my $xmlfile ( @xmlfiles ) {
        debug "now loading user distro file: $xmlfile\n" if $opts->{debug};
        my $tmpXML = &baxml_load( $opts, $xmlfile );
        while ( my ($key, $val) = each %{$tmpXML->{distro}} ) {
            debug " $key => $val\n" if $opts->{debug};
            $baXML->{'distro'}->{$key} = clone( $val );
        }
    }

    foreach my $distro ( keys %{$baXML->{distro}} ) {
        my $dh = $baXML->{distro}->{$distro};
        foreach my $class ( keys %{$classXML->{class}} ) {
            my $ch = $classXML->{class}->{$class};
            foreach my $os ( keys %{$ch->{os}} ) {
                if ( $dh->{os} =~ m|$os| ) {
                    $dh->{class} = $class;
                    $dh->{pkgtype} = $ch->{pkgtype};
                    $dh->{autotype} = $ch->{autobuild};
                }
            }
        }
    }

    return $baXML;
}

###########################################################################
##
##  GENERIC BASOURCE HELPER ROUTINES not db or xml specific

sub download_iso
{
    use Term::ReadKey;

    my $opts   = shift;
    my $distro = shift;
    my $extras = shift;
    my $proxy  = shift;
    my $checkhr = shift;

    my $status = 1;

    my @dalist;

    #    print "+++++ download_iso\n" if ( $opts->{debug} > 1 );

    push @dalist, $distro if $distro;
    push @dalist, split( /\s+/, $extras) if ( $extras );

    my $daisohr = {};
    my @isofilelist;
    my $found = 0;

    eval {
        $SIG{CHLD} = '';
        ## create directory for iso files if not present
        unless ( -d $baDir{builds} ) {
            mkdir $baDir{builds}, 0755 or die;
        }
        unless (-d $baDir{'isos'}) {
            mkdir $baDir{'isos'}, 0755 or die;
        }

        debug "Searching for iso files needing download ...\n" if ($opts->{verbose});
        foreach my $da ( @dalist ) {
            my @distisolist = ();
            my $distisoinfo = {};
            foreach my $prod ( &baxml_products_getlist( $opts, $da ) ) {
                foreach my $isofile ( &baxml_isos_getlist( $opts, $da, $prod ) ) {
                    my $ih = &baxml_iso_gethash( $opts, $da, $prod, $isofile );
                    $distisoinfo->{$isofile}->{path} = $ih->{isopath};
                    $distisoinfo->{$isofile}->{hash} = $ih;
                    my $skip = 0;
                    find ( { wanted =>
                             sub {
                                 if ($_ eq $isofile) {
                                     debug "found $File::Find::name\n" if $opts->{debug};
                                     $found=1;
                                     $skip=1;
                                 }
                             },
                             follow => 1
                            },
                           $baDir{isos} );
                    unless ( $skip ) {
                        push @distisolist, $isofile;
                    }
                }
            }
            $daisohr->{ $da }->{info} = $distisoinfo;
            push @{$daisohr->{ $da }->{list}}, @distisolist;
            push @{$checkhr->{ $da }->{check}}, @distisolist;
            push @isofilelist, @distisolist;
        }
        if ($found) {
            warning "ISO download requested and files were already found. If checksum\n";
            warning "verification fails for a file, please remove the file and retry.\n";
        }

        return 1 unless @isofilelist;

        my $username="";
        my $password="";
        my $proxyaddr="";
        my $pusername="";
        my $ppassword="";

        my $dh = &baxml_distro_gethash( $opts, $distro );

        if ($dh->{autodownload} eq "no") {
            $opts->{LASTERROR} = "Baracus assisted download not supported for $distro\n";
            error $opts->{LASTERROR};
            return 0;
        }

        # TODO - AUTH AND PROXY BROKEN WITH NON-INTERACTIVE - dhb

        #    if ($dh->{autodownload} eq "auth") {
        #        print "Please enter (novell.com) userid: ";
        #        chomp($username = ReadLine 0);
        #
        #        print "Please enter (novell.com) password: ";
        #        ReadMode 'noecho';
        #        chomp($password = ReadLine 0);
        #        ReadMode 'normal';
        #    }
        #
        #    if ($proxy) {
        #        print "Please enter proxy address: ";
        #        chomp($proxyaddr = ReadLine 0);
        #
        #        print "Please enter proxy username: ";
        #        chomp($pusername = ReadLine 0);
        #
        #        print "Please enter proxy password: ";
        #        ReadMode 'noecho';
        #        chomp($ppassword = ReadLine 0);
        #        ReadMode 'normal';
        #        print "\n";
        #    }

        debug "\nDownloading: \n";
        foreach my $da ( @dalist ) {
            foreach my $isofile ( sort @{$daisohr->{ $da }->{list}} ) {
                # here isofile has no path info just the filename
                my $url = $daisohr->{$da}->{info}->{$isofile}->{hash}->{url};
                &get_iso($opts,$distro,$url,$isofile,$username,$password,$proxy,$pusername,$ppassword,$proxyaddr);
            }
        }
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }

    return $status;
}

sub get_iso
{
    my ($opts,$distro,$url,$iso,$username,$password,$proxy,$pusername,$ppassword,$proxyaddr) = @_;
    use LWP::UserAgent;
    my $idir = "$baDir{'isos'}/$distro";
    my $file = "$idir/$iso";
    my $br;
    my $ua;
    my $status = 1;

    #    print "+++++ get_iso\n" if ( $opts->{debug} > 1 );

    my $dh = &baxml_distro_gethash( $opts, $distro );

    if ($proxy) {
        $proxyaddr =~ s|http://||;
        $ENV{'HTTP_PROXY'} = "http://${pusername}:${ppassword}\@${proxyaddr}";
        $ua = LWP::UserAgent->new(keep_alive => 1, env_proxy=>1 ) || error "$!";
    } else {
        $ua = LWP::UserAgent->new(keep_alive => 1 ) || error "$!";
    }
    unless ($dh->{autodownload} eq "open") {
        $ua->cookie_jar({});
        $ua->credentials('cdn.novell.com:80', 'iChain', "$username",  "$password" );
    }

    eval {
        # If set to nonzero, forces a flush right away and after every
        # write or print on the currently selected output channel.
        $| = 1;

        open(FILE, ">$file") or die;
        my $req = $ua->request
            (
             HTTP::Request->new(GET => $url),
             sub {
                 $br += length($_[0]);
                 #                 if ($_[1]->content_length) {
                 #                     printf STDERR " $iso: [ %d%% ] \r",100*$br/$_[1]->content_length;
                 #                 }
                 binmode FILE;
                 print FILE $_[0] or die;
             }
             );
        if (not $req->is_success) {
            close(FILE) or die;
            unlink $file;
            $opts->{LASTERROR} = subroutine_name." : ".$@;
            error $opts->{LASTERROR};
            $status = 0;
        } elsif (fileno(FILE)) {
            close(FILE) or die;
        }
    };
    if ( $@ ) {
        unless ( $opts->{LASTERROR} ) {
            $opts->{LASTERROR} = subroutine_name." : ".$@;
            error $opts->{LASTERROR};
        }
        $status = 0;
    }

    return $status;
}

sub get_iso_locations
{
    # this is going to find all location instances of all files named *.iso
    my $opts = shift;
    my %isohash;

    find ({ wanted =>
            sub {
                if ($_ =~ /.*\.iso$/) {
                    debug "found $File::Find::name\n" if ( $opts->{debug} > 2 );
                    push @{ $isohash{ $_ } }, $File::Find::name;
                }
            },
            follow => 1
           },
          $baDir{isos});

    return \%isohash;
}

sub verify_iso
{
    my $opts   = shift;
    my $distro = shift;
    my $extras = shift;
    my $isos   = shift;
    my $check  = shift;
    my $checkhr = shift;

    use File::Basename qw( basename );

    my @dalist;

    push @dalist, $distro if $distro;
    push @dalist, split( /\s+/, $extras) if ( $extras );

    my $halt = 0;
    my $daisohr = {};

    my $iso_location_hashref = &get_iso_locations( $opts );
    debug "Searching for required iso files ...\n" if ($opts->{verbose});
    foreach my $da ( @dalist ) {
        debug "verify working dist $da\n" if ($opts->{debug} > 1);
        my @distisolist = ();
        my $distisoinfo = {};

        foreach my $prod ( &baxml_products_getlist( $opts, $da ) ) {
            foreach my $isofile ( &baxml_isos_getlist( $opts, $da, $prod ) ) {
                debug "dist $da prod $prod iso $isofile\n";
                my $ih = &baxml_iso_gethash( $opts, $da, $prod, $isofile );
                $distisoinfo->{$isofile}->{'hash'} = $ih;
                $distisoinfo->{$isofile}->{'path'} = $ih->{'isopath'};
                if ( defined $iso_location_hashref->{$isofile} ) {
                    if ( defined $iso_location_hashref->{$isofile}[1] ) {
                        warn "multiple iso name matches, need to check MD5s\n" if ($opts->{debug} > 1);
                        foreach my $iso ( @{ $iso_location_hashref->{$isofile} }  ) {
                            my $iah = &baxml_iso_gethash( $opts, $da, $prod, basename($iso) );
                            my $md5 = &get_md5sum( $iso );
                            if ( $md5 eq $iah->{md5} ) {
                                warn "match, using: $iso \n" if ($opts->{debug} > 1);
                                push @distisolist, $iso;
                            }
                        }
                    } else {
                        push @distisolist, $iso_location_hashref->{$isofile}[0];
                    }
                } else {
                    $halt = 1;
                    warning "Missing required file $isofile\n";
                }
            }
        }
        $daisohr->{ $da }->{info} = $distisoinfo;
        push @{$daisohr->{ $da }->{list}}, @distisolist;
        debug "verify:\n" . join( "\n", @distisolist ) . "\n" if ($opts->{debug} > 1);
    }

    if ( $halt ) {
        error "Please use --isos to download missing files.\n";
        return undef;
    }

    unless (($isos) || ($check)) {
        return $daisohr;
    }

    $halt = 0;
    foreach my $da ( @dalist ) {
        warning "Verifing iso checksums for $da ...\n"; # print LONG

        my $check_list;
        if ( $isos ) {
            $check_list = join " ", @{$checkhr->{ $da }->{check}};
        }

        foreach my $isofile ( @{$daisohr->{ $da }->{list}} ) {
            my $isoshort = $isofile;
            $isoshort =~ s|$baDir{isos}/||;
            if ( $isos && not $check ) {
                # skip non-downloaded unless check is specified
                next unless ( $check_list =~ m|$isoshort| );
            }
            debug $isoshort . " checksum in progress\n";
            my $md5 = &get_md5sum( $isofile );
            my $iname = basename( $isofile );
            my $storedmd5 = $daisohr->{$da}->{info}->{$iname}->{hash}->{md5};
            debug "$isoshort : $md5 == $storedmd5 ?\n" if ($opts->{debug});
            if ( $md5 ne $storedmd5 ) {
                error "Bad md5sum for $isoshort\n";
                $halt=1;
            } elsif ( $opts->{verbose} ) {
                debug "Good md5sum for $isoshort\n";
            }
        }
    }
    if ( $halt ) {
        error "Please remove file(s) with bad checksum and retry --isos\n";
        return undef;
    }

    return $daisohr;
}

sub make_paths
{
    my $opts     = shift;
    my $distro   = shift;
    my $extras   = shift;
    my $daisohr  = shift;
    my $loopback = shift;

    my $status = 1;

    use File::Basename qw( basename );

    #
    # $daisohr
    #   -> { $distro }                   # distro or addon name
    #     -> { 'list' } = @{$isofiles}   # isos found with complete pathing
    #     -> { 'info' }
    #       -> { $isoname }
    #         -> { 'path' } = "fulldir"  # where to extract isos and share
    #         -> { 'hash' }              # href to xml data
    #           -> { 'md5' } = md5sum
    #           -> { 'url' } = url
    #                                    # and for distro product base
    #           -> { 'kernel' } = linux  # relative path to loader
    #           -> { 'initrd' } = initrd
    #

    $opts->{LASTERROR} = "";

    my @dalist;

    push @dalist, $distro if $distro;
    push @dalist, split( /\s+/, $extras) if ( $extras );

    ## Create /tmp/directory to mount iso files for copy
    ##
    eval {
        $SIG{CHLD} = '';
        my $tdir = tempdir( "baracus.XXXXXX", TMPDIR => 1, CLEANUP => 1 );
        debug "using tempdir $tdir\n" if ($opts->{debug} > 1);
        unless ( -d $tdir ) {
            mkdir ($tdir,0777) or die;
        }
        my @mount = qx|mount|;

        debug "dalist: " . join( ' ', @dalist ) . "\n" if ( $opts->{debug} > 1 );
        foreach my $da ( @dalist ) {
            foreach my $isofile ( @{$daisohr->{ $da }->{list}} ) {
                my $iname = basename( $isofile );
                debug "$isofile and $iname\n" if ( $opts->{debug} > 1 );
                my $idir  = $daisohr->{ $da }->{info}->{$iname}->{path};
                if ( $loopback ) {
                    unless ( -d $idir ) {
                        unless ( mkpath $idir ) {
                            $opts->{LASTERROR} .= "Unable to create directory $idir $!";
                            next;
                        }
                    }
                    my $is_mounted = 0;
                    foreach ( @mount ) {
                        $is_mounted = 1 if (/$idir/);
                    }
                    unless ( $is_mounted ) {
                        $SIG{CHLD} = '';
                        system( "sudo mount -o loop $isofile $idir" ) == 0 or die $!;
                        &add_db_iso_entry($opts, $da, $iname, $idir, 1);
                    }
                }
            }
        }

        debug "removing tempdir $tdir\n" if ($opts->{debug} > 1);
        rmdir $tdir;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }
    return $status;
}

###########################################################################

sub remove_dud_initrd
{
    my $opts  = shift;
    my $dud   = shift;

    if ( &sqlfs_getstate( $opts, "initrd.$dud" ) ) {
        &sqlfs_remove( $opts, "initrd.$dud" );
    }
}

sub add_dud_initrd
{
    my $opts  = shift;
    my $base  = shift;
    my $dud   = shift;
    my $status = 1;

    my $bh = &baxml_distro_gethash( $opts, $base );
    my $basedist = $bh->{basedist};

    my $dh = &baxml_distro_gethash( $opts, $dud );
    my @pl = &baxml_products_getlist( $opts, $dud );
    my $ph = $pl[0];         # assume we're dealing with a list of one
    my @il = &baxml_isos_getlist( $opts, $dud, $ph );
    # again assume we're dealing with a list of one
    my $ih = &baxml_iso_gethash( $opts, $dud, $ph, $il[0] );

    eval {
        $SIG{CHLD} = '';
        if ( &sqlfs_getstate( $opts, "initrd.$basedist" ) ) {
            debug "found bootloader initrd.$basedist in file database\n" if $opts->{verbose};
        } else {
            $opts->{LASTERROR} = "bootloader initrd.$basedist not found in database\n";
            error $opts->{LASTERROR};
            die;
        }

        my $tdir = tempdir( "baracus.XXXXXX", TMPDIR => 1, CLEANUP => 1 );
        debug "using tempdir $tdir\n" if ($opts->{debug} > 1);
        unless ( -d $tdir ) {
            mkdir ($tdir,0777) or die;
        }

        debug "extract base distro initrd from db to $tdir/initrd.gz\n" if ( $opts->{debug} > 1 );
        copy($bh->{baseinitrd},"$tdir/initrd.gz") or die;

        # unzip the initrd
        system("cd $tdir; zcat $tdir/initrd.gz | cpio --quiet -id") == 0 or die;

        # unsquash if opensuse 11.2 or sles 11 sp1 or higher
        if ( ( $bh->{os} eq "sles" and $bh->{release} > 11 ) or
             ( $bh->{os} eq "opensuse" and $bh->{release} >= 11.2 ) ) {
            system("cd $tdir; unsquashfs $tdir/parts/00_lib") == 0 or die;
        }

        # Find all relevant kernel drivers
        my @drvlist;
        find ( { wanted =>
                 sub {
                     if ( $_ =~ m/^.*\.ko$/ ) {
                         debug "found $File::Find::name ($_)\n" if $opts->{debug};
                         push @drvlist, $File::Find::name;
                     }
                 },
                 follow => 1
                },
               $ih->{isopath} );

        # match os
        my @filtered;
        my $prefix = qr|$ih->{isopath}|o;
        my $filt64 = qr'^.*(x86_64|amd64).*$';
        my $filt32 = qr'^.*(x|i).*86[^_]+.*$';
        foreach my $loc (@drvlist) {
            $loc =~ s|$prefix/||;
            if ( $loc =~ m/$bh->{os}/ ) {
                push (@filtered, $loc);
            }
        }
        # use the filtered list only if there was an os name match
        @drvlist = @filtered if ( scalar @filtered );
        # match arch
        @filtered = ();
        foreach my $loc (@drvlist) {
            $loc =~ s|$prefix/||;
            if ($bh->{arch} eq "x86_64") {
                if ( $loc =~ m/$filt64/ ) {
                    push (@filtered, $loc);
                }
            } else {
                if ( $loc =~ m/$filt32/ ) {
                    push (@filtered, $loc);
                }
            }
        }
        unless (scalar @filtered) {
            $opts->{LASTERROR} = "death to useless regex - try 'file' on the list\n" ;
            error $opts->{LASTERROR};
            die;
        }
        foreach my $loc ( @filtered ) {
            debug "final answer using: $loc\n" if $opts->{debug};
        }


        # Determine driver path in initrd
        my $drvpath;
        my $kernel;
        if ( $bh->{os} eq "sles" and $bh->{release} eq "11.1" ) {
            opendir(IMD, "$tdir/parts/squashfs-root/lib/modules") or die;
            my @dfiles = readdir(IMD);
            closedir(IMD);
            foreach my $dfile ( @dfiles ) {
                if ( $dfile =~ /2.6/ ) {
                    $kernel = $dfile;
                }
            }
            $drvpath = "/parts/squashfs-root/lib/modules/$kernel/initrd/";
        } elsif ( $bh->{os} eq "sles" and $bh->{release} eq "11" ) {
            opendir(IMD, "$tdir/lib/modules") or die;
            my @dfiles = readdir(IMD);
            closedir(IMD);
            foreach my $dfile ( @dfiles ) {
                if ( $dfile =~ /2.6/ ) {
                    $kernel = $dfile;
                }
            }
            $drvpath = "/lib/modules/$kernel/initrd";
        } else {
            $opts->{LASTERROR} = "$basedist does not yet have dud support in baracus \n";
            error $opts->{LASTERROR};
            die;
        }

        # Copy drivers to correct location in initrd
        foreach my $driver ( @filtered ) {
            debug "cp $ih->{isopath}/$driver to $tdir/$drvpath\n" if ( $opts->{debug} > 1 );
            copy("$ih->{isopath}/$driver", "$tdir/$drvpath") or die;
        }

        # Create depmod files
        if ( $bh->{os} eq "sles" and $bh->{release} eq "11.1" ) {
            system("depmod", "-a", "--basedir", "$tdir/parts/squashfs-root", "$kernel") == 0 or die;
        } elsif ( $bh->{os} eq "sles" and $bh->{release} eq "11" ) {
            system("depmod", "-a", "--basedir", "$tdir", "$kernel") == 0 or die;
        } else {
            $opts->{LASTERROR} = "$base does not yet have dud support in baracus \n";
            error $opts->{LASTERROR};
            die;
        }

        # Recreate the initrd
        debug "creating initrd.$dud\n" if $opts->{debug};
        system("cd $tdir; find . | cpio --quiet --create --format='newc' > ../initrd.$dud") == 0 or die;
        system("gzip", "$tdir/../initrd.$dud") == 0 or die;
        system("mv", "$tdir/../initrd.$dud.gz", "$tdir/../initrd.$dud") == 0 or die;

        # Store the newly created initrd
        &sqlfs_store( $opts, "$tdir/../initrd.$dud" );
        unlink( "$tdir/initrd.$basedist" ) or die;
        unlink("$tdir/../initrd.$dud" ) or die;

        debug "removing tempdir $tdir\n" if ($opts->{debug} > 1);
        rmdir $tdir;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }
    return $status;
}

sub add_bootloader_files
{
    my $opts   = shift;
    my $distro = shift;

    my $state = undef;
    my $status = 1;

    #    print "+++++ add_bootloader_files\n" if ( $opts->{debug} > 1 );

    eval {
        $SIG{CHLD} = '';
        my $tdir = tempdir( "baracus.XXXXXX", TMPDIR => 1, CLEANUP => 1 );
        debug "using tempdir $tdir\n" if ($opts->{debug} > 1);
        unless ( -d $tdir ) {
            mkdir ($tdir,0777) or die;
        }

        my $dh = &baxml_distro_gethash( $opts, $distro );
        my $bh = $dh->{basedisthash};
        my $arch = $dh->{arch};
        my $basedist = $dh->{basedist};

        if ( $distro =~ m/win/i ) {
            my $baddiff = 0;
            while ( my ($fname, $fh) = each ( %{$bh->{baseshares}} ) ) {
                unless ( -f $fh->{file} ) {
                    my $winstall_msg = qq|
Missing $fh->{file}

Network install files for Win products need to be generated.

Make sure you have the helper cifs share available to user
'root' with no password:

  > grep winstall.conf /etc/samba/smb.conf
  include = /etc/samba/winstall.conf
  > service smb start    # if not already running
  > smbpasswd -a root
  # hit return twice for the password
  > smbclient -L $baVar{shareip}  # look for winstall
  > smbclient -U root //$baVar{shareip}/winstall
  # ctrl-c out of smb client

Then in a running instance of Win 7/2008/Vista,
which has Auto Install Toolkit (AIK) installed,
launch an AIK cmd shell as administrator, and
mount the share "winstall" and run "bawinstall.bat"
as follows:

  c: net use /user:root x: \\\\$baVar{shareip}\\winstall
  x:
  bawinstall.bat x

Afterwards,

  > service smb stop   # unless needed for other shares

then try this basource command again.

  > basource add --distro $distro

|;
                    $opts->{LASTERROR} = $winstall_msg;
                    error $opts->{LASTERROR};
                    $status = 0;
                    die;
                }
                my $stname = "${fname}-${arch}";
                $state = undef;
                $state = &sqlfs_fetch( $opts, "$tdir/$stname" );
                if ( ( $state == 1 ) or ( $state == 2 ) ) {
                    # file found and written out for compare
                    my $result = system("diff $fh->{file} $tdir/$stname >& /dev/null");
                    if ( $result == 0 ) { # same as what we'd add
                        debug "found $stname in file database\n" if $opts->{verbose};
                    } else {
                        if ( $baddiff == 0 ) {
                            $baddiff = 1;
                            error "\nDifferences in the db files and the winstall/import area have been found.\nYou likely have regenerated the winpe env and have not updated the files in the db.\nPlease run the following commands to sync these files:\n\n"
                        }
                        error "  baconfig update file --name $stname --file $fh->{file}\n";
                    }
                } else {
                    # file not found in db
                    debug "cp from $fh->{file} to $tdir/$stname\n" if $opts->{debug};
                    # we don't go from $fh->{file} to sqlfs_store directly
                    # there may be a name change / difference from $fname
                    copy($fh->{file},"$tdir/$stname") or die;
                    &sqlfs_store( $opts, "$tdir/$stname" );
                    unlink( "$tdir/$stname" ) or die;
                }
            }
        } elsif ( $distro =~ m/(xenserver|solaris)/i ) {
            while ( my ($fname, $fh) = each ( %{$bh->{baseshares}} ) ) {
                $state = undef;
                $state = &sqlfs_getstate( $opts, $fname );
                if ( $state ) {
                    if ( $state != -1 ) {
                        debug "found $fname in file database\n" if $opts->{verbose};
                    } else {
                        debug "cp from $fh->{file} to $tdir/$fname\n" if ( $opts->{debug} > 1 );
                        # we don't go from $fh->{file} to sqlfs_store directly
                        # there may be a name change / difference from $fname
                        copy($fh->{file},"$tdir/$fname") or die;
                        &sqlfs_store( $opts, "$tdir/$fname" );
                        unlink( "$tdir/$fname" ) or die;
                    }
                } else {
                    $opts->{LASTERROR} = "error looking up $fname in file database\n";
                    error $opts->{LASTERROR};
                }
            }
        } else {
            $state = undef;
            $state = &sqlfs_getstate( $opts, "linux.$basedist" ) or die;
            if ( $state ) {
                if ( $state != -1 ) {
                    debug "found bootloader linux.$basedist in file database\n" if $opts->{verbose};
                } else {
                    debug "cp from $bh->{baselinux} to $tdir/linux.$basedist\n" if ( $opts->{debug} > 1 );
                    copy($bh->{baselinux},"$tdir/linux.$basedist") or die;
                    &sqlfs_store( $opts, "$tdir/linux.$basedist" );
                    unlink ( "$tdir/linux.$basedist" ) or die;
                }
            } else {
                $opts->{LASTERROR} = "error looking up linux.$distro in file database\n";
                error $opts->{LASTERROR};
            }

            $state = undef;
            $state = &sqlfs_getstate( $opts, "initrd.$basedist" ) or die;
            if ( $state ) {
                if ( $state != -1 ) {
                    debug "found bootloader initrd.$basedist in file database\n" if $opts->{verbose};
                } else {
                    debug "cp from $bh->{baseinitrd} to $tdir/initrd.gz\n" if ( $opts->{debug} > 1 );
                    copy($bh->{baseinitrd},"$tdir/initrd.gz") or die;
                    if ( $distro =~ /sles-11/ ) {
                        system("gunzip", "$tdir/initrd.gz") == 0 or die;
                        copy("$baDir{data}/gpghome/.gnupg/my-key.gpg", "$tdir/my-key.gpg") or die;
                        my $result = `cd $tdir; find my-key.gpg | cpio --quiet -o -A -F initrd -H newc >> /dev/null`;
                        unlink( "$tdir/my-key.gpg" ) or die;
                        system("gzip", "$tdir/initrd") == 0 or die;
                    }
                    debug "cp from $tdir/initrd.gz to $tdir/initrd.$basedist\n" if ( $opts->{debug} > 1 );
                    copy("$tdir/initrd.gz", "$tdir/initrd.$basedist") or die;
                    unlink( "$tdir/initrd.gz" ) or die;

                    &sqlfs_store( $opts, "$tdir/initrd.$basedist" );
                    unlink( "$tdir/initrd.$basedist" ) or die;
	        }
            } else {
                $opts->{LASTERROR} = "error looking up initrd.$distro in file database\n";
                error $opts->{LASTERROR};
            }
        }
        debug "removing tempdir $tdir\n" if ($opts->{debug} > 1);
        rmdir $tdir;
    };
    if ( $@ ) {
        unless ( $opts->{LASTERROR} ) {
            $opts->{LASTERROR} = subroutine_name." : ".$@;
            error $opts->{LASTERROR};
        }
        $status = 0;
    }
    return $status;
}

sub remove_bootloader_files
{
    my $opts   = shift;
    my $distro = shift;

    my $status = 1;

    eval {
        my $dh = &baxml_distro_gethash( $opts, $distro );
        my $bh = $dh->{basehash};
        my $basedist = $dh->{basedist};

        while ( my ($fname, $fh) = each ( %{$bh->{baseshares}} ) ) {
            if ( $fname =~ m/kernel|initrd/i ) {
                if ( $fname =~ m/kernel/i ) {
                    $fname = "linux";
                }
                $fname = $fname.".$basedist";
            }

            ## eventually would like to be able to remove the kernel|initrd
            ## check but other distros share some of the files that might
            ## get removed.
            if ( ( &sqlfs_getstate( $opts, $fname ) ) and
                 ( $fname =~ m/linux|initrd/i ) ) {
                debug "Removing $fname from fileDB\n" if ( $opts->{debug} );
                &sqlfs_remove( $opts, $fname );
            }
        }
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }
    return $status;
}

################################################################################
# networking service handling

# add line or config file for build and restart service (only if neeeded)
sub add_build_service
{
    my $opts   = shift;
    my $distro = shift;
    my $extras = shift;
    my $status = 1;
    my $sharetype = $baVar{sharetype};


    my $dh = &baxml_distro_gethash( $opts, $distro );

    my $sql;
    my $sth;

    $opts->{LASTERROR} = "";

    my $ret = 0;
    my @dalist;

    push @dalist, $distro if $distro;
    push @dalist, split( /\s+/, $extras) if ( $extras );

    my $dbref = &get_db_source_entry( $opts, $dalist[0] );
    if ( defined $dbref ) {
        $sharetype = $dbref->{sharetype};
    } else {
        $sharetype = $dh->{'sharetype'} if ( $dh->{'sharetype'} );
    }

    debug "Calling routine to configure $sharetype\n";

    eval {
        # unlike http or cifs we pre-load nfs so we can manipulate
        if ($sharetype eq "nfs") {
            &enable_service( $opts, $sharetype );
        }

        my $restartservice = 0;
        foreach my $da ( @dalist ) {

            foreach my $prod ( &baxml_products_getlist( $opts, $da ) ) {

                my ($file, $confdir, $template, $share, $state) =
                    &check_service_product( $opts, $da, $prod, $sharetype );

                $share = $dh->{'distpath'}."/".$dh->{'sharepath'} if defined ( $dh->{'sharepath'} );

                if ( $state ) {
                    debug "$sharetype file $file found present for $da\n" if $opts->{verbose};
                } else {
                    debug "modifying $file adding $share\n" if $opts->{debug};

                    if ($sharetype eq "nfs") {
                        ## NFSv4 workaround
                        $share = &solaris_nfs_waround( $opts, $share ) if ( $distro =~ /solaris/ );
                        debug "exportfs -o ro,not_root_squash,insecure,sync,no_subtree_check *:$share\n" if ( $opts->{debug} > 1 );
                        system("exportfs -o ro,root_squash,insecure,sync,no_subtree_check *:$share") == 0 or die;
                    }

                    if ($sharetype eq "http") {
                        $restartservice = 1;

                        unless ( -d $confdir ) {
                            mkdir $confdir,0755 or die;
                        }

                        open(FILE, "<$template") or die;
                        my $httpdconf = join '', <FILE>;
                        close(FILE);

                        open(FILE, ">$file") or die;
                        $httpdconf =~ s|%OS%|$da|g;
                        $httpdconf =~ s|%ALIAS%|/install/$da/|g;
                        $httpdconf =~ s|%SERVERDIR%|$share/|g;
                        print FILE $httpdconf;
                        close(FILE);

                    }

                    if ($sharetype eq "cifs") {
                        $restartservice = 1;

                        unless ( -d $confdir ) {
                            mkdir $confdir,0755 or die;
                        }

                        open(FILE, "<$template") or die;
                        my $sambaconf = join '', <FILE>;
                        close(FILE);

                        open(FILE, ">$file") or die;
                        $sambaconf =~ s|%DISTRO%|$distro|g;
                        $sambaconf =~ s|%PATH%|$share|g;
                        print FILE $sambaconf;
                        close(FILE);

                        my $listfile = "${confdir}/includes.conf";
                        open( LISTING, "<$listfile" ) or die;
                        my $dontadd = 0;
                        while (<LISTING>) {
                            if (m|$distro|) {
                                $dontadd = 1;
                            }
                        }
                        close(LISTING);

                        unless ( $dontadd ) {
                            open(SAMBA, ">>${confdir}/includes.conf") or die;
                            print SAMBA "include = $file\n";
                            close(SAMBA);
                        }
                    }
                }
            }
        }
        if ( $restartservice ) {
            # clever enough to reload if possible
            enable_service( $opts, $sharetype );
        }
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }
    return $status;
}

# add line or config file for build and restart service (only if neeeded)
sub remove_build_service
{
    my $opts   = shift;
    my $distro = shift;
    my $extras = shift;
    my $sharetype = $baVar{sharetype};
    my $status = 1;

    my $dh = &baxml_distro_gethash( $opts, $distro );

    my $sql;
    my $sth;

    $opts->{LASTERROR} = "";

    my $ret = 0;
    my @dalist;
    push @dalist, $distro if $distro;
    push @dalist, split( /\s+/, $extras) if ( $extras );

    my $dbref = &get_db_source_entry( $opts, $dalist[0] );
    if ( defined $dbref ) {
        $sharetype = $dbref->{sharetype};
    } else {
        $sharetype = $dh->{'sharetype'} if ( defined $dh->{'sharetype'} );
    }

    eval {
        # unlike http or cifs we pre-load nfs so we can manipulate
        if ($sharetype eq "nfs") {
            &enable_service( $opts, $sharetype );
        }

        my $restartservice = 0;
        foreach my $da ( @dalist ) {

            foreach my $prod ( &baxml_products_getlist( $opts, $da ) ) {

                my ($file, $confdir, $template, $share, $state) =
                    &check_service_product( $opts, $da, $prod, $sharetype );

                $share = $dh->{'distpath'}."/".$dh->{'sharepath'} if defined ( $dh->{'sharepath'} );

                if ( not $state ) {
                    debug "$sharetype file $file found no longer shared for $da\n" if $opts->{verbose};
                } else {
                    debug "modifying $file removing $share\n" if ( $opts->{debug} );

                    if ($sharetype eq "nfs") {
                        ## Ugly Solaris NFSc4 workaround
                        if ( $distro =~ /solaris/ ) {
                            $share = "/var/lib/nfs/v4-root/" .  $share;
                        }
                        system("exportfs -u *:$share") == 0 or die;
                    }

                    if ($sharetype eq "http") {
                        $restartservice = 1;
                        unlink( $file );
                    }

                    if ($sharetype eq "cifs") {
                        $restartservice = 1;
                        unlink $file;
                        my $listfile    = "${confdir}/includes.conf";
                        my $listfilebak = "${listfile}.baback";
                        copy($listfile, $listfilebak) or die;
                        open(OUTFILE, ">$listfile" ) or die;
                        open(INFILE, "<$listfilebak" ) or die;
                        while (<INFILE>) {
                            unless (m|$distro|) {
                                print OUTFILE $_;
                            }
                        }
                        close INFILE;
                        close OUTFILE;
                        unlink $listfilebak;
                    }
                }
            }
        }
        if ( $restartservice ) {
            # clever enought to reload if possible
            enable_service( $opts, $sharetype );
        }
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }
    return $status;
}

sub init_mounter
{
    my $opts = shift;
    my @mount;
    my $ret = 0;
    my $isoloc;
    my $iso_location_hashref = &get_iso_locations( $opts );

    my $status = 1;

    my $sql = qq| SELECT mntpoint, iso, distroid
                  FROM $baTbls{'iso'}
                  WHERE is_loopback = 't'
               |;

    my $sth;
    my $href;

    eval {
        $sth = database->prepare( $sql );
        $sth->execute();

        while ( $href = $sth->fetchrow_hashref() ) {
            unless ( -d $href->{'mntpoint'} ) {
                mkpath $href->{'mntpoint'} or die;
            }
            my $is_mounted = 0;
            @mount = qx|mount|;
            foreach ( @mount ) {
                if (/$href->{'mntpoint'}/) {
                    debug "$iso_location_hashref->{$href->{'iso'}} already mounted\n" if $opts->{verbose};
                    $is_mounted = 1;
                }
            }
            next if ( $is_mounted );

            if ( scalar ($iso_location_hashref->{ $href->{'iso'} }) > 1 ) {
                ## more than one possible iso to mount
                ## determine correct choice
                debug "More than one iso found for mount, verifying with md5sum\n" if ( $opts->{verbose} );
                foreach my $prod ( &baxml_products_getlist( $opts, $href->{'distroid'} ) ) {
                    foreach my $iso ( @{ $iso_location_hashref->{ $href->{'iso'} } }  ) {
                        my $iah = &baxml_iso_gethash( $opts, $href->{'distroid'}, $prod, basename($iso) );
                        my $md5 = &get_md5sum( $iso );
                        if ( $md5 eq $iah->{md5} ) {
                            debug "match, using: $iso \n" if ($opts->{debug} > 1);
                            $isoloc = $iso;
                        }
                    }
                }
            } else {
                $isoloc = $iso_location_hashref->{ $href->{'iso'} }[0];
            }
            debug "mounting $isoloc at $href->{'mntpoint'} \n" if ( $opts->{verbose} );
            system("mount -o loop $isoloc $href->{'mntpoint'}") == 0 or die;
        }
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }
    return $status;
}

sub init_exporter
{
    my $opts = shift;
    my @mount;
    my $ret = 0;
    my $status = 1;


    my $sql = qq| SELECT mntpoint, distroid
                  FROM $baTbls{'iso'}
                  WHERE sharetype = '1'
               |;

    my $sth;
    my $href;

    eval {
        $sth = database->prepare( $sql );
        $sth->execute();

        $href = $sth->fetchrow_hashref();

        if ( defined $href ) {

            # if here then have need nfs shares so make sure have nfsserver
            enable_service( $opts, "nfs" ) if ( defined $href );

            my @share = qx|showmount -e localhost|;

            do {

                unless ( -d $href->{'mntpoint'} ) {
                    $opts->{LASTERROR} = "Distro share point does not exist: $href->{'mntpoint'}: $!";
                    error $opts->{LASTERROR};
                    next;
                }
    
                my $is_shared = 0;
                foreach ( @share ) {
                    if (/$href->{'mntpoint'}/) {
                        debug "Already exported: $href->{'mntpoint'}\n" if ( $opts->{verbose} );
                        $is_shared = 1;
                    }
                }
                next if ( $is_shared );

                # Solaris NFSv4 workaround
                $href->{'mntpoint'} = &solaris_nfs_waround( $opts, $href->{'mntpoint'} ) if ( $href->{distroid} =~ /solaris/ );

                debug "exporting $href->{'mntpoint'} \n" if ( $opts->{verbose} );
                system("exportfs -o ro,root_squash,insecure,sync,no_subtree_check *:$href->{'mntpoint'}") == 0 or die;

            } while ( $href = $sth->fetchrow_hashref() );
        }
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }
    return $status;
}

sub solaris_nfs_waround
{
    my $opts = shift;
    my $share = shift;

    my $nfsroot = "/var/lib/nfs/v4-root";
    my $nfsdir;

    eval {
        $SIG{CHLD} = '';
        unless ( -d $nfsroot ) {
            mkdir $nfsroot, 0755 or die;
        }

        my $not_exported = system("showmount -e localhost | grep \"$nfsroot \" >& /dev/null");
        if ( $not_exported ) {
            system("exportfs -o fsid=root,nohide *:$nfsroot") == 0 or die;
        }

        $nfsdir = $nfsroot . $share;
        mkpath( $nfsdir, { verbose => 0, mode => 0755} ) or die;
        system("mount -o bind,nfsexp $share $nfsdir") == 0 or die;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        return undef;
    }
    return $nfsdir;
}

# return $file, $confdir, $template, $share, $state;
#  state -1-error 0-missing 1-found
sub check_service_product
{
    my $opts      = shift;
    my $distro    = shift;
    my $product   = shift;
    my $sharetype = shift;

    my ($shares, $name) = &get_distro_share( $opts, $distro );
    my $share = @$shares[0];

    my $confdir = "";
    my $file = "";
    my $template = "";

    my $state = 0;

    eval {
        if ($sharetype eq "nfs") {
            $file = "nfs export";
            my @return = qx|showmount -e localhost| ;
            die if ( $? != 0 );
            foreach (@return) {
                $state = 1 if(/$share/);
            }
        }
        if ($sharetype eq "http") {
            $confdir = "$baDir{root}/http";
            $file = "${confdir}/$name.conf";
            $template = "$baDir{data}/templates/inst_server.conf.in";
            $state = 1 if ( -f $file);
        }
        if ($sharetype eq "cifs") {
            $confdir = "$baDir{root}/cifs";
            $file = "${confdir}/$name.conf";
            $template = "$baDir{data}/templates/samba.conf.in";
            $state = 1 if ( -f $file);
        }
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        return undef, undef, undef, undef, -1;
    }
    return $file, $confdir, $template, $share, $state;
}

###########################################################################
# distro_cfg - basource state relation

sub source_register
{
    my $opts    = shift;
    my $command = shift;
    my $distro  = shift;
    my $sharetype = $baVar{sharetype};

    my $status = 1;


    eval {
        #        debug "setting uid to $opts->{dbrole}\n" if ($opts->{debug} > 2);
        #        my $uid = Baracus::DB::su_user( $opts->{dbrole} );

        if ($command eq "add") {

            debug "Updating registration: add $distro\n";
            my $dbref = &get_db_source_entry( $opts, $distro );

            # get correct sharetype from DB, if not avail use sysconfig
            $sharetype = $dbref->{sharetype} if ( defined $dbref );
            
            unless ( defined $dbref->{distroid} and
                     ( $dbref->{distroid} eq $distro ) and
                     defined $dbref->{staus} and
                     ( $dbref->{staus} != BA_REMOVED ) ) {
                &add_db_source_entry( $opts, $distro );
            }
        } elsif ($command eq "remove") {

            debug "Updating registration: remove $distro\n";

            my $sql = qq|UPDATE $baTbls{ distro }
                         SET ( change, sharetype, shareip, status )
                         = ( CURRENT_TIMESTAMP(0), ?, ?, ? )
                         WHERE distroid=?|;

            my $sth = database->prepare( $sql );

            my $isosql = qq|DELETE from $baTbls{ 'iso' } WHERE distroid=?|;

            my $sthiso = database->prepare( $isosql );


            my $dh = &baxml_distro_gethash( $opts, $distro );
            $sharetype = $dh->{'sharetype'} if ( $dh->{'sharetype'} );


            $sth->execute( $sharetype, $baVar{shareip}, BA_REMOVED, $distro );
            $sthiso->execute( $distro );

        } elsif ($command eq "disable") {

            debug "Updating registration: disable $distro\n";

            my $sql = qq|UPDATE $baTbls{ distro }
                         SET ( change,status ) = ( CURRENT_TIMESTAMP(0),? )
                         WHERE distroid=?|;

            my $sth = database->prepare( $sql );
            $sth->execute( BA_DISABLED, $distro );

        } elsif ($command eq "enable") {

            debug "Updating registration: enable $distro\n";

            my $sql = qq|UPDATE $baTbls{ distro }
                         SET ( change,status ) = ( CURRENT_TIMESTAMP(0),? )
                         WHERE distroid=?|;

            my $sth = database->prepare( $sql );
            $sth->execute( BA_ENABLED, $distro );

        } else {
            $opts->{LASTERROR} = subroutine_name ." : Incorrect subcommand passed for source register\n";
            error $opts->{LASTERROR};
            $status = 0;
        }

        #        debug "setting uid back to $uid\n" if ($opts->{debug} > 2);
        #        $> = $uid;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name ." : " .$@;
        error $opts->{LASTERROR};
        $status = 0;
    }
    return $status;
}

sub is_loopback
{
    my $opts  = shift;
    my $share = shift;
    my $dbh = $opts->{dbh};

    my $sql = qq|SELECT is_loopback
                 FROM $baTbls{'iso'}
                 WHERE mntpoint = '$share'|;

    my $sth;
    my $href;

    eval {
        $sth = database->prepare( $sql );
        $sth->execute( );
        $href = $sth->fetchrow_hashref();
        $sth->finish;
        undef $sth;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        return 0;
    }
    return ( defined $href ) ? $href->{'is_loopback'} : 0;
}

sub get_enabled_disabled_distro_list
{
    my $opts    = shift;
    my $status  = shift;            ## enabled
    my @distros = ();
    my $dbh = $opts->{dbh};

    my $sql = qq|SELECT distroid
                 FROM $baTbls{'distro'}
                 WHERE status = ?
                |;

    my $sth;
    my $href;

    eval {
        $sth = database->prepare( $sql );
        $sth->execute( $status );
        while ( my $distro = $sth->fetchrow_array() ) {
            push @distros, $distro;
        }
        $sth->finish;
        undef $sth;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        return @distros;
    }

    return @distros;
}

sub get_inactive_distro_list
{
    my $opts  = shift;
    my @distros = ();

    my $sql = qq|SELECT distroid, status
                 FROM $baTbls{'distro'}
                |;

    my $sth;
    my $href;

    eval {
        $sth = database->prepare( $sql );
        $sth->execute( );
        while ( $href = $sth->fetchrow_hashref() ) {
            unless ( defined $href->{status} ) {
                push @distros, $href->{distroid};
            }
            if ( ( defined $href->{status} ) and ( $href->{status} != 3 ) ) {
                push @distros, $href->{distroid};
            }
        }
        $sth->finish;
        undef $sth;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        return @distros;
    }

    return @distros;
}

sub get_sharetype
{
    my $opts = shift;
    my $distro = shift;

    my $sql = qq| SELECT sharetype
                  FROM $baTbls{'distro'}
                  WHERE distroid = '$distro' |;

    my $sth;
    my $href;

    eval {
        $sth = database->prepare( $sql );
        $sth->execute( );
        $href = $sth->fetchrow_hashref();
        $sth->finish;
        undef $sth;
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        return undef;
    }
    return $href->{'sharetype'};
}

sub get_distro_includes
{
    my $opts   = shift;
    my $distro = shift;

    my $dh = &baxml_distro_gethash( $opts, $distro );
    if ( defined $dh->{include} ) {
        my $includes = $dh->{include};
        return $includes;
    }

    return undef;
}

sub get_distro_share
{
    my $opts   = shift;
    my $distro = shift;

    my $share;
    my @shares;
    my $name;

    # collapse multi prod sles-9 down to
    # os/release/arch

    # all other shares have one installable product
    # os/release/arch[/addos[/addrel]]/product

    my $dh = &baxml_distro_gethash( $opts, $distro );
    $name  = "${distro}_server";

    foreach my $prod ( &baxml_products_getlist( $opts, $distro ) ) {
        foreach my $isofile ( &baxml_isos_getlist( $opts, $distro, $prod ) ) {
            my $ih = &baxml_iso_gethash( $opts, $distro, $prod, $isofile );
            push @shares, $ih->{'isopath'};
        }
    }
    #  my $ph = &baxml_product_gethash( $opts, $distro, $prods[0] );
    #  $share = $ph->{prodpath};
    #  $name = "$distro-$prod_server";

    debug "get_distro_share: returning share @shares and name $name\n" if $opts->{debug};
    return (\@shares, $name);
}

sub list_installed_extras
{
    my $opts   = shift;
    my $distro = shift;
    my @list;

    my $dh = &baxml_distro_gethash( $opts, $distro );
    my $bh = $dh->{basedisthash};
    my $base = $dh->{basedist};

    foreach my $dist ( @{$bh->{addons}} ) {
        debug "is distro $base addon $dist 'added' ? " if $opts->{debug};
        my $dbref = &get_db_source_entry( $opts, $dist );
        if ( defined $dbref and defined $dbref->{status} and
             ( $dbref->{distroid} eq $dist ) and
             ( $dbref->{status} != BA_REMOVED ) ) {
            debug "YES\n" if $opts->{debug};
            push @list, $dist;
        } else {
            debug "NO\n" if $opts->{debug};
        }
    }
    return @list;
}

sub check_either
{
    my $opts   = shift;
    my $distro = shift;

    unless ( $distro ) {
        debug "\nMissing arg: <distro>\n";
        return 0;
        #        &help();
    }

    unless ( &baxml_distro_gethash( $opts, $distro ) ) {
        error "Unknown distribution or addon specified: $distro\n";
        #        error "Please use one of the following:\n";
        #        foreach my $dist ( reverse sort &baxml_distros_getlist( $opts ) ) {
        #            my $href = &baxml_distro_gethash( $opts, $dist );
        #            print "\t" . $dist . "\n" unless ( $href->{requires} );
        #        }
        return 0;
    }
    return 1;
}

sub check_distro
{
    my $opts   = shift;
    my $distro = shift;

    #    unless ( $distro ) {
    #        print "\nMissing arg: <distro>\n";
    #        &help();
    #    }

    my $dh = &baxml_distro_gethash( $opts, $distro );

    unless ( $dh ) {
        error "Unknown distribution specified: $distro\n";
        error "Please use one of the following:\n";
        foreach my $dist ( reverse sort &baxml_distros_getlist( $opts ) ) {
            my $href = &baxml_distro_gethash( $opts, $dist );
            error "\t" . $dist . "\n" if ( $href->{type} eq $badistroType{ BA_SOURCE_BASE } );
        }
        exit 1;
    }

    if ( $dh->{type} ne $badistroType{ BA_SOURCE_BASE } ) {
        error "Non-base distribution passed as base $distro\n";
        error "Perhaps try:\n\t\t--distro $dh->{basedist} --$dh->{type} $distro\n";
        exit 1;
    }
}

sub check_extras
{
    my $opts   = shift;
    my $distro = shift;
    my $extras = shift;

    # verify all addons passed are intended for given distro as base
    foreach my $extra ( split /\s+/, $extras ) {
        &check_extra( $opts, $extra );

        my $eh = &baxml_distro_gethash( $opts, $extra );

        unless ( ( $eh->{basedist} eq $distro ) or ( $eh->{type} eq $badistroType{ BA_SOURCE_SDK } ) ) {
            error "Base passed $distro instead of $eh->{basedist} for $extra\n";
            error "Perhaps try\n\t\t--distro $eh->{basedist} --addon $extra\n";
            exit 1;
        }
    }
}

sub check_extra
{
    my $opts   = shift;
    my $extra  = shift;

    my $dh = &baxml_distro_gethash( $opts, $extra );

    unless ( $dh ) {
        error "Unknown source specified: $extra\n";
        error "Please use one of the following:\n";
        foreach my $ao ( reverse sort &baxml_distros_getlist( $opts ) ) {
            my $ah = &baxml_distro_gethash( $opts, $ao );
            if ( ( $ah->{type} eq $badistroType{ BA_SOURCE_ADDON } ) or
                 ( $ah->{type} eq $badistroType{ BA_SOURCE_SDK   } ) or
                 ( $ah->{type} eq $badistroType{ BA_SOURCE_DUD   } ) ) {
                error "\t${ao}\n" ;
            }
        }
        exit 1;
    }

    if ( $dh->{type} eq $badistroType{ BA_SOURCE_BASE } ) {
        error "Base distro passed as value for --addon/--sdk/--dud $extra\n";
        exit 1;
    }
}

sub is_extra_dependant
{
    my $opts   = shift;
    my $distro = shift;
    my $extra  = shift;

    my $dbh = $opts->{dbh};

    foreach my $dist ( &baxml_distros_getlist( $opts ) ) {
        my $dh = &baxml_distro_gethash( $opts, $dist );

        if ( ( $dh->{type} eq $badistroType{ BA_SOURCE_BASE } ) and
             ( defined $dh->{include} ) and
             ( $dh->{include} eq $extra ) and
             ( $dist ne $distro ) ) {
            # now check if active
            if ( &is_source_installed( $opts, $dist ) ) {
                return 1;
            }
        }
    }

    return undef;
}

sub is_source_installed
{
    my $opts  = shift;
    my $source = shift;

    my $dbh = $opts->{dbh};
    my $dh = &get_db_data( $dbh, 'distro', $source );

    if ( ( defined $dh->{status}) and 
         ( $dh->{status} == BA_SOURCE_ENABLED ) ) {
        return 1;
    } elsif ( ( defined $dh->{status}) and
              ( $dh->{status} == BA_SOURCE_DISABLED ) ) {
        return 1;
    }

    return undef;
}


1;

__END__

=head1 AUTHOR

Daniel Westervelt, E<lt>dwestervelt@novellE<gt>
David Bahi, E<lt>dbahi@novellE<gt>

=cut
