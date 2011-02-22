package BaracusSql;

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

use Tie::IxHash;

use lib "/usr/share/baracus/perl";

use BaracusState qw ( :vars );

=pod

=head1 NAME

B<BaracusSql> - hash definitions and subroutines for managing Baracus sql

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
         vars =>
         [qw(
                BA_DBMAXLEN
                %baTbls
                %baTblCert
                %baTblId
            )],
         subs =>
         [qw(
                hash2columns
                get_cols
                get_col_type_href
                bytea_encode
                bytea_decode
                get_sqltftp_tables
                get_baracus_tables
                get_baracus_functions
                get_baracus_triggers
            )],
         );
    Exporter::export_ok_tags('vars');
    Exporter::export_ok_tags('subs');
}

# for sql tftp db binary file chunking 1MB blobs
use constant BA_DBMAXLEN => 268435456; # 256 MB
#use constant BA_DBMAXLEN => 1048575;

use vars qw ( %baTbls %baTblCert %baTblId );

%baTbls =
    (
     'file'      => 'sqlfstable',

     'mac'       => 'mac',
     'host'      => 'host',
     'distro'    => 'distro',
     'iso'       => 'iso',
     'hardware'  => 'hardware',
     'hwcert'    => 'hardware_cert',
     'module'    => 'module',
     'modcert'   => 'module_cert',
     'profile'   => 'profile',
     'autobuild' => 'autobuild',
     'abcert'    => 'autobuild_cert',
     'action'    => 'action',
     'history'   => 'action_hist',
     'actabld'   => 'action_autobuild',
     'actmod'    => 'action_module',
     'power'     => 'power',
     'storage'   => 'storage',
     'mcast'     => 'mcast',
     'user'      => 'auth',
     );


%baTblCert =
    (
     'hardware'  => 'hardware_cert',
     'module'    => 'module_cert',
     'autobuild' => 'autobuild_cert',
     'profile'   => 'profile_cert',
     );

# the following hash if for the most common WHERE lookup values
# not the actual key(s) for uniquely identifying a table row

%baTblId =
    (
     'file'      => 'name',         # to get all chunks (key is SERIAL)

     'mac'       => 'mac',          # unique id
     'host'      => 'hostname',     # unique id
     'distro'    => 'distroid',     # unique id
     'iso'       => 'iso',          # unique id
     'hardware'  => 'hardwareid',   # unique id
     'hwcert'    => 'distroid',     # to get all hw certified for distro
     'module'    => 'moduleid',     # unique id
     'modcert'   => 'distroid',     # to get all mod certified for distro
     'profile'   => 'profileid',    # unique id
     'autobuild' => 'autobuildid',  # unique id
     'abcert'    => 'distroid',     # to get all abuild certified for distro
     'action'    => 'mac',          # unique id
     'history'   => 'mac',          # to get all action hist for given mac
     'actmod'    => 'mac',          # to get all modules for given action/mac
     'actabld'   => 'mac',          # unique id
     'power'     => 'mac',          # unique id
     'storage'   => 'storageid',    # unique id
     'mcast'     => 'mcastid',      # unique id
     'user'      => 'username',     # unique id
     );


=item keys2columns

generate a string column representation
suitable for sql SELECT statements from
hash keys

=cut

sub keys2columns
{
    my $hash = shift;
    my $str = '';
    foreach my $key ( keys %{ $hash } ) {
        next if ( $key =~ m|^[A-Z]+| );
        $str .= ',' if $str;
        $str .= " $key";
    }
    return $str;
}

=item keys2shorthashdef

generate an abbreviated hash of the key/col => val(len)
for use in routines to do length and type checking

=cut

sub keys2shorthashdef
{
    my $hash = shift;
    my %reth;
    while ( my ( $key, $val ) = each %{ $hash } ) {
        # by convention our UPPERCASE keys are SQL directives
        next if ( $key =~ m|^[A-Z]+| );
        # anything following the 'type(len)' value definition is stripped
        $val =~ s|\w+.*$||;
        $reth{$key} = $val;
    }
    return \%reth;
}

=item hash2columns

generate the string column name type representation
suitable for sql CREATE TABLE statements
from hash key, values pairs

=cut

sub hash2columns
{
    my $hash = shift;
    my $str = '';
    while ( my ($key,$value) = each %{ $hash } ) {
        $str .= ',' if $str;
        $str .= sprintf( "%s %s", $key, $value );
    }
    return $str;
}

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
    } elsif ( defined $sqltftptbls ) {
        return keys2columns( $sqltftptbls );
    } else {
        carp "Internal database table/name usage error.\n";
        return undef;
    }
}

=item get_col_type_href

wrapper to get abrivated column type[(len)] table definition
no matter which baracus related database it is from

=cut

sub get_col_type_href
{
    my $tbl = shift;
    my $baracustbls = get_baracus_tables()->{ $tbl };
    my $sqltftptbls = get_sqltftp_tables()->{ $tbl };
    if ( defined $baracustbls ) {
        return keys2shorthashdef( $baracustbls );
    } elsif ( defined $sqltftptbls ) {
        return keys2shorthashdef( $sqltftptbls );
    } else {
        carp "Internal database table/name usage error.\n";
        return undef;
    }
}

# encode bytestream for binary VARCHAR storage

sub bytea_encode
{
    my ($in, $out);
    $in = shift;
    $out = pack( 'u', $in);
    return $out;
}

# decode bytestream for binary VARCHAR storage

sub bytea_decode
{
    my ($in,$out);
    $in = shift;
    $out = unpack( 'u', $in );
    return $out;
}



# sqltftp database tables

sub get_sqltftp_tables
{
    my $tbl_sqlfs = "sqlfstable";
    my %tbl_sqlfs_columns =
        (
         'id'          => 'SERIAL PRIMARY KEY',
         'name'        => 'VARCHAR(160) NOT NULL',
         'size'        => 'VARCHAR',
         'description' => 'VARCHAR',
         'bin'         => 'VARCHAR',
         'enabled'     => 'INTEGER',
         'insertion'   => 'TIMESTAMP',
         'change'      => 'TIMESTAMP',
         );

    my %sqltftp_tbls =
        (
         $tbl_sqlfs    => \%tbl_sqlfs_columns,
         );
    return \%sqltftp_tbls;
}

# baracus database tables

sub get_baracus_tables
{
    my $tbl_mac = "mac";
    my %tbl_mac_cols =
        (
         'mac'       => 'VARCHAR(17) PRIMARY KEY',
         'state'     => 'INTEGER',
         );
    # all states have a column here with a timestamp
    # to show when this mac was last in the named state
    # this tracks **ALL** admin, action, and events

    # build this set of columns dynamically
    # based on the baStates array from BaracusState.pm
    foreach my $col ( @baStates ) {
        $tbl_mac_cols{ $col } = 'TIMESTAMP';
    }

    # hostname to mac binding - hardware profile info may go here
    # like a distro - the host relates to a box and info about the
    # box not a combination of things currently installed on the box

    my $tbl_host = "host";
    my %tbl_host_columns =
        (
         'hostname' => 'VARCHAR(64) PRIMARY KEY',
         'mac'      => 'VARCHAR(17) REFERENCES mac(mac) ON DELETE CASCADE',
         );

    my $tbl_distro = "distro";
    my %tbl_distro_columns =
        (
         'distroid'    => 'VARCHAR(128) PRIMARY KEY',
         'os'          => 'VARCHAR(64)',
         'release'     => 'VARCHAR(16)',
         'addos'       => 'VARCHAR(16)',
         'addrel'      => 'VARCHAR(16)',
         'arch'        => 'VARCHAR(16)',

         'description' => 'VARCHAR(64)',
         'addon'       => 'BOOLEAN',
         'shareip'     => 'VARCHAR(15)',
         'sharetype'   => 'VARCHAR(8)',
         'basepath'    => 'VARCHAR(128)',
         'status'      => 'INTEGER',
         'creation'    => 'TIMESTAMP',
         'change'      => 'TIMESTAMP',
         );

    my $tbl_iso = "iso";
    my %tbl_iso_columns =
        (
         'iso'         => 'VARCHAR(128)',
         'mntpoint'    => 'VARCHAR(128)',
         'distroid'    => 'VARCHAR(128) REFERENCES distro(distroid)',
         'is_loopback' => 'BOOLEAN',
         'sharetype'   => 'INTEGER',
         'is_local'    => 'BOOLEAN',
         'creation'    => 'TIMESTAMP',
         'change'      => 'TIMESTAMP',
         'CONSTRAINT'  => 'iso_pk PRIMARY KEY (iso, mntpoint)',
        );

#         'kernel'      => 'VARCHAR(32)',
#         'initrd'      => 'VARCHAR(32)',

    my $tbl_hardware = "hardware";
    my %tbl_hardware_columns =
        (
         'hardwareid'   => 'VARCHAR(32)',
         'version'      => 'INTEGER',
         'description'  => 'VARCHAR(64)',
         'status'       => 'BOOLEAN',
         'bootArgs'     => 'VARCHAR(4096)',
         'rootDisk'     => 'VARCHAR(32)',
         'rootPart'     => 'VARCHAR(32)',
         'hwdriver'     => 'VARCHAR(32)',
         'CONSTRAINT'   => 'hardware_pk PRIMARY KEY (hardwareid, version)',
         );

    my $tbl_hardware_cert = "hardware_cert";
    my %tbl_hardware_cert_columns =
        (
         'hardwareid'   => 'VARCHAR(32)',
         'distroid'     => 'VARCHAR(128) REFERENCES distro(distroid)',
         'CONSTRAINT'   => 'hardware_cert_pk PRIMARY KEY (hardwareid, distroid)',
         );

    my $tbl_module = "module";
    my %tbl_module_columns =
        (
         'moduleid'    => 'VARCHAR(32)',
         'version'     => 'INTEGER',
         'description' => 'VARCHAR(64)',
         'interpreter' => 'VARCHAR(8)',
         'data'        => 'VARCHAR',
         'status'      => 'BOOLEAN',
         'CONSTRAINT'  => 'module_pk PRIMARY KEY (moduleid, version)',
         );

    my $tbl_module_cert = "module_cert";
    my %tbl_module_cert_columns =
        (
         'moduleid'    => 'VARCHAR(32)',
         'distroid'    => 'VARCHAR(128) REFERENCES distro(distroid)',
         'mandatory'   => 'BOOLEAN',
         'CONSTRAINT'  => 'module_cert_pk PRIMARY KEY (moduleid, distroid)',
         );

    my $tbl_profile = "profile";
    my %tbl_profile_columns =
        (
         'profileid'   => 'VARCHAR(32)',
         'version'     => 'INTEGER',
         'description' => 'VARCHAR(64)',
         'data'        => 'VARCHAR',
         'status'      => 'BOOLEAN',
         'CONSTRAINT'  => 'profile_pk PRIMARY KEY (profileid, version)',
         );

    my $tbl_autobuild = "autobuild";
    my %tbl_autobuild_columns =
        (
         'autobuildid' => 'VARCHAR(128)',
         'version'     => 'INTEGER',
         'description' => 'VARCHAR(64)',
         'data'        => 'VARCHAR',
         'status'      => 'BOOLEAN',
         'CONSTRAINT'  => 'autobuild_pk PRIMARY KEY (autobuildid, version)',
         );

    my $tbl_autobuild_cert = "autobuild_cert";
    my %tbl_autobuild_cert_columns =
        (
         'autobuildid' => 'VARCHAR(32)',
         'distroid'    => 'VARCHAR(128) REFERENCES distro(distroid)',
         'CONSTRAINT'  => 'autobuild_cert_pk PRIMARY KEY (autobuildid, distroid)',
         );

    my $tbl_action = "action";
    my %tbl_action_columns =
        (
         'mac'           => 'VARCHAR(17)  PRIMARY KEY',
         'hostname'      => 'VARCHAR(64)',

         'distro'        => 'VARCHAR(128) DEFAULT NULL',
         'hardware'      => 'VARCHAR(32)  DEFAULT NULL',
         'hardware_ver'  => 'INTEGER      DEFAULT NULL',
         'profile'       => 'VARCHAR(32)  DEFAULT NULL',
         'profile_ver'   => 'INTEGER      DEFAULT NULL',

         'addons'      => 'VARCHAR', # list of addons to use for build
         'vars'        => 'VARCHAR', # list of additional vars for build

         'oper'        => 'INTEGER', # oper state action or event driven
         'admin'       => 'INTEGER', # admin enable / disabled / ignore

         'pxecurr'     => 'INTEGER', # current pxestate / action on pxeboot
         'pxenext'     => 'INTEGER', # next state / action on pxeboot

         'ip'          => 'VARCHAR(15)',
         'uuid'        => 'VARCHAR(36)',
         'loghost'     => 'VARCHAR(64)',
         'raccess'     => 'VARCHAR(128)',

         'autonuke'    => 'BOOLEAN', # if asserted pass autowipe option
         'autoclone'   => 'BOOLEAN', # if asserted pass autoclone option
         'disk'        => 'INTEGER', # localboot target disk
         'partition'   => 'INTEGER', # localboot target partition
         'storageid'   => 'VARCHAR', # clone/image id
         'mcastid'     => 'VARCHAR', # multicast channel id
         'cmdline'     => 'VARCHAR',
         'creation'    => 'TIMESTAMP',
         'change'      => 'TIMESTAMP',

         'FOREIGN KEY' => '(mac)                      REFERENCES mac(mac)',
         'FOREIGN KEY' => '(distro)                   REFERENCES distro(distroid)',
         'FOREIGN KEY' => '(hardware,  hardware_ver)  REFERENCES hardware(hardwareid,version)   ',
         'FOREIGN KEY' => '(profile,   profile_ver)   REFERENCES profile(profileid,version)   ',
         );

    my $tbl_action_hist = "action_hist";
    # copy the action table and modify the 'mac' to remove the "KEY"
    my %tbl_action_hist_columns = %tbl_action_columns;
    $tbl_action_hist_columns{mac} = 'VARCHAR(17)';
    # don't define another hash
    # we have the action table already.

    my $tbl_action_autobuild = "action_autobuild";
    my %tbl_action_autobuild_columns =
        (
         'mac'           => 'VARCHAR(17) PRIMARY KEY REFERENCES action(mac) ON DELETE CASCADE',
         'autobuild'     => 'VARCHAR(32)',
         'autobuild_ver' => 'INTEGER',
         'FOREIGN KEY' => '(autobuild, autobuild_ver) REFERENCES autobuild(autobuildid,version)   ',
         );

    my $tbl_action_module = "action_module";
    my %tbl_action_module_columns =
        (
         'mac'         => 'VARCHAR(17) REFERENCES action(mac) ON DELETE CASCADE',
         'module'      => 'VARCHAR(32)',
         'module_ver'  => 'INTEGER',

         'FOREIGN KEY' => '(module, module_ver) REFERENCES module(moduleid, version)',
         'CONSTRAINT'  => 'action_module_pk PRIMARY KEY (mac, module)',
         );


    my $tbl_power = "power";
    my %tbl_power_columns =
        (
         'mac'     => 'VARCHAR(17) PRIMARY KEY',
         'hostname'=> 'VARCHAR(64)',
         'ctype'   => 'VARCHAR(16)',
         'login'   => 'VARCHAR(16)',
         'passwd'  => 'VARCHAR(32)',
         'bmcaddr' => 'VARCHAR(1024)', # virsh URI
         'node'    => 'VARCHAR(4096)',
         'other'   => 'VARCHAR(32)',
         );

    my $tbl_storage = "storage";
    my %tbl_storage_columns =
        (
         'storageid'   => 'VARCHAR(64) PRIMARY KEY', # storage alias/name
         'storageip'   => 'VARCHAR(15)',
         'storage'     => 'VARCHAR(64)', # storage path
         'md5sum'      => 'VARCHAR(32)',
         'size'        => 'VARCHAR',
         'type'        => 'INTEGER',     # 1 ISCSI, 2 AOE, 3 NFS, 4 IMAGE
         'username'    => 'VARCHAR(32)',
         'passwd'      => 'VARCHAR(32)',
         'description' => 'VARCHAR(124)',
         );

    my $tbl_mcast = "mcast";
    my %tbl_mcast_columns =
        (
         'mcastid'     => 'VARCHAR(64) PRIMARY KEY', # udpcast channel alias/name
         'storageid'   => 'VARCHAR(64)',
         'dataip'      => 'VARCHAR(15)',
         'rdvip'       => 'VARCHAR(15)',
         'interface'   => 'VARCHAR(8)',
         'ratemx'      => 'INTEGER',
         'mrecv'       => 'INTEGER',
         'status'      => 'BOOLEAN',
         );

    my $tbl_auth = "auth";
    my %tbl_auth_columns =
        (
         'username'    => 'VARCHAR(255) PRIMARY KEY',  # htpasswd2 limit
         'password'    => 'VARCHAR(128)', # sha-1 160bit, but prefix & base64 enc
         'encryption'  => 'INTEGER',      # mapping in BaracusAuth
         'status'      => 'BOOLEAN',
         'realm'       => 'VARCHAR(16)',  # useless here with only key username
         'creation'    => 'TIMESTAMP',    #   perhaps we need authrealm table
         'change'      => 'TIMESTAMP',    #   like a module certs table
         );

    tie( my %baracus_tbls, 'Tie::IxHash',
         $tbl_mac               => \%tbl_mac_cols,
         $tbl_host              => \%tbl_host_columns,
         $tbl_distro            => \%tbl_distro_columns,
         $tbl_iso               => \%tbl_iso_columns,
         $tbl_hardware          => \%tbl_hardware_columns,
         $tbl_hardware_cert     => \%tbl_hardware_cert_columns,
         $tbl_module            => \%tbl_module_columns,
         $tbl_module_cert       => \%tbl_module_cert_columns,
         $tbl_profile           => \%tbl_profile_columns,
         $tbl_autobuild         => \%tbl_autobuild_columns,
         $tbl_autobuild_cert    => \%tbl_autobuild_cert_columns,
         $tbl_action            => \%tbl_action_columns,
         $tbl_action_hist       => \%tbl_action_hist_columns,
         $tbl_action_module     => \%tbl_action_module_columns,
         $tbl_action_autobuild  => \%tbl_action_autobuild_columns,
         $tbl_power             => \%tbl_power_columns,
         $tbl_storage           => \%tbl_storage_columns,
         $tbl_mcast             => \%tbl_mcast_columns,
         $tbl_auth              => \%tbl_auth_columns,
        );
    return \%baracus_tbls;
}

sub get_baracus_functions
{
    my $histtbl  = get_baracus_tables()->{ action_hist };

    my $declare = "";
    my $insert  = "";
    my $values  = "";

    while ( my ( $col, $val ) = each %{ $histtbl } ) {
        # crude skip of SQL constraints
        next if ( $col =~ m|^[A-Z]+| );
        next if ( $col eq "change" );
        $val =~ s/[(|\s)].*//;  # strip off len or other constraints
        $insert .= ',' if $insert;
        $insert .= "${col}";
        $declare .= "new_${col} ${val} ; ";
        $values  .= ',' if $values;
        $values  .= "NEW.${col}";
    }
    $insert .= ",change";
    $values .= ",CURRENT_TIMESTAMP";

    my $func_add_delete = qq|
RETURNS TRIGGER AS \$host_state_trigger\$
    DECLARE
        $declare
    BEGIN
    INSERT INTO action_hist ( $insert )
    VALUES ( $values );
    RETURN NEW;
    END;
\$host_state_trigger\$ LANGUAGE 'plpgsql';
|;

    #     my $func_update = q|
    # RETURNS TRIGGER AS $host_state_trigger$
    #     DECLARE
    #         new_hostname VARCHAR;
    #         new_ip       VARCHAR;
    #         new_mac      VARCHAR;
    #         new_uuid     VARCHAR;
    #         new_pxestate INTEGER;
    #         new_admin    INTEGER;
    #         new_pxenext  INTEGER;
    #         new_oper     INTEGER;
    #         new_cmdline  VARCHAR;
    #         new_creation TIMESTAMP;
    #     BEGIN
    #     INSERT INTO action_hist ( hostname,
    #                                  ip,
    #                                  mac,
    #                                  uuid,
    #                                  pxestate,
    #                                  admin,
    #                                  pxenext,
    #                                  oper,
    #                                  cmdline,
    #                                  creation,
    #                                  change )
    #     VALUES ( NEW.hostname,
    #              NEW.ip,
    #              NEW.mac,
    #              NEW.uuid,
    #              NEW.pxestate,
    #              NEW.admin,
    #              NEW.pxenext,
    #              NEW.oper,
    #              NEW.cmdline,
    #              NEW.creation,
    #              CURRENT_TIMESTAMP(0) );
    #     RETURN NEW;
    #     END;
    # $host_state_trigger$ LANGUAGE 'plpgsql';
    # |;


    my %baracus_functions =
        (
         'action_state_add_delete()' => $func_add_delete,
         'action_state_update()'     => $func_add_delete,
         );

    return \%baracus_functions;
}

sub get_baracus_triggers
{
    my $trigger_add_delete = q|AFTER INSERT ON action
FOR EACH ROW EXECUTE PROCEDURE action_state_add_delete()
|;

    my $trigger_update = q|AFTER UPDATE ON action
FOR EACH ROW EXECUTE PROCEDURE action_state_update()
|;

    my %baracus_triggers =
        (
         'action_state_add_delete_trigger' => $trigger_add_delete,
         'action_state_update_trigger'     => $trigger_update,
         );

    return \%baracus_triggers;
}

1;

__END__


