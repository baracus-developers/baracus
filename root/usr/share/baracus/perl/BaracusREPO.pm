package BaracusREPO;

use 5.006;
use strict;
use File::Copy;
use File::Basename;
use File::Path;

our $LASTERROR="";

sub error {
    return $LASTERROR;
}

sub create_repo {
    my $repo = shift;
    my @packages = @_;
    my $base = basename ( $repo );
    my $status;

    ## Create Apache repo configuration
    ##
    unless ( -f "/etc/apache2/conf.d/$base.conf" ) {
        open(TEMPLATE, "</usr/share/baracus/templates/byum.conf.template") or
            die "Unable to open barepo apache template. $!\n";
        my $byumrepo = join '', <TEMPLATE>;
        close(TEMPLATE);
        $byumrepo =~ s/%REPO%/$base/g;
        open(CONFIG, ">/etc/apache2/conf.d/$base.conf") or
            die "Unable to open $base.conf $!\n";
        print CONFIG $byumrepo;
        close(CONFIG);
    }

    ## Soft test to see if Repo exists
    ##
    if (-d "$repo/repodata") {
        opendir(DIR, "$repo/repodata");
        unless(scalar(grep(!/^\.+$/, readdir(DIR)) == 0)) {
            $LASTERROR = "Create stop. Found existing repodata for '$base'.\n";
            return 1;
        }
        close(DIR);
    }

    ## Create repo directory and repo files
    ##
    unless ( -d "$repo" or mkdir $repo, 0755 ) {
        $LASTERROR ="Unable create directory $repo $!\n";
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
        copy($package, $repo);
    }

    system("/usr/bin/createrepo -q $repo &> /dev/null");

    return sign_repo($repo);
}

sub add_packages {
    my $repo = shift;
    my @packages = @_;
    my $status;

    unless( scalar @packages ) {
        $LASTERROR = "Attempt to add without providing any rpm file arguments.\n";
        return 1;
    }

    # verify repopath and apache conf - from create
    return 1 if ( &verify_repo_creation( $repo ) );

    foreach my $package (@packages) {
        if (-f $package) {
            if ( $package =~ m|\.rpm| ) {
                copy($package, $repo);
            } else {
                print "Skipping add of non-rpm $package\n";
            }
        } else {
            print "Skipping non-existing $package\n";
        }
    }

    return $status if ( $status = &update_repo($repo) );

    return &sign_repo($repo);
}

sub update_repo {
    my $repo = shift @_;
    my $status;

    # verify repopath and apache conf - from create
    return 1 if ( &verify_repo_creation( $repo ) );

    if (-f "$repo/repodata/repomd.xml.asc") {
        unlink("$repo/repodata/repomd.xml.asc");
    }

    system("/usr/bin/createrepo -q $repo &> /dev/null");

    return &sign_repo($repo);
}

sub remove_repo {
    my $repo = shift @_;
    my $base =  basename("$repo");

    # verify only that the name is a dir under the byum directory
    unless ( $repo =~ m|byum| and -d $repo ) {
        $LASTERROR = "Unable to remove non-byum or non-directory $base\n";
        return 1;
    }
    rmtree($repo);
    unlink("/etc/apache2/conf.d/$base.conf");

    return 0;
}


sub sign_repo {

    my $repo = shift;

    return 1 if ( &verify_repo_creation( $repo ) );

    my $status;
    my $gpghome = "/usr/share/baracus/gpghome";

    ## Sign $filename
    ##
    if (-f "$repo/repodata/repomd.xml.asc") {
        unlink("$repo/repodata/repomd.xml.asc");
    }
    system("gpg", "--homedir=$gpghome/.gnupg",
           "-a", "--detach-sign", "--default-key=C685894B",
           "$repo/repodata/repomd.xml");

    ## Install key into repo
    ##
    unless (-f "$repo/repodata/repomd.xml.key") {
       copy("$gpghome/.gnupg/my-key.gpg", "$repo/repodata/repomd.xml.key");
    }

    return 0;
}

sub verify_repo_creation {
    my $repo = shift;
    my $repopath = "$repo/repodata";
    my $base = basename( $repo );

    $LASTERROR = "Missing repo dir $repopath\n"
        unless (-d $repopath);

    $LASTERROR .= "Missing apache repo config for $base.\n"
        unless (-f "/etc/apache2/conf.d/$base.conf");

    if ( $LASTERROR ne "" ) {
        $LASTERROR .= "Recommend 'barepo create $base'.\n";
        return 1;
    }

    return 0;
}

sub verify_repo_repodata {
    my $repo = shift @_;
    my $repopath = "$repo/repodata";
    my $base = basename( $repo );

    my @repofiles = qw| filelists.xml.gz
                        primary.xml.gz
                        repomd.xml
                        other.xml.gz
                      |;

    foreach my $file (@repofiles) {
        unless (-f "$repopath/$file" ) {
            $LASTERROR .= "Missing repo file $file\n";
        }
    }

    if ( $LASTERROR ne "" ) {
        $LASTERROR .= "Recommend 'barepo update $base' to regenerate.\n";
        return 1;
    }

    return 0;
}

sub verify_repo_sign {
    my $repo = shift @_;
    my $repopath = "$repo/repodata";
    my $base = basename( $repo );

    my @repofiles = qw| repomd.xml.asc
                        repomd.xml.key
                      |;

    foreach my $file (@repofiles) {
        unless (-f "$repopath/$file" ) {
            $LASTERROR .= "Missing repo sig file $file\n";
        }
    }

    if ( $LASTERROR ne "" ) {
        $LASTERROR .= "Recommend 'barepo update $base' to sign.\n";
        return 1;
    }

    my $gpghome = "/usr/share/baracus/gpghome";

    my $status = system("gpg2", "--homedir=$gpghome/.gnupg/",
                        "--verify", "$repopath/repomd.xml.asc" );

    if ( $status ) {
        $LASTERROR = "Failed gpg sig check. Recommend 'barepo update $base'\n";
        return 1;
    }

    return 0;
}

1;
