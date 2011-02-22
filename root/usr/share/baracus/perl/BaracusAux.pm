package BaracusAux;

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

use lib "/usr/share/baracus/perl";

use BaracusSql    qw( :subs :vars );
use BaracusState  qw( :vars :subs :states );
use BaracusCore   qw( :subs );
use BaracusConfig qw( :vars );
use BaracusStorage qw( :subs );

=pod

=head1 NAME

B<BaracusAux> - auxillary routines for db reading and manipulation

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
         subs   =>
         [qw(
                get_name_version

                get_distro
                get_hardware
                get_autobuild
                get_profile
                get_module

                get_version_or_enabled

                find_tftpfile
                delete_tftpfile

                load_profile
                load_storage
                load_distro
                load_addons
                load_hardware
                load_autobuild
                load_modules
                load_vars
                load_baracusconfig
                get_autobuild_expanded

                remove_sqlFS_files
                get_mandatory_modules

                check_enabled
                check_mandatory
                check_distros
                get_certs_hash
                check_cert
                cert_for_distro
                get_versions
                redundant_data
                find_helper

                add_db_data
                remove_db_data
                remove_db_data_by
                update_db_data
                get_db_data
                get_db_data_by

                check_broadcast
            )],
         );
    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

###########################################################################

sub get_name_version
{
    my $compound = shift;
    my ($ver, $name);

    # expected format is name:ver if :ver present at all

    if ( $compound =~ m/:/ ) {
        ( $name, $ver ) = split ( ':', $compound, 2 );
    } else {
        $ver = 0;
        $name = $compound;
    }
    return ( $name, $ver );
}

sub get_distro() {
    my $type = "distro";

    my $opts = shift;
    my $dbh  = shift;
    my $aref = shift;

    my $name = $aref->{$type};

    my $sql = qq|SELECT * FROM $baTbls{$type} WHERE $baTblId{$type} = '$name'|;
    my $sth;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute(  ) );

    return $sth->fetchrow_hashref( );
}

sub get_hardware() {
    my $type = "hardware";

    my $opts = shift;
    my $dbh  = shift;
    my $aref = shift;
    my $vers = shift;

    my $name = $aref->{$type};

    return get_version_or_enabled( $opts, $dbh, $type, $name, $vers );
}

sub get_autobuild() {
    my $type = "autobuild";

    my $opts = shift;
    my $dbh  = shift;
    my $aref = shift;
    my $vers = shift;

    my $name = $aref->{$type};

    return get_version_or_enabled( $opts, $dbh, $type, $name, $vers );
}

sub get_profile() {
    my $type = "profile";

    my $opts = shift;
    my $dbh  = shift;
    my $aref = shift;
    my $vers = shift;

    my $name = $aref->{$type};

    return get_version_or_enabled( $opts, $dbh, $type, $name, $vers );
}

sub get_module() {
    my $type = "module";

    my $opts = shift;
    my $dbh  = shift;
    my $aref = shift;
    my $vers = shift;

    my $name = $aref->{$type};

    return get_version_or_enabled( $opts, $dbh, $type, $name, $vers );
}

sub get_version_or_enabled
{
    my $opts = shift;
    my $dbh  = shift;
    my $type = shift;
    my $name = shift;
    my $vers = shift;

    return undef unless ( defined $name );

    $vers = 0 unless ( defined $vers );

    my ($vref, $href, $eref) = &get_versions( $opts, $dbh, $type, $name, $vers);
    return undef unless ( defined $vref or defined $href or defined $eref );

    # if no highest version found - no entry at all was found
    unless ( defined $href ) {
        $opts->{LASTERROR} = "Unable to find $type entry for $name.\n";
        return undef;
    }

    # if vers passed we want a matching vref
    if ( $vers > 0 and not defined $vref ) {
        $opts->{LASTERROR} = "Unable to find *version* ($vers) $type entry for $name\n";
        return undef;
    }

    # if no vers passed we want the enabled eref
    if ( $vers == 0 and not defined $eref ) {
        die "Unable to find *enabled* $type entry for $name.\n";
        return undef;
    }

    return $vref if ( $vers > 0 );

    return $eref;
}


# with chunking this is only good for non-data
# fetch of name for checking if already exists
sub find_tftpfile() {
    my $type = "file";

    my $opts     = shift;
    my $tftph    = shift;
    my $filename = shift;

    my $sql = qq|SELECT COUNT(id) as count, name FROM $baTbls{$type} WHERE name = '$filename' GROUP BY name|;
    my $sth;

    die "$!\n$tftph->errstr" unless ( $sth = $tftph->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref( );
}

sub delete_tftpfile() {
    my $type = "file";

    my $opts     = shift;
    my $tftph    = shift;
    my $filename = shift;

    my $sql = qq|DELETE FROM $baTbls{$type} WHERE name = '$filename'|;
    my $sth;

    die "$!\n$tftph->errstr" unless ( $sth = $tftph->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    $sth->finish();
}


sub load_profile
{
    use Config::General;

    my $type = "profile";

    my $opts = shift;
    my $dbh  = shift;
    my $aref = shift;

    my $name = $aref->{$type};
    my $vers = $aref->{"${type}_ver"};

    my $found = get_version_or_enabled( $opts, $dbh, $type, $name, $vers );
    return 1 unless ( defined $found );
    print $found . "\n" if ( $opts->{debug} > 1 );

    # getall is a destructive assignment - so use tmp
    my $conf = new Config::General( -String => $found->{'data'} );
    my %tmpHash = $conf->getall;
    my $tmphref = \%tmpHash;

    while ( my ($key, $value) = each ( %$tmphref ) ) {
        if (ref($value) eq "ARRAY") {
            print "$key has more than one entry or value specified\n";
            print "Such ARRAYs are not supported.\n";
            exit(1);
            #           foreach my $avalue (@{$aref->{$key}}){
            #               print "$avalue\n";
            #           }
            next;
        }
        if (defined $value) {
            $aref->{$key} = $value;
        } else {
            $aref->{$key} = "";
        }
        print "profile: $key => $aref->{$key}\n" if ( $opts->{debug} > 1 );
    }

    # record the version from the entry for storage
    $aref->{profile_ver} = $found->{version};

    return 0;
}

sub load_storage
{
    my $opts = shift;
    my $dbh  = shift;
    my $aref = shift;

    my $found = &get_db_data( $dbh, 'storage', $aref->{storageid} );
    unless ( defined $found ) {
        $opts->{LASTERROR} = "Unable to find storage entry for $aref->{storageid}\n";
        return 1;
    }
    print $found . "\n" if ( $opts->{debug} > 1 );

    while ( my ($key, $value) = each( %$found ) ) {
        if (defined $value) {
            $aref->{$key} = $value;
        } else {
            $aref->{$key} = "";
        }
        print "storage: $key => $aref->{$key}\n" if ( $opts->{debug} > 1 );
    }

    # hash special cases
    $aref->{storageuri} = &get_db_storage_uri( $dbh, $aref->{storageid} );
    delete $aref->{username};
    delete $aref->{passwd};

    return 0;
}

sub load_distro
{
    my $opts = shift;
    my $dbh  = shift;
    my $aref = shift;

    my $found = &get_distro( $opts, $dbh, $aref );
    unless ( defined $found ) {
        $opts->{LASTERROR} = "Unable to find distro entry for $aref->{distro}\n";
        return 1;
    }
    print $found . "\n" if ( $opts->{debug} > 1 );

    while ( my ($key, $value) = each( %$found ) ) {
        if (defined $value) {
            $aref->{$key} = $value;
        } else {
            $aref->{$key} = "";
        }
        print "distro: $key => $aref->{$key}\n" if ( $opts->{debug} > 1 );
    }

    return 0;
}

sub load_addons
{
    my $opts = shift;
    my $dbh  = shift;
    my $aref = shift;

    unless ( $aref->{addons} ) {
        $aref->{addon} = "";
        return 0;
    }

    my @addonlist;
    if ( $aref->{addons} =~ m/[,\s]+/ ) {
        @addonlist = split(/[,\s*]/, $aref->{addons});
    } else {
        push @addonlist, $aref->{addons};
    }

    # incorporate addons passed into 'addon' key for __ADDON__ autobuild sub
    $aref->{addon} = "";

    my $status = 0;
    $opts->{LASTERROR} = "";

    foreach my $name ( @addonlist ) {
        print "load_addons: working with $name\n" if ($opts->{debug} > 1);
        my $tref = { distro => "$name" };
        my $found = &get_distro( $opts, $dbh, $tref );
        if ( defined $found ) {
            my $addonbase = "$found->{os}-$found->{release}-$found->{arch}";
            if ( $aref->{distro} ne $addonbase ) {
                if ( $status == 0 ) {
                    $status = 1;
                }
                $opts->{LASTERROR} .= "addon $name is for $addonbase not the specified $aref->{distro}\n";
            } else {
                print $found . " addon\n" if ($opts->{debug} > 1);

                $aref->{addon} .= "\n" if ( $aref->{addon} );
                $aref->{addon} .="      <listentry>
        <media_url>$found->{sharetype}://$found->{shareip}$found->{basepath}</media_url>
        <product>$found->{distroid}</product>
        <product_dir>/</product_dir>\n";
                if ( ( $found->{os} eq "sles"
                       or $found->{os} eq "opensuse"
                      ) and $found->{release} >= 11.0 )
                {
                    $aref->{addon} .="        <ask_on_error config:type=\"boolean\">false</ask_on_error> <!-- available since openSUSE 11.0 -->
        <name>$found->{distroid}</name> <!-- available since openSUSE 11.1/SLES11 (bnc#433981) -->\n";
                }
                $aref->{addon} .="      </listentry>"
            }
        } elsif ( -d "$baDir{byum}/${name}" ) {
            print $found . " repo\n" if ($opts->{debug} > 1);
            # so we have a 'repo' with this name
            $aref->{addon} .= "\n" if ( $aref->{addon} );
            $aref->{addon} .="      <listentry>
        <media_url>http://$baVar{serverip}/${name}</media_url>
        <product>${name}</product>
        <product_dir>/</product_dir>\n";
            $aref->{addon} .="      </listentry>"
        } elsif ( $name =~ m%^(http|ftp)\:\/\/(([^/]+\/){1,4}).*% ) {
            print $found . " url\n" if ($opts->{debug} > 1);
            # so we have a 'URL'
            $aref->{addon} .= "\n" if ( $aref->{addon} );
            $aref->{addon} .="      <listentry>
        <media_url>${name}</media_url>
        <product>$2</product>
        <product_dir>/</product_dir>\n";
            $aref->{addon} .="      </listentry>"
        } else {
            $status = 1 if ( $status == 0 );
            $opts->{LASTERROR} = "Unable to find addon entry for $name\n";
        }
    }
    return $status;
}

sub load_hardware
{
    my $type = "hardware";

    my $opts = shift;
    my $dbh  = shift;
    my $aref = shift;

    my $name = $aref->{$type};
    my $vers = $aref->{"${type}_ver"};

    my $found = get_version_or_enabled( $opts, $dbh, $type, $name, $vers );
    return 1 unless ( defined $found );
    print $found . "\n" if ($opts->{debug} > 1);

    while ( my ($key, $value) = each( %$found ) ) {
        if (defined $value) {
            $aref->{$key} = $value;
        } else {
            $aref->{$key} = "";
        }
        print "hware: $key => $aref->{$key}\n" if ( $opts->{debug} > 1 );
    }

    # record the version from the entry for storage
    $aref->{hardware_ver} = $found->{version};

    return 0;
}

sub load_autobuild
{
    my $type = "autobuild";

    my $opts = shift;
    my $dbh  = shift;
    my $aref = shift;

    my $name = $aref->{$type};
    my $vers = $aref->{"${type}_ver"};

    print "load_autobuild name $name ver $vers\n" if ($opts->{debug} > 1);

    my $found = get_version_or_enabled( $opts, $dbh, $type, $name, $vers );
    return 1 unless ( defined $found );
    print $found . "\n" if ($opts->{debug} > 1);

    # record the version from the entry for storage
    $aref->{autobuild_ver} = $found->{version};

    return 0;
}

sub load_modules
{
    my $type = "module";

    my $opts = shift;
    my $dbh  = shift;
    my $aref = shift;

    my $sth;

    unless ($aref->{modules}) {
        $aref->{module} = "";
        return 0;
    }

    my @modulelist;
    if ( $aref->{modules} =~ m/[,\s]+/ ) {
        @modulelist = split(/[,\s*]/, $aref->{modules});
    } else {
        push @modulelist, $aref->{modules};
    }

    print "module list: " . join (", ", @modulelist) . "\n" if ( $opts->{debug} > 1 );

    # incorporate modules passed into 'module' key for __MODULE__ autobuild sub
    $aref->{'module'} = "";

#   $aref->{'module'} = "    <post-scripts config:type="list">\n";
    foreach my $item ( @modulelist ) {

        # get verison and name from possible compound
        my ( $name, $vers ) = get_name_version( $item );
        print "working $item : $name + $vers\n" if ( $opts->{debug} > 1 );

        my $found = get_version_or_enabled( $opts, $dbh, $type, $name, $vers );
        return 1 unless ( defined $found );
        print "found $item : $name + $found->{version}\n" if ( $opts->{debug} > 1 );
        print $found . "\n" if ( $opts->{debug} > 1 );

        # hum... this format is only SUSE family
        # what about post insatll scripts for other distros ???

        $aref->{'module'} .="<script>
        <filename>$found->{'moduleid'}</filename>
        <source><![CDATA[";
        $aref->{'module'} .= $found->{'data'};
        $aref->{'module'} .="]]>\n        </source>\n      </script>";
    }
#   $aref->{'module'} .= "\n    </post-scripts>"

    return 0;
}

sub load_vars
{
    my $opts = shift;
    my $aref = shift;

    if ($aref->{vars}) {
        my @varray = split(/[,\s*]/, $aref->{vars});
        foreach my $item (@varray) {
            (my $key, my $value) = split(/=/, $item);
            $aref->{$key} = $value;
        }
    }
    return 0;
}

sub load_baracusconfig
{
    my $opts = shift;
    my $aref = shift;
    my ( $key, $value );

    if ( %baVar) {
        while ( ( $key, $value ) = each %baVar )  {
            $aref->{$key} = $value;
        }
    }
    if ( %baDir) {
        while ( ( $key, $value ) = each %baDir )  {
            $aref->{$key} = $value;
        }
    }
    return 0;
}

sub get_autobuild_expanded
{
    use File::Temp qw/ tempdir /;

    my $opts = shift;
    my $dbh  = shift;
    my $aref = shift;

    my $name = $aref->{autobuild};
    my $vers = $aref->{autobuild_ver};

    print "get_autobuild_expanded name $name ver $vers\n" if ($opts->{debug} > 1);

    my $abhref = &get_autobuild( $opts, $dbh, $aref, $vers );

    unless ( defined $abhref && $abhref->{data} ne "" ) {
        $opts->{LASTERROR} .= "\nUnable to find autobuild template $aref->{autobuild}\n View available templates with 'baconfig list autobuild'\n";
        return undef;
    }

    # record the version from the entry for storage
    $aref->{autobuild_ver} = $abhref->{version};

    my $abfile  = $abhref->{data};
    my $date    = &get_rundate();

    while ( my ($key, $value) = each %$aref ) {
        $key =~ tr/a-z/A-Z/;
        $key = "__${key}__";
        $abfile =~ s/$key/$value/g;
    }

    # we do the search and replace again
    # to expand vars within __MODULE__ or other vars
    while ( my ($key, $value) = each %$aref ) {
        $key =~ tr/a-z/A-Z/;
        $key = "__${key}__";
        $abfile =~ s/$key/$value/g;
    }

    # comment block for suse and win xml template families
    my $cstart="<!--";
    my $cstop="-->";

    if ( $aref->{os} eq "rhel"   ||
         $aref->{os} eq "esx"    ||
         $aref->{os} eq "fedora" ||
         $aref->{os} eq "centos" ) {
        # comment block for rhel kickstart script families
        $cstart="#";
        $cstop="";
    }

    $abfile .= "$cstart baracus.Hostname: $aref->{'hostname'} $cstop\n";
    $abfile .= "$cstart baracus.MAC: $aref->{'mac'}; $cstop\n";
    $abfile .= "$cstart baracus.Generated: $date $cstop\n";

    if ( $abfile =~ m/__.*__/ ) {
        my $automac = $aref->{autobuild} . "-" . $aref->{autobuild_ver};
        my $tdir = tempdir( "baracus.XXXXXX", TMPDIR => 1, CLEANUP => 1 );
        print "using tempdir $tdir\n" if ($opts->{debug} > 1);
        open(FILE, ">$tdir/$automac") or
            die "Cannot open file $tdir/$automac: $!\n";
        print FILE $abfile;
        close(FILE);
        warn "generated but some vars still need to be replaced in $automac\n";
        system "grep -Ene '__.*__' $tdir/$automac";
        unlink "$tdir/$automac";
        print "removing tempdir $tdir\n" if ($opts->{debug} > 1);
        rmdir $tdir;
    }

    return $abfile;
}

sub remove_sqlFS_files
{
    my $opts    = shift;
    my $mac     = shift;
    my $dbtftp  = "sqltftp";

    my $lhref;
    my $deepdebug = $opts->{debug} > 2 ? 1 : 0;
    my $sqlfsOBJ = SqlFS->new( 'DataSource' => "DBI:Pg:dbname=$dbtftp;port=5162",
                               'User' => "baracus",
                               'debug' => $deepdebug )
        or die "Unable to create new instance of SqlFS\n";

    my $list =  $sqlfsOBJ->list_start( "${mac}" );
    while ( $lhref = $sqlfsOBJ->list_next( $list ) ) {
        $sqlfsOBJ->remove( $lhref->{name} );
        print "$lhref->{name} removed from file DB \n" if ( $opts->{debug} > 1 );
    }
    $sqlfsOBJ->list_finish( $list );

}


sub get_mandatory_modules
{
    my $type = "module";

    my $opts = shift;
    my $dbh  = shift;
    my $dist = shift;

    my @modarray;

    my $cert_href = &cert_for_distro( $opts, $dbh, $type, $dist );
    return undef unless ( defined $cert_href );

    while ( my ($key, $man) = each %$cert_href ) {
        push(@modarray, $key) if ( $man );
    }

    return $modarray[0] unless ( @modarray > 1 );
    return join ", ", @modarray;
}


# checks for presence of enabled version
#
# return value
#   undef on failure
#   zero if no enabled version was found
#   non-zero version number of enabled entry

sub check_enabled
{
    my $opts = shift;
    my $dbh  = shift;
    my $type = shift;
    my $id   = shift;

    my $sth;
    my $href;

    unless ( $type eq "hardware" or
             $type eq "module"   or
             $type eq "autobuild"
            )
    {
        die "Expected 'module', 'autobuild' or 'hardware'\n";
    }

    my $sql = qq| SELECT status, version
                  FROM $baTbls{ $type }
                  WHERE $baTblId{ $type } = '$id'
                  AND version >= 1
                 |;

    print $sql . "\n" if $opts->{debug};

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} =
            "Unable to prepare 'check_enabled' statement\n" . $dbh->errstr;
        return undef;
    }

    unless( $sth->execute( ) ) {
        $opts->{LASTERROR} =
            "Unable to execute 'check_enabled' statement\n" . $sth->err;
        return undef;
    }

    while ( $href = $sth->fetchrow_hashref( ) ) {
        if ( $href->{status} ) {
            return $href->{version};
        }
    }

    $sth->finish;
    undef $sth;

    return 0;
}


# checks for presence of mandatory module
#
# return value
#   undef on failure
#   zero if no mandatory certification was found
#   array ref of distroid for mandatory certs found

sub check_mandatory
{
    my $opts     = shift;
    my $dbh      = shift;
    my $moduleid = shift;

    my $sth;
    my $href;

    my $sql = qq| SELECT mandatory, distroid
                  FROM $baTbls{ modcert }
                  WHERE moduleid = '$moduleid'
                |;

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} =
            "Unable to prepare 'check_mandatory' statement\n" . $dbh->errstr;
        return undef;
    }

    unless( $sth->execute( ) ) {
        $opts->{LASTERROR} =
            "Unable to execute 'check_mandatory' statement\n" . $sth->err;
        return undef;
    }

    my @mancerts;
    while ( $href = $sth->fetchrow_hashref( ) ) {
        if ($href->{'mandatory'}) {
            push @mancerts, $href->{'distroid'}
        }
    }

    $sth->finish;
    undef $sth;

    return \@mancerts if ( scalar @mancerts > 0 );

    return 0;
}



# checks for distro usable for cert
#
# return value
#   undef on failure
#   count of distros passed that have problem
#   0 if all distros are ok to use with cert

sub check_distros
{
    my $opts  = shift;
    my $dbh   = shift;
    my $tftph = shift;
    my $certs = shift;

    my @certlist;
    if ( $certs =~ m/[,\s]+/ ) {
        @certlist = split(/[,\s*]/, $certs);
    } else {
        push @certlist, $certs;
    }

    my $cert_status = 0;

    foreach my $cert_in ( @certlist ) {
        my $findcount = &find_helper( $opts, $dbh, $tftph, "distro", $cert_in );
        unless ( defined $findcount ) {
            # &find call failed
            $opts->{LASTERROR} = "Failed in check_distros\n" . $opts->{LASTERROR};
            return undef;
        }
        unless ( $findcount ) {
            print "Unable to certify: $cert_in does not exist\n";
            $cert_status = 1;
            next;
        }
    }

    return $cert_status;
}


# checks for distro cert
#
# return value
#   undef on failure
#   hash ref of distros associated with id if any found
#     hash has key of distroid and value of mandatory_flag

sub get_certs_hash
{
    my $opts = shift;
    my $dbh  = shift;
    my $type = shift;
    my $name = shift;

    my %cert_hash;

    my $sth;
    my $href;
    my $sql;

    return \%cert_hash if ( not defined $name or $name eq "" );

    if ( $type eq "hardware" ) {
        $sql = qq| SELECT distroid
                   FROM $baTblCert{ $type }
                   WHERE $baTblId{ $type } = '$name'
                 |;
    } elsif ( $type eq "module" ) {
        $sql = qq| SELECT distroid, mandatory
                   FROM $baTblCert{ $type }
                   WHERE $baTblId{ $type } = '$name'
                 |;
    } elsif ( $type eq "autobuild" ) {
        $sql = qq| SELECT distroid
                   FROM $baTblCert{ $type }
                   WHERE $baTblId{ $type } = '$name'
                 |;
    } else {
        die "Expected 'module', 'autobuild' or 'hardware'\n";
    }

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} =
            "Unable to prepare 'get_certs_hash' statement\n" . $dbh->errstr;
        return undef;
    }

    unless( $sth->execute( ) ) {
        $opts->{LASTERROR} =
            "Unable to execute 'get_certs_hash' statement\n" . $sth->err;
        return undef;
    }

    while ( $href = $sth->fetchrow_hashref( ) ) {
        # the fact that the distro is a key means
        # this type is certified for this distro
        if ( defined $href->{mandatory} ) {
            $cert_hash{ $href->{'distroid'} }= $href->{mandatory};
        } else {
            $cert_hash{ $href->{'distroid'} }= 0;
        }
    }

    $sth->finish;
    undef $sth;

    return \%cert_hash;
}


sub check_cert
{
    my $opts = shift;
    my $dbh  = shift;
    my $dist = shift;
    my $type = shift;
    my $list = shift;  # this is a string not an array - w.s. seperated values

    my $cert_hash;

    my $status = 0;
    $opts->{LASTERROR} = "";

    my @listtocheck;
    if ( $list =~ m/[,\s]+/ ) {
        @listtocheck = split(/[,\s*]/, $list);
    } else {
        push @listtocheck, $list;
    }

    foreach my $item (@listtocheck) {

        # we don't care about version here but
        # make sure we strip it if it was specified
        my ( $name, $ver ) = get_name_version( $item );

        # not the most efficient call for this - but
        # code reuse overrides efficiency
        # at this level of perf impact for sure
        $cert_hash = get_certs_hash( $opts, $dbh, $type, $name );

        if ( defined $cert_hash and defined $cert_hash->{ $dist } ) {
            print "$type $item is certified for $dist\n" if $opts->{debug};
        } else {
            if ( $status == 0 ) {
                $status = 1;
                $opts->{LASTERROR} = "$type not certified for use with $dist\nconfirm you want to use these in combination and then do:\n";
            }
            $opts->{LASTERROR} .= "   baconfig update $type --name $item --addcert $dist\n"
        }
    }
    return $status;
}


# checks for all of a flavor certivied for given distro
#
# return value
#   undef on failure
#   hash ref of flavor items associated with distro if any found
#     hash has key of id and value of mandatory_flag

sub cert_for_distro
{
    my $opts = shift;
    my $dbh  = shift;
    my $type = shift;
    my $dist = shift;

    my $sth;
    my $href;
    my $sql;

    if ( $type eq "hardware" ) {
        $sql = qq| SELECT hardwareid AS name
                   FROM $baTbls{ "hwcert" }
                   WHERE distroid = '$dist'
                 |;
    } elsif ( $type eq "module" ) {
        $sql = qq| SELECT moduleid AS name, mandatory
                   FROM $baTbls{ modcert }
                   WHERE distroid = '$dist'
                 |;
    } elsif ( $type eq "autobuild" ) {
        $sql = qq| SELECT autobuildid AS name
                   FROM $baTbls{ abcert }
                   WHERE distroid = '$dist'
                 |;
    }

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} =
            "Unable to prepare 'cert_for_distro' statement\n" . $dbh->errstr;
        return undef;
    }

    unless( $sth->execute( ) ) {
        $opts->{LASTERROR} =
            "Unable to execute 'cert_for_distro' statement\n" . $sth->err;
        return undef;
    }

    my %cert_hash;
    while ( $href = $sth->fetchrow_hashref( ) ) {
        if ( defined $href->{mandatory} ) {
            $cert_hash{ $href->{name} }= $href->{mandatory};
        } else {
            $cert_hash{ $href->{name} }= 0;
        }
    }

    $sth->finish;
    undef $sth;

    return \%cert_hash;
}


# get_versions
#
# args: type (module, hardware, profile, file), $name, $version
# ret:  hash to entries found to specified, highest, enabled versions on match
#         or undef on error

sub get_versions
{
    my $opts = shift;
    my $dbh  = shift;
    my $type = shift;
    my $name = shift;
    my $vers = shift;

    my $version_href;
    my $highest_href;
    my $enabled_href;

    $vers = 0 unless ( defined $vers );

    unless ( $type eq "hardware" or
             $type eq "module"   or
             $type eq "profile"  or
             $type eq "autobuild"
            )
    {
        die "Expected 'module', 'profile', 'autobuild' or 'hardware'\n";
    }

    my $sql_cols = lc get_cols( $baTbls{ $type } );
    my $sql = qq| SELECT $sql_cols FROM $baTbls{ $type } WHERE $baTblId{ $type } = '$name' ORDER BY version|;


    my $sth;
    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} = "Unable to prepare 'get_entry' statement\n" . $dbh->errstr;
        return ( undef, undef, undef );
    }

    unless( $sth->execute() ) {
        $opts->{LASTERROR} = "Unable to execute 'get_entry' statement\n" . $sth->err;
        return ( undef, undef, undef );
    }

    my $href;
    while ( $href = $sth->fetchrow_hashref( ) ) {
        $version_href = $href if ( $href->{'version'} == $vers);
        $highest_href = $href;
        $enabled_href = $href if ( $href->{'status'} == 1 );
    }

    $sth->finish;
    undef $sth;

    $opts->{LASTERROR} = "Unable to find $type entry for $name\n"
        unless ( defined $version_href or
                 defined $highest_href or
                 defined $enabled_href );

    return ( $version_href, $highest_href, $enabled_href );
}

#
# add_db_data( $dbh, $tbl, $hashref )
#

sub add_db_data
{
    my $dbh     = shift;
    my $tbl     = shift;
    my $hashref = shift;
    my %Hash    = %{$hashref};

    my $fields = lc get_cols( $baTbls{ $tbl  } );
    $fields =~ s/[ \t]*//g;
    my @fields = split( /,/, $fields );
    my $values = join(', ', (map { $dbh->quote($_) } @Hash{@fields}));

    my $sql = qq|INSERT INTO $baTbls{ $tbl } ( $fields ) VALUES ( $values )|;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish;
    undef $sth;
}

#
# remove_db_data( $dbh, $tbl, $id )
#

sub remove_db_data
{
    my $dbh = shift;
    my $tbl = shift;
    my $id = shift;

    my $index;
    my $caller = &whocalled;
    if ( $caller =~ m/remove_db_data_by/ ) {
        $index = shift;
    } else {
        $index = $baTblId{ $tbl };
    }

    my $sql = qq|DELETE FROM $baTbls{ $tbl } WHERE $index = '$id'|;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish();
    undef $sth;
}

#
# update_db_data( $dbh, $tbl, $hashref )
#

sub update_db_data
{
    my $dbh     = shift;
    my $tbl     = shift;
    my $hashref = shift;
    my %Hash    = %{$hashref};

    my $fields = lc get_cols( $baTbls{ $tbl } );
    $fields =~ s/[ \t]*//g;
    my @fields;

    foreach my $field ( split( /,/, $fields ) ) {
        next if ( $field eq $baTblId{ $tbl } );  # skip key
        next if ( $field eq "creation" );  # skip creation col
        $Hash{ $field } = "now()" if ( $field eq "change" ); # add update time
        push @fields, $field;
    }
    $fields = join(', ', @fields);
    my $values = join(', ', (map { $dbh->quote($_) } @Hash{@fields}));

    my $sql = qq|UPDATE $baTbls{ $tbl }
                SET ( $fields ) = ( $values )
                WHERE $baTblId{ $tbl } = '$hashref->{ $baTblId{ $tbl } }' |;

    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
}

#
# get_db_data( $dbh, $tbl, $id );
#

sub get_db_data
{
    my $dbh = shift;
    my $tbl = shift;
    my $id  = shift;

    my $index;
    my $caller = &whocalled;
    if ( $caller =~ m/get_db_data_by/ ) {
        $index = shift;
    } else {
        $index = $baTblId{ $tbl };
    }

   # my $sql = qq|SELECT * FROM $baTbls{ $tbl } WHERE $baTblId{ $tbl } = '$id' |;
    my $sql = qq|SELECT * FROM $baTbls{ $tbl } WHERE $index = '$id' |;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref();
}

#
# get_db_data_by( $dbh, $tbl, $id, $index );
#

sub get_db_data_by
{
    my $dbh   = shift;
    my $tbl   = shift;
    my $id    = shift;
    my $index = shift;
    
    my $href = &get_db_data( $dbh, $tbl, $id, $index);

    return $href;
}

#
# remove_db_data_by( $dbh, $tbl, $id, $index );
#

sub remove_db_data_by
{
    my $dbh   = shift;
    my $tbl   = shift;
    my $id    = shift;
    my $index = shift;

    &remove_db_data( $dbh, $tbl, $id, $index );
}


# rendundant_data
#
#   when possibly adding a new version we make sure that the
#   'data' is not already pressent in another entry. if it is
#   return 1 - with LASTERROR of the version already present.

sub redundant_data
{
    my $opts = shift;
    my $dbh  = shift;
    my $type = shift;
    my $name = shift;
    my $data = shift;

    my $sth;
    my $href;

    print "args type: $type name: $name\n" if ( $opts->{debug} );

    unless ( $type eq "hardware" or
             $type eq "module"   or
             $type eq "profile"  or
             $type eq "autobuild"
            )
    {
        die "Expected 'module', 'profile', 'autobuild' or 'hardware'\n";
    }

    my $sql_cols = lc get_cols( $baTbls{ $type } );
    my $sql = qq| SELECT $sql_cols FROM $baTbls{ $type } WHERE $baTblId{ $type } = '$name' ORDER BY version;|;

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} =
            "Unable to prepare 'redundant_data' statement\n" . $dbh->errstr;
        return 1;
    }

    unless( $sth->execute( ) ) {
        $opts->{LASTERROR} =
            "Unable to execute 'redundant_data' statement\n" . $sth->err;
        return 1;
    }

    while ( $href = $sth->fetchrow_hashref( ) ) {
        # hardware we compare values of params
        # other items are stored as files / blobs
        # so compared 'data' directly
        if (
            ( ( $type eq "hardware" ) and
              (
               ( $href->{'hwdriver'} eq $data->{'hwdriver'} ) and
               ( $href->{'bootargs'} eq $data->{'bootargs'} ) and
               ( $href->{'rootdisk'} eq $data->{'rootdisk'} ) and
               ( $href->{'rootpart'} eq $data->{'rootpart'} )
               )
             ) or
            ( ( $type ne "hardware" ) and ( $href->{'data'} eq $data ) )
            ) {
            $opts->{LASTERROR} =
                "Reject adding new version with content identical to this version: $href->{'version'}\n";
            return 1;
        }
    }

    $sth->finish;
    undef $sth;

    return 0;
}

# find - simple lookup to see if entry already exists
# return count of entries found or undef on error

sub find_helper
{
    my $opts  = shift;
    my $dbh   = shift;
    my $tftph = shift;
    my $type  = shift;
    my $name  = shift;

    my $sql;

    my $db2use = $dbh;

    if ( $type eq "hardware" ) {
        $sql = qq|SELECT hardwareid as name
                  FROM $baTbls{ $type }
                  WHERE hardwareid = '$name'
                 |;
    } elsif ( $type eq "module" ) {
        $sql = qq|SELECT moduleid as name
                  FROM $baTbls{ $type }
                  WHERE moduleid = '$name'
                 |;
    } elsif ( $type eq "profile" ) {
        $sql = qq|SELECT profileid as name
                  FROM $baTbls{ $type }
                  WHERE profileid = '$name'
                 |;
    } elsif ( $type eq "autobuild" ) {
        $sql = qq|SELECT autobuildid as name
                  FROM $baTbls{ $type }
                  WHERE autobuildid = '$name'
                 |;
    } elsif ( $type eq "file" ) {
        $sql = qq|SELECT name, id
                  FROM $baTbls{ $type }
                  WHERE name = '$name'
                  ORDER BY id
                 |;
        $db2use = $tftph;
    } elsif ( $type eq "distro" ) {
        $sql = qq|SELECT distroid as name
                  FROM $baTbls{ $type }
                  WHERE distroid = '$name'
                 |;
    }
    print $sql . "\n" if $opts->{debug};

    my $sth = $db2use->prepare( $sql );
    unless ( defined $sth ) {
        $opts->{LASTERROR} = "Unable to prepare 'find' $type statement\n" .
            $db2use->errstr;
        return undef;
    }

    unless( $sth->execute( ) ) {
        $opts->{LASTERROR} = "Unable to execute 'find' $type query" . $sth->err;
        return undef;
    }

    my $rowcount = 0;
    while ( $sth->fetchrow_hashref() ) {
        $rowcount += 1;
        print "rowcount +1 $rowcount\n" if $opts->{debug};
    }

    $sth->finish;
    undef $sth;

    return $rowcount;
}

sub check_broadcast
{
    my $opts = shift;
    my $aref = shift;

    # if not specified compute 'broadcast' from ip & netmask
    if (defined $aref->{ip} and $aref->{ip} ne "dhcp" and
        defined $aref->{netmask} and not defined $aref->{broadcast}) {
	use Net::Netmask;

	my $block = new Net::Netmask ( $aref->{ip}, $aref->{netmask} );
	print STDERR "Use broadcast address: " . $block->broadcast() . "\n" if ( $opts->{debug} > 1);
	$aref->{broadcast} = $block->broadcast();
    }
}

1;

__END__
