package BaracusREPO;

use 5.006;
use strict;
use File::Copy;
use File::Basename;
use File::Path;

sub sign_repo {

    my $repo = shift;

     unless ( &verify_repo($repo) == 0) {
        print "$repo does not exist\n";
        return 1;
    }

    ## Sign $filename
    ##
    system("gpg", "--homedir=/usr/share/baracus/gpghome/.gnupg", "-a", "--detach-sign", "--default-key=C685894B", "$repo/repodata/repomd.xml");
    
    ## Install key into repo
    ## 
    unless (-f "$repo/repodata/repomd.xml.key") {
       copy("/usr/share/baracus/gpghome/.gnupg/my-key.gpg", "$repo/repodata/repomd.xml.key");
    } 

    return 0;

}

sub update_repo {
    my $repo = shift @_;

    unless ( &verify_repo($repo) == 0) {
        print "$repo does not exist\n";
        return 1;
    }

    if (-f "$repo/repodata/repomd.xml.asc") {
        unlink("$repo/repodata/repomd.xml.asc");
    }
    system("/usr/bin/createrepo", "-q",  "$repo");

    return 0;
}

sub add_packages {
    my $repo = shift;
    my @packages = @_;

    unless ( &verify_repo($repo) == 0) {
        print "$repo does not exist\n";
        return 1;
    }

    foreach my $package (@packages) {
        if (-f $package) {
            copy($package, $repo);
        }
        else {
            print "package: $package does not exist, skipping \n";
        }
    }

    &update_repo($repo);
    &sign_repo($repo);

    return 0;
}

sub create_repo {
    my $repo = shift;
    my @packages = @_;
    
    ## Soft test to see if Repo exists
    ##
    if (-d "$repo/repodata") {
        opendir(DIR, "$repo/repodata");
        unless(scalar(grep(!/^\.?$/, readdir(DIR)) == 0)) {
            print "error: repodata contains repo data \n";
            exit(1);
        }
    }
    close(DIR);

    ## Create Apache repo configuration
    ##
    open(TEMPLATE, "</usr/share/baracus/templates/byum.conf.template");
    my $byumrepo = join '', <TEMPLATE>;
    close(TEMPLATE);

    my $reponame = basename("$repo");
    $byumrepo =~ s/%REPO%/$reponame/g;
    open(CONFIG, ">/etc/apache2/conf.d/$reponame.conf");
    print CONFIG $byumrepo;
    close(CONFIG);

    ## Create repo directory and repo files
    ##
    unless (-d "$repo") {
        mkdir $repo, 0755 || die ("Cannot create $repo directory\n");
    }

    foreach my $package (@packages) {
        if (-f $package) {
            copy($package, $repo);
        }
        else {
            print "package: $package does not exist, skipping \n";
        }
    }

    system("/usr/bin/createrepo", "-q",  "$repo");

    #sign_repo($repo);

    return 0;
}

sub remove_repo {
    my $repo = shift @_;
    
    unless ( &verify_repo($repo) == 0) {
        $repo = basename($repo);
        print "$repo repo does not exist\n";
        return 1;
    }

    rmtree($repo);
    $repo =  basename("$repo");
    unlink("/etc/apache2/conf.d/$repo.conf");

    return 0;
}

sub verify_repo {
    my $repo = shift @_;
    my $repopath = "$repo/repodata";

    ## Verify directory exists and repo files are present
    ##
    unless (-d $repopath) {
        print "error: base repo dir missing \n";
        return 1;
    }
    my @repofiles = ("filelists.xml.gz", "primary.xml.gz", "repomd.xml", "other.xml.gz");
    foreach my $file (@repofiles) {
        unless (-f "$repopath/$file" ) {
            print "error: repo missing $file \n";
            return 1;
        }
    }

    ## Check Apache repo configuration
    ##
    $repo =  basename("$repo");
    unless (-f "/etc/apache2/conf.d/$repo.conf") {
        print "error: apache repo config missing \n";
        return 1;
    }

    return 0;
}

1;
