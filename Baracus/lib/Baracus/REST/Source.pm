package Baracus::REST::Source;

use 5.006;
use strict;
use warnings;

use Dancer qw( :syntax);

use Baracus::State  qw( :vars :admin );
use Baracus::Source qw( :vars :subs );

#use Baracus::REST::Aux qw( :subs );

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
                source_list
                source_add
                source_remove
                source_update
                source_verify
                source_enable
                source_disable
         )],
         );

    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

###########################################################################
##
## Main Source REST Subroutines (list/add/remove/update/verify)

sub source_list() {

    my $distro = params->{distro};
#    $distro = &normalize_verb( $distro );

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    # my $rtype = vars->{rtype};

    my $returnList = "";
    my %returnHash;

    foreach my $adistro ( reverse sort &baxml_distros_getlist( $opts ) ) {
        my $dh = &baxml_distro_gethash( $opts, $adistro );

        ## Determine current status
        my $dbref = &get_db_source_entry( $opts, $adistro );
        my $status;

        if ( defined $dbref and
             defined $dbref->{status} ) {
            $status = $baState{ $dbref->{status} };
        } else {
            $status = $baState{ BA_NONE };
        }

        ## Build up return based on request
        if ( ($adistro eq $distro) && ($status ne $baState{ BA_NONE }) && ($status ne $baState{ BA_ADMIN_REMOVED }) ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{description} = $dh->{description};
        } elsif ( ($distro eq "disabled") && ($status eq ($baState{ BA_DISABLED })) ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{description} = $dh->{description};
        } elsif ( ($distro eq "enabled") && ($status eq ($baState{ BA_ADMIN_ENABLED })) ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{description} = $dh->{description};
        } elsif ( ($distro eq "removed") && ($status eq ($baState{ BA_REMOVED })) ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{description} = $dh->{description};
        } elsif ( ($distro eq "none") && ($status eq ($baState{ BA_NONE })) ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{description} = $dh->{description};
        } elsif ( $distro eq "all" ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{description} = $dh->{description};
        }
    }

    if ( request->{accept} =~ m|text/html| ) {
        return $returnList;
    } elsif ( request->{accept} eq 'text/xml' ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub source_add() {

    my $distro = params->{distro};
    #    $distro = &normalize_verb( $distro );

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $loopback = 1;
    my $addons = "";
    my $isos;
    my $check = 0;
    my $checkhr = {};

    # my $rtype = vars->{rtype};

    my $sdk = get_distro_sdk( $opts, $distro );

    # do we have an sdk for this base
    if ( defined $sdk ) {
        if ( not $addons ) {
            # no other addons specified
            $addons = $sdk;
        } elsif ( $addons !~ m/$sdk/ ) {
            # add sdk not specified in addons
            $addons = "$sdk " . $addons;
        }
    }

    my $daisohr = &verify_iso( $opts, $distro, $addons, $isos, $check, $checkhr );

    unless ( defined $daisohr ) {
        status 'error';
        return $opts->{LASTERROR};
    }

    unless ( &make_paths( $opts, $distro, $addons, $daisohr, $loopback ) ) {
        status 'error';
        return $opts->{LASTERROR};
    }

    unless ( &create_build( $opts, $distro ) )  {
        status 'error';
        return $opts->{LASTERROR};
    }

    unless ( $loopback ) {
        unless ( &streamline_install( $opts, $distro ) ) {
            status 'error';
            return $opts->{LASTERROR};
        }
    }

    unless ( &add_build_service( $opts, $distro, $addons ) ) {
        status 'error';
        return $opts->{LASTERROR};
    }

    unless ( &add_bootloader_files( $opts, $distro ) )  {
        status 'error';
        return $opts->{LASTERROR};
    }


    unless ( &source_register( $opts, 'add', $distro, $addons ) )  {
        status 'error';
        return $opts->{LASTERROR};
    }

    if ( request->{accept} =~ m|text/html| ) {
        return "Added $distro<br>"
    } elsif ( request->{accept} eq "text/xml" ) {
        my @returnArray = ("Added", "$distro");
        return \@returnArray;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }
}

sub source_remove() {

    use File::Path;

    my $distro = params->{distro};
#    $distro = &normalize_verb( $distro );

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    #  my $rtype = vars->{rtype};

    my $distroList = "";
    my @distroArray;

    my $command = "remove";
    my $addons = "";
    my @addons;
    my $share;
    my $is_loopback = "";
    my $ret = 0;

    @ARGV = @_;

#    $addons = $multiarg{ 'addons' } if (defined $multiarg{ 'addons' });

    ## Test if selection is valid
    ##
    $distro = lc $distro;
    unless ( &check_distro( $opts, $distro ) )  {
        status 'error';
        return $opts->{LASTERROR};
    }

    # tempting - but don't put sdk in $addons here or it will be
    # removed even if only a different addon was to be removed leaving
    # the base and maybe other addons in place
    #

#    if ( ( $distro eq "all" ) and $addons ) {
#        $distroList = "Unsafe mix of --all and --addon <addon> usage";
#        return 1;
#    }

    if ( $distro eq "all" ) {
        my $dh =  &baxml_distro_gethash( $opts, $distro );
        @addons = @{$dh->{basedisthash}->{addons}};
        $addons = join " ", @addons;
#        print "working with 'all': $addons\n" if $opts->{debug};
    } else {
        @addons = split( /\s+/, $addons );

        # only check addons passed if not removing all
        if ( scalar @addons ) {
#            print "Calling routine to verify addon(s) passed\n";
            unless ( &check_addons( $opts, $distro, $addons ) ) {
                status 'error';
                return $opts->{LASTERROR};
            }
        }
    }

    if ( scalar @addons ) {
        foreach my $addon ( @addons ) {
            my @shares;
#            print "Removing addon $addon\n";
            ($share, undef) = &get_distro_share( $opts, $addon );
            $is_loopback = &get_loopback( $opts, $share );
            unless (defined $is_loopback) {
                status 'error';
                return $opts->{LASTERROR};
            }
            unless (&remove_build_service( $opts, "", $addons) ) {
                status 'error';
                return $opts->{LASTERROR};
            }

#            print "$share ... removing\n" if $opts->{verbose};
            debug "is_loopback $is_loopback for share $share";

            # you know - we get out of sync sometimes...
            # and it doesn't hurt to umount a non-mounted dir

            system("umount $share");
            rmtree($share);
        }
        unless ( &source_register( $opts, $command, "", $addons) ) {
            status 'error';
            return $opts->{LASTERROR};
        }
    }

    # only remove base if no addons specified or --all passed
    if ( not scalar @addons or $opts->{all} ) {
        my $dh = &baxml_distro_gethash( $opts, $distro );

        # need to check if removing base which has dependent add-ons
        my @addons = &list_installed_addons( $opts, $distro );

        # handle default 'unspecified' sdk as transparent member of base
        my $sdk = &get_distro_sdk( $opts, $distro );

        if ( ( scalar @addons > 1 ) or
             ( scalar @addons and not defined $sdk ) or
             ( scalar @addons and $addons[0] ne $sdk ) ) {
            $opts->{LASTERROR} = "Remove these addons before removing $distro (or use --all)\n\t" . join ("\n\t", @addons ) . "\n";
            status 'error';
            return $opts->{LASTERROR};
        }
        if ( scalar @addons and defined $sdk and $addons[0] eq $sdk ) {
            ($share,undef) = &get_distro_share( $opts, $sdk );
            $is_loopback = &get_loopback( $opts, $share );
            unless ( defined $is_loopback )  {
                status 'error';
                return $opts->{LASTERROR};
            }
            unless (&remove_build_service( $opts, "", $sdk) ) {
                status 'error';
                return $opts->{LASTERROR};
            }
            debug "is_loopback $is_loopback for share $share";
            debug "$share ... removing\n" if $opts->{verbose};

            # you know - we get out of sync sometimes...
            # and it doesn't hurt to umount a non-mounted dir

            system("umount $share");
            rmtree($share);

            &source_register( $opts, $command, "", $sdk);
        }
        ($share,undef) = &get_distro_share( $opts, $distro );
        $is_loopback = &get_loopback( $opts,  $share );
        &remove_build_service( $opts, $distro, $addons);
        debug "is_loopback $is_loopback for share $share";
        debug "$share ... removing\n" if $opts->{verbose};

        # you know - we get out of sync sometimes...
        # and it doesn't hurt to umount a non-mounted dir

        system("umount $share");
        rmtree($share);

        unless ( &remove_bootloader_files( $opts, $distro ) ) {
            status 'error';
            return $opts->{LASTERROR};
        }
        unless ( &source_register( $opts, $command, $distro, $addons) ) {
            status 'error';
            return $opts->{LASTERROR};
        }
    }

    if ( request->{accept} =~ m|text/html| ) {
        return "Removed $distro<br>"
    } elsif ( request->{accept} eq "text/xml" ) {
        my @returnArray = ("Removed", "$distro");
        return \@returnArray;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }
}

sub source_update() {

    my $distro = params->{distro};
    #    $distro = &normalize_verb( $distro );

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $sharetype = params->{sharetype};
    my $shareip = params->{shareip};

    # my $rtype = vars->{rtype};

    my $returnString = "";
    my %returnHash;

    my $addons = "";
    my @addons;
    my $dbref;
    my $ret = 0;

    ## Test if selection is valid
    ##
    #    $distro = lc $distro;
    #    &check_distro( $opts, $distro );

    # unless (( $shareip ne "" ) || ( $sharetype ne "" ))  {
    #    $opts->{LASTERROR} = "update requires either --sharetype or --shareip\n";
    #    return 1;
    # }

    # $addons = $multiarg{ 'addons' } if (defined $multiarg{ 'addons' });

    # if ( $opts->{all} and $addons ) {
    #         $opts->{LASTERROR} = "Unsafe mix of --all and --addon <addon> usage\n";
    #         return 1;
    # }

    # if ( $sharetype ne "") {
    #     unless (( $sharetype eq "nfs" ) || ( $sharetype eq "http" )) {
    #         $opts->{LASTERROR} = "$sharetype not valid. (supported types: nfs/http) \n";
    #         return 1;
    #     }
    # }

    # if ( $opts->{all} ) {
    #      my $dh =  &baxml_distro_gethash( $opts, $distro );
    #      @addons = @{$dh->{basedisthash}->{addons}};
    #      $addons = join " ", @addons;
    #      print "working with 'all': $addons\n" if $opts->{debug};
    #  } else {
    #      @addons = split( /\s+/, $addons );

    # only check addons passed if not removing all
    #      if ( scalar @addons ) {
    #          print "Calling routine to verify addon(s) passed\n";
    #          return 1 if &check_addons( $opts, $distro, $addons );
    #      }
    #  }

    if ( scalar @addons ) {
        foreach my $addon ( @addons ) {
            my @shares;
            #          print "Updating addon $addon\n";
            if ( $sharetype ne "" ) {
                $dbref = &get_db_source_entry( $opts, $addon );
                &remove_build_service( $opts, $addon );
                &update_db_source_entry( $opts, $sharetype, "", $addon);
                &update_db_iso_entry( $opts, $addon, $sharetype );
                #      &remove_build_service( $opts, $addon );
                &add_build_service( $opts, $addon );
                print "$sharetype ... Updated\n" if $opts->{verbose};
            }
            if ( $shareip ne "" ) {
                #              print "Update ShareIP\n";
                &update_db_source_entry( $opts, "", $shareip, $addon);
            }
        }
    }

    # only update base if no addons specified or --all passed
    if ( not scalar @addons or $opts->{all} ) {
        my $dh = &baxml_distro_gethash( $opts, $distro );

        # need to check if updating base which has dependent add-ons
        my @addons = &list_installed_addons( $opts, $distro );

        # handle default 'unspecified' sdk as transparent member of base
        #  my $sdk = &get_distro_sdk( $opts, $distro );
        my $sdk;

        if ( ( scalar @addons > 1 ) or
             ( scalar @addons and not defined $sdk ) or
             ( scalar @addons and $addons[0] ne $sdk ) ) {
            $opts->{LASTERROR} = "Update these addons before Updating $distro (or use --all)\n\t" . join ("\n\t", @addons ) . "\n";
            return 1;
        }
        if ( scalar @addons and defined $sdk and $addons[0] eq $sdk ) {
            if ( $sharetype ne "" ) {
                $dbref = &get_db_source_entry( $opts, $sdk );
                &remove_build_service( $opts, $sdk );
                &update_db_source_entry( $opts, $sharetype, "", $sdk);
                &update_db_iso_entry( $opts, $sdk, $sharetype );
                # &remove_build_service( $opts, $sdk );
                &add_build_service( $opts, $sdk );
                #              print "$sharetype ... updated\n" if $opts->{verbose};
            }
            if ( $shareip ne "" ) {
                #              print "Update ShareIP\n";
                &update_db_source_entry( $opts, "", $shareip, $sdk);
            }
        }
        if ( $sharetype ne "" ) {
            $dbref = &get_db_source_entry( $opts, $distro );
            &remove_build_service( $opts, $distro );
            &update_db_source_entry( $opts, $sharetype, "", $distro );
            &update_db_iso_entry( $opts, $distro, $sharetype );
            #         &remove_build_service( $opts, $distro );
            &add_build_service( $opts, $distro );
            #          print "$sharetype ... updated\n" if $opts->{verbose};
        }
        if ( $shareip ne "" ) {
            #              print "Update ShareIP\n";
            &update_db_source_entry( $opts, "", $shareip, $distro );
        }
    }

    return 0;

}

sub source_verify() {

    my $distro = params->{distro};
    #    $distro = &normalize_verb( $distro );

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    # my $rtype = vars->{rtype};

    my $returnString = "";
    my %returnHash;

    my $dbref = &get_db_source_entry( $opts, $distro );

    unless ( defined $dbref and
             $dbref->{status} and
             $dbref->{status} != BA_ADMIN_REMOVED ) {
        $opts->{LASTERROR} = "No entry found for $distro\n";
        return 1;
    }

    $returnString .= "Target: $dbref->{distroid}<br>";
    $returnHash{target} = $dbref->{distroid};

    $returnString .= "Created: $dbref->{creation}<br>";
    $returnHash{creation} = $dbref->{creation};

    $returnString .= "Modified: $dbref->{change}<br>" if defined $dbref->{change};
    $returnHash{change} = $dbref->{change} if defined $dbref->{change};

    $returnString .= "Status: $baState{$dbref->{status}}<br>";
    $returnHash{status} = $dbref->{status};

    my $service_status = "";
    if ( &check_service( $opts, $dbref->{sharetype} ) ) {
        $service_status = "not running";
    } else {
        $service_status = "ok";
    }
    $returnHash{servicestatus} = $service_status;

    $returnString .= "Service: $dbref->{sharetype} $service_status<br>";
    $returnHash{sharetype} = $dbref->{sharetype};

    $returnString .= "Share IP: $dbref->{shareip}<br>";
    $returnHash{shareip} = $dbref->{shareip};


    my $oldshare = "";
    foreach my $prod ( &baxml_products_getlist( $opts, $distro ) ) {
        my ($netcfg, $confdir, $template, $share, $state) =
            &check_service_product( $opts, $distro, $prod, $dbref->{sharetype} );

        if ( $oldshare ne $share ) {
            $oldshare = $share;

            my $share_status = "";
            if ( not $state ) {
                $share_status =  "missing";
            } else {
                $share_status = "ok";
            }
            $returnHash{sharestatus} = $share_status;
            $returnString .= "Share: $netcfg $share_status<br>";
            $returnHash{share} = $netcfg;

            my $path_status = "";
            if ( not -d $share ) {
                $path_status = "missing";
            } else {
                $path_status = "ok";
            }
            $returnHash{pathstatus} = $path_status;
            $returnString .= "Path: $share $path_status<br>";
            $returnHash{path} = $share;
        }
    }

    my $dh = &baxml_distro_gethash( $opts, $distro );
    my $base = $dh->{basedist};

    my $state = &sqlfs_getstate( $opts, "linux.$base" );
    my $kernel_status = "";
    if ( not $state ) {
        $kernel_status = "missing";
    } else {
        if ( $state != 1 ) {
            $kernel_status = "disabled";
        } else {
            $kernel_status = "ok";
        }
    }
    $returnHash{kernelstatus} = $kernel_status;
    $returnString .= "Kernel: linux.$base $kernel_status<br>";
    $returnHash{kernel} = "linux.$base";

    $state = &sqlfs_getstate( $opts, "initrd.$base" );
    my $ramdisk_status = "";
    if ( not $state ) {
        $ramdisk_status = "missing";
    } else {
        if ( $state != 1 ) {
            $ramdisk_status = "disabled";
        } else {
            $ramdisk_status = "ok";
        }
    }
    $returnHash{ramdiskstatus} = $ramdisk_status;
    $returnString .= "Ramdisk: initrd.$base $ramdisk_status<br>";
    $returnHash{initrd} = "initrd.$base";

    if ( request->{accept} =~ m|text/html| ) {
        return $returnString;
    } elsif ( request->{accept} eq "text/xml" ) {
        return \%returnHash;
    } else {
        return "error";
    }

}

sub source_enable() {

    my $distro = params->{distro};
    #    $distro = &normalize_verb( $distro );

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    # my $rtype = vars->{rtype};

    my $dbref = &get_db_source_entry( $opts, $distro );
    unless ( defined $dbref->{distroid} and
             ( $dbref->{distroid} eq $distro ) ) {
        $opts->{LASTERROR} = "Unable to find entry for $distro to enable\n";
        return 1;
    }
    unless ( defined $dbref->{status} and
             ( $dbref->{status} != BA_ADMIN_REMOVED ) ) {
        $opts->{LASTERROR} = "Unable to enable $distro not yet added.\n";
        return 1;
    }
    if ( $dbref->{status} != BA_ADMIN_DISABLED ) {
        $opts->{LASTERROR} = "Unable to enable $distro not disabled.\n";
        return 1;
    }

    # do the add_build_service - less code
    &add_build_service( $opts, $distro );

    &source_register( $opts, 'enable', $distro );

    if ( request->{accept} =~ m|text/html| ) {
        return "Enabled $distro<br>"
    } elsif ( request->{accept} eq "text/xml" ) {
        my @returnArray = ("Enabled", "$distro");
        return \@returnArray;
    } else {
        return "error";
    }

}

sub source_disable() {

    my $distro = params->{distro};
    #    $distro = &normalize_verb( $distro );

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

   # my $rtype = vars->{rtype};

    my $dbref = &get_db_source_entry( $opts, $distro );
    unless ( defined $dbref->{distroid} and
             ( $dbref->{distroid} eq $distro ) ) {
        $opts->{LASTERROR} = "Unable to find entry for $distro to enable\n";
        return 1;
    }
    unless ( defined $dbref->{status} and
             ( $dbref->{status} != BA_ADMIN_REMOVED ) ) {
        $opts->{LASTERROR} = "Unable to disable $distro not yet added.\n";
        return 1;
    }
    if ( $dbref->{status} != BA_ADMIN_ENABLED ) {
        $opts->{LASTERROR} = "Unable to disable $distro not enabled.\n";
        return 1;
    }

    # do the remove_build_service - less code
    &remove_build_service( $opts, $distro );

    &source_register( $opts, 'disable', $distro);

    if ( request->{accept} =~ m|text/html| ) {
        return "Disabled $distro<br>"
    } elsif ( request->{accept} eq "text/xml" ) {
        my @returnArray = ("Disabled", "$distro");
        return \@returnArray;
    } else {
        return "error";
    }

}

1;
