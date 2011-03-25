package BaracusREPO;

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

=pod

=head1 NAME

B<BaracusREPO> - subroutines for managing Baracus repos

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
                create_repo
                add_packages
                update_repo
                remove_repo
                sign_repo
                verify_repo_creation
                verify_repo_repodata
                verify_repo_sign
            )],
         );

    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

sub create_repo {

    my $opts     = shift;
    my $repo     = shift;
    my $packages = shift;

    my @packages = split( /\s+/, $packages );
    my $base = basename ( $repo );
    my $status;

    ## Create Apache repo configuration
    ##
    unless ( -f "/etc/apache2/conf.d/$base.conf" ) {
        open(TEMPLATE, "</usr/share/baracus/templates/repo/byum.conf.template") or
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
            $opts->{LASTERROR}  = "Create stop. Found existing repodata for '$base'.\n";
            return 1;
        }
        close(DIR);
    }

    ## Create repo directory and repo files
    ##
    unless ( -d "$repo" or mkdir $repo, 0755 ) {
        $opts->{LASTERROR} ="Unable create directory $repo $!\n";
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

    return &sign_repo( $opts, $repo );
}

sub add_packages {

    my $opts     = shift;
    my $repo     = shift;
    my $packages = shift;

    my @packages = split( /\s+/, $packages );
    my $status;

    unless( scalar @packages ) {
        $opts->{LASTERROR} = "Attempt to add without providing any rpm file arguments.\n";
        return 1;
    }

    # verify repopath and apache conf - from create
    return 1 if ( &verify_repo_creation( $opts, $repo ) );

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

    return $status if ( $status = &update_repo( $opts, $repo ) );

    return &sign_repo( $opts, $repo );
}

sub update_repo {

    my $opts = shift;
    my $repo = shift;

    my $status;

    # verify repopath and apache conf - from create
    return 1 if ( &verify_repo_creation( $opts, $repo ) );

    if (-f "$repo/repodata/repomd.xml.asc") {
        unlink("$repo/repodata/repomd.xml.asc");
    }

    system("/usr/bin/createrepo -q $repo &> /dev/null");

    return &sign_repo( $opts, $repo );
}

sub remove_repo {
 
    my $opts = shift;
    my $repo = shift;

    my $base =  basename("$repo");

    # verify only that the name is a dir under the byum directory
    unless ( $repo =~ m|byum| and -d $repo ) {
        $opts->{LASTERROR} = "Unable to remove non-byum or non-directory $base\n";
        return 1;
    }
    rmtree($repo);
    unlink("/etc/apache2/conf.d/$base.conf");

    return 0;
}


sub sign_repo {

    my $opts = shift;
    my $repo = shift;

    return 1 if ( &verify_repo_creation( $opts, $repo ) );

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

    my $opts = shift;
    my $repo = shift;

    my $repopath = "$repo/repodata";
    my $base = basename( $repo );

    $opts->{LASTERROR} = "Missing repo dir $repopath\n"
        unless (-d $repopath);

    $opts->{LASTERROR} .= "Missing apache repo config for $base.\n"
        unless (-f "/etc/apache2/conf.d/$base.conf");

    if ( $opts->{LASTERROR} ne "" ) {
        $opts->{LASTERROR} .= "Recommend 'barepo create $base'.\n";
        return 1;
    }

    return 0;
}

sub verify_repo_repodata {

    my $opts = shift;
    my $repo = shift;

    my $repopath = "$repo/repodata";
    my $base = basename( $repo );

    my @repofiles = qw| filelists.xml.gz
                        primary.xml.gz
                        repomd.xml
                        other.xml.gz
                      |;

    foreach my $file (@repofiles) {
        unless (-f "$repopath/$file" ) {
            $opts->{LASTERROR} .= "Missing repo file $file\n";
        }
    }

    if ( $opts->{LASTERROR} ne "" ) {
        $opts->{LASTERROR} .= "Recommend 'barepo update $base' to regenerate.\n";
        return 1;
    }

    return 0;
}

sub verify_repo_sign {

    my $opts = shift;
    my $repo = shift;

    my $repopath = "$repo/repodata";
    my $base = basename( $repo );

    my @repofiles = qw| repomd.xml.asc
                        repomd.xml.key
                      |;

    foreach my $file (@repofiles) {
        unless (-f "$repopath/$file" ) {
            $opts->{LASTERROR} .= "Missing repo sig file $file\n";
        }
    }

    if ( $opts->{LASTERROR} ne "" ) {
        $opts->{LASTERROR} .= "Recommend 'barepo update $base' to sign.\n";
        return 1;
    }

    my $gpghome = "/usr/share/baracus/gpghome";

    my $status = system("gpg2", "--homedir=$gpghome/.gnupg/",
                        "--verify", "$repopath/repomd.xml.asc" );

    if ( $status ) {
        $opts->{LASTERROR} = "Failed gpg sig check. Recommend 'barepo update $base'\n";
        return 1;
    }

    return 0;
}

1;

__END__

=head1 AUTHOR

Daniel Westervelt, E<lt>dwestervelt@novellE<gt>
David Bahi, E<lt>dbahi@novellE<gt>

=cut
