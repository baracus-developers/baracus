package BaracusSYSLOG;

use 5.006;
use strict;
use File::Copy;
use File::Basename;
use File::Path;

sub enable_remote_logging {

    my ($logpath, $logconf, $logip) = @_;
    my $flag = 0;
    my $source = "baracus_ext";

    unless ( -d "$logpath/YaST2" ) {
        mkdir "$logpath/YaST2", 0755
            or die ("Cannot create: $! \n");
    }

    open(FILE, "<$logconf");
    my $log = join '', <FILE>;
    close(FILE);

    ## Determine if remote logging (udp) src already available
    ##
    ## Test Dave's code here

    ## if udp already enabled match source name and use it in $source below
    #  if (UDP) {
    #  $source = "";
    #  $flag = 1;
    #   }

    ## test if udp is already configured and add new source if not
    ##
    open(FILE, ">>$logconf");
    unless ($flag) {
        print FILE "##BARACUS_BEGIN##\n";
        print FILE "source baracus_ext {\n";
        print FILE "    udp(ip(\"$logip\") port(514));\n";
        print FILE "}\n\n";
    }
    
    ## Add required logging for baracus
    ## Note: syslog-ng ver3.x support include files
    ##
    if ($flag) {
        print FILE "##BARACUS_BEGIN##\n";
    }
    print FILE "filter f_daemon     { facility(daemon); };\n\n";
    print FILE "destination hosts { \n";
    print FILE "   file(\"/var/spool/baracus/logs/YaST2/\$HOST/\$YEAR-\$MONTH-\$DAY/y2log\" \n";
    print FILE "   owner(root) group(root) perm(0600) dir_perm(0700) create_dirs(yes)); \n ";
    print FILE "}; \n";
    print FILE "log { source($source); filter(f_daemon); destination(hosts); };\n";
    print FILE "##BARACUS_END##\n";
    close(FILE);

}

sub disable_remote_logging {

    my $logconf = shift;

    ## Test syslog-ng for BARACUS
    ##
    open(FILE, "<$logconf");
    my $log = join '', <FILE>;
    close(FILE);

    $log =~ s/##BARACUS_BEGIN(.*?)BARACUS_END##//gs;
 
    open(FILE, ">$logconf");
    print FILE $log;
    close(FILE);

}

sub enable_apparmor() {

    my $aflag = 0;

    ## Test for apparmor
    ##
    if (-f "/etc/init.d/boot.apparmor") {
        open(PIPE, "/etc/init.d/boot.apparmor status|")
        while(<PIPE>) {
           if (/syslog-ng/) {
               my $aflag = 1;
           }
        }
        close(PIPE);
    }

    if ($aflag) {
        ## Need to add "@(CHROOT_BASE)/var/spool/baracus/logs/YaST/** w,"
        ## to /etc/apparmor.d/sbin.syslog-ng
        ##
    }
        
     
}

1;
