package BaracusState;

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
use Carp;
use strict;
use warnings;

=pod

=head1 NAME

B<BaracusState> - Defines states and tools for Baracus

=head1 SYNOPSIS

Defines states in terms of admin, actions and events constant
Also provides related <admin|actions|events>_state_change routines
and an array of state names as well as a hash to maps names to values
and values to string names.

Note that all the admin, actions and events have a related BA_<state>
to ensure they have a globaly unique value and baState name string.

=cut

BEGIN {
    use Exporter ();
    use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
    @ISA         = qw(Exporter);
    @EXPORT      = qw();
    @EXPORT_OK   = qw();

    %EXPORT_TAGS =
        (
         vars =>
         [qw(
                @baStates
                %baState
            )],
         subs =>
         [qw(
                admin_state_change
                action_state_change
                event_state_change
            )],
         states =>
         [qw(
                BA_ADDED
                BA_REMOVED
                BA_ENABLED
                BA_DISABLED
                BA_IGNORED
                BA_NONE
                BA_INVENTORY
                BA_BUILD
                BA_DISKWIPE
                BA_RESCUE
                BA_NORESCUE
                BA_LOCALBOOT
                BA_PXEWAIT
                BA_NETBOOT
                BA_FOUND
                BA_REGISTER
                BA_BUILDING
                BA_BUILT
                BA_SPOOFED
                BA_WIPING
                BA_WIPED
                BA_WIPEFAIL
                BA_IMAGE
                BA_IMAGING
                BA_IMAGED
                BA_IMAGEFAIL
                BA_MCAST
                BA_MCASTING
                BA_MCASTED
                BA_MCASTFAIL
                BA_CLONE
                BA_CLONING
                BA_CLONED
                BA_CLONEFAIL
		BA_MIGRATE
		BA_MIGRATING
		BA_MIGRATED
		BA_MIGRATEFAIL
            )],
         admin =>
         [qw(
                BA_ADMIN_ADDED
                BA_ADMIN_REMOVED
                BA_ADMIN_ENABLED
                BA_ADMIN_DISABLED
                BA_ADMIN_IGNORED
            )],
         actions =>
         [qw(
                BA_ACTION_NONE
                BA_ACTION_INVENTORY
                BA_ACTION_BUILD
                BA_ACTION_DISKWIPE
                BA_ACTION_RESCUE
                BA_ACTION_NORESCUE
                BA_ACTION_LOCALBOOT
                BA_ACTION_PXEWAIT
                BA_ACTION_NETBOOT
                BA_ACTION_IMAGE
                BA_ACTION_MCAST
                BA_ACTION_CLONE
		BA_ACTION_MIGRATE
            )],
         events =>
         [qw(
                BA_EVENT_FOUND
                BA_EVENT_REGISTER
                BA_EVENT_BUILDING
                BA_EVENT_BUILT
                BA_EVENT_SPOOFED
                BA_EVENT_WIPING
                BA_EVENT_WIPED
                BA_EVENT_WIPEFAIL
                BA_EVENT_IMAGING
                BA_EVENT_IMAGED
                BA_EVENT_IMAGEFAIL
                BA_EVENT_MCASTING
                BA_EVENT_MCASTED
                BA_EVENT_MCASTFAIL
                BA_EVENT_CLONING
                BA_EVENT_CLONED
                BA_EVENT_CLONEFAIL
		BA_EVENT_MIGRATING
		BA_EVENT_MIGRATED
		BA_EVENT_MIGRATEFAIL
            )],
         );
    Exporter::export_ok_tags('vars');
    Exporter::export_ok_tags('subs');
    Exporter::export_ok_tags('states');
    Exporter::export_ok_tags('admin');
    Exporter::export_ok_tags('actions');
    Exporter::export_ok_tags('events');
}

use vars qw( @baStates %baState );

# this is the superset of admin, action, and event
use constant BA_ADDED             => 1  ;
use constant BA_REMOVED           => 2  ;
use constant BA_ENABLED           => 3  ;
use constant BA_DISABLED          => 4  ;
use constant BA_IGNORED           => 5  ;
use constant BA_NONE              => 6  ;
use constant BA_INVENTORY         => 7  ;
use constant BA_BUILD             => 8  ;
use constant BA_DISKWIPE          => 9 ;
use constant BA_RESCUE            => 10 ;
use constant BA_NORESCUE          => 11 ;
use constant BA_LOCALBOOT         => 12 ;
use constant BA_PXEWAIT           => 13 ;
use constant BA_NETBOOT           => 14 ;
use constant BA_FOUND             => 15 ;
use constant BA_REGISTER          => 16 ;
use constant BA_BUILDING          => 17 ;
use constant BA_BUILT             => 18 ;
use constant BA_SPOOFED           => 19 ;
use constant BA_WIPING            => 20 ;
use constant BA_WIPED             => 21 ;
use constant BA_WIPEFAIL          => 22 ;
use constant BA_IMAGE             => 23 ;
use constant BA_IMAGING           => 24 ;
use constant BA_IMAGED            => 25 ;
use constant BA_IMAGEFAIL         => 26 ;
use constant BA_MCAST             => 27 ;
use constant BA_MCASTING          => 28 ;
use constant BA_MCASTED           => 29 ;
use constant BA_MCASTFAIL         => 30 ;
use constant BA_CLONE             => 31 ;
use constant BA_CLONING           => 32 ;
use constant BA_CLONED            => 33 ;
use constant BA_CLONEFAIL         => 34 ;
use constant BA_MIGRATE           => 35 ;
use constant BA_MIGRATING         => 36 ;
use constant BA_MIGRATED          => 37 ;
use constant BA_MIGRATEFAIL       => 38 ;

# map to host admin
use constant BA_ADMIN_ADDED       => BA_ADDED     ;
use constant BA_ADMIN_REMOVED     => BA_REMOVED   ;
use constant BA_ADMIN_ENABLED     => BA_ENABLED   ;
use constant BA_ADMIN_DISABLED    => BA_DISABLED  ;
use constant BA_ADMIN_IGNORED     => BA_IGNORED   ;

# map to user actions
use constant BA_ACTION_NONE       => BA_NONE      ;
use constant BA_ACTION_INVENTORY  => BA_INVENTORY ;
use constant BA_ACTION_BUILD      => BA_BUILD     ;
use constant BA_ACTION_DISKWIPE   => BA_DISKWIPE  ;
use constant BA_ACTION_RESCUE     => BA_RESCUE    ;
use constant BA_ACTION_NORESCUE   => BA_NORESCUE  ;
use constant BA_ACTION_LOCALBOOT  => BA_LOCALBOOT ;
use constant BA_ACTION_PXEWAIT    => BA_PXEWAIT   ;
use constant BA_ACTION_NETBOOT    => BA_NETBOOT   ;
use constant BA_ACTION_IMAGE      => BA_IMAGE     ;
use constant BA_ACTION_MCAST      => BA_MCAST     ;
use constant BA_ACTION_CLONE      => BA_CLONE     ;
use constant BA_ACTION_MIGRATE    => BA_MIGRATE   ;

# map to non-user triggered events
use constant BA_EVENT_FOUND       => BA_FOUND     ;
use constant BA_EVENT_REGISTER    => BA_REGISTER  ;
use constant BA_EVENT_BUILDING    => BA_BUILDING  ;
use constant BA_EVENT_BUILT       => BA_BUILT     ;
use constant BA_EVENT_SPOOFED     => BA_SPOOFED   ;
use constant BA_EVENT_WIPING      => BA_WIPING    ;
use constant BA_EVENT_WIPED       => BA_WIPED     ;
use constant BA_EVENT_WIPEFAIL    => BA_WIPEFAIL  ;
use constant BA_EVENT_IMAGING     => BA_IMAGING   ;
use constant BA_EVENT_IMAGED      => BA_IMAGED    ;
use constant BA_EVENT_IMAGEFAIL   => BA_IMAGEFAIL ;
use constant BA_EVENT_MCASTING    => BA_MCASTING  ;
use constant BA_EVENT_MCASTED     => BA_MCASTED   ;
use constant BA_EVENT_MCASTFAIL   => BA_MCASTFAIL ;
use constant BA_EVENT_CLONING     => BA_CLONING   ;
use constant BA_EVENT_CLONED      => BA_CLONED    ;
use constant BA_EVENT_CLONEFAIL   => BA_CLONEFAIL ;
use constant BA_EVENT_MIGRATING   => BA_MIGRATING ;
use constant BA_EVENT_MIGRATED    => BA_MIGRATED  ;
use constant BA_EVENT_MIGRATEFAIL => BA_MIGRATEFAIL;

=pod

=item array baStates

This is an array of all the state names in the order they are defined
as constant values above.

The admin, actions, and events are each from a corresponding and set
to the value of that state constant.

=cut

@baStates =
    (
     'added'      ,
     'removed'    ,
     'enabled'    ,
     'disabled'   ,
     'ignored'    ,
     'none'       ,
     'inventory'  ,
     'build'      ,
     'diskwipe'   ,
     'rescue'     ,
     'norescue'   ,
     'localboot'  ,
     'pxewait'    ,
     'netboot'    ,
     'found'      ,
     'register'   ,
     'building'   ,
     'built'      ,
     'spoofed'    ,
     'wiping'     ,
     'wiped'      ,
     'wipefail'   ,
     'image'      ,
     'imaging'    ,
     'imaged'     ,
     'imagefail'  ,
     'mcast'      ,
     'mcasting'   ,
     'mcasted'    ,
     'mcastfail'  ,
     'clone'      ,
     'cloning'    ,
     'cloned'     ,
     'clonefail'  ,
     'migrate'    ,
     'migrating'  ,
     'migrated'   ,
     'migratefail',
     );

=item hash baState

here we define a hash to make easy using the state constants easier

=cut

%baState =
    (
     1              => 'added'      ,
     2              => 'removed'    ,
     3              => 'enabled'    ,
     4              => 'disabled'   ,
     5              => 'ignored'    ,
     6              => 'none'       ,
     7              => 'inventory'  ,
     8              => 'build'      ,
     9              => 'diskwipe'   ,
     10             => 'rescue'     ,
     11             => 'norescue'   ,
     12             => 'localboot'  ,
     13             => 'pxewait'    ,
     14             => 'netboot'    ,
     15             => 'found'      ,
     16             => 'register'   ,
     17             => 'building'   ,
     18             => 'built'      ,
     19             => 'spoofed'    ,
     20             => 'wiping'     ,
     21             => 'wiped'      ,
     22             => 'wipefail'   ,
     23             => 'image'      ,
     24             => 'imaging'    ,
     25             => 'imaged'     ,
     26             => 'imagefail'  ,
     27             => 'mcast'      ,
     28             => 'mcasting'   ,
     29             => 'mcasted'    ,
     30             => 'mcastfail'  ,
     31             => 'clone'      ,
     32             => 'cloning'    ,
     33             => 'cloned'     ,
     34             => 'clonefail'  ,
     35             => 'migrate'    ,
     36		    => 'migrating'  ,
     37		    => 'migrated'   ,
     38		    => 'migratefail'   ,

     'added'        => BA_ADDED     ,
     'removed'      => BA_REMOVED   ,
     'enabled'      => BA_ENABLED   ,
     'disabled'     => BA_DISABLED  ,
     'ignored'      => BA_IGNORED   ,
     'none'         => BA_NONE      ,
     'inventory'    => BA_INVENTORY ,
     'build'        => BA_BUILD     ,
     'diskwipe'     => BA_DISKWIPE  ,
     'rescue'       => BA_RESCUE    ,
     'norescue'     => BA_NORESCUE  ,
     'localboot'    => BA_LOCALBOOT ,
     'pxewait'      => BA_PXEWAIT   ,
     'netboot'      => BA_NETBOOT   ,
     'found'        => BA_FOUND     ,
     'register'     => BA_REGISTER  ,
     'building'     => BA_BUILDING  ,
     'built'        => BA_BUILT     ,
     'spoofed'      => BA_SPOOFED   ,
     'wiping'       => BA_WIPING    ,
     'wiped'        => BA_WIPED     ,
     'wipefail'     => BA_WIPEFAIL  ,
     'image'        => BA_IMAGE     ,
     'imaging'      => BA_IMAGING   ,
     'imaged'       => BA_IMAGED    ,
     'imagefail'    => BA_IMAGEFAIL ,
     'mcast'        => BA_MCAST     ,
     'mcasting'     => BA_MCASTING  ,
     'mcasted'      => BA_MCASTED   ,
     'mcastfail'    => BA_MCASTFAIL ,
     'clone'        => BA_CLONE     ,
     'cloning'      => BA_CLONING   ,
     'cloned'       => BA_CLONED    ,
     'clonefail'    => BA_CLONEFAIL ,
     'migrate'      => BA_MIGRATE   ,
     'migrating'    => BA_MIGRATING ,
     'migrated'     => BA_MIGRATED  ,
     'migratefail'  => BA_MIGRATEFAIL,

     BA_ADDED       => 'added'      ,
     BA_REMOVED     => 'removed'    ,
     BA_ENABLED     => 'enabled'    ,
     BA_DISABLED    => 'disabled'   ,
     BA_IGNORED     => 'ignored'    ,
     BA_NONE        => 'none'       ,
     BA_INVENTORY   => 'inventory'  ,
     BA_BUILD       => 'build'      ,
     BA_DISKWIPE    => 'diskwipe'   ,
     BA_RESCUE      => 'rescue'     ,
     BA_NORESCUE    => 'norescue'   ,
     BA_LOCALBOOT   => 'localboot'  ,
     BA_PXEWAIT     => 'pxewait'    ,
     BA_NETBOOT     => 'netboot'    ,
     BA_FOUND       => 'found'      ,
     BA_REGISTER    => 'register'   ,
     BA_BUILDING    => 'building'   ,
     BA_BUILT       => 'built'      ,
     BA_SPOOFED     => 'spoofed'    ,
     BA_WIPING      => 'wiping'     ,
     BA_WIPED       => 'wiped'      ,
     BA_WIPEFAIL    => 'wipefail'   ,
     BA_IMAGE       => 'image'      ,
     BA_IMAGING     => 'imaging'    ,
     BA_IMAGED      => 'imaged'     ,
     BA_IMAGEFAIL   => 'imagefail'  ,
     BA_MCAST       => 'mcast'      ,
     BA_MCASTING    => 'mcasting'   ,
     BA_MCASTED     => 'mcasted'    ,
     BA_MCASTFAIL   => 'mcastfail'  ,
     BA_CLONE       => 'clone'      ,
     BA_CLONING     => 'cloning'    ,
     BA_CLONED      => 'cloned'     ,
     BA_CLONEFAIL   => 'clonefail'  ,
     BA_MIGRATE     => 'migrate'    ,
     BA_MIGRATING   => 'migrating'  ,
     BA_MIGRATED    => 'migrated'   ,
     BA_MIGRATEFAIL => 'migratefail',

     BA_ADMIN_ADDED       => 'added'      ,
     BA_ADMIN_REMOVED     => 'removed'    ,
     BA_ADMIN_ENABLED     => 'enabled'    ,
     BA_ADMIN_DISABLED    => 'disabled'   ,
     BA_ADMIN_IGNORED     => 'ignored'    ,

     BA_ACTION_NONE       => 'none'       ,
     BA_ACTION_INVENTORY  => 'inventory'  ,
     BA_ACTION_BUILD      => 'build'      ,
     BA_ACTION_DISKWIPE   => 'diskwipe'   ,
     BA_ACTION_RESCUE     => 'rescue'     ,
     BA_ACTION_NORESCUE   => 'norescue'   ,
     BA_ACTION_LOCALBOOT  => 'localboot'  ,
     BA_ACTION_PXEWAIT    => 'pxewait'    ,
     BA_ACTION_NETBOOT    => 'netboot'    ,
     BA_ACTION_IMAGE      => 'image'      ,
     BA_ACTION_MCAST      => 'mcast'      ,
     BA_ACTION_CLONE      => 'clone'      ,
     BA_ACTION_MIGRATE    => 'migrate'    ,

     BA_EVENT_FOUND       => 'found'      ,
     BA_EVENT_REGISTER    => 'register'   ,
     BA_EVENT_BUILDING    => 'building'   ,
     BA_EVENT_BUILT       => 'built'      ,
     BA_EVENT_SPOOFED     => 'spoofed'    ,
     BA_EVENT_WIPING      => 'wiping'     ,
     BA_EVENT_WIPED       => 'wiped'      ,
     BA_EVENT_WIPEFAIL    => 'wipefail'   ,
     BA_EVENT_IMAGE       => 'image'      ,
     BA_EVENT_IMAGING     => 'imaging'    ,
     BA_EVENT_IMAGED      => 'imaged'     ,
     BA_EVENT_IMAGEFAIL   => 'imagefail'  ,
     BA_EVENT_MCASTING    => 'mcasting'   ,
     BA_EVENT_MCASTED     => 'mcasted'    ,
     BA_EVENT_MCASTFAIL   => 'mcastfail'  ,
     BA_EVENT_CLONING     => 'cloning'    ,
     BA_EVENT_CLONED      => 'cloned'     ,
     BA_EVENT_CLONEFAIL   => 'clonefail'  ,
     BA_EVENT_MIGRATING   => 'migrating'  ,
     BA_EVENT_MIGRATED    => 'migrated'   ,
     BA_EVENT_MIGRATEFAIL => 'migratefail',
     );

=item admin_state_change

The administrative bahost related actions / states including

  enable | disable | ( ignore obsolete )

use the admin that triggered this call
and the current state to decide on next state

=cut

sub admin_state_change
{
    my $dbh      = shift;
    my $event    = shift;

    my $macref   = shift;       # modified for all state changes
    my $actref   = shift;       # modified for all state changes

    if ( $event eq BA_ADMIN_ADDED ) {
        unless ( defined $actref->{admin} and $actref->{admin} ne "" ) {
            $actref->{admin} = BA_ADMIN_ENABLED;
        }
        $actref->{oper}    = $event;
        $actref->{pxecurr} = BA_ACTION_NONE;
        $actref->{pxenext} = BA_ACTION_INVENTORY;
    }
    elsif ( $event eq BA_ADMIN_REMOVED ) {
        unless ( defined $actref->{admin} and $actref->{admin} ne "" ) {
            $actref->{admin} = BA_ADMIN_ENABLED;
        }
        $actref->{oper}    = $event;
        $actref->{pxecurr} = BA_ACTION_NONE;
        $actref->{pxenext} = BA_ACTION_PXEWAIT;
    }
    elsif ( $event eq BA_ADMIN_ENABLED ) {
        $actref->{admin} = $event;
    }
    elsif ( $event eq BA_ADMIN_DISABLED ) {
        $actref->{admin} = $event;
    }
    elsif ( $event eq BA_ADMIN_IGNORED ) {
        $actref->{admin}   = $event;
        $actref->{oper}    = BA_ACTION_LOCALBOOT;
        $actref->{pxecurr} = BA_ACTION_NONE;
        $actref->{pxenext} = BA_ACTION_NONE;
    }
    else {
        print "Unknown admin value $event in attempt to change state.\n";
    }
}

=item action_state_change

The actions related bado user command including

  inventory | build | diskwipe | rescue | localboot | pxewait | netboot | image

use bado action that triggered this call
and the current state to decide on next state

=cut

sub action_state_change
{
    my $dbh    = shift;
    my $event  = shift;

    my $macref = shift;
    my $actref = shift;

    unless ( defined $actref->{admin} and $actref->{admin} ne "" ) {
        $actref->{admin} = BA_ADMIN_ENABLED;
    }
    unless ( defined $actref->{pxecurr} and $actref->{pxecurr} ne "" ) {
        $actref->{pxecurr} = $event;
    }
    $actref->{oper} = $event;
    $actref->{pxenext} = $event;
}

=item event_state_change

use pxe or callback event that triggered this call
and the current state to decide on next state

=cut

sub event_state_change
{
    my $dbh    = shift;
    my $event  = shift;

    my $macref = shift;
    my $actref = shift;

    # we always have an $actref even if just a state holder
    # created even on pxeboot discover / found / inventory

    if ( $event eq BA_EVENT_FOUND ) {
        $actref->{admin}   = BA_ADMIN_ENABLED;
        $actref->{oper}    = BA_ADMIN_ADDED;
        $actref->{pxecurr} = BA_ACTION_INVENTORY;
        $actref->{pxenext} = BA_ACTION_LOCALBOOT;
    }
    elsif ( $event eq BA_EVENT_REGISTER ) {
        # question is what is the next thing - given that we're
        # done with inventory - and next may be localboot or
        # build, or pxewait if user set to entry after discover
        # or none if set to ignore....

        if ( $macref->{state} eq BA_ACTION_BUILD or
             $macref->{state} eq BA_ACTION_DISKWIPE or
             $macref->{state} eq BA_ACTION_RESCUE or
             $macref->{state} eq BA_ACTION_LOCALBOOT or
             $macref->{state} eq BA_ACTION_IMAGE or
             $macref->{state} eq BA_ACTION_MCAST or
             $macref->{state} eq BA_ACTION_CLONE or
             $macref->{state} eq BA_ACTION_NETBOOT
            ){
            $actref->{pxenext} = $macref->{state};
        }
        if ( $macref->{state} eq BA_ACTION_PXEWAIT or
             $macref->{state} eq BA_ACTION_INVENTORY or
             $macref->{state} eq BA_EVENT_FOUND or
             $macref->{state} eq BA_ADMIN_ADDED
            ){
            $actref->{pxenext} = BA_ACTION_PXEWAIT;
        }
        if ( $macref->{state} eq BA_ACTION_NONE )
        {
            # obsolete IGNORE handling removed here
            $actref->{pxenext} = BA_ACTION_NONE;
        }
        $actref->{oper} = $event;
        $actref->{pxecurr} = BA_ACTION_INVENTORY;
    }
    elsif ( $event eq BA_EVENT_BUILDING ) {
        if ( defined $actref->{storageid} and $actref->{storageid} ne "" ) {
            $actref->{pxenext} = BA_ACTION_NETBOOT;
        } else {
            $actref->{pxenext} = BA_ACTION_LOCALBOOT;
        }
        $actref->{oper}    = $event;
        $actref->{pxecurr} = BA_ACTION_BUILD;
    } elsif ( $event eq BA_EVENT_BUILT or
              $event eq BA_EVENT_SPOOFED
             ) {
        if ( defined $actref->{storageid} and $actref->{storageid} ne "" ) {
            $actref->{pxecurr} = BA_ACTION_NETBOOT;
        } else {
            $actref->{pxecurr} = BA_ACTION_LOCALBOOT;
        }
        $actref->{oper}    = $event;
    }
    elsif ( $event eq BA_EVENT_WIPING ) {
        $actref->{oper}    = $event;
        $actref->{pxecurr} = BA_ACTION_DISKWIPE;
    }
    elsif ( $event eq BA_EVENT_WIPED or
            $event eq BA_EVENT_WIPEFAIL
           ) {
        $actref->{oper}    = $event;
        $actref->{pxecurr} = BA_ACTION_DISKWIPE;
        $actref->{pxenext} = BA_ACTION_PXEWAIT;
    }
    elsif ( $event eq BA_EVENT_IMAGING ) {
        $actref->{oper}    = $event;
        $actref->{pxecurr} = BA_ACTION_IMAGE;
        $actref->{pxenext} = BA_ACTION_LOCALBOOT;
    }
    elsif ( $event eq BA_EVENT_IMAGED or
            $event eq BA_EVENT_IMAGEFAIL
           ) {
        $actref->{oper}    = $event;
        $actref->{pxenext} = BA_ACTION_LOCALBOOT;
    }
    elsif ( $event eq BA_EVENT_MCASTING ) {
        $actref->{oper}    = $event;
        $actref->{pxecurr} = BA_ACTION_MCAST;
        $actref->{pxenext} = BA_ACTION_LOCALBOOT;
    }
    elsif ( $event eq BA_EVENT_MCASTED or
            $event eq BA_EVENT_MCASTFAIL
           ) {
        $actref->{oper}    = $event;
        $actref->{pxenext} = BA_ACTION_LOCALBOOT;
    }
    elsif ( $event eq BA_EVENT_CLONING ) {
        $actref->{oper}    = $event;
        $actref->{pxecurr} = BA_ACTION_CLONE;
        $actref->{pxenext} = BA_ACTION_LOCALBOOT;
    }
    elsif ( $event eq BA_EVENT_CLONED or
            $event eq BA_EVENT_CLONEFAIL
           ) {
        $actref->{oper}    = $event;
        $actref->{pxenext} = BA_ACTION_LOCALBOOT;
    }
    elsif ( $event eq BA_EVENT_MIGRATING ) {
        $actref->{oper}    = $event;
        $actref->{pxecurr} = BA_ACTION_MIGRATE;
        $actref->{pxenext} = BA_ACTION_NETBOOT;
    }
    elsif ( $event eq BA_EVENT_MIGRATED ) {
        $actref->{oper}    = $event;
        $actref->{pxenext} = BA_ACTION_NETBOOT;
    }
    elsif ( $event eq BA_EVENT_MIGRATEFAIL) {
        $actref->{oper}    = $event;
        $actref->{pxenext} = BA_ACTION_PXEWAIT;
    }
    else {
        print "Unknown event value $event in attempt to change state.\n";
    }
}

###########################################################################
##
##  non exported routine

sub get_previous_state
{
    my $dbh    = shift;
    my $macref = shift;

    my $state;
    my %stack = ();
    &get_state_stack( $dbh, $macref, \%stack );

    # rescue is current [0]
    # if count is 1 - all we have is 'rescue' - can't be...
    # must have some prior info about the entry and a host template
    unless ( $stack{count} > 1 ) {
        croak "Impossible to have only 'rescue' state in the mac table";
    }

    # else skip back one (or if one back is "disabled" skip back two)
    # this is the only way we can deal with "disable/rescue/disable/..."
    $state = $stack{ordered}[1];
    $state = $stack{ordered}[2] if $state eq "disabled";
    $state = $baState{ $state };

    return $state;
}

sub get_state_stack
{
    my $dbh    = shift;
    my $macref = shift;

    my $stack  = shift;         # hash ref

    while ( my ($key, $val) = each (%$macref) ) {
        next if ( $key eq "state" or $key eq "mac" );
        next unless ( defined $val );
        $stack->{ $key } = $val; # only states with timestamps
    }
    @{$stack->{ordered}} = reverse sort { $stack->{ $a } cmp $stack->{ $b } } keys %$stack;
    $stack->{count} = scalar @{$stack->{ordered}};
}


1;

__END__


