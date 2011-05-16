package Baracus::Services;

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

use Baracus::Config qw( :vars :subs );

=pod

=head1 NAME

B<Baracus::Services> - subroutines for managing services Baracus requires

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
                enable_service
                disable_service
                add_cifs_perl
                add_apache2_perl
                apache2_listen_conf
                add_www_sudoers
                check_service
            )],
         );

    Exporter::export_ok_tags('subs');
}


our $VERSION = '2.01';

sub enable_service
{
    my $opts      = shift;
    my $sharetype = shift;
    my $status = 1;

    debug "Enabling $sharetype ... \n" if $opts->{verbose};

    $sharetype =~ s/cifs/smb/;
    $sharetype =~ s/http/apache2/;
    $sharetype =~ s/^nfs$/nfsserver/;
    eval {
       # system("chkconfig $sharetype on >& /dev/null") == 0 or die;
        if ( check_service( $opts, $sharetype ) == 0 ) {
            # could have also done this to avoid nfs reload
            # need avoidance check here anyway... else bad
            if ( $sharetype !~ m/(nfs|nfsserver)/ ) {
                system("/etc/init.d/$sharetype reload") == 0 or die;
            }
        } else {
            system("/etc/init.d/$sharetype start");
        }
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }
    return $status;
}

sub disable_service
{
    my $opts      = shift;
    my $sharetype = shift;
    my $status = 1;

    debug "Disabling $sharetype ... \n" if $opts->{verbose};

    $sharetype =~ s/cifs/smb/;
    $sharetype =~ s/http/apache2/;
    $sharetype =~ s/^nfs$/nfsserver/;
    eval {
        system("chkconfig $sharetype off >& /dev/null") == 0 or die;
        if ( check_service( $opts, $sharetype) == 0 ) {
            system("/etc/init.d/$sharetype stop") == 0 or die;
        }
    };
    if ( $@ ) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
        $status = 0;
    }
    return $status;
}


# status returns 0 if enabled
sub check_service
{
    my $opts      = shift;
    my $sharetype = shift;

    $sharetype =~ s/cifs/smb/;
    $sharetype =~ s/http/apache2/;
    $sharetype =~ s/^nfs$/nfsserver/;

    system("/etc/init.d/$sharetype status >& /dev/null");
}

sub add_cifs_perl
{
    use Baracus::Config qw( :vars );

    my $startnet_in = "$baDir{data}/templates/startnet.cmd";
    my $startnet_out= "$baDir{builds}/winstall/install/startnet.cmd";
    my $smbconf_src = "$baDir{data}/templates/winstall.conf";
    my $smbconf_dst = "/etc/samba/winstall.conf";
    my $sysconf_in  = "/etc/samba/smb.conf.bk";
    my $sysconf_out = "/etc/samba/smb.conf";
    my $mods = 1;
    my $restart = 0;

    if ( %baVar and $baVar{serverip} ) {
        if ( -f $startnet_out ) {
            print STDERR "(re)generating $startnet_out\n";
        }
        # slurp carefully
        # the use of local() sets $/ to undef and when the scope exits
        # it will revert $/ back to its previous value (most likely ``\n'')
        open( my $fhin, "<$startnet_in" ) or
            die "Unable to open $startnet_in: $!\n";
        my $startnet = do { local( $/ ) ; <$fhin> } ;
        close $fhin;

        while ( my ($key, $value) = each %baVar ) {
            $key =~ tr/a-z/A-Z/;
            $key = "__$key\__";
            $startnet =~ s/$key/$value/g;
        }

        open( my $fhout, ">$startnet_out" ) or
            die "Unable to open $startnet_out: $!\n";
        print $fhout $startnet;
        close $fhout;
    } else {
        print STDERR "/etc/sysconfig/baracus needs setting for SERVER_IP\n";
    }


    if ( ! -f $smbconf_dst ) {
        copy ($smbconf_src, $smbconf_dst);
        $restart = 1;
    }

    copy ($sysconf_out, $sysconf_in);
    open (SYSCONF_IN, "<$sysconf_in")
        or die "Unable to open $sysconf_in: $!\n";
    open (SYSCONF_OUT, ">$sysconf_out")
        or die "Unable to open $sysconf_out: $!\n";
    while (<SYSCONF_IN>) {
        $mods = 0 if (m|\s*${smbconf_dst}\s*$|);
        print SYSCONF_OUT $_;
    }
    close SYSCONF_IN;
    if ( $mods ) {
        $restart = 1;
        print SYSCONF_OUT "\ninclude=${smbconf_dst}\n";
    }
    close SYSCONF_OUT;
    unlink $sysconf_in;
    return $restart;
}

sub add_apache2_perl
{
    my $sysconf_in  = "/etc/sysconfig/apache2.bk";
    my $sysconf_out = "/etc/sysconfig/apache2";
    my $mods;
    my $restart = 0;

    copy ($sysconf_out, $sysconf_in);
    open (SYSCONF_IN, "<$sysconf_in")
        or die "Unable to open $sysconf_in: $!\n";
    open (SYSCONF_OUT, ">$sysconf_out")
        or die "Unable to open $sysconf_out: $!\n";
    while (<SYSCONF_IN>) {
        if (m/^(\s*APACHE_MODULES\s*=\s*"\s*)([^"]*)(\s*"\s*)$/) {
            my $pre = $1;
            $mods = $2;
            my $post = $3;
            if ( ! ( $mods =~ m/\s*perl\s*/ ) ) {
                $mods .= " perl";
                $_ = $pre . $mods . $post ;
                $restart = 1;
            }
        }
        print SYSCONF_OUT $_;
    }
    close SYSCONF_IN;
    close SYSCONF_OUT;
    unlink $sysconf_in;
    return $restart;
}

sub apache2_listen_conf
{
    my $listenconf_in  = "/etc/apache2/listen.conf.bk";
    my $listenconf_out = "/etc/apache2/listen.conf";
    my $restart = 0;

    use Baracus::Config qw( %baVar );

    if ( %baVar and $baVar{serverip} ) {
	my $mods = $baVar{serverip};

	print STDERR "(re)generating $listenconf_out\n";

	# listen.conf support systems with more than one IP and use BUILDIP

	copy ($listenconf_out, $listenconf_in);
	open (LISTENCONF_IN, "<$listenconf_in")
	    or die "Unable to open $listenconf_in: $!\n";
	open (LISTENCONF_OUT, ">$listenconf_out")
	    or die "Unable to open $listenconf_out: $!\n";
	while (<LISTENCONF_IN>) {
	    if (m|^(\s*[Ll]isten\s+)([0-9.]+:)?([0-9]+)$|) {
		$_ = $1 . $mods . ':' . $3 . "\n";
		if (!defined($2) || "$mods:" ne $2) {
		    $restart = 1;
		}
	    }
	    print LISTENCONF_OUT $_;
	}
	close LISTENCONF_IN;
	close LISTENCONF_OUT;
	unlink $listenconf_in;
    } else {
	print STDERR "/etc/sysconfig/baracus needs setting for SERVER_IP\n";
    }

    return $restart;
}

sub add_www_sudoers
{
    my $www_search = qr|^\s*%www\s*ALL\s*=\s*\(\s*ALL\s*\)\s*NOPASSWD\s*:\s*ALL|;
    my $www_line = qq|\n%www	ALL=(ALL) NOPASSWD: ALL\n|;
    my $sudoers  = "/etc/sudoers";
    my $found = 0;

    open (SUDOERS, "+<$sudoers")
        or die "Unable to open $sudoers: $!\n";
    while (<SUDOERS>) {
        if (m/$www_search/) {
            $found = 1;
        }
    }
    if (not $found) {
        print SUDOERS $www_line;
    }
    close SUDOERS;
}

1;

__END__
