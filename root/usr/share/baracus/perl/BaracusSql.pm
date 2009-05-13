package BaracusSql;

use 5.006;
use Carp;
use strict;
use warnings;


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
                        $tbl_sqlfs => \%tbl_sqlfs_columns
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
                                  'iphex'    => 'VARCHAR(9)',
                                  'mac'      => 'VARCHAR(17)',
                                  'uuid'     => 'VARCHAR(37)',
                                  'state'    => 'INTEGER',
                                  'cmdline'  => 'VARCHAR(255)',
                                  'creation' => 'TIMESTAMP',
                                  'change'   => 'TIMESTAMP',
                                  );

    my $tbl_templateidhist = "templateidhist";
    my %tbl_templateidhist_comlumns = (
                                       'hostname' => 'VARCHAR(32)',
                                       'ip'       => 'VARCHAR(15)',
                                       'iphex'    => 'VARCHAR(9)',
                                       'mac'      => 'VARCHAR(17)',
                                       'uuid'     => 'VARCHAR(37)',
                                       'state'    => 'INTEGER',
                                       'stateOLD' => 'INTEGER',
                                       'cmdline'  => 'VARCHAR(255)',
                                       'creation' => 'TIMESTAMP',
                                       'change'   => 'TIMESTAMP',
                                       );

    my %baracus_tbls = (
                        $tbl_templateid     => \%tbl_templateid_columns,
                        $tbl_templateidhist => \%tbl_templateidhist_comlumns,
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
        new_iphex VARCHAR;
        new_mac VARCHAR;
        new_uuid VARCHAR;
        new_state INTEGER;
        new_cmdline VARCHAR;
        new_creation TIMESTAMP;
    BEGIN
    IF (TG_OP='INSERT') THEN
        INSERT INTO templateidhist ( hostname,
                                     ip,
                                     iphex,
                                     mac,
                                     uuid,
                                     state,
                                     stateOLD,
                                     cmdline,
                                     creation,
                                     change )
        VALUES ( NEW.hostname,
                 NEW.ip,
                 NEW.iphex,
                 NEW.mac,
                 NEW.uuid,
                 '1',
                 NEW.state,
                 NEW.cmdline,
                 NEW.creation,
                 CURRENT_TIMESTAMP(2) );
        RETURN NEW;
    ELSIF (TG_OP='DELETE') THEN
        INSERT INTO templateidhist ( hostname,
                                     ip,
                                     iphex,
                                     mac,
                                     uuid,
                                     state,
                                     stateOLD,
                                     cmdline,
                                     creation,
                                     change )
        VALUES ( OLD.hostname,
                 OLD.ip,
                 OLD.iphex,
                 OLD.mac,
                 OLD.uuid,
                 '4',
                 OLD.state,
                 OLD.cmdline,
                 OLD.creation,
                 CURRENT_TIMESTAMP(2) );
        RETURN OLD;
    END IF;
    END;
$template_state_trigger$ LANGUAGE 'plpgsql';
|;

    my $func_update = q|
RETURNS TRIGGER AS $template_state_trigger$
    DECLARE
        new_hostname VARCHAR;
        new_ip VARCHAR;
        new_iphex VARCHAR;
        new_mac VARCHAR;
        new_uuid VARCHAR;
        new_state INTEGER;
        new_cmdline VARCHAR;
        new_creation TIMESTAMP;
    BEGIN
    INSERT INTO templateidhist ( hostname,
                                 ip,
                                 iphex,
                                 mac,
                                 uuid,
                                 state,
                                 stateOLD,
                                 cmdline,
                                 creation,
                                 change )
    VALUES ( NEW.hostname,
             NEW.ip,
             NEW.iphex,
             NEW.mac,
             NEW.uuid,
             '2',
             NEW.state,
             NEW.cmdline,
             NEW.creation,
             CURRENT_TIMESTAMP(2) );
    RETURN NEW;
    END;
$template_state_trigger$ LANGUAGE 'plpgsql';
|;

    my %baracus_functions = (
        'template_state_add_delete()' => $func_add_delete,
        'template_state_update()' => $func_update,
                            );

    return \%baracus_functions;
}

sub get_baracus_triggers
{
    my $trigger_add_delete = q|AFTER INSERT OR DELETE ON templateid
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


