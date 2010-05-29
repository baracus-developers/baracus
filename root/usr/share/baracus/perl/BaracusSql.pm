package BaracusSql;

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
            )],
         subs =>
         [qw(
                keys2columns
                hash2columns
                get_cols
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

use vars qw ( %baTbls );

%baTbls =
    (
     'tftp'      => 'sqlfstable',

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
     'power'     => 'power',
     'lun'       => 'lun',
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

=item hash2columns

generate a string column representation
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
         'mac'      => 'VARCHAR(17) REFERENCES mac',
         );

    my $tbl_distro = "distro";
    my %tbl_distro_columns =
        (
         'distroid'    => 'VARCHAR(128) PRIMARY KEY',
         'os'          => 'VARCHAR(64)',
         'release'     => 'VARCHAR(16)',
         'arch'        => 'VARCHAR(16)',
         'description' => 'VARCHAR(64)',
         'addon'       => 'BOOLEAN',
         'addos'       => 'VARCHAR(16)',
         'addrel'      => 'VARCHAR(16)',
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
         'iso'         => 'VARCHAR(128) NOT NULL',
         'distroid'    => 'VARCHAR(128)',
         'is_loopback' => 'BOOLEAN',
         'sharetype'   => 'INTEGER',
         'is_local'    => 'BOOLEAN',
         'mntpoint'    => 'VARCHAR(128)',
         'creation'    => 'TIMESTAMP',
         'change'      => 'TIMESTAMP',
         'CONSTRAINT'  => 'iso_pk PRIMARY KEY (iso, mntpoint)',
        );

#         'kernel'      => 'VARCHAR(32)',
#         'initrd'      => 'VARCHAR(32)',

    my $tbl_hardware = "hardware";
    my %tbl_hardware_columns =
        (
         'hardwareid'   => 'VARCHAR(32) NOT NULL',
         'version'      => 'INTEGER',
         'description'  => 'VARCHAR(64)',
         'status'       => 'BOOLEAN',
         'bootArgs'     => 'VARCHAR(256)',
         'rootDisk'     => 'VARCHAR(32)',
         'rootPart'     => 'VARCHAR(32)',
         'hwdriver'     => 'VARCHAR(32)',
         'CONSTRAINT'   => 'hardware_pk PRIMARY KEY (hardwareid, version)',
         );

    my $tbl_hardware_cert = "hardware_cert";
    my %tbl_hardware_cert_columns =
        (
         'hardwareid'   => 'VARCHAR(32) NOT NULL',
         'distroid'     => 'VARCHAR(128) NOT NULL',
         'FOREIGN KEY'  => '(hardwareid) REFERENCES hardware(hardwareid)',
         'FOREIGN KEY'  => '(distroid) REFERENCES distro(distroid)',
         'CONSTRAINT'   => 'hardware_cert_pk PRIMARY KEY (hardwareid, distroid)',
         );

    my $tbl_module = "module";
    my %tbl_module_columns =
        (
         'moduleid'    => 'VARCHAR(32) NOT NULL',
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
         'moduleid'    => 'VARCHAR(32) NOT NULL',
         'distroid'    => 'VARCHAR(128) NOT NULL',
         'mandatory'   => 'BOOLEAN',
         'FOREIGN KEY' => '(moduleid) REFERENCES module(moduleid)',
         'FOREIGN KEY' => '(distroid) REFERENCES distro(distroid)',
         'CONSTRAINT'  => 'module_cert_pk PRIMARY KEY (moduleid, distroid)',
         );

    my $tbl_profile = "profile";
    my %tbl_profile_columns =
        (
         'profileid'   => 'VARCHAR(32) NOT NULL',
         'version'     => 'INTEGER',
         'description' => 'VARCHAR(64)',
         'data'        => 'VARCHAR',
         'status'      => 'BOOLEAN',
         'CONSTRAINT'  => 'profile_pk PRIMARY KEY (profileid, version)',
         );

    my $tbl_autobuild = "autobuild";
    my %tbl_autobuild_columns =
        (
         'autobuildid' => 'VARCHAR(32) NOT NULL',
         'version'     => 'INTEGER',
         'description' => 'VARCHAR(64)',
         'data'        => 'VARCHAR',
         'status'      => 'BOOLEAN',
         'CONSTRAINT'  => 'autobuild_pk PRIMARY KEY (autobuildid, version)',
         );

    my $tbl_autobuild_cert = "autobuild_cert";
    my %tbl_autobuild_cert_columns =
        (
         'autobuildid' => 'VARCHAR(32) NOT NULL',
         'distroid'    => 'VARCHAR(128) NOT NULL',
         'FOREIGN KEY' => '(autobuildid) REFERENCES autobuild(autobuildid)',
         'FOREIGN KEY' => '(distroid) REFERENCES distro(distroid)',
         'CONSTRAINT'  => 'autobuild_cert_pk PRIMARY KEY (autobuildid, distroid)',
         );

    my $tbl_action = "action";
    my %tbl_action_columns =
        (
         'mac'         => 'VARCHAR(17) PRIMARY KEY',
         'hostname'    => 'VARCHAR(64)',
         'distro'      => 'VARCHAR(128)',

         'hardware'    => 'VARCHAR(32)',
         'hardwarever' => 'INTEGER',
         'profile'     => 'VARCHAR(32)',
         'profilever'  => 'INTEGER',
         'autobuild'   => 'VARCHAR(32)',
         'abuildver'   => 'INTEGER',

         'modules'     => 'VARCHAR', # list of moudles to use for build
         'addons'      => 'VARCHAR', # list of addons to use for build
         'vars'        => 'VARCHAR', # list of additional vars for build

         'oper'        => 'INTEGER', # oper state action or event driven
         'admin'       => 'INTEGER', # admin enable / disabled / ignore
         'autopxeoff'  => 'BOOLEAN', # has auto pxe disable been asserted
         'pxecurr'     => 'INTEGER', # current pxestate / action on pxeboot
         'pxenext'     => 'INTEGER', # next state / action on pxeboot

         'ip'          => 'VARCHAR(15)',
         'uuid'        => 'VARCHAR(36)',
         'loghost'     => 'VARCHAR(64)',
         'raccess'     => 'VARCHAR(128)',

         'autonuke'    => 'BOOLEAN', # if asserted pass autowipe option
         'netboot'     => 'VARCHAR', # netboot target (for iSCSI and ilk)
         'netbootip'   => 'VARCHAR', # netboot target server ip address
         'cmdline'     => 'VARCHAR',
         'creation'    => 'TIMESTAMP',
         'change'      => 'TIMESTAMP',

         'FOREIGN KEY' => '(distro)       REFERENCES distro(distroid)',
         'FOREIGN KEY' => '(hardware)     REFERENCES hardware(hardwareid)',
         'FOREIGN KEY' => '(hardwarever)  REFERENCES hardware(version)',
         'FOREIGN KEY' => '(profile)      REFERENCES profile(profileid)',
         'FOREIGN KEY' => '(profilever)   REFERENCES profile(version)',
         'FOREIGN KEY' => '(autobuild)    REFERENCES autobuild(autobuildid)',
         'FOREIGN KEY' => '(autobuildver) REFERENCES autobuild(version)',

         );

    my $tbl_action_hist = "action_hist";
    # copy the action table and modify the 'mac' to remove the "KEY"
    my %tbl_action_hist_columns = %tbl_action_columns;
    $tbl_action_hist_columns{mac} = 'VARCHAR(17)';

    # don't define another hash
    # we have the action table already.

    my $tbl_power = "power";
    my %tbl_power_columns =
        (
         'mac'     => 'VARCHAR(17) PRIMARY KEY',
         'hostname'=> 'VARCHAR(64)',
         'ctype'   => 'VARCHAR(16)',
         'login'   => 'VARCHAR(16)',
         'passwd'  => 'VARCHAR(32)',
         'bmcaddr' => 'VARCHAR(32)',
         'node'    => 'VARCHAR(32)',
         'other'   => 'VARCHAR(32)',
         );

    my $tbl_lun = "lun";
    my %tbl_lun_columns =
        (
         'targetid'    => 'VARCHAR(64) PRIMARY KEY',
         'targetip'    => 'VARCHAR(15)',
         'size'        => 'VARCHAR',
         'type'        => 'INTEGER', # 1 ISCSI, 2 AOE, 3 NFS, 4 FC <<-- should be embedded in the targetid / URI
         'username'    => 'VARCHAR(32)',
         'passwd'      => 'VARCHAR(32)',
         'name'        => 'VARCHAR(32)',
         'description' => 'VARCHAR(124)',
         );

    my $tbl_auth = "auth";
    my %tbl_auth_columns =
        (
         'username'    => 'VARCHAR(32) PRIMARY KEY',
         'password'    => 'VARCHAR(128)',
         'crypto'      => 'VARCHAR(16)',
         'realm'       => 'VARCHAR(16)',
         'creation'    => 'TIMESTAMP',
         'change'      => 'TIMESTAMP',
         );

    tie( my %baracus_tbls, 'Tie::IxHash',
         $tbl_mac            => \%tbl_mac_cols,
         $tbl_host           => \%tbl_host_columns,
         $tbl_distro         => \%tbl_distro_columns,
         $tbl_iso            => \%tbl_iso_columns,
         $tbl_hardware       => \%tbl_hardware_columns,
         $tbl_hardware_cert  => \%tbl_hardware_cert_columns,
         $tbl_module         => \%tbl_module_columns,
         $tbl_module_cert    => \%tbl_module_cert_columns,
         $tbl_profile        => \%tbl_profile_columns,
         $tbl_autobuild      => \%tbl_autobuild_columns,
         $tbl_autobuild_cert => \%tbl_autobuild_cert_columns,
         $tbl_action         => \%tbl_action_columns,
         $tbl_action_hist    => \%tbl_action_hist_columns,
         $tbl_power          => \%tbl_power_columns,
         $tbl_lun            => \%tbl_lun_columns,
         $tbl_auth           => \%tbl_auth_columns,
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


