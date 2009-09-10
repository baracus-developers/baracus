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
                'ready'    => BA_READY,
                'built'    => BA_BUILT,
                'spoofed'  => BA_SPOOFED,
                'deleted'  => BA_DELETED,
                'updated'  => BA_UPDATED,
                'diskwipe' => BA_DISKWIPE,
                'disabled' => BA_DISABLED,
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
                                  'oscert'       => 'VARCHAR(32)',
                                  'CONSTRAINT'   => 'hardwareid_pk PRIMARY KEY (hardwareid, oscert)',
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
                                   'mandatory'   => 'BOOLEAN',
                                   'CONSTRAINT'  => 'module_cfg_pk PRIMARY KEY (moduleid, version)',
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

    tie( my %baracus_tbls, 'Tie::IxHash',
         $tbl_templateid     => \%tbl_templateid_columns,
         $tbl_templateidhist => \%tbl_templateidhist_comlumns,
         $tbl_hardware_cfg   => \%tbl_hardware_cfg_comlumns,
         $tbl_hardwareid     => \%tbl_hardwareid_columns,
         $tbl_distro_cfg     => \%tbl_distro_cfg_comlumns,
         $tbl_module_cfg     => \%tbl_module_cfg_comlumns,
         $tbl_profile_cfg    => \%tbl_profile_cfg_comlumns,
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


