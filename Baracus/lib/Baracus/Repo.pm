package Baracus::Repo;

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
use File::Copy;
use File::Basename;
use File::Path;
use File::Temp;
use File::Find;

use lib "/usr/share/baracus/perl";

use Baracus::Config qw( :vars :subs );
use Baracus::Source qw( :vars :subs );

=pod

=head1 NAME

B<Baracus::Repo> - subroutines for managing Baracus repos

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
                %barepoType
                BA_REPO_YUM
                BA_REPO_APT
                BA_REPO_IPS
                BA_REPO_MSI
                BA_REPO_UNSUPPORTED
            )],
         subs   =>
         [qw(
                create_repo_yum
                create_repo_apt
                add_packages_yum
                add_packages_apt
                update_repo
                remove_repo
                sign_repo
                verify_repo_creation
                verify_repo_repodata
                verify_repo_sign
            )],
         );

    Exporter::export_ok_tags('vars');
    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

use vars qw ( %barepoType );

use constant BA_REPO_YUM => 1;
use constant BA_REPO_APT => 2;
use constant BA_REPO_IPS => 3;
use constant BA_REPO_MSI => 4;
use constant BA_REPO_UNSUPPORTED => 5;

%barepoType =
    (
      1     => 'rpm',
      2     => 'deb',
      3     => 'pkg',
      4     => 'msi',
      5     => 'unsupported',

      'rpm'         => BA_REPO_YUM,
      'deb'         => BA_REPO_APT,
      'pkg'         => BA_REPO_IPS,
      'msi'         => BA_REPO_MSI,
      'unsupported' => BA_REPO_UNSUPPORTED,

      BA_REPO_YUM          => 'rpm',
      BA_REPO_APT          => 'deb',
      BA_REPO_IPS          => 'pkg',
      BA_REPO_MSI          => 'msi',
      BA_REPO_UNSUPPORTED  => 'unsupported',
    );


sub create_repo_yum {

    my $opts     = shift;
    my $repo     = shift;
    my $distro   = shift;
    my $packages = shift;

    my @packages = split( /\s+/, $packages );
    my $status;
    my $template = "$baDir{templates}/repo/byum.conf.template";

    my $dh = &baxml_distro_gethash( $opts, $distro );
    my $os      = $dh->{os};
    my $release = $dh->{release};
    my $arch    = $dh->{arch};

    my $rpath = "$baDir{'byum'}/$repo/${os}_${release}";

    ## Create repo directory
    ##
    unless ( -d $baDir{'byum'}) {
        mkdir $baDir{'byum'}, 0755 || die ("Cannot create directory\n");
    }

    ## Create Apache repo configuration
    ##
    unless ( -f "/etc/apache2/conf.d/$repo.conf" ) {
        open(TEMPLATE, "<$template") or
            die "Unable to open $template: $!\n";
        my $barepo = join '', <TEMPLATE>;
        close(TEMPLATE);
        $barepo =~ s/%REPO%/$repo/g;
        open(CONFIG, ">/etc/apache2/conf.d/$repo.conf") or
            die "Unable to open $repo.conf $!\n";
        print CONFIG $barepo;
        close(CONFIG);
    }

    ## Soft test to see if Repo exists
    ##
    if (-d "$rpath") {
        opendir(DIR, "$rpath/repodata");
        unless(scalar(grep(!/^\.+$/, readdir(DIR)) == 0)) {
            $opts->{LASTERROR}  = "Create stop. Found existing repodata for '$repo'.\n";
            return 1;
        }
        close(DIR);
    }

    ## Create repo directory and repo files
    ##
    unless ( -d "$rpath" or mkpath "$rpath", { verbose => 0, mode => 0755 } ) {
        $opts->{LASTERROR} ="Unable create directory $rpath $!\n";
        return 1;
    }

    ## Create repo directory and repo files
    ##
    unless ( -d "$rpath/$arch" or mkdir "$rpath/$arch", 0755 ) {
        $opts->{LASTERROR} ="Unable create directory $rpath $!\n";
        return 1;
    }

    foreach my $package (@packages) {
        unless (-e $package) {
            print "Skipping non-existing $package\n";
            next;
        }
        unless (-f $package) {
            print "Skipping non-file $package\n";
            next;
        }
        unless ( $package =~ m|\.rpm| ) {
            print "Skipping non-rpm $package\n";
        }
        copy($package, "$rpath/$arch");
    }

    system("/usr/bin/createrepo -q $rpath &> /dev/null");

    &sign_repo( $opts, $rpath );

    return 0;
}

sub create_repo_apt {

    my $opts     = shift;
    my $repo     = shift;
    my $distro   = shift;
    my $packages = shift;

    my $dh = &baxml_distro_gethash( $opts, $distro );
    my $arch     = $dh->{arch};
    my $codename = $dh->{codename};

    my @packages = split( /\s+/, $packages );
    my $base = basename ( $repo );
    my $status;
    my $template = "$baDir{templates}/repo/batp.conf.template";
    my %vhash =
            (
                'base'        => "$base",
                'origin'      => "$base",
                'label'       => "$base",
                'codename'    => "$codename",
                'arch'        => "$arch",
                'desc'        => "Baracus Apt Repository: $base",
                'deboverride' => "",
                'dscoverride' => "",
            );

    ## Test to see if Repo exists
    ##
    if ( -f "$baDir{'byum'}/$repo/db/packages.db" ) {
        $opts->{LASTERROR}  = "Create stop. Found existing repodata for '$base'.\n";
        return 1;
    }

    ## Create repo directory
    ##
    unless ( -d "$baDir{'byum'}/$repo") {
        mkdir "$baDir{'byum'}/$repo", 0755 || die ("Cannot create directory\n");
        mkdir "$baDir{'byum'}/$repo/conf", 0755 || die ("Cannot create directory\n");
    }
 
    ## Create Apache repo configuration
    ##
    unless ( -f "/etc/apache2/conf.d/$base.conf" ) {
        open(TEMPLATE, "<$template") or
            die "Unable to open $template: $!\n";
        my $barepo = join '', <TEMPLATE>;
        close(TEMPLATE);
        $barepo =~ s/%REPO%/$base/g;
        open(CONFIG, ">/etc/apache2/conf.d/$base.conf") or
            die "Unable to open $base.conf $!\n";
        print CONFIG $barepo;
        close(CONFIG);
    }

    ## Create repo directory and repo files
    ##
    unless ( -d "$repo" or mkdir $repo, 0755 ) {
        $opts->{LASTERROR} ="Unable create directory $repo $!\n";
        return 1;
    }

    ## Create conf file and populate 
    open(DISTRIBUTIONS, "<", "$baDir{templates}/repo/distributions.debian") ||
      die "Unable to open barepo debian distributions template. $!\n";
    my $distributions = join '', <DISTRIBUTIONS>;
    close(DISTRIBUTIONS);

    while ( my ($key, $value) = each(%vhash) ) {
        $key = uc( $key );
        $distributions =~ s/%$key%/$value/g;
    }

    open(DISTCONF, ">$baDir{'byum'}/$repo/conf/distributions") ||
      die "Unable to open barepo debian distributions file. $!\n";
    print DISTCONF $distributions;
    close(DISTCONF);

    foreach my $package (@packages) {
        unless (-e $package) {
            print "Skipping non-existing $package\n";
            next;
        }
        unless (-f $package) {
            print "Skipping non-file $package\n";
            next;
        }
        unless ( $package =~ m|\.deb| ) {
            print "Skipping non-deb $package\n";
        }

        print "calling: /usr/bin/reprepro --gnupghome /usr/share/baracus/gpghome/.gnupg --basedir $baDir{'byum'}/$repo includedeb $codename $package" if ( $opts->{debug} );
        system("/usr/bin/reprepro", "--gnupghome", "/usr/share/baracus/gpghome/.gnupg", 
                                    "--basedir", "$baDir{'byum'}/$repo", "includedeb", 
                                    "$codename", "$package");
    }

}

sub add_packages_yum {

    my $opts     = shift;
    my $repo     = shift;
    my $distro   = shift;
    my $packages = shift;

    my @packages = split( /\s+/, $packages );

    my $dh = &baxml_distro_gethash( $opts, $distro );
    my $os      = $dh->{os};
    my $release = $dh->{release};
    my $arch    = $dh->{arch};

    my $rpath = "$baDir{'byum'}/$repo/${os}_${release}";

    unless( scalar @packages ) {
        $opts->{LASTERROR} = "Attempt to add without providing any rpm file arguments.\n";
        return 1;
    }

    # verify repopath and apache conf - from create
    return 1 if ( &verify_repo_creation( $opts, $repo ) );

    foreach my $package (@packages) {
        if (-f $package) {
            if ( $package =~ m|\.rpm| ) {
                copy($package, "$rpath/$arch");
            } else {
                print "Skipping add of non-rpm $package\n";
            }
        } else {
            print "Skipping non-existing $package\n";
        }
    }

    # verify repopath and apache conf - from create
    if ( &verify_repo_creation( $opts, $repo ) ) {
        $opts->{LASTERROR} = "Bad repo, cannot add packages.\n";
        return 1;
    }

    system("/usr/bin/createrepo -q $rpath &> /dev/null");

    return &sign_repo( $opts, $rpath );
}

sub add_packages_apt {

    my $opts     = shift;
    my $repo     = shift;
    my $distro   = shift;
    my $packages = shift;

    my @packages = split( /\s+/, $packages );

    unless( scalar @packages ) {
        $opts->{LASTERROR} = "Attempt to add without providing any rpm file arguments.\n";
        return 1;
    }

    my $dh = &baxml_distro_gethash( $opts, $distro );
    my $arch     = $dh->{arch};
    my $codename = $dh->{codename};

    # verify repopath and apache conf - from create
    if ( &verify_repo_creation( $opts, $repo ) ) {
        $opts->{LASTERROR} = "Bad repo, cannot add packages.\n";
        return 1;
    }

    foreach my $package (@packages) {
        if (-f $package) {
            if ( $package =~ m|\.deb| ) {
                print "calling: /usr/bin/reprepro --basedir $baDir{'byum'}/$repo includedeb $codename $package" if ( $opts->{debug} );
                system("/usr/bin/reprepro", "--gnupghome", "/usr/share/baracus/gpghome/.gnupg",
                                            " --basedir", "$baDir{'byum'}/$repo", "includedeb",
                                            "$codename", "$package");
            } else {
                print "Skipping add of non-rpm $package\n";
            }
        } else {
            print "Skipping non-existing $package\n";
        }
    }

    return 0;

}

sub remove_repo {
 
    my $opts = shift;
    my $repo = shift;

    # verify only that the name is a dir under the byum directory
    unless ( -d "$baDir{'byum'}/$repo" ) {
        $opts->{LASTERROR} = "Unable to remove non-byum or non-directory $repo\n";
        return 1;
    }
    rmtree("$baDir{'byum'}/$repo");
    unlink("/etc/apache2/conf.d/$repo.conf");

    return 0;
}


sub sign_repo {

    my $opts = shift;
    my $rpath = shift;
     
    my $distro = basename($rpath);
    my $repo   = $rpath;
    $repo =~ s/$distro//;
    $repo = basename($repo);

    if ( &verify_repo_creation( $opts, $repo ) ) {
        $opts->{LASTERROR} = "$repo does not exist.\n";
        return 1;
    }

    my $gpghome = "/usr/share/baracus/gpghome";

    print "Signing repo: $repo\n" if ( $opts->{verbose} );

    ## Sign $filename
    ##
    if (-f "$rpath/repodata/repomd.xml.asc") {
        unlink("$rpath/repodata/repomd.xml.asc");
    }
    system("gpg", "--homedir=$gpghome/.gnupg",
           "-a", "--detach-sign", "--default-key=C685894B",
           "$rpath/repodata/repomd.xml");

    ## Install key into repo
    ##
    unless (-f "$rpath/repodata/repomd.xml.key") {
       copy("$gpghome/.gnupg/my-key.gpg", "$rpath/repodata/repomd.xml.key");
    }

    return 0;
}

sub verify_repo_creation {

    my $opts = shift;
    my $repo = shift;

    unless (-d "$baDir{'byum'}/$repo") {
        $opts->{LASTERROR} = "Missing repo dir $repo\n";
        return 1;
    };

    unless (-f "/etc/apache2/conf.d/$repo.conf") {
        $opts->{LASTERROR} .= "Missing apache repo config for $repo.\n";
        return 1;
    }

    return 0;
}

sub verify_repo_repodata {

    my $opts = shift;
    my $repo = shift;

    my $type = &get_type( $opts, $repo );
    my @paths;
    my $path;
    my @chkfiles;
    my $rpath = "$baDir{'byum'}/$repo";

    if ( $type == BA_REPO_YUM ) {
        opendir(DIR, "$rpath");
        foreach my $path ( grep(!/^\.+$/, readdir(DIR)) ) {
            push @paths, "$rpath/$path/repodata";
            use XML::Simple qw(:strict);
            my $xs = XML::Simple->new
            ( SuppressEmpty => 1,
              ForceArray =>
              [ qw
                ( data
                )
               ],
              KeyAttr =>
              {
               data     => 'type',
               },
             );

            my $repoXML = $xs->XMLin("$rpath/$path/repodata/repomd.xml");

            @chkfiles = ("$repoXML->{data}->{filelists}->{location}->{href}",
                         "$repoXML->{data}->{other}->{location}->{href}",
                         "$repoXML->{data}->{primary}->{location}->{href}");

            foreach my $path ( @paths ) {
                foreach my $file (@chkfiles) {
                    $file = basename($file);
                    unless (-f "$path/$file" ) {
                        $opts->{LASTERROR} = "Missing repo file $file\n";
                        return 1;
                    }
                }
            }
        }
    } elsif ( $type == BA_REPO_APT ) {
        @paths = "$rpath/db";
        @chkfiles = qw| references.db
                        checksums.db
                        packages.db
                        version
                        release.caches.db
                      |;

        foreach my $path ( @paths ) {
            foreach my $file (@chkfiles) {
                $file = basename($file);
                unless (-f "$path/$file" ) {
                    $opts->{LASTERROR} = "Missing repo file $file\n";
                    return 1;
                }
            }
        }
    } else {
        $opts->{LASTERROR} = "Unable to determine repo type: unsupported or corrupt repo\n";
        return 1;
    }

    return 0;
}

sub verify_repo_sign {

    my $opts = shift;
    my $repo = shift;

    my @yumfiles = qw| repomd.xml.asc
                       repomd.xml.key
                     |;

    my @aptfiles = qw| Release.gpg |;

    my $type = &get_type( $opts, $repo );
    my $path;
    my @paths;
    my @chkfiles;

    my $rpath = "$baDir{'byum'}/$repo";

    if ( $type == BA_REPO_YUM ) {
        opendir(DIR, "$rpath");
        foreach $path ( grep(!/^\.+$/, readdir(DIR)) ) {
            push @paths, "$rpath/$path/repodata";
        }
        @chkfiles = @yumfiles;
    } elsif ( $type == BA_REPO_APT ) {
        opendir(DIR, "$rpath/dists");
        foreach $path ( grep(!/^\.+$/, readdir(DIR)) )  {
            push @paths, "$rpath/dists/$path";
        }
        @chkfiles = @aptfiles;
    } else {
        $opts->{LASTERROR} = "Unable to determine repo type\n";
        return 1;
    }

    foreach my $path ( @paths ) {
        foreach my $file (@chkfiles) {
            unless (-f "$path/$file" ) {
                $opts->{LASTERROR} .= "Missing repo sig file $file\n";
                return 1;
            }
        }
    }

    if ( $type == BA_REPO_YUM ) {

        foreach my $path ( @paths ) {
            my $gpghome = "/usr/share/baracus/gpghome";
            open STDERR, '>', '/dev/null' or die "Cannot open STDERR\n";
            my $status = system("gpg2", "--homedir=$gpghome/.gnupg/",
                                "--verify", "$path/repomd.xml.asc" );
            close(STDERR);
            if ( $status ) {
                $opts->{LASTERROR} = "Failed gpg sig check. Recommend 'barepo update $repo'\n";
                return 1;
            }
        }
    }

    return 0;

}

sub get_type
{

    my $opts = shift;
    my $repo = shift;

    my $type = BA_REPO_UNSUPPORTED;

    find ( { wanted =>
             sub {
                     if (  $_ eq "repodata" ) {
                         $type = BA_REPO_YUM;
                     } elsif ( $_ eq "dists" ) {
                         $type = BA_REPO_APT;
                     }
                 },
                 follow => 1
           },
           "$baDir{'byum'}/$repo" );

    return $type;

}

1;

__END__

=head1 AUTHOR

Daniel Westervelt, E<lt>dwestervelt@novellE<gt>
David Bahi, E<lt>dbahi@novellE<gt>

=cut
