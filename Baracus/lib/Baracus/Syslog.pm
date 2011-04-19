package Baracus::Syslog;

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

BEGIN {
  use Exporter ();
  use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
  @ISA         = qw(Exporter);
  @EXPORT      = qw();
  @EXPORT_OK   = qw();
  %EXPORT_TAGS =
      (
       subs =>
       [ qw(
               enable_remote_logging
               disable_remote_logging
               enable_apparmor_logging
               disable_apparmor_logging
           ) ]
       );
  Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

our $LASTERROR="";

sub error {
    return $LASTERROR;
}

sub enable_remote_logging {

    my ($logpath, $logconf, $logip) = @_;
    my $flag = 0;
    my $skip = 0;
    my $source = "baracus_ext";

    open(FILE, "<$logconf") or die "Unable to open $logconf: $!\n";

    ## Determine if remote logging (udp) src already available
    ##
    my $composed;
    while ( my $line = readline FILE ) {
        $line =~ s|^\s*||;
        $line =~ s|}\s*;\s*|};|;
        if ( $line =~ m|##BARACUS_BEGIN##|) {  # not only is it available,
            $skip = 1;                         # but we put it here. get out.
            last;
        }
        next if ( $line =~ m|^#| );
        $line =~ s|[ \t\n]+| |g;

        if ($line =~ s|(.*)};(.*)|${1}\};\n${2}|g) {
            $composed .= "${1}\};\n";
            if ( $composed =~ m|source\s+(\S+)\s*{.*udp\s*\(\s*ip\s*\(\s*"(\d+.\d+.\d+.\d+)"| ) {
                $flag = 1;
                $source = $1;
                $logip = $2;
            }
            $composed = $2;
        } else {
            $composed .= $line;
        }
    }
    close(FILE);

    if ( $skip ) {
        $LASTERROR = "Baracus settings already configured in $logconf\n";
        return 0;
    }

    ## test if udp is already configured and add new source if not
    ##
    open(FILE, ">>$logconf") or die "Unable to open $logconf: $!\n";

    if ($flag) {
        print FILE "##BARACUS_BEGIN##\n";
    }
    else {
        print FILE "##BARACUS_BEGIN##\n";
        print FILE "source baracus_ext {\n";
        print FILE "    udp(ip(\"$logip\") port(514));\n";
        print FILE "};\n\n";
    }

    ## Add required logging for baracus
    ## Note: syslog-ng ver3.x support include files
    ##
#    print FILE "filter f_daemon     { facility(daemon); };\n\n";
    print FILE "destination hosts { \n";
    print FILE "   file(\"$logpath/\$HOST/\$YEAR-\$MONTH-\$DAY.log\" \n";
    print FILE "   owner(root) group(root) perm(0600) dir_perm(0700) create_dirs(yes)); \n ";
    print FILE "}; \n";
#    print FILE "log { source($source); filter(f_daemon); destination(hosts); };\n";
    print FILE "log { source($source); destination(hosts); };\n";
    print FILE "##BARACUS_END##\n";
    close(FILE);

    return 1;
}

sub disable_remote_logging {

    my $logconf = shift;

    ## Test syslog-ng for BARACUS
    ##
    open(FILE, "<$logconf") or die "Unable to open $logconf: $!\n";
    my $log = join '', <FILE>;
    close(FILE);

    unless ($log =~ s/##BARACUS_BEGIN(.*?)BARACUS_END##//gs ) {
        $LASTERROR = "Baracus settings not present in $logconf\n";
        return 0;
    }

    open(FILE, ">$logconf") or die "Unable to open $logconf: $!\n";
    print FILE $log;
    close(FILE);

    return 1;
}

sub apparmor_syslog_ng_isloaded {
    my $aflag = 0;

    ## Test for apparmor
    ##
    if (-f "/etc/init.d/boot.apparmor") {
        open(PIPE, "/etc/init.d/boot.apparmor status|");
        while (<PIPE>) {
            $aflag = 1 if (/syslog-ng/);
        }
        close(PIPE);
    }
    return $aflag;

}

sub enable_apparmor_logging
{

    return unless &apparmor_syslog_ng_isloaded();

    ## Need to add "@{CHROOT_BASE}/var/spool/baracus/logs/remote/** w,"
    ##

    my ($logpath, $logconf) = @_;
    my $found = 0;
    my $fh;

    open( $fh, "<", $logconf) or die "Unable to open $logconf: $!\n";
    while ( <$fh> ) {
        if ( m|  @\{CHROOT_BASE\}$logpath/\*\* w,| ) {
            $found = 1;
            last;
        }
    }
    close( $fh );

    if ( $found ) {
        $LASTERROR = "Baracus settings already configured in $logconf\n";
        return 0;
    }

    # cant just append have to modify the { block }
    open( $fh, "<", $logconf) or die "Unable to open $logconf: $!\n";
    my @lines = <$fh>;
    close $fh;
    open( $fh, ">", $logconf) or die "Unable to open $logconf: $!\n";
    my $index = 0;
    foreach my $line ( @lines ) {
        if (( $line =~ m|^\s*$| ) && ( $lines[ $index + 1 ] =~ m|^(\s*}\s*)| )) {
            # end of block reached - print this line first
            print $fh "  @\{CHROOT_BASE\}$logpath/** w,\n";
        }
        $index += 1;
        print $fh $line;
    }
    close( $fh );

    return 1;
}

sub disable_apparmor_logging
{

    return unless &apparmor_syslog_ng_isloaded();

    ## Need to remove "@{CHROOT_BASE}/var/spool/baracus/logs/remote/** w,"
    ##

    my ($logpath, $logconf) = @_;
    my $found = 0;
    my $line;
    my $fh;

    open( $fh, "<", $logconf) or die "Unable to open $logconf: $!\n";
    while ( <$fh> ) {
        if ( m|  @\{CHROOT_BASE\}$logpath/\*\* w,| ) {
            $found = 1;
            last;
        }
    }
    close( $fh );

    unless ( $found ) {
        $LASTERROR = "Baracus settings not present in $logconf\n";
        return 0;
    }

    open( $fh, "<", $logconf) or die "Unable to open $logconf: $!\n";
    my @lines = <$fh>;
    close $fh;
    open( $fh, ">", $logconf) or die "Unable to open $logconf: $!\n";
    foreach $line ( @lines ) {
        print $fh $line
            unless ( $line =~ m|  @\{CHROOT_BASE\}$logpath/\*\* w,| );
    }
    close( $fh );

    return 1;
}

1;
