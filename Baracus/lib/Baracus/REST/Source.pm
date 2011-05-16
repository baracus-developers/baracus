package Baracus::REST::Source;

use 5.006;
use strict;
use warnings;

use Dancer qw( :syntax);

use Baracus::State  qw( :vars :admin );
use Baracus::Source qw( :vars :subs );
use Baracus::Config qw( :vars :subs );
use Baracus::Services qw( :subs );
use Baracus::Aux qw( :subs );

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
                source_detail
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
            $returnHash{$adistro}{type} = $dh->{type};
            $returnHash{$adistro}{description} = $dh->{description};
        } elsif ( ($distro eq "disabled") && ($status eq ($baState{ BA_DISABLED })) ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{type} = $dh->{type};
            $returnHash{$adistro}{description} = $dh->{description};
        } elsif ( ($distro eq "enabled") && ($status eq ($baState{ BA_ADMIN_ENABLED })) ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{type} = $dh->{type};
            $returnHash{$adistro}{description} = $dh->{description};
        } elsif ( ($distro eq "removed") && ($status eq ($baState{ BA_REMOVED })) ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{type} = $dh->{type};
            $returnHash{$adistro}{description} = $dh->{description};
        } elsif ( ($distro eq "none") && ($status eq ($baState{ BA_NONE })) ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{type} = $dh->{type};
            $returnHash{$adistro}{description} = $dh->{description};
        } elsif ( $distro eq "all" ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{type} = $dh->{type};
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

    # Build up extras (ie. addons, sdks and duds)
    my $extras = "";
#    $extras = $extras . " $multiarg{ addons }" if ( defined $multiarg{ addons } );
#    $extras = $extras . " $multiarg{ sdks }" if ( defined $multiarg{ sdks } );
#    $extras = $extras . " $multiarg{ duds }" if ( defined $multiarg{ duds } );
#    $extras =~ s/^\s+//;

    if ( $extras ) {
        debug "Calling routine to verify additional source(s) passed\n" if $opts->{verbose};
        return 1 if &check_extras( $opts, $distro, $extras );
    }

    # my $rtype = vars->{rtype};
    my $includes = &get_distro_includes( $opts, $distro );
    if ( defined $includes ) {
        my $incchk = &get_db_data( $opts, 'distro', $includes );
        unless ( defined $incchk->{state} ) {
            $extras = "$extras "  . $includes;
            $extras =~ s/^\s+//;
        }  # else include is already present in distro table
    }

    my $daisohr = &verify_iso( $opts, $distro, $extras, $isos, $check, $checkhr );

    unless ( defined $daisohr ) {
        status 'error';
        return $opts->{LASTERROR};
    }

    unless ( &make_paths( $opts, $distro, $extras, $daisohr, $loopback ) ) {
        status 'error';
        return $opts->{LASTERROR};
    }

    # Check to see if any extras are already installed
    my @extras = split( /\s+/, $extras );
    foreach my $item ( @extras ) {
        if ( &is_source_installed( $opts, $item) ) {
            $extras =~ s/$item\s*//;
        }
    }
    undef @extras;
    @extras = split( /\s+/, $extras );

    unless ( &add_build_service( $opts, $distro, $addons ) ) {
        status 'error';
        return $opts->{LASTERROR};
    }

    # Add base distro
    unless ( &is_source_installed( $opts, $distro ) ) {
        unless ( &add_bootloader_files( $opts, $distro ) ) {
            status 'error';
            return $opts->{LASTERROR};
        }
        unless ( &source_register( $opts, 'add', $distro ) ) {
            status 'error';
            return $opts->{LASTERROR};
        }
    }

    # Add all extras
    foreach my $extra ( @extras ) {
        my $eh = &get_db_data( $opts, 'distro', $extra );
        unless ( defined $eh ) {
            status 'error';
            return $opts->{LASTERROR};
        }

        if ( $eh->{type} == BA_SOURCE_DUD ) {
            unless ( &add_dud_initrd( $opts, $distro, $extra ) ) {
                status 'error';
                return $opts->{LASTERROR};
            }
        }
        unless ( &source_register( $opts, 'add', $extra ) ) {
            status 'error';
            return $opts->{LASTERROR};
        }
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

    my $opts = vars->{opts};
    unless ( $opts ) {
        $opts->{LASTERROR} = "'vars' not properly initialized";
        error $opts->{LASTERROR};
    }

    my $distroList = "";
    my @distroArray;

    my $command = "remove";
    my $extras = "";
    my @extras;
    my $shares;
    my $is_loopback = "";
    my $ret = 0;

    @ARGV = @_;

    # Build up extras
#    $extras = $extras . " $multiarg{ 'addons' }" if ( defined $multiarg{ 'addons' } );
#    $extras = $extras . " $multiarg{ 'sdks' }" if ( defined $multiarg{ 'sdks' } );
#    $extras = $extras . " $multiarg{ 'duds' }" if ( defined $multiarg{ 'duds' } );
#    $extras =~ s/^\s+// if ( defined $extras );

    my $is_extra_passed;
    $is_extra_passed = 1 if ( $extras );

    ## Test if selection is valid
    ##
    $distro = lc $distro;
    unless ( &check_distro( $opts, $distro ) )  {
        status 'error';
        error $opts->{LASTERROR};
    }

    my $dh =  &baxml_distro_gethash( $opts, $distro );

    if ( $distro eq "all" ) {
        @extras = @{$dh->{basedisthash}->{addons}} if (defined $dh->{basedisthash}->{addons} );
        foreach my $item ( @extras ) {
            if ( &is_source_installed( $opts, $item ) ) {
                $extras = $extras . " $item";
            }
        }
        $extras =~ s/^\s+//;
        debug "working with 'all': $extras\n" if $opts->{debug};
    } 

    ## Are there any extras not removed dependant on base
    if ( ( ! $extras ) and ( defined $distro ) ) {
        my @extchk = &list_installed_extras( $opts, $distro );
        foreach my $extchk (@extchk) {
            if ( $extchk eq &get_distro_includes( $opts, $distro ) ) { next; }
            if ( ! exists {map { $_ => 1 } @extras}->{$extchk} ) {
                $opts->{LASTERROR} =  "cannot remove $distro:\n\t$extchk installed and depends on $distro\n";
                error $opts->{LASTERROR};;
            }
        }
    }

    # do we include anything in this distros
    unless ( ( $is_extra_passed ) and ( ! $opts->{all} ) ) {
        my $includes = &get_distro_includes( $opts, $distro );
        if ( ( defined $includes ) and
             ( ! grep $includes, @extras ) ) {
            my $incchk = &get_db_data( $opts, 'distro', $includes );
            unless ( defined $incchk->{state} ) {
                $extras = "$extras "  . $includes;
                $extras =~ s/^\s+//;
            }  # else include is already present in distro table
        }
    }
    undef @extras;
    @extras = split( /\s+/, $extras );

    ## only check extras passed if not removing all
    if ( scalar @extras ) {
        debug "Calling routine to verify extra(s) passed\n" if $opts->{verbose};
        return 1 if &check_extras( $opts, $distro, $extras );
    }

    ## Remove all extras
    if ( scalar @extras ) {
        foreach my $extra ( @extras ) {
            if ( &is_extra_dependant( $opts, $distro, $extra ) ) {
                debug "Leaving $extra - required for other installed distro\n" if $opts->{verbose};
            } else {
                if ( &is_source_installed( $opts, $extra ) ) {
                    debug "Removing extra $extra\n" if $opts->{verbose};
                    ($shares, undef) = &get_distro_share( $opts, $extra );
                    $is_loopback = &is_loopback( $opts, @$shares[0] );
                    if ( &remove_build_service( $opts, "", $extra ) ) {
                        $opts->{LASTERROR} = "";
                    }
                    debug "@$shares[0] ... removing\n" if $opts->{verbose};
                    if ( $is_loopback ) {
                        my $mntchk = `sudo mount | grep @$shares[0] | grep -v ^@$shares[0]`;
                        $mntchk = (split / /, $mntchk)[2];
                        if ( ( defined $mntchk ) and
                             (  $mntchk eq @$shares[0] ) ) {
                            $ret = system("sudo umount @$shares[0]");
                            if ( $ret > 0 ) {
                                $opts->{LASTERROR} = "loopback unmount failed\n";
                                error $opts->{LASTERROR};
                            }
                        }
                        rmdir(@$shares[0]);
                    } else {
                        rmtree(@$shares[0]);
                    }
                    my $dudh = &get_db_data( $opts, 'distro', $extra );
                    if ( $dudh->{type} == BA_SOURCE_DUD ) {
                        &remove_dud_initrd( $opts, $extra )
                    }
                    &source_register( $opts, $command, $extra );
                }
            }
        }
    }

    ## Remove base distro
    unless ( ( $is_extra_passed ) and ( ! $opts->{all} ) ) {
        ($shares,undef) = &get_distro_share( $opts, $distro );
        if ( &remove_build_service( $opts, $distro, "" ) ) {
            debug "$opts->{LASTERROR}\n";
            $opts->{LASTERROR} = "";
        }
        foreach my $share ( @$shares ) {
            $is_loopback = &is_loopback( $opts, $share );
            debug "$share ... removing\n" if $opts->{verbose};
            if ( $is_loopback ) {
                my $mntchk = `mount | grep $share| grep -v ^$share`;
                $mntchk = (split / /, $mntchk)[2];
                if ( ( defined $mntchk ) and
                     ( $mntchk eq $share ) ) {
                    $ret = system("sudo umount $share");
                    if ( $ret > 0 ) {
                        $opts->{LASTERROR} = "loopback unmount failed\n";
                        error $opts->{LASTERROR};
                    }
                }
                rmdir($share);
            }
        }
        &remove_bootloader_files( $opts, $distro );
        &source_register( $opts, $command, $distro);
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
    my $sharetype = params->{sharetype};
    my $shareip = params->{shareip};

    my $returnString = "";
    my %returnHash;

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my $extras = "";
    my @extras;
    my $dbref;
    my $ret = 0;

    # Build up extras (ie. addons, sdks and duds)
#    $extras = $extras . " $multiarg{ addons }" if ( defined $multiarg{ addons } );
#    $extras = $extras . " $multiarg{ sdks }" if ( defined $multiarg{ sdks } );
#    $extras = $extras . " $multiarg{ duds }" if ( defined $multiarg{ duds } );
#    $extras =~ s/^\s+//;

    my $is_extra_passed;
    $is_extra_passed = 1 if ( $extras );	

    ## Check if extras installed and not updated
    if ( ( ! $is_extra_passed ) and ( ! $opts->{all} ) ) {
        my @extchk = &list_installed_extras( $opts, $distro );
        if ( scalar @extchk > 1 ) {
            $opts->{LASTERROR} = "Update these extras before updating $distro (or use --all)\n\t" . join ("\n\t", @extchk ) . "\n";
            error $opts->{LASTERROR};
        }
    }

    if ( $extras ) {
        debug "Calling routine to verify additional source(s) passed\n" if $opts->{verbose};
        if ( &check_extras( $opts, $distro, $extras ) ) {
            error "extra is not valid\n";
        }
    }

    unless (( $shareip ne "" ) || ( $sharetype ne "" ))  {
        $opts->{LASTERROR} = "update requires either sharetype or shareip to be passed\n";
        error $opts->{LASTERROR};
    }


    if ( $opts->{all} and $extras ) {
            $opts->{LASTERROR} = "Unsafe mix of all and addon\n";
            error 1;
    }

    if ( $sharetype ne "") {
        unless (( $sharetype eq "nfs" ) || ( $sharetype eq "http" )) {
            $opts->{LASTERROR} = "$sharetype not valid. (supported types: nfs/http) \n";
            error $opts->{LASTERROR};
        }
    }

    my $dh =  &baxml_distro_gethash( $opts, $distro );

    if ( $opts->{all} ) {
        @extras = @{$dh->{basedisthash}->{addons}} if (defined $dh->{basedisthash}->{addons} );
        foreach my $item ( @extras ) {
            if ( &is_source_installed( $opts, $item ) ) {
                $extras = $extras . " $item";
            }
        }
        $extras =~ s/^\s+//;
        debug "working with 'all': $extras\n" if $opts->{debug};
    }

    # do we include anything in this distros
    unless ( ( $is_extra_passed ) and ( ! $opts->{all} ) ) {
        my $includes = &get_distro_includes( $opts, $distro );
        if ( ( defined $includes ) and
             ( ! grep $includes, @extras ) ) {
            my $incchk = &get_db_data( $opts, 'distro', $includes );
            unless ( defined $incchk->{state} ) {
                $extras = "$extras "  . $includes;
                $extras =~ s/^\s+//;
            }  # else include is already present in distro table
        }
    }
    undef @extras;
    @extras = split( /\s+/, $extras );

     # Update extras
    if ( scalar @extras ) {
        foreach my $extra ( @extras ) {
            my @shares;
            debug "Updating extra $extra\n";
            if ( $sharetype ne "" ) {
                $dbref = &get_db_source_entry( $opts, $extra );
                if ( &remove_build_service( $opts, $extra ) ) {
                    debug "$opts->{LASTERROR}\n";
                    $opts->{LASTERROR} = "";
                }
                &update_db_source_entry( $opts, $sharetype, "", $extra);
                &update_db_iso_entry( $opts, $extra, $sharetype );
                if ( &add_build_service( $opts, $extra ) ) {
                    debug "$opts->{LASTERROR}\n";
                    $opts->{LASTERROR} = "";
                }
                debug "$sharetype ... Updated\n" if $opts->{verbose};
            }
            if ( $shareip ne "" ) {
                &update_db_source_entry( $opts, "", $shareip, $extra);
                debug "$shareip ... Updated\n" if $opts->{verbose};
            }
        }
    }

    # Update base
    unless ( ( $is_extra_passed ) and ( ! $opts->{all} ) ) {
        my $dh = &baxml_distro_gethash( $opts, $distro );

        if ( $sharetype ne "" ) {
            $dbref = &get_db_source_entry( $opts, $distro );

            if ( &remove_build_service( $opts, $distro ) ) {
                debug "$opts->{LASTERROR}\n";
                $opts->{LASTERROR} = "";
            }
            &update_db_source_entry( $opts, $sharetype, "", $distro );
            &update_db_iso_entry( $opts, $distro, $sharetype );

            if ( &add_build_service( $opts, $distro ) ) {
                debug "$opts->{LASTERROR}\n";
                $opts->{LASTERROR} = "";
            }
            debug "$sharetype ... updated\n" if $opts->{verbose};
        }
        if ( $shareip ne "" ) {
                debug "Update ShareIP\n";
                &update_db_source_entry( $opts, "", $shareip, $distro );
        }
    }

    if ( request->{accept} =~ m|text/html| ) {
        return "Updated $distro<br>"
    } elsif ( request->{accept} eq "text/xml" ) {
        my @returnArray = ("Updated", "$distro");
        return \@returnArray;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub source_verify() {

    my $distro = params->{distro};

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

sub source_detail() {

    my $distro = params->{distro};
    my $status = undef;

    use File::Find;

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    # my $rtype = vars->{rtype};

    my $returnString = "";
    my %returnHash;

    $distro = lc $distro;

    my $dbref = &get_db_source_entry( $opts, $distro );
    unless ( defined $dbref and
             $dbref->{status} and
             $dbref->{status} != BA_ADMIN_REMOVED ) {
        $opts->{LASTERROR} = "No entry found for $distro\n";
        return 1;
    }
    
    if ( defined $dbref and
         defined $dbref->{status} )
    {
        $status = $baState{ $dbref->{status} };
    } else {
        $status = $baState{ BA_NONE };
    }

    my $dh = &baxml_distro_gethash( $opts, $distro );
    my $bh = $dh->{basedisthash};

    my %iodhash;

    find ( { wanted =>
             sub {
                 $iodhash{$_} .= "$File::Find::name ";
             },
             follow => 1
            },
           $baDir{isos} );

    $returnString = "Details for $distro<br>";
    $returnHash{distro} = $distro;
    $returnString .= "With current status '$status'<br>";
    $returnHash{status} = $status;
    if ($dh->{requires}) {
        $returnString .=  "Add-on product extending $dh->{basedist}<br>";
        $returnHash{basedist} = $dh->{basedist};
    } else {
        $returnString .= "Base product";
        if ( $bh->{addons} and scalar @{$bh->{addons}} ) {
            $returnString .= " supporting extension(s):  " .
                join (", ", (sort @{$bh->{addons}} ) );
            $returnHash{extensions} = join (", ", (sort @{$bh->{addons}} ) );
        }
        $returnString .= "\n";
    }

        $returnString .= "Based on product(s):  " .
        join (", ", ( sort &baxml_products_getlist( $opts, $distro ) ) ) . "<br>";
    foreach my $product ( sort &baxml_products_getlist( $opts,  $distro ) ) {
        $returnString .= "Detail for $product<br>";
        my $ph = &baxml_product_gethash( $opts, $distro, $product );
        foreach my $iso ( sort &baxml_isos_getlist( $opts, $distro, $product ) ) {
            my $ih = &baxml_iso_gethash( $opts, $distro, $product, $iso );
            my $builds = $ih->{isopath};
            my $isoexist = "-";
            my $direxist = "-";
            $isoexist = "+" if ( $iodhash{$iso} );
            $direxist = "+" if ( -d $builds );

            $builds =~ s|$baDir{builds}/||og;
            $returnString .=  " + $iso  =>  + $builds<br>", $isoexist, $direxist;
            $returnHash{product} = $product;
            $returnHash{iso} = $iso;
            $returnHash{builds} = $builds;
            $returnHash{mntdir} = $direxist;
        }
    }

    if ( request->{accept} =~ m|text/html| ) {
        return $returnString;
    } elsif ( request->{accept} eq "text/xml" ) {
        return \%returnHash;
    } else {
        error;
    }

}

sub source_enable() {

    my $distro = params->{distro};

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
