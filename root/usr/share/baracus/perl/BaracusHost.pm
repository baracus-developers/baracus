package BaracusHost;

use 5.006;
use Carp;
use strict;
use warnings;

use lib "/usr/share/baracus/perl";

use BaracusSql   qw( :subs :vars );
use BaracusState qw( :vars );
use BaracusCore  qw( :subs );

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
         subs   =>
         [qw(
                get_mac_by_hostname

                add_db_mac
                get_db_mac
                update_db_mac_state
                remove_db_mac

                add_db_action
                get_db_action
                get_db_action_by_hostname
                update_db_action
                remove_db_action

                add_db_host
                get_db_host
                get_db_host_by_mac
                update_db_host
                remove_db_host
                remove_db_host_by_mac
            )],
         );
    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';


# this routine checks for mac and hostname args
# and if hostname passed finds related mac entry
# returns undef on error (e.g., unable to find hostname)

sub get_mac_by_hostname
{
    my $opts     = shift;
    my $dbh      = shift;
    my $mac      = shift;
    my $hostname = shift;

#    if ( $mac ne "" and $hostname ne "" ) {
#        $opts->{LASTERROR} = "Please specify either --mac or --hostname, not both.\n";
#        return undef;
#    }

    if ( $mac eq "" and  $hostname eq "" ) {
        $opts->{LASTERROR} = "Requires --mac or --hostname.\n";
        return undef;
    }

    my $mref;
    my $href;

    if ( $mac ne "" ) {
        $mac = check_mac( $mac );
        $mref = &get_db_host_by_mac( $dbh, $mac );
    }
    if ( $hostname ne "" ) {
        if ( check_hostname ( $hostname ) ) {
            $opts->{LASTERROR} = "Need DNS formatted hostname, without domain.\n";
            return undef;
        }
        $href = &get_db_host( $dbh, $hostname );
    }

    if ( defined $mref ) {
        # mac found in host table
        if ( $hostname ne "" and $hostname ne $mref->{hostname} ) {
            # mac and hostname passed
            # but hostname passed differes from hostname in table
            $opts->{LASTERROR} = "MAC already bound to $mref->{hostname}\n";
            return undef;
        }
    }

    if ( defined $href ) {
        # hostname found in host table
        if ( $mac eq "" ) {

            # given hostname and no mac then here is where we get the mac
            # for all other actions.  entry for hostname passed was found

            $mac = $href->{mac};
        }
        elsif ( $mac ne "" and $mac ne $href->{mac} ) {
            # mac and hostname passed
            # but mac passed differs from mac in table
            $opts->{LASTERROR} = "Hostname already bound to $href->{mac}\n";
            return undef;
        }
    }
    else {
        # not defined $href
        if ( $mac eq "" ) {
            $opts->{LASTERROR } = "Unable to find hostname.  Try --mac\n";
            return undef;
        }
    }

    return $mac;
}

# These _db_ entry routines collect the host template db table interface

###########################################################################
##
## MAC relation - for macaddr and global state (admin, actions, events) hist

sub add_db_mac
{
    my $dbh   = shift;
    my $mac   = shift;
    my $state = shift;

    my $fields = "mac,state,$baState{ $state }";
    my $values = qq|'$mac',$state,CURRENT_TIMESTAMP|;
    my $sql = qq|INSERT INTO mac ( $fields ) VALUES ( $values )|;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish();
    undef $sth;
}

sub get_db_mac
{
    my $dbh = shift;
    my $mac = shift;

    my $sql = qq|SELECT * FROM mac WHERE mac = '$mac' |;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref();
}

sub update_db_mac_state
{
    my $dbh   = shift;
    my $mac   = shift;
    my $state = shift;

    my $fields = "state,$baState{ $state }";
    my $values = qq|'$state',CURRENT_TIMESTAMP|;
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
    my $sql = qq|DELETE FROM mac WHERE mac = '$mac'|;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish();
    undef $sth;
}

###########################################################################
##
## ACTION jackson
##   relation - for mac, host, and how to build boot
##   also has admin state, oper status, and curr and next actions (pxe)

sub add_db_action
{
    my $dbh    = shift;
    my $actref = shift;
    my %Hash   = %{$actref};

    my $fields = lc get_cols( $baTbls{ action } );
    $fields =~ s/[ \t]*//g;
    my @fields;
    foreach my $field ( split( /,/, $fields ) ) {
        next if ( $field eq "creation" );
        next if ( $field eq "change"   );
        push @fields, $field;
    }
    $fields = join(', ', @fields);
    my $values = join(', ', (map { $dbh->quote($_) } @Hash{@fields}));

    $fields .= ", creation, change";
    $values .= ", CURRENT_TIMESTAMP(0), CURRENT_TIMESTAMP(0)";

    my $sql = qq|INSERT INTO $baTbls{ action } ( $fields ) VALUES ( $values )|;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish;
    undef $sth;
}

sub get_db_action
{
    my $dbh = shift;
    my $mac = shift;

    my $sql = qq|SELECT * FROM $baTbls{ action } WHERE mac = '$mac' |;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref();
}

sub get_db_action_by_hostname
{
    my $dbh      = shift;
    my $hostname = shift;

    my $sql = qq|SELECT * FROM $baTbls{ action } WHERE hostname = '$hostname' |;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref();
}

sub update_db_action
{
    my $dbh    = shift;
    my $actref = shift;  # entry from get_db_action passed in with any needed mods
    my %Hash   = %{$actref};

    my $fields = lc get_cols( $baTbls{ action } );
    $fields =~ s/[ \t]*//g;
    my @fields;

    foreach my $field ( split( /,/, $fields ) ) {
        next if ( $field eq "mac"    );  # skip key
        next if ( $field eq "change" );  # skip update col
        next if ( $field eq "creation" );  # skip creation col
        push @fields, $field;
    }
    $fields = join(', ', @fields);
    my $values = join(', ', (map { $dbh->quote($_) } @Hash{@fields}));

    $fields .= ", change";
    $values .= ", CURRENT_TIMESTAMP(0)";

    my $sql = qq|UPDATE $baTbls{ action }
                SET ( $fields ) = ( $values )
                WHERE mac = '$actref->{mac}' |;

    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    $sth->finish;
    undef $sth;
}

sub remove_db_action
{
    my $dbh = shift;
    my $mac = shift;

    my $sql = qq|DELETE FROM $baTbls{'action'} WHERE mac='$mac'|;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish();
    undef $sth;
}


###########################################################################
##
## HOST
##   relation - for mac, host, and at somepoint either the info in hardware
##   or at a minimum the hardware id for what the box is.

sub add_db_host
{
    my $dbh     = shift;
    my $hostref = shift;
    my %Hash    = %{$hostref};

    my $fields = lc get_cols( $baTbls{ host } );
    $fields =~ s/[ \t]*//g;
    my @fields = split( /,/, $fields );
    my $values = join(', ', (map { $dbh->quote($_) } @Hash{@fields}));

#    my @fields = keys %{$hostref};
#    my $fields = join(', ', @fields);
#    my $values = join(', ', (map { $dbh->quote($_) } @Hash{@fields}));

    my $sql = qq|INSERT INTO $baTbls{ host } ( $fields ) VALUES ( $values )|;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish;
    undef $sth;
}

sub get_db_host
{
    my $dbh      = shift;
    my $hostname = shift;

    my $sql = qq|SELECT * FROM host WHERE hostname = '$hostname' |;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref();
}

sub get_db_host_by_mac
{
    my $dbh = shift;
    my $mac = shift;

    my $sql = qq|SELECT * FROM $baTbls{ host } WHERE mac = '$mac' |;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref();
}

sub update_db_host
{
    my $dbh     = shift;
    my $hostref = shift;
    my %hash    = %{$hostref};

    my $fields = lc get_cols( $baTbls{ host } );
    $fields =~ s/[ \t]*//g;
    my @fields = split( /,/, $fields );
    my $values = join(', ', (map { $dbh->quote($_) } @hash{@fields}));

    my $sql = qq|UPDATE $baTbls{ host }
                 SET ( $fields ) = ( $values )
                 WHERE hostname = '$hostref->{ hostname }' |;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish;
    undef $sth;
}

sub remove_db_host
{
    my $dbh      = shift;
    my $hostname = shift;
    my $sql = qq|DELETE FROM $baTbls{host} WHERE hostname = '$hostname'|;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish;
    undef $sth;
}

sub remove_db_host_by_mac
{
    my $dbh = shift;
    my $mac = shift;
    my $sql = qq|DELETE FROM $baTbls{host} WHERE mac = '$mac'|;
    my $sth;
    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );
    $sth->finish;
    undef $sth;
}

1;

__END__

=head1 AUTHOR

Daniel Westervelt, E<lt>dwestervelt@novellE<gt>
David Bahi, E<lt>dbahi@novellE<gt>

=cut
