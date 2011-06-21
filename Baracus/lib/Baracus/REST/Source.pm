package Baracus::REST::Source;

use 5.006;
use strict;
use warnings;

use File::Path;

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
                source_verify
                source_detail
                source_admin
         )],
         );

    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

###########################################################################
##
## Main Source REST Subroutines (list/add/remove/update/verify)

sub source_list() {

    my $filter = params->{filter};

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
        if ( ($adistro eq $filter) && ($status ne $baState{ BA_NONE }) && ($status ne $baState{ BA_ADMIN_REMOVED }) ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{type} = $dh->{type};
            $returnHash{$adistro}{description} = $dh->{description};
        } elsif ( ($filter eq "disabled") && ($status eq ($baState{ BA_DISABLED })) ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{type} = $dh->{type};
            $returnHash{$adistro}{description} = $dh->{description};
        } elsif ( ($filter eq "enabled") && ($status eq ($baState{ BA_ADMIN_ENABLED })) ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{type} = $dh->{type};
            $returnHash{$adistro}{description} = $dh->{description};
        } elsif ( ($filter eq "removed") && ($status eq ($baState{ BA_REMOVED })) ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{type} = $dh->{type};
            $returnHash{$adistro}{description} = $dh->{description};
        } elsif ( ($filter eq "none") && ($status eq ($baState{ BA_NONE })) ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{type} = $dh->{type};
            $returnHash{$adistro}{description} = $dh->{description};
        } elsif ( $filter eq "all" ) {
            $returnList .= "$adistro $status $dh->{description} <br>";
            $returnHash{$adistro}{status} = $status;
            $returnHash{$adistro}{type} = $dh->{type};
            $returnHash{$adistro}{description} = $dh->{description};
        }
    }

    if ( request->{accept} =~ m|text/html| ) {
        return $returnList;
    } elsif ( ( request->{accept} eq 'text/xml' ) or ( request->{accept} eq 'application/json' ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub source_add() {

    my $command = 'add';
    my $distro      = request->params->{distro};
    my $extras      = request->params->{extras} if ( defined request->params->{extras} );

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    unless ( defined request->params->{distro} ) {
        status '406';
        error "distro required for source_add";
        return { code => "26", error => "missing required argument" };
    }

    my $loopback = 1;
    my $addons = "";
    my $isos;
    my $check = 0;
    my $checkhr = {};

    my %returnHash;

    # Build up extras (ie. addons, sdks and duds)
    $extras = "" unless ( defined $extras );
    $extras =~ s/^\s+//;

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
        status '406';
        error "failed creating build paths";
        return { code => "28", error => "failed creating build paths" };
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

    unless ( &add_build_service( $opts, $distro, $extras ) ) {
        status '406';
        error "failed adding build service";
        return { code => "27", error => "failed adding build service" };
    }

    # Add base distro
    unless ( &is_source_installed( $opts, $distro ) ) {
        unless ( &add_bootloader_files( $opts, $distro ) ) {
            status '406';
            error "failed adding bootloader files";
            return { code => "29", error => "failed adding bootloader files" };
        }
        unless ( &source_register( $opts, 'add', $distro ) ) {
            status '406';
            error "failed registering source";
            return { code => "30", error => "failed registering source" };
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
            status '406';
            error "failed registering source";
            return { code => "30", error => "failed registering source" };
        }
    }

    $returnHash{distro} = $distro;
    $returnHash{extras} = $extras;
    $returnHash{action} = $command;
    $returnHash{result} = '0';

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub source_remove() {

    my $command = 'remove';
    my $distro = params->{distro};
    my $extras = params->{extra} if ( defined params->{extra} );

    my $opts = vars->{opts};
    unless ( $opts ) {
        $opts->{LASTERROR} = "'vars' not properly initialized";
        error $opts->{LASTERROR};
    }

    my @extras;
    my $shares;
    my $is_loopback = "";
    my $ret = 0;

    my %returnHash;

    @ARGV = @_;

    # Build up extras (ie. addons, sdks and duds)
    $extras = "" unless ( defined $extras );
    $extras =~ s/^\s+//;

    my $is_extra_passed;
    $is_extra_passed = 1 if ( $extras );

    ## Test if selection is valid
    ##
    $distro = lc $distro;
    if ( &check_distro( $opts, $distro ) )  {
        status 'error';
        error $opts->{LASTERROR};
    }

    my $dh =  &baxml_distro_gethash( $opts, $distro );

    if ( $extras eq "all" ) {
        $extras = "";
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
                error $opts->{LASTERROR};
            }
        }
    }

    # do we include anything in this distros
    unless ( ( $is_extra_passed ) and ( $extras ne "all" ) ) {
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
        debug "Calling routine to verify extra(s) passed\n";
        if ( &check_extras( $opts, $distro, $extras ) ) {
            error "failed in check_extras \n";
        }
    }

    ## Remove all extras
    if ( scalar @extras ) {
        foreach my $extra ( @extras ) {
            if ( &is_extra_dependant( $opts, $distro, $extra ) ) {
                debug "Leaving $extra - required for other installed distro\n";
            } else {
                if ( &is_source_installed( $opts, $extra ) ) {
                    debug "Removing extra $extra\n";
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
    unless ( ( $is_extra_passed ) and ( $extras ne "all" ) ) {
        ($shares,undef) = &get_distro_share( $opts, $distro );
        if ( &remove_build_service( $opts, $distro, "" ) ) {
            debug "$opts->{LASTERROR}\n";
            $opts->{LASTERROR} = "";
        }
        foreach my $share ( @$shares ) {
            $is_loopback = &is_loopback( $opts, $share );
            debug "$share ... removing\n";
            if ( $is_loopback ) {
                my $mntchk = `sudo mount | grep $share| grep -v ^$share`;
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

    $returnHash{distro} = $distro;
    $returnHash{extras} = $extras if ( defined $extras );;
    $returnHash{action} = $command;
    $returnHash{result} = '0';

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
    }

}

sub source_admin() {
    if ( request->params->{verb} eq "update" ) {
        &source_update(  @_ );
    } elsif ( request->params->{verb} eq "enable" ) {
        &source_enable(  @_ );
    } elsif ( request->params->{verb} eq "disable" ) {
        &source_disable(  @_ );
    } else {
        status '406';
        error "distro required for source_add";
        return { code => "26", error => "missing required argument" };
    }
}       

sub source_update() {

    my $command = 'update';
    my $distro    = params->{distro};
    my $sharetype = params->{sharetype} if ( defined params->{sharetype} );
    my $shareip   = params->{shareip}   if ( defined params->{shareip} );

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
    if ( ( ! $is_extra_passed ) and ( $extras ne "all" ) ) {
        my @extchk = &list_installed_extras( $opts, $distro );
        if ( scalar @extchk > 1 ) {
            $opts->{LASTERROR} = "Update these extras before updating $distro (or use --all)\n\t" . join ("\n\t", @extchk ) . "\n";
            error $opts->{LASTERROR};
        }
    }

    if ( $extras ) {
        debug "Calling routine to verify additional source(s) passed\n";
        if ( &check_extras( $opts, $distro, $extras ) ) {
            error "extra is not valid\n";
        }
    }

    unless (( $shareip ne "" ) || ( $sharetype ne "" ))  {
        $opts->{LASTERROR} = "update requires either sharetype or shareip to be passed\n";
        error $opts->{LASTERROR};
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
        debug "working with 'all': $extras\n";
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
                debug "$sharetype ... Updated\n";
            }
            if ( $shareip ne "" ) {
                &update_db_source_entry( $opts, "", $shareip, $extra);
                debug "$shareip ... Updated\n";
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

    $returnHash{distro}    = $distro;
    $returnHash{action}    = $command;
    $returnHash{shareip}   = $shareip   if ( defined $shareip );
    $returnHash{sharetype} = $sharetype if ( defined $sharetype );
    $returnHash{result}    = '0';

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
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

    my %returnHash;

    my $dbref = &get_db_source_entry( $opts, $distro );

    unless ( defined $dbref and
             $dbref->{status} and
             $dbref->{status} != BA_ADMIN_REMOVED ) {
        $opts->{LASTERROR} = "No entry found for $distro\n";
        return 1;
    }

    $returnHash{target} = $dbref->{distroid};
    $returnHash{creation} = $dbref->{creation};
    $returnHash{change} = $dbref->{change} if defined $dbref->{change};
    $returnHash{status} = $dbref->{status};

    my $service_status = "";
    if ( &check_service( $opts, $dbref->{sharetype} ) ) {
        $service_status = "not running";
    } else {
        $service_status = "ok";
    }
    $returnHash{servicestatus} = $service_status;
    $returnHash{sharetype} = $dbref->{sharetype};
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
            $returnHash{share} = $netcfg;

            my $path_status = "";
            if ( not -d $share ) {
                $path_status = "missing";
            } else {
                $path_status = "ok";
            }
            $returnHash{pathstatus} = $path_status;
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
    $returnHash{initrd} = "initrd.$base";

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
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

    $returnHash{distro} = $distro;
    $returnHash{status} = $status;
    if ($dh->{requires}) {
        $returnHash{basedist} = $dh->{basedist};
    } else {
        if ( $bh->{addons} and scalar @{$bh->{addons}} ) {
            $returnHash{extensions} = join (", ", (sort @{$bh->{addons}} ) );
        }
    }

    foreach my $product ( sort &baxml_products_getlist( $opts,  $distro ) ) {
        my $ph = &baxml_product_gethash( $opts, $distro, $product );
        foreach my $iso ( sort &baxml_isos_getlist( $opts, $distro, $product ) ) {
            my $ih = &baxml_iso_gethash( $opts, $distro, $product, $iso );
            my $builds = $ih->{isopath};
            $returnHash{isoexist} = "-";
            $returnHash{direxist} = "-";
            $returnHash{isoexist} = "+" if ( $iodhash{$iso} );
            $returnHash{direxist} = "+" if ( -d $builds );

            $builds =~ s|$baDir{builds}/||og;
            $returnHash{product} = $product;
            $returnHash{iso} = $iso;
            $returnHash{builds} = $builds;
        }
    }

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub source_enable() {

    my $command = 'disable';
    my $distro = params->{distro};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my %returnHash;

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

    $returnHash{distro}    = $distro;
    $returnHash{action}    = $command;
    $returnHash{result}    = '0';

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

sub source_disable() {

    my $command = 'enable';
    my $distro  = request->params->{distro};

    my $opts = vars->{opts};
    unless ( $opts ) {
        status 'error';
        return "internal 'vars' not properly initialized";
    }

    my %returnHash;

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

    $returnHash{distro}    = $distro;
    $returnHash{action}    = $command;
    $returnHash{result}    = '0';

    if ( ( request->{accept} eq 'text/xml' )
      or ( request->{accept} eq 'application/json' )
      or ( request->{accept} =~ m|text/html| ) ) {
        return \%returnHash;
    } else {
        status 'error';
        return $opts->{LASTERROR};
    }

}

1;
