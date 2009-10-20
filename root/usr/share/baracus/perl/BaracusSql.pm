package BaracusSql;

use 5.006;
use Carp;
use strict;
use warnings;

use Tie::IxHash;


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

=item baState

here we define some state constants and a hash to make easy use of them

=cut

our %baState = (
                1          => 'ready',
                2          => 'built',
                3          => 'spoofed',
                4          => 'deleted',
                5          => 'updated',
                6          => 'diskwipe',
                7          => 'disabled',
                8          => 'found',
                9          => 'building',
                10         => 'wiping',
                11         => 'wiped',
                'ready'    => BA_READY,
                'built'    => BA_BUILT,
                'spoofed'  => BA_SPOOFED,
                'deleted'  => BA_DELETED,
                'updated'  => BA_UPDATED,
                'diskwipe' => BA_DISKWIPE,
                'disabled' => BA_DISABLED,
                'found'    => BA_FOUND,
                'building' => BA_BUILDING,
                'wiping'   => BA_WIPING,
                'wiped'    => BA_WIPED,
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
    my %tbl_sqlfs_columns = (
                             'id'          => 'SERIAL PRIMARY KEY',
                             'name'        => 'VARCHAR(64) NOT NULL',
                             'description' => 'VARCHAR(32)',
                             'bin'         => 'VARCHAR',
                             'enabled'     => 'INTEGER',
                             'insertion'   => 'TIMESTAMP',
                             'change'      => 'TIMESTAMP',
                             );

    my %sqltftp_tbls = (
                        $tbl_sqlfs      => \%tbl_sqlfs_columns,
                        );
    return \%sqltftp_tbls;
}

# baracus database tables


sub get_baracus_tables
{

    my $tbl_templateid = "templateid";
    my %tbl_templateid_columns = (
                                  'hostname' => 'VARCHAR(32) PRIMARY KEY',
                                  'ip'       => 'VARCHAR(15)',
                                  'mac'      => 'VARCHAR(17)',
                                  'uuid'     => 'VARCHAR(37)',
                                  'state'    => 'INTEGER',
                                  'cmdline'  => 'VARCHAR(1024)',
                                  'creation' => 'TIMESTAMP',
                                  'change'   => 'TIMESTAMP',
                                  );

    my $tbl_templateidhist = "templateidhist";
    my %tbl_templateidhist_comlumns = (
                                       'hostname' => 'VARCHAR(32)',
                                       'ip'       => 'VARCHAR(15)',
                                       'mac'      => 'VARCHAR(17)',
                                       'uuid'     => 'VARCHAR(37)',
                                       'state'    => 'INTEGER',
                                       'cmdline'  => 'VARCHAR(1024)',
                                       'creation' => 'TIMESTAMP',
                                       'change'   => 'TIMESTAMP',
                                       );

    my $tbl_hardware_cfg = "hardware_cfg";
    my %tbl_hardware_cfg_comlumns = (
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
    my %tbl_hardwareid_columns = (
                                  'hardwareid'   => 'VARCHAR(32) REFERENCES hardware_cfg',
                                  'distroid'     => 'VARCHAR(32)',
                                  'CONSTRAINT'   => 'hardwareid_pk PRIMARY KEY (hardwareid, distroid)',
                                  );

    my $tbl_distro_cfg = "distro_cfg";
    my %tbl_distro_cfg_comlumns = (
                                   'distroid'    => 'VARCHAR(48) PRIMARY KEY',
                                   'os'          => 'VARCHAR(12)',
                                   'release'     => 'VARCHAR(8)',
                                   'arch'        => 'VARCHAR(8)',
                                   'description' => 'VARCHAR(64)',
                                   'addon'       => 'BOOLEAN',
                                   'addos'       => 'VARCHAR(8)',
                                   'addrel'      => 'VARCHAR(8)',
                                   'buildip'     => 'VARCHAR(15)',
                                   'type'        => 'VARCHAR(8)',
                                   'basepath'    => 'VARCHAR(128)',
                                   'status'      => 'INTEGER',
                                   'creation'    => 'TIMESTAMP',
                                   'change'      => 'TIMESTAMP',
                                   );

    my $tbl_module_cfg = "module_cfg";
    my %tbl_module_cfg_comlumns = (
                                   'moduleid'    => 'VARCHAR(32) NOT NULL',
                                   'version'     => 'INTEGER',
                                   'description' => 'VARCHAR(64)',
                                   'interpreter' => 'VARCHAR(8)',
                                   'data'        => 'VARCHAR',
                                   'status'      => 'BOOLEAN',
                                   'CONSTRAINT'  => 'module_cfg_pk PRIMARY KEY (moduleid, version)',
                                  );

    my $tbl_module_cert_cfg = "module_cert_cfg";
    my %tbl_module_cert_cfg_columns = (
                                       'moduleid'   => 'VARCHAR(32)',
                                       'distroid'   => 'VARCHAR(48)',
                                       'mandatory'  => 'BOOLEAN',
                                       'CONSTRAINT' => 'module_cert_cfg_pk PRIMARY KEY (moduleid, distroid)',
                                      );

    my $tbl_profile_cfg = "profile_cfg";
    my %tbl_profile_cfg_comlumns = (
                                   'profileid'   => 'VARCHAR(32) NOT NULL',
                                   'version'     => 'INTEGER',
                                   'description' => 'VARCHAR(64)',
                                   'data'        => 'VARCHAR',
                                   'status'      => 'BOOLEAN',
                                   'CONSTRAINT'  => 'proflie_cfg_pk PRIMARY KEY (profileid, version)',
                                  );

    my $tbl_device_inventory_cfg = "device_inventory_cfg";
    my %tbl_device_inventory_cfg_columns = (
                                            'vendor'      => 'VARCHAR(32)',
                                            'product'     => 'VARCHAR(64)',
                                            'description' => 'VARCHAR(64)',
                                            'version'     => 'VARCHAR(32)',
                                            'product'     => 'VARCHAR(64)',
                                            'serial'      => 'VARCHAR(32) PRIMARY KEY',
                                            'mac'         => 'VARCHAR(17)',
                                           );

    my $tbl_device_bios_inventory = "device_bios_inventory_cfg";
    my %tbl_device_bios_inventory_columns = (
                                            'id'          => 'VARCHAR(32) REFERENCES device_inventory_cfg(serial) PRIMARY KEY',
                                            'vendor'      => 'VARCHAR(32)',
                                            'description' => 'VARCHAR(64)',
                                            'version'     => 'VARCHAR(32)',
                                            );

    my $tbl_cpu_inventory_cfg = "cpu_inventory_cfg";
    my %tbl_cpu_inventory_cfg_columns = (
                                         'id'          => 'VARCHAR(32) REFERENCES device_inventory_cfg(serial) PRIMARY KEY',
                                         'vendor'      => 'VARCHAR(32)',
                                         'product'     => 'VARCHAR(64)',
                                         'description' => 'VARCHAR(64)',
                                         'speed'       => 'VARCHAR(32)',
                                         'size'        => 'VARCHAR(16)',
                                        );

    my $tbl_cpu_cache_inventory_cfg = "cpu_cache_inventory_cfg";
    my %tbl_cpu_cache_inventory_cfg_columns = (
                                               'id'          => 'VARCHAR(32) REFERENCES cpu_inventory_cfg(id) PRIMARY KEY',
                                               'slot'        => 'VARCHAR(8)',
                                               'description' => 'VARCHAR(64)',
                                               'size'        => 'VARCHAR(16)',
                                              );

    my $tbl_cpu_capability_inventory_cfg = "cpu_capability_inventory_cfg";
    my %tbl_cpu_capability_inventory_cfg_columns = (
                                                    'id'          => 'VARCHAR(32) REFERENCES cpu_inventory_cfg(id) PRIMARY KEY',
                                                    'capability'  => 'VARCHAR(16)',
                                                    'description' => 'VARCHAR(64)',
                                                   );

    my $tbl_disk_inventory_cfg = "disk_inventory_cfg";
    my %tbl_disk_inventory_cfg_columns = (
                                    'id'          => 'VARCHAR(32) REFERENCES device_inventory_cfg(serial) PRIMARY KEY',
                                    'vendor'      => 'VARCHAR(32)',
                                    'product'     => 'VARCHAR(64)',
                                    'description' => 'VARCHAR(64)',
                                    'logicalname' => 'VARCHAR(32)',
                                    'serial'      => 'VARCHAR(32)',
                                    'size'        => 'VARCHAR(16)',
                                    'businfo'     => 'VARCHAR(16)',
                                    'dev'         => 'VARCHAR(8)',
                                   );

    my $tbl_network_inventory_cfg = "network_inventory_cfg";
    my %tbl_network_inventory_cfg_columns = (
                                             'id'          => 'VARCHAR(32) REFERENCES device_inventory_cfg(serial)',
                                             'vendor'      => 'VARCHAR(32)',
                                             'product'     => 'VARCHAR(64)',
                                             'description' => 'VARCHAR(64)',
                                             'logicalname' => 'VARCHAR(32)',
                                             'mac'         => 'VARCHAR(17) PRIMARY KEY',
                                             'businfo'     => 'VARCHAR(16)',
                                            );

    my $tbl_network_setting_inventory_cfg = "network_setting_inventory_cfg"; 
    my %tbl_network_setting_inventory_cfg_columns = (
                                                     'id'      => 'VARCHAR(32) REFERENCES network_inventory_cfg(mac) PRIMARY KEY',
                                                     'setting' => 'VARCHAR(16)',
                                                     'value'   => 'VARCHAR(16)',
                                                     );
    
    my $tbl_network_capability_inventory_cfg = "network_capability_inventory_cfg";
    my %tbl_network_capability_inventory_cfg_columns = (
                                                        'id'          => 'VARCHAR(32) REFERENCES network_inventory_cfg(mac) PRIMARY KEY',
                                                        'capability'  => 'VARCHAR(16)',
                                                        'description' => 'VARCHAR(64)',
                                                       );

    my $tbl_memory_inventory_cfg = "memory_inventory_cfg";
    my %tbl_memory_inventory_cfg_columns = (
                                            'id'          => 'VARCHAR(32) REFERENCES device_inventory_cfg(serial) PRIMARY KEY',
                                            'slot'        => 'VARCHAR(8)',
                                            'physid'      => 'VARCHAR(8)',
                                            'description' => 'VARCHAR(64)',
                                            'size'        => 'VARCHAR(16)',
                                           );

    my $tbl_memory_dimm_inventory_cfg = "memory_dimm_inventory_cfg";
    my %tbl_memory_dimm_inventory_cfg_columns = (
                                                 'id'          => 'VARCHAR(32) REFERENCES memory_inventory_cfg(id) PRIMARY KEY',
                                                 'slot'        => 'VARCHAR(8)',
                                                 'description' => 'VARCHAR(64)',
                                                 'size'        => 'VARCHAR(16)',
                                                 'speed'       => 'VARCHAR(32)',
                                                );

    tie( my %baracus_tbls, 'Tie::IxHash',
         $tbl_templateid                       => \%tbl_templateid_columns,
         $tbl_templateidhist                   => \%tbl_templateidhist_comlumns,
         $tbl_hardware_cfg                     => \%tbl_hardware_cfg_comlumns,
         $tbl_hardwareid                       => \%tbl_hardwareid_columns,
         $tbl_distro_cfg                       => \%tbl_distro_cfg_comlumns,
         $tbl_module_cfg                       => \%tbl_module_cfg_comlumns,
         $tbl_module_cert_cfg                  => \%tbl_module_cert_cfg_columns,
         $tbl_profile_cfg                      => \%tbl_profile_cfg_comlumns,
         $tbl_device_inventory_cfg             => \%tbl_device_inventory_cfg_columns,
         $tbl_device_bios_inventory            => \%tbl_device_bios_inventory_columns,
         $tbl_cpu_inventory_cfg                => \%tbl_cpu_inventory_cfg_columns,
         $tbl_cpu_cache_inventory_cfg          => \%tbl_cpu_cache_inventory_cfg_columns,
         $tbl_cpu_capability_inventory_cfg     => \%tbl_cpu_capability_inventory_cfg_columns,
         $tbl_disk_inventory_cfg               => \%tbl_disk_inventory_cfg_columns,
         $tbl_network_inventory_cfg            => \%tbl_network_inventory_cfg_columns,
         $tbl_network_setting_inventory_cfg    => \%tbl_network_setting_inventory_cfg_columns,
         $tbl_network_capability_inventory_cfg => \%tbl_network_capability_inventory_cfg_columns,
         $tbl_memory_inventory_cfg             => \%tbl_memory_inventory_cfg_columns,
         $tbl_memory_dimm_inventory_cfg        => \%tbl_memory_dimm_inventory_cfg_columns,
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


    my %baracus_functions = (
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

    my %baracus_triggers = (
        'template_state_add_delete_trigger' => $trigger_add_delete,
        'template_state_update_trigger' => $trigger_update,
                            );

    return \%baracus_triggers;
}

1;

__END__


