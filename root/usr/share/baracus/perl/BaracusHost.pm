package BaracusHost;

use 5.006;
use Carp;
use strict;
use warnings;

use lib "/usr/share/baracus/perl";

use BaracusDB;
use BaracusSql qw( :states :subs :vars );


=pod

=head1 NAME

B<BaracusHost> - subroutines for managing Baracus host macs and templates

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
         events  =>
         [qw(
                BA_EVENT_ADD
                BA_EVENT_WIPE
                BA_EVENT_REMOVE
                BA_EVENT_ENABLE
                BA_EVENT_DISABLE
                BA_EVENT_FOUND
                BA_EVENT_REGISTER
                BA_EVENT_PXEDISABLE
                BA_EVENT_BUILDING
                BA_EVENT_BUILT
                BA_EVENT_SPOOFED
                BA_EVENT_WIPING
                BA_EVENT_WIPED
                BA_EVENT_WIPEFAIL
            )],
         vars   => [qw( %bahost_tbls )],
         subs   =>
         [qw(
                get_cols
                manage_host_states
                add_db_host_entry
                get_db_host_entry
                get_db_host_by_mac
                get_db_build_by_host
                update_db_host_entry
                remove_db_host_entry
                add_db_mac
                get_db_mac
                update_db_mac_state
                remove_db_mac
            )],
         );
    Exporter::export_ok_tags('events');
    Exporter::export_ok_tags('vars');
    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';

use constant  BA_EVENT_ADD        => 1;
use constant  BA_EVENT_WIPE       => 2;
use constant  BA_EVENT_REMOVE     => 3;
use constant  BA_EVENT_ENABLE     => 4;
use constant  BA_EVENT_DISABLE    => 5;
use constant  BA_EVENT_FOUND      => 6;
use constant  BA_EVENT_REGISTER   => 7;
use constant  BA_EVENT_PXEDISABLE => 8;
use constant  BA_EVENT_BUILDING   => 9;
use constant  BA_EVENT_BUILT      => 10;
use constant  BA_EVENT_SPOOFED    => 11;
use constant  BA_EVENT_WIPING     => 12;
use constant  BA_EVENT_WIPED      => 13;
use constant  BA_EVENT_WIPEFAIL   => 14;

use vars qw ( %bahost_tbls );

%bahost_tbls =
    (
     'host'      => 'templateid',
     'profile'   => 'profile_cfg',
     'distro'    => 'distro_cfg',
     'hardware'  => 'hardware_cfg',
     'module'    => 'module_cfg',
     'modcert'   => 'module_cert_cfg',
     'history'   => 'templateidhist',
     'oscert'    => 'hardwareid',
     'build'     => 'build',
     'mac'       => 'mac',
     );

my %tbl = %bahost_tbls;

=item manage_host_states

nothing fancy - a state machine of sorts

we look at states and the action and decide on next states

all addition of entries and updates are done outside this routine

there is an oddity / explaination needed for the states themselves

=over 4

=item admin The administrative bahost { enable | disable } template
state.

=item pxestate The state related to the AUTO_DISABLE_PXE option.
Usage of this option (setting it to "yes" in the sysconfig/baracus)
should no longer be requred to prevent PXE boot loops, as Baracus is
now a proper state-driven boot manager.  However if the
AUTO_DISABLE_PXE option is 'on' this state will go to DISABLED after
serving up a response to any PXE boot request.  To put this pxestate
back to READY use the administrative 'bahost enable' command.

=item oper The operational state of the template and host.  Its
current state or what it is currently doing, or last instructed to do.

=item pxenext The next PXE menu action to feed the host on the next
pxeboot request.

=back

=cut

sub manage_host_states
{
    my $dbh     = shift;
    my $event   = shift;
    my $macref  = shift;
    my $hostref = shift;

    # new template
    if ( $event eq BA_EVENT_ADD ) {

        # pxestate here in BA_EVENT_ADD always BA_READY

        # need inventory
        if ( $macref->{state} eq BA_FOUND or
             $macref->{state} eq BA_ADDED or
             $macref->{state} eq BA_DELETED )
        {
            $hostref->{admin}   = BA_READY;
            $hostref->{pxenext} = BA_REGISTER;  # on inventory complete
            $hostref->{oper}    = BA_ADDED;
            unless ( $macref->{state} eq BA_ADDED )
            {
                &update_db_mac_state( $dbh, $macref->{mac},
                                      BA_ADDED, $baState{ BA_ADDED });
            }
        }

        # already successfully inventoried
        # but was missing build template
        elsif ( $macref->{state} eq BA_REGISTER )
        {
            $hostref->{admin}   = BA_READY;
            $hostref->{pxenext} = BA_BUILDING;
            $hostref->{oper}    = BA_READY;
            &update_db_mac_state( $dbh, $macref->{mac},
                                  BA_READY, $baState{ BA_READY } );
        }

        # the above are the only valid mac states to have a template added
        else
        {
            carp "unexpected mac state '$macref->{state}' in add event";
        }
    }
    # wipe the host and discard host template
    elsif ( $event eq BA_EVENT_WIPE ) {

        # don't care what the former state was
        # we go into this state and we don't leave
        # until deletion
        $hostref->{admin}   = BA_READY;
        $hostref->{pxenext} = BA_WIPING;   # on inventory complete
        $hostref->{oper}    = BA_DISKWIPE;
        unless ( $macref->{'state'} eq BA_DISKWIPE ) {
            &update_db_mac_state( $dbh, $macref->{mac},
                                  BA_DISKWIPE, $baState{ BA_DISKWIPE } );
        }
    } elsif ( $event eq BA_EVENT_REMOVE ) {
        # the coup de gras
        # we may be here w/o a templatedid hostentry
        if ( defined $hostref ) {
            $hostref->{admin}   = BA_DELETED;
            $hostref->{pxenext} = BA_NOPXE;
            $hostref->{oper}    = BA_DELETED;
        }
        unless ( $macref->{'state'} eq BA_DELETED ) {
            &update_db_mac_state( $dbh, $macref->{mac},
                                  BA_DELETED, $baState{ BA_DELETED } );
        }
    }
    # enable
    elsif ( $event eq BA_EVENT_ENABLE ) {

        $hostref->{pxestate}= BA_READY;
        $hostref->{admin}   = BA_READY;
        $hostref->{oper}    = $macref->{state};

        # only way to get sanity back is not to touch mac state w/ en/dis-able
        # this is an odd seperation of mac state and host oper status
        # it also implies that the mac state should never go to disabled....

        if ( $macref->{state} eq BA_ADDED or
             $macref->{state} eq BA_FOUND    # not likely cause we have template
            )
        {
            $hostref->{pxenext} = BA_REGISTER;
        }
        elsif ( $macref->{state} eq BA_READY or
                $macref->{state} eq BA_UPDATED or
                $macref->{state} eq BA_REGISTER
               )
        {
            $hostref->{pxenext} = BA_BUILDING;
        }
        elsif ( $macref->{state} eq BA_BUILT or
                $macref->{state} eq BA_SPOOFED or
                $macref->{state} eq BA_BUILDING
               )
        {
            $hostref->{pxenext} = BA_LOCALBOOT;
        }
        elsif ( $macref->{state} eq BA_DISKWIPE or
                $macref->{state} eq BA_WIPING or
                $macref->{state} eq BA_WIPED or
                $macref->{state} eq BA_WIPEFAIL
               )
        {
            $hostref->{pxenext} = BA_WIPING;
        }
        else {
            carp "unexpected mac state '$macref->{state}' in enable event";
        }
    }
    # disable
    elsif ( $event eq BA_EVENT_DISABLE ) {
        $hostref->{admin}   = BA_DISABLED;
        $hostref->{pxenext} = BA_NOPXE;
        $hostref->{oper}    = BA_DISABLED;
        $hostref->{pxestate}= BA_DISABLED;
    }
    # new mac discovered with no related host template
    elsif ( $event eq BA_EVENT_FOUND ) {
        # no host template entry
        # so no state to manipulate
        ; # no-op
    }
    elsif ( $event eq BA_EVENT_REGISTER ) {
        if ( defined $hostref and $hostref->{hostname} ne "" ) {
            if ( $hostref->{admin} eq BA_READY ) {
                $hostref->{pxenext} = BA_BUILDING;
                $hostref->{oper}    = BA_REGISTER;
            }
        }
        unless ( $macref->{'state'} eq BA_REGISTER ) {
            &update_db_mac_state( $dbh, $macref->{mac},
                                  BA_REGISTER, $baState{ BA_REGISTER } );
        }
    }
    elsif ( $event eq BA_EVENT_PXEDISABLE ) {
    }
    elsif ( $event eq BA_EVENT_BUILDING ) {
        if ( $hostref->{admin} eq BA_READY ) {
            $hostref->{pxenext} = BA_LOCALBOOT;
            $hostref->{oper}    = BA_BUILDING;
        }
            &update_db_mac_state( $dbh, $macref->{mac},
                                  BA_BUILDING, $baState{ BA_BUILDING } );
    }
    elsif ( $event eq BA_EVENT_BUILT ) {
        if ( $hostref->{admin} eq BA_READY ) {
            $hostref->{pxenext} = BA_LOCALBOOT;
            $hostref->{oper}    = BA_BUILT;
        }
        unless ( $macref->{'state'} eq BA_BUILT ) {
            &update_db_mac_state( $dbh, $macref->{mac},
                                  BA_BUILT, $baState{ BA_BUILT } );
        }
    }
    elsif ( $event eq BA_EVENT_SPOOFED ) {
        if ( $hostref->{admin} eq BA_READY ) {
            $hostref->{pxenext} = BA_NOPXE;
            $hostref->{oper}    = BA_SPOOFED;
        }
        unless ( $macref->{'state'} eq BA_SPOOFED ) {
            &update_db_mac_state( $dbh, $macref->{mac},
                                  BA_SPOOFED, $baState{ BA_SPOOFED } );
        }
    }
    elsif ( $event eq BA_EVENT_WIPING ) {
        if ( $hostref->{admin} eq BA_READY ) {
            $hostref->{pxenext} = BA_NOPXE;
            $hostref->{oper}    = BA_WIPING;
            $hostref->{pxestate}= BA_READY;
        }
            &update_db_mac_state( $dbh, $macref->{mac},
                                  BA_WIPING, $baState{ BA_WIPING } );
    }
    elsif ( $event eq BA_EVENT_WIPED ) {
        if ( defined $hostref and $hostref->{hostname} ne "" ) {
            if ( $hostref->{admin} eq BA_READY ) {
                $hostref->{pxenext} = BA_NOPXE;
                $hostref->{oper}    = BA_WIPED;
            }
        }
        unless ( $macref->{'state'} eq BA_WIPED ) {
            &update_db_mac_state( $dbh, $macref->{mac},
                                  BA_WIPED, $baState{ BA_WIPED } );
        }
    }
    elsif ( $event eq BA_EVENT_WIPEFAIL ) {
        if ( defined $hostref and $hostref->{hostname} ne "" ) {
            if ( $hostref->{admin} eq BA_READY ) {
                $hostref->{pxenext} = BA_NOPXE;
                $hostref->{oper}    = BA_WIPEFAIL;
            }
        }
        unless ( $macref->{'state'} eq BA_WIPEFAIL ) {
            &update_db_mac_state( $dbh, $macref->{mac},
                                  BA_WIPEFAIL, $baState{ BA_WIPEFAIL } );
        }
    }
}


# These _db_ entry routines collect the host template db table interface

sub add_db_host_entry
{
    my $dbh  = shift;
    my $href = shift;
    my %Hash = %$href;

    my @fields = qw|hostname ip mac uuid loghost raccess autonuke pxestate admin pxenext oper cmdline|;
    my $fields = join(', ', @fields);
    my $values = join(', ', (map { $dbh->quote($_) } @Hash{@fields}));
    $fields .= ", creation, change";
    $values .= ", CURRENT_TIMESTAMP(0), CURRENT_TIMESTAMP(0)";
    my $sql = qq|INSERT INTO $tbl{'host'} ( $fields ) VALUES ( $values )|;

    my $sth = $dbh->prepare( $sql )
        or die "Cannot prepare sth: ",$dbh->errstr;

    $sth->execute()
        or die "Cannot execute sth: ", $sth->errstr;

    ##
    ##  bind mac, hostname, distro, hardware for pxe boot info
    #
    my %entry = (
                 'mac'        => $Hash{'mac'},
                 'hostname'   => $Hash{'hostname'},
                 'distroid'   => $Hash{'distro'},
                 'hardwareid' => $Hash{'hardware'},
#                'profile'    => $Hash{'profile'},
                 );

    my $sql_cols = lc get_cols( $tbl{'build'} );

    $sql_cols =~ s/[ \t]*//g;
    my @cols = split( /,/, $sql_cols );
    my $sql_vals = "?," x scalar @cols; chop $sql_vals;

    $sql = qq|INSERT INTO $tbl{ 'build' }
              ( $sql_cols )
              VALUES ( $sql_vals )
              |;
#    print $sql . "\n" if $debug;

    $sth = $dbh->prepare( $sql )
         or die "Cannot prepare sth: ", $dbh->errstr;

    my $paramidx = 0;
    foreach my $col (@cols) {
        $paramidx += 1;
        $sth->bind_param( $paramidx, $entry{ $col } );
    }

    $sth->execute()
        or die "Cannot execute sth: ", $sth->errstr;

    $sth->finish;
    undef $sth;
}

sub get_db_host_entry
{

    my $dbh      = shift;
    my $hostname = shift;

    my $cols = lc get_cols( $tbl{'host'} );

    my $sql = qq|SELECT $cols FROM $tbl{ host } WHERE hostname = '$hostname' |;

#    print $sql . "and hostname is $hostname \n" if $debug;

    my $sth = $dbh->prepare( $sql )
        or die "Cannot prepare select statement\n" . $dbh->errstr;
    $sth->execute()
        or die "Cannot execute select statement\n" . $sth->err;

    return $sth->fetchrow_hashref();
}

sub get_db_host_by_mac
{

    my $dbh = shift;
    my $mac = shift;

    my $cols = lc get_cols( $tbl{'host'} );

    my $sql = qq|SELECT $cols FROM $tbl{ host } WHERE mac = '$mac' |;

#    print $sql . "and mac is $mac \n" if $debug;

    my $sth = $dbh->prepare( $sql )
        or die "Cannot prepare select statement\n" . $dbh->errstr;
    $sth->execute()
        or die "Cannot execute select statement\n" . $sth->err;

    return $sth->fetchrow_hashref();
}

sub get_db_build_by_host
{

    my $dbh      = shift;
    my $hostname = shift;

    my $cols = lc get_cols( $tbl{'build'} );

    my $sql = qq|SELECT $cols FROM $tbl{ build } WHERE hostname = ? |;

#    print $sql . "and hostname is $hostname \n" if $debug;

    my $sth = $dbh->prepare( $sql )
        or die "Cannot prepare select statement\n" . $dbh->errstr;
    $sth->execute( $hostname )
        or die "Cannot execute select statement\n" . $sth->err;

    return $sth->fetchrow_hashref();
}

sub update_db_host_entry
{

    my $dbh  = shift;
    my $href = shift;  # entry passed in with any needed mods

    my $sql_cols = lc get_cols( $tbl{'host'} );
    $sql_cols =~ s/[ \t]*//g;
    my @cols = split( /,/, $sql_cols );
    $sql_cols ="";
    my $sql_vals = "";
    foreach my $col ( @cols ) {
        next if ( $col eq "hostname" );  # skip the key
        next if ( $col eq "change"   );  # skip update col if present
        next if ( $col eq "cmdline"  );  # skip update cmdline if present
        if ( defined $href->{ $col } ) {
            $sql_cols .= "$col,";
            $sql_vals .= "'$href->{ $col }',";
        }
    }
    $sql_cols .= "change, cmdline";
    $sql_vals .= "CURRENT_TIMESTAMP(0), '$href->{cmdline}'";

    my $sql = qq|UPDATE $tbl{ host }
                SET ( $sql_cols ) = ( $sql_vals )
                WHERE hostname = ?
                |;

#    print $sql . "and hostname is $href->{ hostname }\n" if $debug;

    my $sth = $dbh->prepare( $sql )
        or die "Cannot prepare update statement\n" . $dbh->errstr;

    $sth->execute( $href->{hostname} )
        or die "Cannot execute update statement\n" . $sth->err;

    $sth->finish;
    undef $sth;
}

sub remove_db_host_entry
{
    my $dbh      = shift;
    my $hostname = shift;

    ##
    ##  bind mac, hostname, distro, hardware for pxe boot info
    #
    my $href = &get_db_build_by_host( $dbh, $hostname );

    my $sql = qq|DELETE FROM $tbl{ 'build' } WHERE mac = ?|;
    my $sth = $dbh->prepare( $sql )
        or die "Cannot prepare sth: ",$dbh->errstr;
    $sth->execute( $href->{mac} )
        or die "Cannot execute sth: ",$sth->errstr;

    $sql = qq|DELETE FROM $tbl{'host'} WHERE hostname=?|;
    $sth = $dbh->prepare( $sql )
        or die "Cannot prepare sth: ",$dbh->errstr;
    $sth->execute( $hostname )
        or die "Cannot execute sth: ",$sth->errstr;


    $sth->finish();
    undef $sth;
}

sub add_db_mac
{
    my $dbh   = shift;
    my $mac   = shift;
    my $state = shift;
    my $field = shift;

    my $fields = "mac,state,$field";
    my $values = qq|'$mac',$state,CURRENT_TIMESTAMP(0)|;
    my $sql = qq|INSERT INTO mac ( $fields ) VALUES ( $values )|;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish();
}

sub get_db_mac
{

    my $dbh = shift;
    my $mac = shift;

    my $cols = lc get_cols( $tbl{'mac'} );

    my $sql = qq|SELECT $cols FROM $tbl{ mac } WHERE mac = '$mac' |;

#    print $sql . "and mac is $mac \n" if $debug;

    my $sth = $dbh->prepare( $sql )
        or die "Cannot prepare select statement\n" . $dbh->errstr;
    $sth->execute( )
        or die "Cannot execute select statement\n" . $sth->err;

    return $sth->fetchrow_hashref();
}

sub update_db_mac_state
{
    my $dbh   = shift;
    my $mac   = shift;
    my $state = shift;
    my $field = shift;

    my $fields = "state,$field";
    my $values = qq|'$state',CURRENT_TIMESTAMP(0)|;
    my $sth;
    my $sql = qq|UPDATE mac SET ( $fields ) = ( $values ) WHERE mac = '$mac'|;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish();
}

sub remove_db_mac
{
    my $dbh = shift;
    my $mac = shift;
    my $sql = qq|DELETE FROM $tbl{'mac'} WHERE mac = '$mac'|;
#    print $sql . "and mac is $mac \n" if $debug;
    my $sth = $dbh->prepare( $sql )
        or die "Cannot prepare statement\n" . $dbh->errstr;
    $sth->execute()
        or die "Cannot execute statement\n" . $sth->err;
    $sth->finish();
}

#destined for BaracusSql after 1.2

=item get_cols

wrapper to simply get the columns based of a table
no matter which baracus related database it is from

=cut

sub get_cols
{
    my $tbl = shift;
    my $baracustbls = get_baracus_tables()->{ $tbl };
    my $sqltftptbls = get_sqltftp_tables()->{ $tbl };
    if ( defined $baracustbls ) {
        return keys2columns( $baracustbls );
    }
    elsif ( defined $sqltftptbls ) {
        return keys2columns( $sqltftptbls );
    }
    else {
        carp "Internal database table/name usage error.\n";
        return undef;
    }
}

1;

__END__

=head1 AUTHOR

Daniel Westervelt, E<lt>dwestervelt@novellE<gt>
David Bahi, E<lt>dbahi@novellE<gt>

=cut
