package Baracus::Aux;

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

use Dancer qw( :syntax );
use Dancer::Plugin::Database;

use Baracus::Sql    qw( :subs :vars );
use Baracus::State  qw( :vars :subs :states );
use Baracus::Core   qw( :subs );
use Baracus::Config qw( :subs :vars );
use Baracus::Storage qw( :subs );

=pod

=head1 NAME

B<Baracus::Aux> - auxillary routines for db reading and manipulation

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
                get_sysidcfg_expanded

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

                list_start_data
                list_next_data
                list_finish_data

                is_should_bigfile
                check_broadcast
                add_bigfile
                remove_bigfile
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
    my $aref = shift;

    my $name = $aref->{$type};

    my $href = undef;
    my $sql = qq|SELECT * FROM $baTbls{$type} WHERE $baTblId{$type} = '$name'|;

    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;
        $href = $sth->fetchrow_hashref();
        $sth->finish;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    return $href;
}

sub get_hardware() {
    my $type = "hardware";

    my $opts = shift;
    my $aref = shift;
    my $vers = shift;

    my $name = $aref->{$type};

    return get_version_or_enabled( $opts, $type, $name, $vers );
}

sub get_autobuild() {
    my $type = "autobuild";

    my $opts = shift;
    my $aref = shift;
    my $vers = shift;

    my $name = $aref->{$type};

    return get_version_or_enabled( $opts, $type, $name, $vers );
}

sub get_profile() {
    my $type = "profile";

    my $opts = shift;
    my $aref = shift;
    my $vers = shift;

    my $name = $aref->{$type};

    return get_version_or_enabled( $opts, $type, $name, $vers );
}

sub get_module() {
    my $type = "module";

    my $opts = shift;
    my $aref = shift;
    my $vers = shift;

    my $name = $aref->{$type};

    return get_version_or_enabled( $opts, $type, $name, $vers );
}

sub get_version_or_enabled
{
    my $opts = shift;
    my $type = shift;
    my $name = shift;
    my $vers = shift;

    return undef unless ( defined $name );

    $vers = 0 unless ( defined $vers );

    my ($vref, $href, $eref) = &get_versions( $opts, $type, $name, $vers);
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
    my $aref = shift;

    my $name = $aref->{$type};
    my $vers = $aref->{"${type}_ver"};

    my $found = get_version_or_enabled( $opts, $type, $name, $vers );
    return 1 unless ( defined $found );
#    print $found . "\n" if ( $opts->{debug} > 1 );

    # getall is a destructive assignment - so use tmp
    my $conf = new Config::General( -String => $found->{'data'} );
    my %tmpHash = $conf->getall;
    my $tmphref = \%tmpHash;

    while ( my ($key, $value) = each ( %$tmphref ) ) {
        if (ref($value) eq "ARRAY") {
            error "$key has more than one entry or value specified\n";
            error "Such ARRAYs are not supported.\n";
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
#        print "profile: $key => $aref->{$key}\n" if ( $opts->{debug} > 1 );
    }

    # record the version from the entry for storage
    $aref->{profile_ver} = $found->{version};

    return 0;
}

sub load_storage
{
    my $opts = shift;
    my $aref = shift;

    unless ( $aref->{storageid} ) {
        return 0;
    }

    my $found = &get_db_data( $opts, 'storage', $aref->{storageid} );
    unless ( defined $found ) {
        $opts->{LASTERROR} = "Unable to find storage entry for $aref->{storageid}\n";
        return 1;
    }
#    print $found . "\n" if ( $opts->{debug} > 1 );

    while ( my ($key, $value) = each( %$found ) ) {
        if (defined $value) {
            $aref->{$key} = $value;
        } else {
            $aref->{$key} = "";
        }
#        print "storage: $key => $aref->{$key}\n" if ( $opts->{debug} > 1 );
    }

    # hash special cases
    $aref->{storageuri} = &get_db_storage_uri( $opts, $aref->{storageid} );
    delete $aref->{username};
    delete $aref->{passwd};

    return 0;
}

sub load_distro
{
    my $opts = shift;
    my $aref = shift;

    my $found = &get_distro( $opts, $aref );
    unless ( defined $found ) {
        $opts->{LASTERROR} = "Unable to find distro entry for $aref->{distro}\n";
        return 1;
    }
#    print $found . "\n" if ( $opts->{debug} > 1 );

    while ( my ($key, $value) = each( %$found ) ) {
        if (defined $value) {
            $aref->{$key} = $value;
        } else {
            $aref->{$key} = "";
        }
#        print "distro: $key => $aref->{$key}\n" if ( $opts->{debug} > 1 );
    }

    return 0;
}

sub load_addons
{
    my $opts = shift;
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
#        print "load_addons: working with $name\n" if ($opts->{debug} > 1);
        my $tref = { distro => "$name" };
        my $found = &get_distro( $opts, $tref );
        if ( defined $found ) {
            my $addonbase = "$found->{os}-$found->{release}-$found->{arch}";
            if ( $aref->{distro} ne $addonbase ) {
                if ( $status == 0 ) {
                    $status = 1;
                }
                $opts->{LASTERROR} .= "addon $name is for $addonbase not the specified $aref->{distro}\n";
            } else {
#                print $found . " addon\n" if ($opts->{debug} > 1);

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
#            print $found . " repo\n" if ($opts->{debug} > 1);
            # so we have a 'repo' with this name
            $aref->{addon} .= "\n" if ( $aref->{addon} );
            $aref->{addon} .="      <listentry>
        <media_url>http://$baVar{serverip}/${name}</media_url>
        <product>${name}</product>
        <product_dir>/</product_dir>\n";
            $aref->{addon} .="      </listentry>"
        } elsif ( $name =~ m%^(http|ftp)\:\/\/(([^/]+\/){1,4}).*% ) {
#            print $found . " url\n" if ($opts->{debug} > 1);
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
    my $aref = shift;

    my $name = $aref->{$type};
    my $vers = $aref->{"${type}_ver"};

    my $found = get_version_or_enabled( $opts, $type, $name, $vers );
    return 1 unless ( defined $found );
#    print $found . "\n" if ($opts->{debug} > 1);

    while ( my ($key, $value) = each( %$found ) ) {
        if (defined $value) {
            $aref->{$key} = $value;
        } else {
            $aref->{$key} = "";
        }
#        print "hware: $key => $aref->{$key}\n" if ( $opts->{debug} > 1 );
    }

    # record the version from the entry for storage
    $aref->{hardware_ver} = $found->{version};

    return 0;
}

sub load_autobuild
{
    my $type = "autobuild";

    my $opts = shift;
    my $aref = shift;

    my $name = $aref->{$type};
    my $vers = $aref->{"${type}_ver"};

#    print "load_autobuild name $name ver $vers\n" if ($opts->{debug} > 1);

    my $found = get_version_or_enabled( $opts, $type, $name, $vers );
    return 1 unless ( defined $found );
#    print $found . "\n" if ($opts->{debug} > 1);

    # record the version from the entry for storage
    $aref->{autobuild_ver} = $found->{version};

    return 0;
}

sub load_modules
{
    my $type = "module";

    my $opts = shift;
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

#    print "module list: " . join (", ", @modulelist) . "\n" if ( $opts->{debug} > 1 );

    # incorporate modules passed into 'module' key for __MODULE__ autobuild sub
    $aref->{'module'} = "";

#   $aref->{'module'} = "    <post-scripts config:type="list">\n";
    foreach my $item ( @modulelist ) {

        # get verison and name from possible compound
        my ( $name, $vers ) = get_name_version( $item );
#        print "working $item : $name + $vers\n" if ( $opts->{debug} > 1 );

        my $found = get_version_or_enabled( $opts, $type, $name, $vers );
        return 1 unless ( defined $found );
#        print "found $item : $name + $found->{version}\n" if ( $opts->{debug} > 1 );
#        print $found . "\n" if ( $opts->{debug} > 1 );

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

sub get_sysidcfg_expanded
{
    use File::Temp qw/ tempdir /;

    my $opts = shift;
    my $aref = shift;

    my $sysidcfg_file="/usr/share/baracus/templates/jumpstart/solaris-10.8-sysidcfg";
    ## Probably better to eventually load this from db
    open( SYSIDCFG, "<$sysidcfg_file" )  or die $!;
    my $sysidcfg = join '', <SYSIDCFG>;
    close ( SYSIDCFG );

    my $date    = &get_rundate();
    while ( my ($key, $value) = each %$aref ) {
        $key =~ tr/a-z/A-Z/;
        $key = "__${key}__";
        $sysidcfg =~ s/$key/$value/g;
    }

    # we do the search and replace again
    # to expand vars within __MODULE__ or other vars
    while ( my ($key, $value) = each %$aref ) {
        $key =~ tr/a-z/A-Z/;
        $key = "__${key}__";
        $sysidcfg =~ s/$key/$value/g;
    }

    my $cstart="#";
    my $cstop="";

    $sysidcfg .= "$cstart baracus.Hostname: $aref->{'hostname'} $cstop\n";
    $sysidcfg .= "$cstart baracus.MAC: $aref->{'mac'}; $cstop\n";
    $sysidcfg .= "$cstart baracus.Generated: $date $cstop\n";

    if ( $sysidcfg =~ m/__.*__/ ) {
        my $automac = $aref->{autobuild} . "-" . $aref->{autobuild_ver};
        my $tdir = tempdir( "baracus.XXXXXX", TMPDIR => 1, CLEANUP => 1 );
#        print "using tempdir $tdir\n" if ($opts->{debug} > 1);
        open(FILE, ">$tdir/$automac") or
            die "Cannot open file $tdir/$automac: $!\n";
        print FILE $sysidcfg;
        close(FILE);
        warn "generated but some vars still need to be replaced in $automac\n";
        system "grep -Ene '__.*__' $tdir/$automac";
        unlink "$tdir/$automac";
#        print "removing tempdir $tdir\n" if ($opts->{debug} > 1);
        rmdir $tdir;
    }

    return $sysidcfg;
}

sub get_autobuild_expanded
{
    use File::Temp qw/ tempdir /;

    my $opts = shift;
    my $aref = shift;

    my $name = $aref->{autobuild};
    my $vers = $aref->{autobuild_ver};

#    print "get_autobuild_expanded name $name ver $vers\n" if ($opts->{debug} > 1);

    my $abhref = &get_autobuild( $opts, $aref, $vers );

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
         $aref->{os} eq "centos" ||
         $aref->{os} eq "solaris" ) {
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
#        print "using tempdir $tdir\n" if ($opts->{debug} > 1);
        open(FILE, ">$tdir/$automac") or
            die "Cannot open file $tdir/$automac: $!\n";
        print FILE $abfile;
        close(FILE);
        warn "generated but some vars still need to be replaced in $automac\n";
        system "grep -Ene '__.*__' $tdir/$automac";
        unlink "$tdir/$automac";
#        print "removing tempdir $tdir\n" if ($opts->{debug} > 1);
        rmdir $tdir;
    }

    return $abfile;
}

sub remove_sqlFS_files
{
    my $opts    = shift;
    my $mac     = shift;

    my $lhref;

    my $list =  $opts->{sqlfsOBJ}->list_start( "${mac}" );
    while ( $lhref = $opts->{sqlfsOBJ}->list_next( $list ) ) {
        $opts->{sqlfsOBJ}->remove( $lhref->{name} );
        debug "$lhref->{name} removed from file DB \n" if ( $opts->{debug} > 1 );
    }
    $opts->{sqlfsOBJ}->list_finish( $list );

}


sub get_mandatory_modules
{
    my $type = "module";

    my $opts = shift;
    my $dist = shift;

    my @modarray;

    my $cert_href = &cert_for_distro( $opts, $type, $dist );
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
    my $type = shift;
    my $id   = shift;

    unless ( $type eq "hardware" or
             $type eq "module"   or
             $type eq "autobuild"
            )
    {
        die "Expected 'module', 'autobuild' or 'hardware'\n";
    }

    my $href = undef;
    my $sql = qq| SELECT status, version
                  FROM $baTbls{ $type }
                  WHERE $baTblId{ $type } = '$id'
                  AND version >= 1
                 |;


    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;

        while ( $href = $sth->fetchrow_hashref( ) ) {
            if ( $href->{status} ) {
                return $href->{version};
            }
        }

        $sth->finish;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

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
    my $moduleid = shift;

    my $href = undef;
    my $sql = qq| SELECT mandatory, distroid
                  FROM $baTbls{ modcert }
                  WHERE moduleid = '$moduleid'
                |;

    my @mancerts;
    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;

        while ( $href = $sth->fetchrow_hashref( ) ) {
            if ($href->{'mandatory'}) {
                push @mancerts, $href->{'distroid'}
            }
        }

        $sth->finish;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

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
        my $findcount = &find_helper( $opts, $tftph, "distro", $cert_in );
        unless ( defined $findcount ) {
            # &find call failed
            $opts->{LASTERROR} = "Failed in check_distros\n" . $opts->{LASTERROR};
            return undef;
        }
        unless ( $findcount ) {
            error "Unable to certify: $cert_in does not exist\n";
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
    my $type = shift;
    my $name = shift;

    my %cert_hash;

    my $sql;

    return \%cert_hash if ( not defined $name or $name eq "" );

    my $href = undef;
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

    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;

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
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    return \%cert_hash;
}


sub check_cert
{
    my $opts = shift;
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
        $cert_hash = get_certs_hash( $opts, $type, $name );

        if ( defined $cert_hash and defined $cert_hash->{ $dist } ) {
#            print "$type $item is certified for $dist\n" if $opts->{debug};
            ;
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
    my $type = shift;
    my $dist = shift;

    my $sql;
    my $href = undef;
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

    my %cert_hash;
    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;

        while ( $href = $sth->fetchrow_hashref( ) ) {
            if ( defined $href->{mandatory} ) {
                $cert_hash{ $href->{name} }= $href->{mandatory};
            } else {
                $cert_hash{ $href->{name} }= 0;
            }
        }

        $sth->finish;
    };

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
    my $type = shift;
    my $name = shift;
    my $vers = shift;

    my $version_href = undef;
    my $highest_href = undef;
    my $enabled_href = undef;

    $vers = 0 unless ( defined $vers );

    unless ( $type eq "hardware" or
             $type eq "module"   or
             $type eq "profile"  or
             $type eq "autobuild"
            )
    {
        die "Expected 'module', 'profile', 'autobuild' or 'hardware'\n";
    }

    my $href = undef;
    my $sql_cols = lc get_cols( $baTbls{ $type } );
    my $sql = qq| SELECT $sql_cols FROM $baTbls{ $type } WHERE $baTblId{ $type } = '$name' ORDER BY version|;


    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;

        while ( $href = $sth->fetchrow_hashref( ) ) {
            $version_href = $href if ( $href->{'version'} == $vers);
            $highest_href = $href;
            $enabled_href = $href if ( $href->{'status'} == 1 );
        }
        $sth->finish;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    unless ( defined $version_href or
             defined $highest_href or
             defined $enabled_href ) {
        $opts->{LASTERROR} = "Unable to find $type entry for $name\n";
        error $opts->{LASTERROR};
    }

    return ( $version_href, $highest_href, $enabled_href );
}

#
# add_db_data(  $opts, $tbl, $hashref )
#

sub add_db_data
{
    my $opts    = shift;
    my $tbl     = shift;
    my $hashref = shift;
    my %Hash    = %{$hashref};

    my $fields = lc get_cols( $baTbls{ $tbl  } );
    $fields =~ s/[ \t]*//g;
    my @fields;

    foreach my $field ( split( /,/, $fields ) ) {
        next if ( $field eq "change" );  # skip change col
        $Hash{ $field } = "now()" if ( $field eq "creation" ); # add creation time
        push @fields, $field;
    }
    $fields = join(', ', @fields);
    my $values = join(', ', (map { database->quote($_) } @Hash{@fields}));

    my $href = undef;
    my $sql = qq|INSERT INTO $baTbls{ $tbl } ( $fields ) VALUES ( $values )|;

    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;
        $sth->finish;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    return 0;
}

#
# remove_db_data( $opts, $tbl, $id )
#

sub remove_db_data
{
    my $opts  = shift;
    my $tbl   = shift;
    my $id    = shift;
    my $index = shift;

    $index = $baTblId{ $tbl } unless (defined $index);

    my $href = undef;
    my $sql = qq|DELETE FROM $baTbls{ $tbl } WHERE $index = '$id'|;

    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;
        $sth->finish;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    return 0;
}

#
# update_db_data( $opts, $tbl, $hashref )
#

sub update_db_data
{
    my $opts    = shift;
    my $tbl     = shift;
    my $hashref = shift;
    my %Hash    = %{$hashref};

    # limit to table defined columns
    my $valid = get_cols( $baTbls{ $tbl  } );
    unless ( defined $valid ) {
        status 'error';
        return $opts->{LASTERROR};
    }
    $valid =~ s/[ \t]*//g;

    my @fields;
    foreach my $field ( split(/,/, $valid ) ) {
        next unless ( defined $Hash{ $field } ); # skip all but fields passed
        next if ( $field eq $baTblId{ $tbl } );  # skip key
        next if ( $field eq "creation" );  # skip creation col
        next if ( $field eq "change" );  # skip change col - will get below
        push @fields, $field;
    }
    my $fields = join(', ', @fields);
    my $values = join(', ', (map { database->quote($_) } @Hash{@fields}));

    if ( $valid =~ /\bchange\b/ ) {
        $fields .= ", change";
        $values .= ", CURRENT_TIMESTAMP";
    }

    my $sql = qq|UPDATE $baTbls{ $tbl }
                SET ( $fields ) = ( $values )
                WHERE $baTblId{ $tbl } = '$hashref->{ $baTblId{ $tbl } }' |;

    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;
        $sth->finish;
    };

    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    return 0;

}

#
# get_db_data( $tbl, $id )
#

sub get_db_data
{
    my $opts  = shift;
    my $tbl   = shift;
    my $id    = shift;
    my $index = shift;
    my $href  = undef;

    $index = $baTblId{ $tbl } unless (defined $index);

    my $sql = qq|SELECT * FROM $baTbls{ $tbl } WHERE $index = '$id' |;

    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;
        $href = $sth->fetchrow_hashref();
        $sth->finish;
        undef $sth;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }
    return $href;
}

#
# get_db_data_by( $tbl, $id, $index )
#

sub get_db_data_by
{
    my $opts  = shift;
    my $tbl   = shift;
    my $id    = shift;
    my $index = shift;

    my $href = &get_db_data( $opts, $tbl, $id, $index);

    return $href;
}

#
# remove_db_data_by( $opts, $tbl, $id, $index )
#

sub remove_db_data_by
{
    my $opts   = shift;
    my $tbl   = shift;
    my $id    = shift;
    my $index = shift;

    &remove_db_data( $opts, $tbl, $id, $index );
}

#
# list_start_data ( $opts, $filter, $fkey )
#

sub list_start_data
{
    my $opts = shift;
    my $tbl  = shift;
    my $filter = shift;

    # default table key
    my $fkey = $baTblId{ $tbl };

    if ( $filter eq "all" ) {
        $filter = "%";  # everything
    } else {
        if ( $filter =~ m/::/ ) {
            ( $fkey, $filter ) = split ( /::/, $filter, 2 );

            # check for valid fkey if 'split' syntax used
            my $valid = get_cols( $baTbls{ $tbl } );
            unless ( $valid =~ m/\b${fkey}\b/ ) {
                $opts->{LASTERROR} = "filter key not valid: $fkey\n";
                return undef;
            }
        } # else no 'split' syntax so use filter with default table key

        # shell wildcard to postgres expression handling
        $filter =~ s|\*|%|g;  # any number chars of anything
        $filter =~ s|\?|_|g;  # one char of anything
    }

    my $sql = qq|SELECT * FROM $tbl WHERE CAST($fkey as TEXT) LIKE '$filter' ORDER BY $baTblId{ $tbl }|;

    my $sth;
    eval {
        $sth = database->prepare( $sql );
        $sth->execute;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }
    return $sth;
}

#
# list_next_data ( $sth )
#

sub list_next_data
{
    my $sth = shift;
    my $href;

    $href = $sth->fetchrow_hashref();

    unless ( defined $href ) {
        &list_finish_data( $sth );
    }

    return $href;
}

#
# list_finish_data ( $sth )
#

sub list_finish_data
{
    my $sth  = shift;

    $sth->finish;
    undef $sth;
}


# rendundant_data
#
#   when possibly adding a new version we make sure that the
#   'data' is not already pressent in another entry. if it is
#   return 1 - with LASTERROR of the version already present.

sub redundant_data
{
    my $opts = shift;
    my $type = shift;
    my $name = shift;
    my $data = shift;

    unless ( $type eq "hardware" or
             $type eq "module"   or
             $type eq "profile"  or
             $type eq "autobuild"
            )
    {
        die "Expected 'module', 'profile', 'autobuild' or 'hardware'\n";
    }

    my $href = undef;
    my $sql_cols = lc get_cols( $baTbls{ $type } );
    my $sql = qq| SELECT $sql_cols FROM $baTbls{ $type } WHERE $baTblId{ $type } = '$name' ORDER BY version;|;

    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;

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
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    return 0;
}

# find - simple lookup to see if entry already exists
# return count of entries found or undef on error

sub find_helper
{
    my $opts  = shift;
    my $tftph = shift;
    my $type  = shift;
    my $name  = shift;

    my $sql;
    my $href=undef;
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
    } elsif ( $type eq "distro" ) {
        $sql = qq|SELECT distroid as name
                  FROM $baTbls{ $type }
                  WHERE distroid = '$name'
                 |;
    }

    my $rowcount = 0;
    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;

        while ( $sth->fetchrow_hashref() ) {
            $rowcount += 1;
        }

        $sth->finish;
    };

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
#	print STDERR "Use broadcast address: " . $block->broadcast() . "\n" if ( $opts->{debug} > 1);
	$aref->{broadcast} = $block->broadcast();
    }
}

sub read_cachelist
{
    my $clh = {};
    my $clfile = "$baDir{ bcdir }/cachelist";
    open( my $fh, "<", $clfile ) or die "unable to open $clfile: $!";
    while (<$fh>) {
        s|#.*$||g;                # remove all comments full-line or eol
        s|\s+||g;                 # remove all extraneous whitespace
        next unless (m/^.+$/);    # skip blank lines
        $clh->{$_} = $_;
    }
    close $fh;
    return $clh;
}

sub is_should_bigfile
{
    my $name = shift;
    my $size = shift || 0;

    my $clhref = &read_cachelist();

    return 1 if ( defined $clhref->{$name} );
    return 1 if ( $size >= $bfsize );
    return 0;
}

sub add_bigfile
{
    my $name = shift;
    my $file = shift;
    my $fh;
    open( $fh, ">", "$baDir{bfdir}/$name" ) or die "why die $baDir{bfdir}/$name : $!";
    print $fh $file;
    close $fh;
}

sub remove_bigfile
{
    my $name = shift;
    unlink "$baDir{bfdir}/$name" if ( -f "$baDir{bfdir}/$name" );
}

1;

__END__
