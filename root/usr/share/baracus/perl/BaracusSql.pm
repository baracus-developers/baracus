package BaracusSql;

use 5.006;
use Carp;
use strict;
use warnings;

use Tie::IxHash;

BEGIN {
  use Exporter ();
  use vars qw( @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
  @ISA         = qw(Exporter);
  @EXPORT      = qw();
  @EXPORT_OK   = qw();

  %EXPORT_TAGS = (
    states => [qw(
        BA_DBMAXLEN
        BA_READY
        BA_BUILT
        BA_SPOOFED
        BA_DELETED
        BA_UPDATED
        BA_DISKWIPE
        BA_DISABLED
        BA_FOUND
        BA_BUILDING
        BA_WIPING
        BA_WIPED
        BA_WIPEFAIL
        BA_REGISTER
    )],
    vars => [qw( %baState )],
    subs => [qw(
        keys2columns
        hash2columns
        get_sqltftp_tables
        get_baracus_tables
        get_baracus_functions
        get_baracus_triggers
    )],
  );
  Exporter::export_ok_tags('states');
  Exporter::export_ok_tags('vars');
  Exporter::export_ok_tags('subs');
}

# for sql binary file chunking 1MB blobs
use constant BA_DBMAXLEN => 1048575;

use constant BA_READY    => 1;
use constant BA_BUILT    => 2;
use constant BA_SPOOFED  => 3;
use constant BA_DELETED  => 4;
use constant BA_UPDATED  => 5;
use constant BA_DISKWIPE => 6;
use constant BA_DISABLED => 7;
use constant BA_FOUND    => 8;
use constant BA_BUILDING => 9;
use constant BA_WIPING   => 10;
use constant BA_WIPED    => 11;
use constant BA_WIPEFAIL => 12;
use constant BA_REGISTER => 13;

=item baState

here we define some state constants and a hash to make easy use of them

=cut

use vars qw( %baState );

%baState =
    (
     1           => 'ready',
     2           => 'built',
     3           => 'spoofed',
     4           => 'deleted',
     5           => 'updated',
     6           => 'diskwipe',
     7           => 'disabled',
     8           => 'found',
     9           => 'building',
     10          => 'wiping',
     11          => 'wiped',
     12          => 'wipefail',
     13          => 'register',
     BA_READY    => 'ready',
     BA_BUILT    => 'built',
     BA_SPOOFED  => 'spoofed',
     BA_DELETED  => 'deleted',
     BA_UPDATED  => 'updated',
     BA_DISKWIPE => 'diskwipe',
     BA_DISABLED => 'disabled',
     BA_FOUND    => 'found',
     BA_BUILDING => 'building',
     BA_WIPING   => 'wiping',
     BA_WIPED    => 'wiped',
     BA_WIPEFAIL => 'wipefail',
     BA_REGISTER => 'register',
     'ready'     => BA_READY,
     'built'     => BA_BUILT,
     'spoofed'   => BA_SPOOFED,
     'deleted'   => BA_DELETED,
     'updated'   => BA_UPDATED,
     'diskwipe'  => BA_DISKWIPE,
     'disabled'  => BA_DISABLED,
     'found'     => BA_FOUND,
     'building'  => BA_BUILDING,
     'wiping'    => BA_WIPING,
     'wiped'     => BA_WIPED,
     'wipefail'  => BA_WIPEFAIL,
     'register'  => BA_REGISTER,
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

# sqltftp database tables

sub get_sqltftp_tables
{
    my $tbl_sqlfs = "sqlfstable";
    my %tbl_sqlfs_columns =
        (
         'id'          => 'SERIAL PRIMARY KEY',
         'name'        => 'VARCHAR(64) NOT NULL',
         'description' => 'VARCHAR(32)',
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
         'mac'      => 'VARCHAR(17) PRIMARY KEY',
         'state'    => 'INTEGER',     # last state
         'ready'    => 'TIMESTAMP',
         'built'    => 'TIMESTAMP',
         'spoofed'  => 'TIMESTAMP',
         'deleted'  => 'TIMESTAMP',
         'updated'  => 'TIMESTAMP',
         'diskwipe' => 'TIMESTAMP',
         'disabled' => 'TIMESTAMP',
         'found'    => 'TIMESTAMP',
         'building' => 'TIMESTAMP',
         'wiping'   => 'TIMESTAMP',
         'wiped'    => 'TIMESTAMP',
         'wipefail' => 'TIMESTAMP',
         'register' => 'TIMESTAMP',
         );

    my $tbl_templateid = "templateid";
    my %tbl_templateid_columns =
        (
         'hostname' => 'VARCHAR(32) PRIMARY KEY',
         'ip'       => 'VARCHAR(15)',
         'mac'      => 'VARCHAR(17)',
         'uuid'     => 'VARCHAR(36)',
         'loghost'  => 'VARCHAR(32)',
         'raccess'  => 'VARCHAR(128)',
         'autonuke' => 'BOOLEAN',
         'pxestate' => 'INTEGER',
         'state'    => 'INTEGER',
         'cmdline'  => 'VARCHAR(1024)',
         'creation' => 'TIMESTAMP',
         'change'   => 'TIMESTAMP',
         );

    my $tbl_templateidhist = "templateidhist";
    my %tbl_templateidhist_columns =
        (
         'hostname' => 'VARCHAR(32)',
         'ip'       => 'VARCHAR(15)',
         'mac'      => 'VARCHAR(17)',
         'uuid'     => 'VARCHAR(36)',
         'loghost'  => 'VARCHAR(32)',
         'raccess'  => 'VARCHAR(128)',
         'autonuke' => 'BOOLEAN',
         'pxestate' => 'INTEGER',
         'state'    => 'INTEGER',
         'cmdline'  => 'VARCHAR(1024)',
         'creation' => 'TIMESTAMP',
         'change'   => 'TIMESTAMP',
         );

    my $tbl_hardware_cfg = "hardware_cfg";
    my %tbl_hardware_cfg_columns =
        (
         'hardwareid'   => 'VARCHAR(32) PRIMARY KEY',
         'description'  => 'VARCHAR(64)',
         'bootArgs'     => 'VARCHAR(64)',
         'rootDisk'     => 'VARCHAR(32)',
         'rootPart'     => 'VARCHAR(32)',
         'pxeTemplate'  => 'VARCHAR(32)',
         'yastTemplate' => 'VARCHAR(32)',
         'hwdriver'     => 'VARCHAR(32)',
         );

    my $tbl_hardwareid = "hardwareid";
    my %tbl_hardwareid_columns =
        (
         'hardwareid'   => 'VARCHAR(32) REFERENCES hardware_cfg',
         'distroid'     => 'VARCHAR(32)',
         'CONSTRAINT'   => 'hardwareid_pk PRIMARY KEY (hardwareid, distroid)',
         );

    my $tbl_distro_cfg = "distro_cfg";
    my %tbl_distro_cfg_columns =
        (
         'distroid'    => 'VARCHAR(48) PRIMARY KEY',
         'os'          => 'VARCHAR(12)',
         'release'     => 'VARCHAR(8)',
         'arch'        => 'VARCHAR(8)',
         'description' => 'VARCHAR(64)',
         'addon'       => 'BOOLEAN',
         'addos'       => 'VARCHAR(8)',
         'addrel'      => 'VARCHAR(8)',
         'shareip'     => 'VARCHAR(15)',
         'sharetype'   => 'VARCHAR(8)',
         'basepath'    => 'VARCHAR(128)',
         'kernel'      => 'VARCHAR(32)',
         'initrd'      => 'VARCHAR(32)',
         'status'      => 'INTEGER',
         'creation'    => 'TIMESTAMP',
         'change'      => 'TIMESTAMP',
         );

    my $tbl_module_cfg = "module_cfg";
    my %tbl_module_cfg_columns =
        (
         'moduleid'    => 'VARCHAR(32) NOT NULL',
         'version'     => 'INTEGER',
         'description' => 'VARCHAR(64)',
         'interpreter' => 'VARCHAR(8)',
         'data'        => 'VARCHAR',
         'status'      => 'BOOLEAN',
         'CONSTRAINT'  => 'module_cfg_pk PRIMARY KEY (moduleid, version)',
         );

    my $tbl_module_cert_cfg = "module_cert_cfg";
    my %tbl_module_cert_cfg_columns =
        (
         'moduleid'   => 'VARCHAR(32)',
         'distroid'   => 'VARCHAR(48)',
         'mandatory'  => 'BOOLEAN',
         'CONSTRAINT' => 'module_cert_cfg_pk PRIMARY KEY (moduleid, distroid)',
         );

    my $tbl_profile_cfg = "profile_cfg";
    my %tbl_profile_cfg_columns =
        (
         'profileid'   => 'VARCHAR(32) NOT NULL',
         'version'     => 'INTEGER',
         'description' => 'VARCHAR(64)',
         'data'        => 'VARCHAR',
         'status'      => 'BOOLEAN',
         'CONSTRAINT'  => 'proflie_cfg_pk PRIMARY KEY (profileid, version)',
         );

    my $tbl_build_cfg = "build";
    my %tbl_build_cfg_columns =
        (
         'mac'         => 'VARCHAR(17) PRIMARY KEY',
         'hostname'    => 'VARCHAR(32) REFERENCES templateid',
         'distroid'    => 'VARCHAR(48) REFERENCES distro_cfg',
         'hardwareid'  => 'VARCHAR(32) REFERENCES hardware_cfg',
         );

    my $tbl_power_cfg = "power_cfg";
    my %tbl_power_cfg_columns =
         (
          'mac'     => 'VARCHAR(17) PRIMARY KEY',
          'ctype'   => 'VARCHAR(16)',
          'login'   => 'VARCHAR(16)',
          'passwd'  => 'VARCHAR(32)',
          'bmcaddr' => 'VARCHAR(32)',
          'node'    => 'VARCHAR(32)',
          'other'   => 'VARCHAR(32)',
         );

    tie( my %baracus_tbls, 'Tie::IxHash',
         $tbl_mac             => \%tbl_mac_cols,
         $tbl_templateid      => \%tbl_templateid_columns,
         $tbl_templateidhist  => \%tbl_templateidhist_columns,
         $tbl_hardware_cfg    => \%tbl_hardware_cfg_columns,
         $tbl_hardwareid      => \%tbl_hardwareid_columns,
         $tbl_distro_cfg      => \%tbl_distro_cfg_columns,
         $tbl_module_cfg      => \%tbl_module_cfg_columns,
         $tbl_module_cert_cfg => \%tbl_module_cert_cfg_columns,
         $tbl_profile_cfg     => \%tbl_profile_cfg_columns,
         $tbl_build_cfg       => \%tbl_build_cfg_columns,
         $tbl_power_cfg       => \%tbl_power_cfg_columns,
        );
    return \%baracus_tbls;
}

sub get_baracus_functions
{
    my $func_add_delete = q|
RETURNS TRIGGER AS $template_state_trigger$
    DECLARE
        new_hostname VARCHAR;
        new_ip VARCHAR;
        new_mac VARCHAR;
        new_uuid VARCHAR;
        new_state INTEGER;
        new_cmdline VARCHAR;
        new_creation TIMESTAMP;
    BEGIN
    INSERT INTO templateidhist ( hostname,
                                 ip,
                                 mac,
                                 uuid,
                                 state,
                                 cmdline,
                                 creation,
                                 change )
    VALUES ( NEW.hostname,
             NEW.ip,
             NEW.mac,
             NEW.uuid,
             NEW.state,
             NEW.cmdline,
             NEW.creation,
             CURRENT_TIMESTAMP(0) );
    RETURN NEW;
    END;
$template_state_trigger$ LANGUAGE 'plpgsql';
|;

    my $func_update = q|
RETURNS TRIGGER AS $template_state_trigger$
    DECLARE
        new_hostname VARCHAR;
        new_ip VARCHAR;
        new_mac VARCHAR;
        new_uuid VARCHAR;
        new_state INTEGER;
        new_cmdline VARCHAR;
        new_creation TIMESTAMP;
    BEGIN
    INSERT INTO templateidhist ( hostname,
                                 ip,
                                 mac,
                                 uuid,
                                 state,
                                 cmdline,
                                 creation,
                                 change )
    VALUES ( NEW.hostname,
             NEW.ip,
             NEW.mac,
             NEW.uuid,
             NEW.state,
             NEW.cmdline,
             NEW.creation,
             CURRENT_TIMESTAMP(0) );
    RETURN NEW;
    END;
$template_state_trigger$ LANGUAGE 'plpgsql';
|;


    my %baracus_functions =
        (
         'template_state_add_delete()' => $func_add_delete,
         'template_state_update()'     => $func_update,
         );

    return \%baracus_functions;
}

sub get_baracus_triggers
{
    my $trigger_add_delete = q|AFTER INSERT ON templateid
FOR EACH ROW EXECUTE PROCEDURE template_state_add_delete()
|;

    my $trigger_update = q|AFTER UPDATE ON templateid
FOR EACH ROW EXECUTE PROCEDURE template_state_update()
|;

    my %baracus_triggers =
        (
         'template_state_add_delete_trigger' => $trigger_add_delete,
         'template_state_update_trigger' => $trigger_update,
         );

    return \%baracus_triggers;
}

1;

__END__


