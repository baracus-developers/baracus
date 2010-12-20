package BaracusSource;

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

use File::Temp qw/ tempdir /;
use File::Find;
use File::Path;
use File::Copy;

use lib "/usr/share/baracus/perl";

use BaracusDB;
use BaracusSql qw( :vars :subs );         # %baTbls && get_cols
use BaracusConfig qw( :vars :subs );
use BaracusState qw( :vars :states );     # %aState  && BA_ states

=pod

=head1 NAME

B<BaracusSource> - subroutines for managing Baracus source distros and repos

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
                %sdks
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
                download_iso
                get_iso_locations
                verify_iso
                make_paths
                add_bootloader_files
                remove_bootloader_files
                add_build_service
                remove_build_service
                check_service_product
                enable_service
                disable_service
                check_service
                start_iff_needed_service
                source_register
                get_loopback
                get_mntcheck
                get_distro_sdk
                get_distro_share
                list_installed_addons
                check_either
                check_distro
                check_addons
                check_addon
                init_exporter
                init_mounter
                get_enabled_distro_list
            )],
         );

    Exporter::export_ok_tags('vars');
    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

use vars qw ( %sdks );

# for semi-transparent addition of sdk with base
%sdks =
    (
     'sles-10.2-x86_64'     => 'sles-10.2-sdk-x86_64',
     'sles-10.2-x86'        => 'sles-10.2-sdk-x86',
     'sles-10.3-x86_64'     => 'sles-10.3-sdk-x86_64',
     'sles-10.3-x86'        => 'sles-10.3-sdk-x86',
     'sles-11-x86_64'       => 'sles-11-sdk-x86_64',
     'sles-11-x86'          => 'sles-11-sdk-x86',
     'sles-11.1-x86_64'     => 'sles-11.1-sdk-x86_64',
     'sles-11.1-x86'        => 'sles-11.1-sdk-x86',
     'opensuse-11.1-x86_64' => 'opensuse-11.1-nonoss-x86_64',
     'opensuse-11.1-x86'    => 'opensuse-11.1-nonoss-x86',
     'opensuse-11.2-x86_64' => 'opensuse-11.2-nonoss-x86_64',
     'opensuse-11.2-x86'    => 'opensuse-11.2-nonoss-x86',
     );

my %stypes =
    (
      'nfs'  => '1',
      'http' => '2',
      'cifs' => '3',
    );

###########################################################################
##
##  DATABASE RELATED ADD/READ - no update or delete provided?

sub get_db_iso_entry
{
    my $opts   = shift;
    my $distro = shift;
    my $dbh    = $opts->{dbh};

    my $sth;
    my $sql = qq|SELECT *
                 FROM $baTbls{ 'iso' }
                 WHERE distroid = '$distro' |;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n"    unless ( $sth->execute( ) );

    my $href = $sth->fetchrow_hashref();

    $sth->finish;
    undef $sth;

    return $href;
}

sub get_db_source_entry
{
    my $opts   = shift;
    my $distro = shift;
    my $dbh    = $opts->{dbh};

    my $sth;
    my $sql = qq|SELECT *
                 FROM $baTbls{ 'distro' }
                 WHERE distroid = '$distro' |;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n"    unless ( $sth->execute( ) );

    my $href = $sth->fetchrow_hashref();

    $sth->finish;
    undef $sth;

    return $href;
}

sub add_db_source_entry
{
    my $opts   = shift;
    my $distro = shift;

    if ($opts->{verbose}) {
        print "Registering source: $distro $baVar{shareip} $baDir{root} $baVar{sharetype}\n";
    }

    my $dbh = $opts->{dbh};

    my $sql;
    my $sth;

    my $dh = &baxml_distro_gethash( $opts, $distro );

    my ($shares,undef) = get_distro_share( $opts, $distro );
    my $share = @$shares[0];

    my $dbref = &get_db_source_entry( $opts, $distro );

    if ( defined $dbref ) {
        $sql = qq|UPDATE $baTbls{ 'distro' }
                  SET creation=CURRENT_TIMESTAMP(0),
                      change=NULL,
                      shareip=?,
                      sharetype=?,
                      basepath=?,
                      status=?
                  WHERE distroid=?|;

        $sth = $dbh->prepare( $sql )
            or die "Cannot prepare sth: ",$dbh->errstr;

        $sth->bind_param( 1, $baVar{shareip}    );
        $sth->bind_param( 2, $baVar{sharetype}  );
        $sth->bind_param( 3, $share      );
        $sth->bind_param( 4, BA_ENABLED  );
        $sth->bind_param( 5, $distro     );

        $sth->execute()
            or die "Cannot execute sth: ", $sth->errstr;
    } else {
        $sql = qq|INSERT INTO $baTbls{ 'distro' }
                  ( distroid,
                    os,
                    release,
                    arch,
                    description,
                    addon,
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

#                  VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
#                    kernel,
#                    initrd,

        $sth = $dbh->prepare( $sql )
            or die "Cannot prepare sth: ",$dbh->errstr;

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
#            $sth->bind_param( 12, 'NULL' );  # no kernel for addon
#            $sth->bind_param( 13, 'NULL' );  # no initrd for addon
        } else {
            $sth->bind_param( 6, 0 );
            $sth->bind_param( 7, 'NULL' );
            $sth->bind_param( 8, 'NULL' );

#            $sth->bind_param( 12, $dh->{basekernelsubpath} );
#            $sth->bind_param( 13, $dh->{baseinitrdsubpath} );
        }
        $sth->bind_param( 9,  $baVar{shareip}    );
        $sth->bind_param( 10, $baVar{sharetype}  );
        $sth->bind_param( 11, $share      );

        $sth->bind_param( 12, BA_ENABLED );

#        print "dist $distro os $dh->{os} rel $dh->{release} arch $dh->{arch} desc $dh->{description} addos $dh->{addos} addrel $dh->{addrel} ip $baVar{shareip} type $baVar{sharetype} share $share\n" if $opts->{debug};
        $sth->execute()
            or die "Cannot execute sth: ", $sth->errstr;
    }
}

sub update_db_source_entry
{
    my $opts      = shift;
    my $sharetype = shift;
    my $shareip   = shift;
    my $distro    = shift;

    if ($opts->{verbose}) {
        print "Updating source: $distro to $sharetype\n";
    }

    my $dbh = $opts->{dbh};

    my $sql;
    my $sth;

    my $dbref = &get_db_source_entry( $opts, $distro );

    if ( defined $dbref ) {
        if ( $sharetype ne "" ) {
            $sql = qq|UPDATE $baTbls{ 'distro' }
                      SET change=CURRENT_TIMESTAMP(0),
                          sharetype=?
                      WHERE distroid='$distro'|;

            $sth = $dbh->prepare( $sql )
                or die "Cannot prepare sth: ",$dbh->errstr;

            $sth->bind_param( 1, $sharetype );

            $sth->execute()
                or die "Cannot execute sth: ", $sth->errstr;
         }
        if ( $shareip ne "" ) {
            $sql = qq|UPDATE $baTbls{ 'distro' }
                      SET change=CURRENT_TIMESTAMP(0),
                          shareip=?
                      WHERE distroid='$distro'|;

            $sth = $dbh->prepare( $sql )
                or die "Cannot prepare sth: ",$dbh->errstr;

            $sth->bind_param( 1, $shareip );

            $sth->execute()
                or die "Cannot execute sth: ", $sth->errstr;
        }
    } else {
        $opts->{LASTERROR} = "$distro not available for updating\n";
        return 1;
    }
}

sub add_db_iso_entry
{
    my $opts        = shift;
    my $distro      = shift;
    my $iso         = shift;
    my $mntpoint    = shift;
    my $is_loopback = shift;
    my $sharetype   = $baVar{sharetype};

    my $is_local = 1;  ## force local for now

    print "Registering iso: $iso for $distro\n" if $opts->{verbose};

    my $dbh = $opts->{dbh};
    my $sql;
    my $sth;

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
                  SET is_loopback=?,
                      change=CURRENT_TIMESTAMP(0)
                  WHERE distroid=?|;

        $sth->bind_param( 1, $dbref->{is_loopback} );

        $sth = $dbh->prepare( $sql )
            or die "Cannot prepare sth: ",$dbh->errstr;

        $sth->execute()
            or die "Cannot execute sth: ", $sth->errstr;
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

        $sth = $dbh->prepare( $sql )
            or die "Cannot prepare sth: ",$dbh->errstr;

        $sth->bind_param( 1, $iso                        );
        $sth->bind_param( 2, $distro                     );
        $sth->bind_param( 3, $is_loopback                );
        $sth->bind_param( 4, $mntpoint                   );
        $sth->bind_param( 5, $stypes{$sharetype}  );
        $sth->bind_param( 6, $is_local                   );

        $sth->execute()
            or die "Cannot execute sth: ", $sth->errstr;
    }

}

sub update_db_iso_entry
{
    my $opts        = shift;
    my $distro      = shift;
    my $sharetype   = shift;

    if ($opts->{verbose}) {
        print "Updating sharetype $sharetype iso entry for: $distro\n";
    }

    my $dbh = $opts->{dbh};
    my $sql;
    my $sth;

    my $dbref = &get_db_iso_entry( $opts, $distro );

    if ( defined $dbref ) {
        $sql = qq|UPDATE $baTbls{ 'iso' }
                  SET change=CURRENT_TIMESTAMP(0),
                      sharetype=?
                  WHERE distroid='$distro'|;

    #    $sth->bind_param( 1, $stypes{$sharetype} );

        $sth = $dbh->prepare( $sql )
            or die "Cannot prepare sth: ",$dbh->errstr;

        $sth->execute( $stypes{$sharetype} )
            or die "Cannot execute sth: ", $sth->errstr;
    } else {
        $opts->{LASTERROR} = "iso for $distro not currently available\n";
        return 1;
    }
}


###########################################################################
# sqlfsOBJ - sqlfstable - tftp db

# lookup file - 0 missing, 1 enabled, 2 disabled
sub sqlfs_getstate
{
    my $opts = shift;
    my $file = shift;
    my $state = 0;
    print "setting uid to $opts->{dbrole}\n" if ($opts->{debug} > 2);
    my $uid = BaracusDB::su_user( $opts->{dbrole} );

    my $sel = $opts->{sqlfsOBJ}->detail( $file );
    if ( defined $sel ) {
        if ( $sel->{'enabled'} ) {
            $state = 1;
        } else {
            $state = 2;
        }
    }
    print "setting uid back to $uid\n" if ($opts->{debug} > 2);
    $> = $uid;

    return $state;
}

# store a file located on disk
sub sqlfs_store
{
    my $opts = shift;
    my $file = shift;
    my $status = 0;
    print "setting uid to $opts->{dbrole}\n" if ($opts->{debug} > 2);
    my $uid = BaracusDB::su_user( $opts->{dbrole} );
    $status = $opts->{sqlfsOBJ}->store( $file );
    if ( $status ) {
        warn "Store failed to store $file in sqlfs\n";
    }
    print "setting uid back to $uid\n" if ($opts->{debug} > 2);
    $> = $uid;
    return $status;
}

# store contents of scalar var ref
sub sqlfs_storeScalar
{
    my $opts = shift;
    my $file = shift;
    my $ref  = shift;
    my $desc = shift;

    my $status = 0;
    print "setting uid to $opts->{dbrole}\n" if ($opts->{debug} > 2);
    my $uid = BaracusDB::su_user( $opts->{dbrole} );
    $status = $opts->{sqlfsOBJ}->storeScalar( $file, $ref, $desc );
    if ( $status ) {
        warn "StoreScalar failed to store $file in sqlfs\n";
    }
    print "setting uid back to $uid\n" if ($opts->{debug} > 2);
    $> = $uid;
    return $status;
}

# remove a file located in sqlfs tftp relation
sub sqlfs_remove
{
    my $opts = shift;
    my $file = shift;
    my $status = 0;
    print "setting uid to $opts->{dbrole}\n" if ($opts->{debug} > 2);
    my $uid = BaracusDB::su_user( $opts->{dbrole} );
    $status = $opts->{sqlfsOBJ}->remove( $file );
    if ( $status ) {
        warn "Unable to remove $file from sqlfs\n";
    }
    print "setting uid back to $uid\n" if ($opts->{debug} > 2);
    $> = $uid;
    return $status;
}

###########################################################################
##
## XML INIT DB ROUTINES

sub prepdbwithxml
{
    my $opts  = shift;
    my $dbh   = $opts->{dbh};
    my $baXML = $opts->{baXML};

    my %entry;

    my $sql_cols = lc get_cols( 'distro' );
    $sql_cols =~ s/[ \t]*//g;
    my @cols = split( /,/, $sql_cols );
    my $sql_vals = "?," x scalar @cols; chop $sql_vals;

    my $sql = qq|INSERT INTO $baTbls{ distro }
                ( $sql_cols )
                VALUES ( $sql_vals )
                |;

    print $sql . "\n" if $opts->{debug};

    my $sth;
    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} = "Unable to prepare 'add' distro statement\n" . $dbh->errstr;
        return 1;
    }

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

        if ( defined $dh->{'requires'} ) {
            $entry{'addon'  } = 1;
            $entry{'addos'  } = $dh->{addos};
            $entry{'addrel' } = $dh->{addrel}
                if ( defined $dh->{addrel} );
#            $entry{'kernel'} = "";
#            $entry{'initrd'} = "";
        } else {
            $entry{'addon'  } = 0;
            $entry{'addos'  } = "";
            $entry{'addrel' } = "";
#            $entry{'kernel'} = $dh->{basekernelsubpath};
#            $entry{'initrd'} = $dh->{baseinitrdsubpath};
        }

        if ( $opts->{debug} > 1 ) {
            while (my ($key, $val) = each %entry) {
                print "entry $key => $val\n"
            }
        }

        my $dbref = &get_db_source_entry( $opts, $distro );
        if ( defined $dbref and defined $dbref->{distroid} ) {
            print "Entry already exists:  distro $entry{'distroid'}.\n" if ( $opts->{debug} > 2 );
            next;
        } else {
            print "Adding entry for:  distro $entry{'distroid'}.\n" if ( $opts->{debug} > 2 );
        }

        my $paramidx = 0;
        foreach my $col (@cols) {
            $paramidx += 1;
            $sth->bind_param( $paramidx, $entry{ $col } );
        }

        # finished with last entry
        unless( $sth->execute( ) ) {
            $opts->{LASTERROR} = "Unable to execute 'add' distro statement\n" .
                $sth->err;
            return 1;
        }
    }

    $sth->finish;
    undef $sth;

    return 0;
}

sub purgedbofxml
{
    my $opts  = shift;
    my $dbh   = $opts->{dbh};
    my $baXML = $opts->{baXML};

    my $sql = qq|DELETE FROM $baTbls{ 'distro' } WHERE distroid = ?|;
    print $sql . "\n" if $opts->{debug};

    my $sth;
    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} = "Unable to prepare 'purge' distro statement\n" . $dbh->errstr;
        return 1;
    }

    foreach my $distro ( keys %{$baXML->{distro}} ) {

        print "Removing $distro entry\n" if ($opts->{debug});

        unless( $sth->execute( $distro ) ) {
            $opts->{LASTERROR} = "Unable to execute 'purge' of $distro\n" .
                $sth->err;
            return 1;
        }
    }

    $sth->finish;
    undef $sth;

    return 0;
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

    print "XML post-processing xml struct\n" if ($opts->{debug} > 2);
    foreach my $distro ( keys %{$baXML->{distro}} ) {
        my $dh = $baXML->{distro}->{$distro};
        my @baseparts = ( $dh->{os}, $dh->{release}, $dh->{arch} );
        $dh->{basedist} = join "-", @baseparts;
        unless ( $baXML->{distro}->{ $dh->{basedist} } ) {
            die "Malformed $xmlfile\nMissing entry for distro $dh->{basename} required by $distro\n";
        }
        print "XML working with distro $distro\n" if ($opts->{debug} > 2);
        print "XML described as $dh->{description}\n" if ($opts->{debug} > 2);
        $dh->{basedisthash} = $baXML->{distro}->{ $dh->{basedist} };

        # start all pathing below the ~baracus/bulids/os/version/arch
        $dh->{distpath} = join "/", $baDir{'builds'}, @baseparts;

        # add-ons have 'requires' specifiers
        # this no longer describes the base distro needed - it's just a flag
        if ( defined $dh->{'requires'} ) {
            if ( $distro eq $dh->{basedist} ) {
                die "Malformed $xmlfile\nAdd-on $distro (has 'requires') only has base components as part of its name\n";
            }
            print "XML distro is addon for base $dh->{basedist}\n" if ($opts->{debug} > 2);

            # addons are placed in sub directories of the base distro
            # ~baracus/bulids/os/version/arch/product/addos[/addrel]
            $dh->{distpath} = join "/", $dh->{distpath}, $dh->{addos};
            $dh->{distpath} = join "/", $dh->{distpath}, $dh->{addrel}
                if ( defined $dh->{addrel} );

            # append distro to base addons list
            print "XML add $distro to $dh->{basedist} addon array\n"
                if ($opts->{debug} > 2);
            push @{$dh->{basedisthash}->{addons}}, $distro;
        } elsif ( $dh != $dh->{basedisthash}) {
            die "non-addon $distro hash $dh not equal to $dh->{basedisthash} ?!\n";
        }
        print "XML distro path $dh->{distpath}\n" if ($opts->{debug} > 2);

        # every non-addon distro needs one product of addon type "base"
        # basefound indicates that <addon>base</addon> was found in product
        # but we also set this flag for addon that 'requires' a base
        # because it should be found thru that product.
        my $basefound = 0;
        $basefound = 1 if ( defined $dh->{'requires'} ); # spoof check for addons

        # a distro with base product needs one iso with "kernel" and "initrd"
        # the loaderfound flag indicates that these files have been found
        # in one, and there can only be one with these, iso of the product
        my $loaderfound = 1;

        foreach my $product ( keys %{$dh->{product}} ) {
            my $ph = $dh->{product}->{$product};

            # product name becomes part of the path for the mount / cp point
            # typically this is 'dvd' but can be more elaborate (as for sles 9)
            $ph->{prodpath} = join "/", $dh->{distpath}, $product;
            print "XML working with product $product\n" if ($opts->{debug} > 2);
            print "XML product path $ph->{prodpath}\n" if ($opts->{debug} > 2);

            if ( defined $ph->{'addon'} and $ph->{'addon'} eq "base" ) {
                if ( $basefound ) {
                    die "Malformed $xmlfile\nDistro $distro has more than one product with <addon>base</addon>\n";
                }
                $basefound = 1;
                $loaderfound = 0;

                # set the base product information for every distro
                $dh->{baseprod} = $product;
                $dh->{baseprodhash} = $ph;
                $dh->{baseprodpath} = $ph->{prodpath};

                print "XML base prod path $dh->{baseprodpath}\n" if ($opts->{debug} > 2);
            }
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
                print "XML iso path $ih->{isopath}\n" if ($opts->{debug} > 2);
                if ( defined $ih->{sharefiles} ) {
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
                            print "XML sharefile $sname $sh->{sharetype}  $dh->{baseshares}->{$sname}->{file}\n" if ($opts->{debug} > 2);
                        }
                    }

                    # isopath will get us to the mount / cp point of the iso
                    # the kernel and initrd values have pathing info embedded
                    # (relative to the root of the iso)

                    print "XML base iso path $dh->{baseisopath}\n" if ($opts->{debug} > 2);

                    my $path = "";
                    $path .= $ih->{path} . "/" if ( defined $ih->{'path'} );

                    if ( defined $dh->{baseshares}->{kernel} ) {
                        $dh->{baselinux}  = $dh->{baseshares}->{kernel}->{file};
                        $dh->{basekernelsubpath} = "${path}$dh->{baseshares}->{kernel}->{file}";
                        print "XML linux $dh->{baselinux}\n" if ($opts->{debug} > 2);
                        print "XML sub $dh->{basekernelsubpath}\n" if ($opts->{debug} > 2);
                    }
                    if ( defined $dh->{baseshares}->{initrd} ) {
                        $dh->{baseinitrd} = $dh->{baseshares}->{initrd}{file};
                        $dh->{baseinitrdsubpath} = "${path}$dh->{baseshares}->{initrd}->{file}";
                        print "XML initrd $dh->{baseinitrd}\n" if ($opts->{debug} > 2);
                        print "XML sub $dh->{baseinitrdsubpath}\n" if ($opts->{debug} > 2);
                    }
                }
            }
            unless ( $loaderfound ) {
                die "Malformed $xmlfile\nEntry $distro base $product is missing an iso containing both <kernel> and <initrd>\n";
            }
        }
        unless ( $basefound ) {
            die "Malformed $xmlfile\nEntry $distro is missing a product containing <addon>base</addon>\n";
        }
        print "\n" if ($opts->{debug} > 2);
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
    my $addons = shift;
    my $proxy  = shift;
    my $checkhr = shift;

    my @dalist;

    print "+++++ download_iso\n" if ( $opts->{debug} > 1 );

    push @dalist, $distro if $distro;
    push @dalist, split( /\s+/, $addons) if ( $addons );

    my $daisohr = {};
    my @isofilelist;
    my $found = 0;

    ## create directory for iso files if not present
    if (! -d $baDir{builds}) {
        mkpath "$baDir{builds}" or die ("Cannot create ~baracus/isos directory\n");
    }

    print "Searching for iso files needing download ...\n" if ($opts->{verbose});
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
                                 print "found $File::Find::name\n" if $opts->{debug};
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
        print "ISO download requested and files were already found. If checksum\n";
        print "verification fails for a file, please remove the file and retry.\n";
    }

    return 0 unless @isofilelist;

    my $username="";
    my $password="";
    my $proxyaddr="";
    my $pusername="";
    my $ppassword="";

    my $dh = &baxml_distro_gethash( $opts, $distro );

    if ($dh->{autodownload} eq "no") {
        $opts->{LASTERROR} = "Baracus assisted download not supported for $distro\n";
        return 1;
    }

    if ($dh->{autodownload} eq "auth") {
        print "Please enter (novell.com) userid: ";
        chomp($username = ReadLine 0);

        print "Please enter (novell.com) password: ";
        ReadMode 'noecho';
        chomp($password = ReadLine 0);
        ReadMode 'normal';
    }

    if ($proxy) {
        print "Please enter proxy address: ";
        chomp($proxyaddr = ReadLine 0);

        print "Please enter proxy username: ";
        chomp($pusername = ReadLine 0);

        print "Please enter proxy password: ";
        ReadMode 'noecho';
        chomp($ppassword = ReadLine 0);
        ReadMode 'normal';
        print "\n";
    }

    print "\nDownloading: \n";
    foreach my $da ( @dalist ) {
        foreach my $isofile ( sort @{$daisohr->{ $da }->{list}} ) {
            # here isofile has no path info just the filename
            my $url = $daisohr->{$da}->{info}->{$isofile}->{hash}->{url};
            &get_iso($opts,$distro,$url,$isofile,$username,$password,$proxy,$pusername,$ppassword,$proxyaddr);
        }
    }
}

sub get_iso
{
    my ($opts,$distro,$url,$iso,$username,$password,$proxy,$pusername,$ppassword,$proxyaddr) = @_;
    use LWP::UserAgent;
    my $file="$baDir{'isos'}/$iso";
    my $br;
    my $ua;

    print "+++++ get_iso\n" if ( $opts->{debug} > 1 );

    my $dh = &baxml_distro_gethash( $opts, $distro );

    $proxyaddr =~ s/http:\/\///;
    $ENV{'HTTP_PROXY'} = "http:\/\/$pusername:$ppassword\@$proxyaddr";

    unless(-d $baDir{'isos'}) {
        mkdir $baDir{'isos'}, 0755 || die ("Cannot create directory\n");
    }

    if ($proxy) {
        $ua = LWP::UserAgent->new(keep_alive => 1, env_proxy=>1 ) || die "$!";
    } else {
        $ua = LWP::UserAgent->new(keep_alive => 1 ) || die "$!";
    }
    unless ($dh->{autodownload} eq "open") {
        $ua->cookie_jar({});
        $ua->credentials('cdn.novell.com:80', 'iChain', "$username",  "$password" );
    }

    $| = 1;
    open(FILE, ">$file") || die "Can't open $file: $!\n";
    my $req = $ua->request(HTTP::Request->new(GET => $url),
                           sub {
                               $br += length($_[0]);
                               if ($_[1]->content_length) {
                                   printf STDERR " $iso: [ %d%% ] \r",100*$br/$_[1]->content_length;
                               }
                               binmode FILE;
                               print FILE $_[0] or die "Can't write to $file: $!\n";
                           });
    if (! $req->is_success) {
        unlink $file;
        print $req->status_line, "\n";
        exit(1);
    }
    print "\n";
    if (fileno(FILE)) {
        close(FILE) || die "Can't write to $file: $!\n";
    }
}

sub get_iso_locations
{
    #this is only going to use the first instance of the iso found
    my $opts = shift;
    my %isohash;

    find ({ wanted =>
            sub {
                if ($_ =~ /.*\.iso$/) {
                    print "found $File::Find::name\n" if ( $opts->{debug} > 2 );
                    $isohash{ $_ } = $File::Find::name ;
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
    my $addons = shift;
    my $isos   = shift;
    my $check  = shift;
    my $checkhr = shift;

    print "+++++ verify_iso\n" if ( $opts->{debug} > 1 );

    use Digest::MD5 qw(md5 md5_hex md5_base64);
    use File::Basename;

    my @dalist;

    push @dalist, $distro if $distro;
    push @dalist, split( /\s+/, $addons) if ( $addons );

    my $halt = 0;
    my $daisohr = {};

    ## test directory for iso files
    if (! -d $baDir{builds}) {
        print "Creating missing directory: $baDir{builds}\n";
	mkdir $baDir{builds};
#        exit(1);
    }

    my $iso_location_hashref = &get_iso_locations( $opts );
    print "Searching for required iso files ...\n" if ($opts->{verbose});
    foreach my $da ( @dalist ) {
        print "verify working dist $da\n" if ($opts->{debug} > 1);
        my @distisolist = ();
        my $distisoinfo = {};

        foreach my $prod ( &baxml_products_getlist( $opts, $da ) ) {
            foreach my $isofile ( &baxml_isos_getlist( $opts, $da, $prod ) ) {
                print "dist $da prod $prod iso $isofile\n" if $opts->{verbose};
                my $ih = &baxml_iso_gethash( $opts, $da, $prod, $isofile );
                $distisoinfo->{$isofile}->{'hash'} = $ih;
                $distisoinfo->{$isofile}->{'path'} = $ih->{'isopath'};
                if ( defined $iso_location_hashref->{$isofile} ) {
                    push @distisolist, $iso_location_hashref->{$isofile};
                } else {
                    $halt = 1;
                    print "Missing required file $isofile\n";
                }
            }
        }
        $daisohr->{ $da }->{info} = $distisoinfo;
        push @{$daisohr->{ $da }->{list}}, @distisolist;
        print "verify:\n" . join( "\n", @distisolist ) . "\n" if ($opts->{debug} > 1);
    }

    if ( $halt ) {
        print "Please use --isos to download missing files.\n";
        exit 1;
    }

    unless (($isos) || ($check)) {
        return $daisohr;
    }

    $halt = 0;
    foreach my $da ( @dalist ) {
#        print "Verifing iso checksums for $da ...\n";            # print LONG

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
            print $isoshort . " checksum in progress\n";
            open(FILE, $isofile) or
                die "Can't open '$isofile': $!";
            binmode(FILE);
            my $md5 = Digest::MD5->new->addfile(*FILE)->hexdigest;
            chomp($md5);
            my $iname = basename( $isofile );
            my $storedmd5 = $daisohr->{$da}->{info}->{$iname}->{hash}->{md5};
            print "$isoshort : $md5 == $storedmd5 ?\n" if ($opts->{debug});
            if ( $md5 ne $storedmd5 ) {
                print "Bad md5sum for $isoshort\n";
                $halt=1;
            } elsif ( $opts->{verbose} ) {
                print "Good md5sum for $isoshort\n";
            }
        }
    }
    if ( $halt ) {
        print  "Please remove file(s) with bad checksum and retry --isos\n";
        exit 1;
    }

    return $daisohr;
}

sub make_paths
{
    my $opts   = shift;
    my $distro  = shift;
    my $addons  = shift;
    my $daisohr = shift;
    my $loopback = shift;

    print "+++++ make_paths\n" if ( $opts->{debug} > 1 );

    use File::Basename;

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
    push @dalist, split( /\s+/, $addons) if ( $addons );

    ## Create /tmp/directory to mount iso files for copy
    ##
    my $tdir = tempdir( "baracus.XXXXXX", TMPDIR => 1, CLEANUP => 1 );
    print "using tempdir $tdir\n" if ($opts->{debug} > 1);
    mkdir $tdir, 0755 || die ("Cannot create directory\n");
    chmod 0777, $tdir || die "$!\n";
    my @mount = qx|mount| or die ("Can't get mount status: ".$!);

    print "dalist: " . join( ' ', @dalist ) . "\n" if ( $opts->{debug} > 1 );
    foreach my $da ( @dalist ) {
        foreach my $isofile ( @{$daisohr->{ $da }->{list}} ) {
            my $iname = basename( $isofile );
            print "$isofile and $iname\n" if ( $opts->{debug} > 1 );
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
                    system( "mount -o loop $isofile $idir" );
                    &add_db_iso_entry($opts, $da, $iname, $idir, 1);
                }
             }
        }
    }

    print "removing tempdir $tdir\n" if ($opts->{debug} > 1);
    rmdir $tdir;

    return 1 if ($opts->{LASTERROR} ne "");
    return 0;
}

sub add_bootloader_files
{
    my $opts   = shift;
    my $distro = shift;

    print "+++++ add_bootloader_files\n" if ( $opts->{debug} > 1 );

    my $tdir = tempdir( "baracus.XXXXXX", TMPDIR => 1, CLEANUP => 1 );
    print "using tempdir $tdir\n" if ($opts->{debug} > 1);
    mkdir $tdir, 0755 || die ("Cannot create directory\n");
    chmod 0777, $tdir || die "$!\n";

    my $dh = &baxml_distro_gethash( $opts, $distro );
    my $bh = $dh->{basedisthash};
    my $arch = $dh->{arch};
    my $basedist = $dh->{basedist};

    if ( $distro =~ m/win/i )  {
	while ( my ($fname, $fh) = each ( %{$bh->{baseshares}} ) ) {
	    unless ( -f $fh->{file} ) {
		my $winstall_msg = qq|
Missing $fh->{file}

Network install files for Win products need to be generated.

Make sure you have the helper cifs share available:

  > grep winstall.conf /etc/samba/smb.conf
  include = /etc/samba/winstall.conf
  > service smb start       # if not already running
  > smbclient -L localhost  # look for winstall

Then in a running instance of Win 7/2008/Vista,
which has Auto Install Toolkit (AIK) installed,
mount the share "winstall" and run "bawinstall.bat"
as follows:

  c: net use x: \\\\$baVar{shareip}\\winstall
  x:
  bawinstall.bat x

Afterwards, stop smb ( rcsmb stop ) unless you have need of
samba for other shares, and then try this basource command again.
|;
		print $winstall_msg;
                exit;
	    }
        my $stname = "${fname}-${arch}";
	    if ( &sqlfs_getstate( $opts, $stname  ) ) {
		print "found $stname in tftp database\n" if $opts->{verbose};
	    } else {
		print "cp from $fh->{file} to $tdir/$stname\n"
		    if ( $opts->{debug} > 1 );
		# we don't go from $fh->{file} to sqlfs_store directly
		# there may be a name change / difference from $fname
		copy($fh->{file},"$tdir/$stname") or die "Copy failed: $!";
		&sqlfs_store( $opts, "$tdir/$stname" );
		unlink( "$tdir/$stname" );
	    }
	}
    } elsif ( $distro =~ m/(xenserver|solaris)/i )  {
        while ( my ($fname, $fh) = each ( %{$bh->{baseshares}} ) ) {
            if ( &sqlfs_getstate( $opts, $fname ) ) {
                print "found $fname in tftp database\n" if $opts->{verbose};
            } else {
                print "cp from $fh->{file} to $tdir/$fname\n"
                    if ( $opts->{debug} > 1 );
                # we don't go from $fh->{file} to sqlfs_store directly
                # there may be a name change / difference from $fname
                copy($fh->{file},"$tdir/$fname") or die "Copy failed: $!";
                &sqlfs_store( $opts, "$tdir/$fname" );
                unlink( "$tdir/$fname" );
            }
        }
    } else {
	if ( &sqlfs_getstate( $opts, "linux.$distro" ) ) {
	    print "found bootloader linux.$basedist in tftp database\n" if $opts->{verbose};
	} else {
	    print "cp from $bh->{baselinux} to $tdir/linux.$basedist\n"
		if ( $opts->{debug} > 1 );
	    copy($bh->{baselinux},"$tdir/linux.$basedist") or die "Copy failed: $!";
	    &sqlfs_store( $opts, "$tdir/linux.$basedist" );
	    unlink ( "$tdir/linux.$basedist" );
	}
	if( &sqlfs_getstate( $opts, "initrd.$basedist" ) ) {
	    print "found bootloader initrd.$basedist in tftp database\n"
		if $opts->{verbose};
	} else {
	    print "cp from $bh->{baseinitrd} to $tdir/initrd.gz\n" if ( $opts->{debug} > 1 );
	    copy($bh->{baseinitrd},"$tdir/initrd.gz") or die "Copy failed: $!";
	    if ( $distro =~ /sles-11/ ) {
		system("gunzip", "$tdir/initrd.gz");
		copy("$baDir{data}/gpghome/.gnupg/my-key.gpg", "$tdir/my-key.gpg") or
		    die "Copy failed: $!";
		my $result = `cd $tdir; find my-key.gpg | cpio --quiet -o -A -F initrd -H newc >> /dev/null`;
		unlink( "$tdir/my-key.gpg" );
		system("gzip", "$tdir/initrd");
	    }
	    print "cp from $tdir/initrd.gz to $tdir/initrd.$basedist\n"
		if ( $opts->{debug} > 1 );
	    copy("$tdir/initrd.gz", "$tdir/initrd.$basedist") or
		die "Copy failed: $!";
	    unlink( "$tdir/initrd.gz" );

	    &sqlfs_store( $opts, "$tdir/initrd.$basedist" );
	    unlink( "$tdir/initrd.$basedist" );
	}
    }
    print "removing tempdir $tdir\n" if ($opts->{debug} > 1);
    rmdir $tdir;
}

sub remove_bootloader_files
{
    my $opts   = shift;
    my $distro = shift;

    print "+++++ remove_bootloader_files\n" if ( $opts->{debug} > 1 );


    my $dh = &baxml_distro_gethash( $opts, $distro );
    my $bh = $dh->{basehash};
    my $basedist = $dh->{basedist};

    if ( &sqlfs_getstate( $opts, "linux.$basedist" ) ) {
        &sqlfs_remove( $opts, "linux.$basedist" );
    }
    if ( &sqlfs_getstate( $opts, "initrd.$basedist" ) ) {
        &sqlfs_remove( $opts, "initrd.$basedist" );
    }

}

################################################################################
# networking service handling

# add line or config file for build and restart service (only if neeeded)
sub add_build_service
{
    my $opts   = shift;
    my $distro = shift;
    my $addons = shift;
    my $sharetype = $baVar{sharetype};

    my $dh = &baxml_distro_gethash( $opts, $distro );

    my $dbh = $opts->{dbh};

    my $sql;
    my $sth;

    print "+++++ add_build_service\n" if ( $opts->{debug} > 1 );

    $opts->{LASTERROR} = "";

    my $ret = 0;
    my @dalist;

    push @dalist, $distro if $distro;
    push @dalist, split( /\s+/, $addons) if ( $addons );

    my $dbref = &get_db_source_entry( $opts, $dalist[0] );
    if ( defined $dbref ) {
        $sharetype = $dbref->{sharetype};
    } else {
        if ( $dh->{'sharetype'} ) {
            $sharetype = $dh->{'sharetype'};
        }
    }

    print "Calling routine to configure $sharetype\n" if $opts->{verbose};

    # unlike http or cifs we pre-load nfs so we can manipulate
    if ($sharetype eq "nfs") {
        &start_iff_needed_service( $opts, $sharetype );
    }

    my $restartservice = 0;
    foreach my $da ( @dalist ) {

        foreach my $prod ( &baxml_products_getlist( $opts, $da ) ) {

            my ($file, $share, $state) =
                &check_service_product( $opts, $da, $prod, $sharetype );

            $share = $dh->{'distpath'}."/".$dh->{'sharepath'} if defined ( $dh->{'sharepath'} );

            if ( $state ) {
                print "$sharetype file $file found added for $da\n" if $opts->{verbose};
            }
            else {
                print "modifying $file adding $share\n" if ( $opts->{debug} );

                if ($sharetype eq "nfs") {
                    $ret = system("exportfs -o ro,root_squash,insecure,sync,no_subtree_check *:$share");
                    print "exportfs -o ro,root_squash,insecure,sync,no_subtree_check *:$share\n" if ( $opts->{debug} > 1 );
                    if ( $ret > 0 ) {
                        $opts->{LASTERROR} .= "export failed: $share $!";
                        next;
                    }
                }

                if ($sharetype eq "http") {
                    $restartservice = 1;
                    open(FILE, "<$baDir{'data'}/templates/inst_server.conf.in") or
                        die ("Cannot open file\n");
                    my $httpdconf = join '', <FILE>;
                    close(FILE);

                    unless ( -d "/etc/apache2/conf.d/") {
                        mkpath "/etc/apache2/conf.d/" || die ("Cannot create directory\n");
                    }

                    open(FILE, ">$file") || die ("Cannot open $file\n");
                    $httpdconf =~ s|%OS%|$da|g;
                    $httpdconf =~ s|%ALIAS%|/install/$da/|g;
                    $httpdconf =~ s|%SERVERDIR%|$share/|g;
                    print FILE $httpdconf;
                    close(FILE);

                }

                if ($sharetype eq "cifs") {
                    $restartservice = 1;
                    open(FILE, "<$baDir{'data'}/templates/samba.conf.in") or
                        die ("Cannot open file\n");
                    my $sambaconf = join '', <FILE>;
                    close(FILE);

                    unless ( -d "/etc/samba/" ) {
                        mkpath "/etc/samba/" || die ("Cannot create directory\n");
                    }

                    open(FILE, ">$file") || die ("Cannot open $file\n");
                    $sambaconf =~ s|%DISTRO%|$distro|g;
                    $sambaconf =~ s|%PATH%|$share|g;
                    print FILE $sambaconf;
                    close(FILE);

                    open(SAMBA, ">>/etc/samba/smb.conf") || die ("Cannot open $file\n");
                    print SAMBA "\ninclude = $file\n";
                    close(SAMBA);

                }
            }
        }
    }
    if ( $restartservice ) {
        # clever enough to reload if possible
        enable_service( $opts, $sharetype );
    }
    return 1 if ($opts->{LASTERROR} ne "");
    return 0;
}

# add line or config file for build and restart service (only if neeeded)
sub remove_build_service
{
    my $opts   = shift;
    my $distro = shift;
    my $addons = shift;
    my $sharetype = $baVar{sharetype};

    my $dh = &baxml_distro_gethash( $opts, $distro );

    my $dbh = $opts->{dbh};

    my $sql;
    my $sth;

    print "+++++ remove_build_service\n" if ( $opts->{debug} > 1 );

    $opts->{LASTERROR} = "";

    my $ret = 0;
    my @dalist;
    push @dalist, $distro if $distro;
    push @dalist, split( /\s+/, $addons) if ( $addons );

    my $dbref = &get_db_source_entry( $opts, $dalist[0] );
    if ( defined $dbref ) {
        $sharetype = $dbref->{sharetype};
    } else {
        if ( $dh->{'sharetype'} ) {
            $sharetype = $dh->{'sharetype'};
        }
    }

    # unlike http or cifs we pre-load nfs so we can manipulate
    if ($sharetype eq "nfs") {
        &start_iff_needed_service( $opts, $sharetype );
    }

    my $restartservice = 0;
    foreach my $da ( @dalist ) {

        foreach my $prod ( &baxml_products_getlist( $opts, $da ) ) {

            my ($file, $share, $state) =
                &check_service_product( $opts, $da, $prod, $sharetype );

            if ( not $state ) {
                print "$sharetype file $file found removed for $da\n" if $opts->{verbose};
            } else {
                print "modifying $file removing $share\n" if ( $opts->{debug} );
                if ($sharetype eq "nfs") {
                    $ret = system("exportfs -u *:$share");
                    if ( $ret > 0 ) {
                        $opts->{LASTERROR} .= "unexport failed: $share $!";
                        next;
                    }
                }

                if ($sharetype eq "http") {
                    $restartservice = 1;
                    unlink( $file );
                }

                if ($sharetype eq "cifs") {
                    $restartservice = 1;
                    unlink $file;
                    copy("/etc/samba/smb.conf", "/etc/samba/smb.conf.baback");
                    open(OUTFILE, ">/etc/samba/smb.conf") || die ("Cannot open file\n");
                    open(INFILE, "</etc/samba/smb.conf.baback") || die ("Cannot open file\n");
                    while (<INFILE>) {
                        unless (m|$distro|) {
                            print OUTFILE $_;
                        }
                    }
                    close(INFILE);
                    close(OUTFILE);
                    unlink("/etc/samba/smb.conf.baback");
                }
            }
        }
    }
    if ( $restartservice ) {
        # clever enought to reload if possible
        enable_service( $opts, $sharetype );
    }
    return 1 if ($opts->{LASTERROR} ne "");
    return 0;
}

sub init_mounter
{
    my $opts = shift;
    my @mount;
    my $ret = 0;
    my $iso_location_hashref = &get_iso_locations( $opts );

    my $sql = qq| SELECT mntpoint, iso
                  FROM $baTbls{'iso'}
                  WHERE is_loopback = 't'
               |;

    my $dbh = $opts->{dbh};
    my $sth;
    my $href;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute() );

    @mount = qx|mount| or die ("Can't get mount status: ".$!);

    while ( $href = $sth->fetchrow_hashref() ) {
        if ( ! -d $href->{'mntpoint'} ) {
            unless ( mkpath $href->{'mntpoint'} ) {
                $opts->{LASTERROR} .= "Unable to create directory: $href->{'mntpoint'} $!";
                next;
            }
        }
        my $is_mounted = 0;
        foreach ( @mount ) {
            if (/$href->{'mntpoint'}/) {
                print "Already mounted: $iso_location_hashref->{$href->{'iso'}}\n" if ( $opts->{verbose} );
                $is_mounted = 1;
            }
        }
        unless ( $is_mounted ) {
            if ( not defined $iso_location_hashref->{ $href->{'iso'} } ) {
                $opts->{LASTERROR} .= "Missing required iso: $href->{'iso'}\n";
            } else {
                print "Mounting $iso_location_hashref->{ $href->{'iso'} } at $href->{'mntpoint'} \n" if ( $opts->{verbose} );
                $ret = system("mount -o loop $iso_location_hashref->{ $href->{'iso'} } $href->{'mntpoint'}");
                if ( $ret > 0 ) {
                    $opts->{LASTERROR} .= "Mount failed for $href->{'mntpoint'}: $!";
                    next;
                }
            }
        }
    }
    return 1 if ( $opts->{LASTERROR} ne "" );
    return 0;
}

sub init_exporter
{
    my $opts = shift;
    my @mount;
    my $ret = 0;

#    $opts->{LASTERROR} = "";

    my $sql = qq| SELECT mntpoint
                  FROM $baTbls{'iso'}
                  WHERE sharetype = '1'
               |;

    my $dbh = $opts->{dbh};
    my $sth;
    my $href;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute() );

    $href = $sth->fetchrow_hashref();

    unless ( defined $href ) {
        # no NFS shares to share
        return 0;
    }
    # if here then have need nfs shares so make sure have nfsserver
    start_iff_needed_service( $opts, "nfs" );
    my @share = qx|showmount -e localhost|;
    unless ( scalar @share ) {
        $opts->{LASTERROR} = "Can't get share status: $!";
        return 1;
    }

    do {
        if ( ! -d $href->{'mntpoint'} ) {
            $opts->{LASTERROR} .= "Distro share point does not exist: $href->{'mntpoint'}: $!";
            next;
        }
        my $is_shared = 0;
        foreach( @share ) {
            if(/$href->{'mntpoint'}/){
                print "Already exported: $href->{'mntpoint'}\n" if ( $opts->{verbose} );
                $is_shared = 1;
            }
        }
        unless ( $is_shared ) {
            print "exporting $href->{'mntpoint'} \n" if ( $opts->{verbose} );
            $ret = system("exportfs -o ro,root_squash,insecure,sync,no_subtree_check *:$href->{'mntpoint'}");
            if ( $ret > 0 ) {
                $opts->{LASTERROR} .= "Export failed for $href->{'mntpoint'}: $!";
                next;
            }
        }
    } while ( $href = $sth->fetchrow_hashref() );
    return 1 if ( $opts->{LASTERROR} ne "" );
    return 0;
}

# return filename and state 0-missing 1-found for service config mods
sub check_service_product
{
    my $opts      = shift;
    my $distro    = shift;
    my $product   = shift;
    my $sharetype = shift;

    print "+++++ check_service_product\n" if ( $opts->{debug} > 1 );

    my ($shares, $name) = &get_distro_share( $opts, $distro );
    my $share = @$shares[0];

    my $file = "";
    my $state = 0;

    if ($sharetype eq "nfs") {
        $file = "nfs export";
        my @return = qx|showmount -e localhost| ;
        die("Can't get shares from showmount : $!") if ( $? != 0 );
        foreach(@return){
            $state = 1 if(/$share/);
        }
    }
    if ($sharetype eq "http") {
        $file = "/etc/apache2/conf.d/$name.conf";
        $state = 1 if ( -f $file);
    }
    if ($sharetype eq "cifs") {
        $file = "/etc/samba/$name.conf";
        $state = 1 if ( -f $file);
    }
    return $file, $share, $state;
}

sub enable_service
{
    my $opts      = shift;
    my $sharetype = shift;

    print "+++++ enable_service\n" if ( $opts->{debug} > 1 );

    $sharetype =~ s/cifs/smb/;
    $sharetype =~ s/http/apache2/;
    $sharetype =~ s/^nfs$/nfsserver/;
    system("chkconfig $sharetype on >& /dev/null");
    if ( check_service( $opts, $sharetype ) == 0 ) {
        # could have also done this to avoid nfs reload
        # need avoidance check here anyway... else bad
        if ( $sharetype !~ m/(nfs|nfsserver)/ ) {
            print "Reloading $sharetype ... \n" if $opts->{verbose};
            system("/etc/init.d/$sharetype reload");
        }
    } else {
        print "Starting $sharetype ... \n" if $opts->{verbose};
        system("/etc/init.d/$sharetype start");
    }
}

sub disable_service
{
    my $opts      = shift;
    my $sharetype = shift;

    print "+++++ disable_service\n" if ( $opts->{debug} > 1 );

    ## Disable service
    ##
    if ($opts->{verbose}) {
        print "Disabling $sharetype ... \n";
    }
    $sharetype =~ s/cifs/smb/;
    $sharetype =~ s/http/apache2/;
    $sharetype =~ s/^nfs$/nfsserver/;
    system("chkconfig $sharetype off >& /dev/null");
    if ( check_service( $opts, $sharetype) == 0 ) {
        system("/etc/init.d/$sharetype stop");
    }
}

# status returns 0 if enabled
sub check_service
{
    my $opts      = shift;
    my $sharetype = shift;

    print "+++++ check_service\n" if ( $opts->{debug} > 1 );

    $sharetype =~ s/cifs/smb/;
    $sharetype =~ s/http/apache2/;
    $sharetype =~ s/^nfs$/nfsserver/;
    qx(/etc/init.d/$sharetype status >& /dev/null);
    return $?;
}

sub start_iff_needed_service
{
    my $opts      = shift;
    my $sharetype = shift;

    print "+++++ start_iff_needed_service\n" if ( $opts->{debug} > 1 );


    $sharetype =~ s/cifs/smb/;
    $sharetype =~ s/http/apache2/;
    $sharetype =~ s/^nfs$/nfsserver/;
    if ( check_service( $opts, $sharetype ) != 0 ) {
        print "Starting $sharetype ... \n" if $opts->{verbose};
        system("/etc/init.d/$sharetype start");
    }
}

###########################################################################
# distro_cfg - basource state relation

sub source_register
{
    my $opts    = shift;
    my $command = shift;
    my $distro  = shift;
    my $addons  = shift;
    my $sharetype = $baVar{sharetype};

    print "+++++ source_register\n" if ( $opts->{debug} > 1 );

    print "setting uid to $opts->{dbrole}\n" if ($opts->{debug} > 2);
    my $uid = BaracusDB::su_user( $opts->{dbrole} );

    my $dbh = $opts->{dbh};

    if ($command eq "add") {

        my @dalist;

        push @dalist, $distro if $distro;
        push @dalist, split( /\s+/, $addons) if ( $addons );

        foreach my $da ( @dalist ) {
            print "Updating registration: add $da\n";
            my $dbref = &get_db_source_entry( $opts, $da );
            unless ( defined $dbref->{distroid} and
                     ( $dbref->{distroid} eq $da ) and
                     defined $dbref->{staus} and
                     ( $dbref->{staus} != BA_REMOVED ) ) {
                &add_db_source_entry( $opts, $da );
            }
        }
    }

    elsif ($command eq "remove") {

        print "Updating registration: remove $distro\n";

        my $sql = qq|UPDATE $baTbls{ distro }
                    SET change=CURRENT_TIMESTAMP(0),
                        sharetype=?,
                        shareip=?,
                        status=?
                    WHERE distroid=?|;

        my $isosql = qq|DELETE from $baTbls{ 'iso' }
                        WHERE distroid=?|;

        my $sth = $dbh->prepare( $sql )
            or die "Cannot prepare sth: ",$dbh->errstr;

        my $sthiso = $dbh->prepare( $isosql )
            or die "Cannot prepare sth: ",$dbh->errstr;

        my @dalist;

        push @dalist, $distro if $distro;
        push @dalist, split( /\s+/, $addons) if ( $addons );

        foreach my $da ( @dalist ) {
            my $dh = &baxml_distro_gethash( $opts, $da );
            if ( $dh->{'sharetype'} ) {
                $sharetype = $dh->{'sharetype'};
            }

            $sth->execute( $sharetype, $baVar{shareip}, BA_REMOVED, $da )
                or die "Cannot execute sth: ", $sth->errstr;

            $sthiso->execute( $da )
                or die "Cannot execute sth: ", $sthiso->errstr;
        }

    }

    elsif ($command eq "disable") {

        print "Updating registration: disable $distro\n";

        my $sql = qq|UPDATE $baTbls{ distro }
                     SET change=CURRENT_TIMESTAMP(0),
                         status=?
                     WHERE distroid=?|;

        my $sth = $dbh->prepare( $sql )
            or die "Cannot prepare sth: ",$dbh->errstr;

        $sth->execute( BA_DISABLED, $distro )
            or die "Cannot execute sth: ", $sth->errstr;

    }

    elsif ($command eq "enable") {

        print "Updating registration: enable $distro\n";

        my $sql = qq|UPDATE $baTbls{ distro }
                     SET change=CURRENT_TIMESTAMP(0),
                         status=?
                     WHERE distroid=?|;

        my $sth = $dbh->prepare( $sql )
            or die "Cannot prepare sth: ",$dbh->errstr;

        $sth->execute( BA_ENABLED, $distro )
            or die "Cannot execute sth: ", $sth->errstr;

    }

    else {
        $opts->{LASTERROR} = "Incorrect subcommand passed for source register\n";
        return 1;
    }

    print "setting uid back to $uid\n" if ($opts->{debug} > 2);
    $> = $uid;

    return 0;
}

sub get_loopback
{
    my $opts  = shift;
    my $share = shift;
    my $dbh = $opts->{dbh};

    my $sql = qq|SELECT is_loopback
                 FROM $baTbls{'iso'}
                 WHERE mntpoint = ?
                |;

    my $sth;
    my $href;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( $share ) );

    $href = $sth->fetchrow_hashref();

    $sth->finish;

    return $href->{'is_loopback'};
}

sub get_enabled_distro_list
{
    my $opts  = shift;
    my $status  = "3"; ## enabled
    my @distros = "";
    my $dbh = $opts->{dbh};

    my $sql = qq|SELECT distroid
                 FROM $baTbls{'distro'}
                 WHERE status = ?
                |;

    my $sth;
    my $href;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( $status ) );

    while ( my $distro = $sth->fetchrow_array() ) {
        push @distros, $distro;
    }

    $sth->finish;

    return @distros;
}

sub get_sharetype
{
    my $opts = shift;
    my $distro = shift;
    my $dbh = $opts->{dbh};

    my $sql = qq| SELECT sharetype
                  FROM $baTbls{'distro'}
                  WHERE distroid = '$distro'
               |;

    my $sth;
    my $href;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    $href = $sth->fetchrow_hashref();

    $sth->finish;

    return $href->{'sharetype'};
}

sub get_distro_sdk
{
    my $opts   = shift;
    my $distro = shift;

    my $dh = &baxml_distro_gethash( $opts, $distro );
    unless ( defined $dh->{basedisthash}->{addons} ) {
        return undef;
    }

    my @addons = @{$dh->{basedisthash}->{addons}};

    foreach my $addon ( @addons ) {
        return $addon if ($addon =~ /\-sdk\-/);
        return $addon if ($addon =~ /\-nonoss\-/);
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

    if ( $distro =~ /sles-9/ ) {
        my $dh = &baxml_distro_gethash( $opts, $distro );
        $share = $dh->{basedisthash}->{distpath};
        $name  = "$dh->{basedist}_server";
    } else {
        my @prods = &baxml_products_getlist( $opts, $distro );
        if ( scalar @prods > 1 ) {
            die "get_distro_share: Unsure how to handle multiple product distro $distro\n";
        }
        foreach my $isofile ( &baxml_isos_getlist( $opts, $distro, $prods[0] ) ) {
            my $ih = &baxml_iso_gethash( $opts, $distro, $prods[0], $isofile );
            push @shares, $ih->{'isopath'};
        }
      #  my $ph = &baxml_product_gethash( $opts, $distro, $prods[0] );
      #  $share = $ph->{prodpath};
        $name = "$distro-$prods[0]_server";
    }
    print "get_distro_share: returning share @shares and name $name\n" if $opts->{debug};
    return (\@shares, $name);
}

sub list_installed_addons
{
    my $opts   = shift;
    my $distro = shift;
    my @list;

    my $dh = &baxml_distro_gethash( $opts, $distro );
    my $bh = $dh->{basedisthash};
    my $base = $dh->{basedist};

    foreach my $dist ( @{$bh->{addons}} ) {
        print "is distro $base addon $dist 'added' ? " if $opts->{debug};
        my $dbref = &get_db_source_entry( $opts, $dist );
        if ( defined $dbref and defined $dbref->{status} and
             ( $dbref->{distroid} eq $dist ) and
             ( $dbref->{status} != BA_REMOVED ) ) {
            print "YES\n" if $opts->{debug};
            push @list, $dist;
        } else {
            print "NO\n" if $opts->{debug};
        }
    }
    return @list;
}
 
sub check_either
{
    my $opts   = shift;
    my $distro = shift;

    unless ( $distro ) {
        print "\nMissing arg: <distro>\n";
        &help();
    }

    unless ( &baxml_distro_gethash( $opts, $distro ) ) {
        print "Unknown distribution or addon specified: $distro\n";
        print "Please use one of the following:\n";
        foreach my $dist ( reverse sort &baxml_distros_getlist( $opts ) ) {
            my $href = &baxml_distro_gethash( $opts, $dist );
            print "\t" . $dist . "\n" unless ( $href->{requires} );
        }
        exit 1;
    }
}

sub check_distro
{
    my $opts   = shift;
    my $distro = shift;

    unless ( $distro ) {
        print "\nMissing arg: <distro>\n";
        &help();
    }

    my $dh = &baxml_distro_gethash( $opts, $distro );

    unless ( $dh ) {
        print "Unknown distribution specified: $distro\n";
        print "Please use one of the following:\n";
        foreach my $dist ( reverse sort &baxml_distros_getlist( $opts ) ) {
            my $href = &baxml_distro_gethash( $opts, $dist );
            print "\t" . $dist . "\n" unless ( $href->{requires} );
        }
        exit 1;
    }

    if ( $dh->{requires} ) {
        print "Non-base distribution passed as base $distro\n";
        print "Perhaps try:\n\t\t--distro $dh->{basedist} --addon $distro\n";
        exit 1;
    }
}

sub check_addons
{
    my $opts   = shift;
    my $distro = shift;
    my $addons = shift;

    my $dh = &baxml_distro_gethash( $opts, $distro );

    # verify all addons passed are intended for given distro as base
    foreach my $addon ( split /\s+/, $addons ) {

        &check_addon( $opts, $addon );

        my $ah = &baxml_distro_gethash( $opts, $addon  );

        unless ( $ah->{basedisthash} eq $dh ) {
            print "Base passed $distro instead of $dh->{basedist} for $addon\n";
            print "Perhaps try\n\t\t--distro $ah->{basedist} --addon $addon\n";
            exit 1;
        }
    }
}

sub check_addon
{
    my $opts   = shift;
    my $addon  = shift;

    my $dh = &baxml_distro_gethash( $opts, $addon );

    unless ( $dh ) {
        print "Unknown addon specified: $addon\n";
        print "Please use one of the following:\n";
        foreach my $ao ( reverse sort &baxml_distros_getlist( $opts ) ) {
            my $ah = &baxml_distro_gethash( $opts, $ao );
            print "\t" . $ao . "\n" if ( $ah->{requires} );
        }
        exit 1;
    }

    unless ( defined $dh->{requires} ) {
        print "Base distro passed as value for --addon $addon\n";
        exit 1;
    }
}


1;

__END__

=head1 AUTHOR

Daniel Westervelt, E<lt>dwestervelt@novellE<gt>
David Bahi, E<lt>dbahi@novellE<gt>

=cut
