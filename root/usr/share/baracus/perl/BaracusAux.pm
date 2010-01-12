package BaracusAux;

use 5.006;
use Carp;
use strict;
use warnings;

use lib "/usr/share/baracus/perl";

use BaracusSql    qw( :subs :vars );
use BaracusState  qw( :vars :subs :states );
use BaracusCore   qw( :subs );
use BaracusConfig qw( :vars );

=pod

=head1 NAME

B<BaracusAux> - auxillary routines for db reading and manipulation

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
                get_distro
                get_hardware
                get_tftpfile
                delete_tftpfile

                load_profile
                load_distro
                load_addons
                load_hardware
                check_modules
                load_modules
                add_autobuild
                remove_autobuild
                db_get_mandatory

                check_hwcert
                check_hwuse
                check_enabled
                check_mandatory
                get_mandatory
                check_distroid
                check_hardware
                check_module
                check_cert
                get_versions
                redundant_data
            )],
         );
    Exporter::export_ok_tags('subs');
}

our $VERSION = '0.01';


###########################################################################
##
## originally from BaracusCgi

sub get_distro() {
    my $dbh = shift;
    my $bref = shift;

    my $sql = qq|SELECT * FROM distro WHERE distroid = '$bref->{distro}'|;
    my $sth;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute(  ) );

    return $sth->fetchrow_hashref( );
}

sub get_hardware() {
    my $dbh = shift;
    my $bref = shift;

    my $sql = qq|SELECT * FROM hardware WHERE hardwareid = '$bref->{hardware}'|;
    my $sth;

    die "$!\n$dbh->errstr" unless ( $sth = $dbh->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref( );
}

sub get_tftpfile() {
    my $tftph = shift;
    my $filename = shift;

    my $sql = qq|SELECT COUNT(id) as count, name FROM sqlfstable WHERE name = '$filename' GROUP BY name|;
    my $sth;

    die "$!\n$tftph->errstr" unless ( $sth = $tftph->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    return $sth->fetchrow_hashref( );
}

sub delete_tftpfile() {
    my $tftph = shift;
    my $filename = shift;

    my $sql = qq|DELETE FROM sqlfstable WHERE name = '$filename'|;
    my $sth;

    die "$!\n$tftph->errstr" unless ( $sth = $tftph->prepare( $sql ) );
    die "$!$sth->err\n" unless ( $sth->execute( ) );

    $sth->finish();
}

###########################################################################
##
## originally from bahost

sub load_profile
{
    use Config::General;

    my $opts    = shift;
    my $dbh     = shift;
    my $hostref = shift;
    my $tmphref = shift;

    my $sql_cols = get_cols( $baTbls{ profile } );
    $sql_cols =~ s/[ \t]*//g;
    my @cols = split(/,/, $sql_cols);
    my $sql = qq|SELECT $sql_cols FROM $baTbls{'profile'}
                 WHERE profileid = '| . $hostref->{'profile'} . qq|'
                 ORDER BY version|;

    my $sth;
    unless ( $sth = $dbh->prepare( $sql ) ) {
        die "Unable to prepare 'profile' statement\n" . $dbh->errstr;
    }
    unless( $sth->execute( ) ) {
        die "Unable to execute 'profile' statement\n" . $sth->err;
    }

    my $rowcount = 0;
    my $sel;
    while( my $hostref = $sth->fetchrow_hashref( ) ) {
        $rowcount += 1;
        $sel = $hostref if ($hostref->{'status'});
    }
    die "Unable to find profile entry for $hostref->{'profile'}.\n"
        unless ( $rowcount );
    die "Unable to find *enabled* profile entry for $hostref->{'profile'}.\n"
        unless ( defined $sel );
    print $sel . "\n" if ( $opts->{debug} > 1 );

    # getall is a destructive assignment - so use tmp
    my $conf = new Config::General( -String => $sel->{'data'} );
    my %tmpHash = $conf->getall;
    $tmphref = \%tmpHash;

    while ( my ($key, $value) = each ( %$tmphref ) ) {
        if (ref($value) eq "ARRAY") {
            print "$key has more than one entry or value specified\n";
            print "Such ARRAYs are not supported.\n";
            exit(1);
            #           foreach my $avalue (@{$hostref->{$key}}){
            #               print "$avalue\n";
            #           }
            next;
        }
        if (defined $value) {
            $hostref->{$key} = $value;
        } else {
            $hostref->{$key} = "";
        }
        print "profile: $key => $hostref->{$key}\n" if ( $opts->{debug} > 1 );
    }
}

sub load_distro
{
    my $opts    = shift;
    my $dbh     = shift;
    my $hostref = shift;

    my $sql_cols = get_cols( $baTbls{'distro'} );
    $sql_cols =~ s/[ \t]*//g;
    my $sql = qq|SELECT $sql_cols FROM $baTbls{'distro'}
                 WHERE distroid = '| . $hostref->{'distro'} . qq|'|;;
    my $sel = $dbh->selectrow_hashref( $sql );
    die "Unable to find distro entry for $hostref->{'distro'}.\n"
        unless ( defined $sel );
    print $sel . "\n" if ( $opts->{debug} > 1 );
    while ( my ($key, $value) = each( %$sel ) ) {
        if (defined $value) {
            $hostref->{$key} = $value;
        } else {
            $hostref->{$key} = "";
        }
        print "distro: $key => $hostref->{$key}\n" if ( $opts->{debug} > 1 );
    }
}

sub load_addons
{
    my $opts    = shift;
    my $dbh     = shift;
    my $hostref = shift;
    my $addons  = shift;

    my $sth;
    # incorporate addons passed into autoinstall formated xml

    my $sql_cols = get_cols( $baTbls{'distro'} );
    $sql_cols =~ s/[ \t]*//g;

    foreach my $item ( split /\s+/, $addons ) {
        print "load_addons: working with $item\n" if ($opts->{debug} > 1);
        my $sql = qq|SELECT $sql_cols FROM $baTbls{'distro'}
                 WHERE distroid = '| . $item . qq|'|;;
        my $sel = $dbh->selectrow_hashref( $sql );

        die "Unable to find distro entry for addon $item.\n"
            unless ( defined $sel );
        die "Unable to find needed distro entry for addon $item.\nMay need to run 'basource add --distro <base> --addon $item'\n"
            unless ( defined $sel->{status} and
                     $sel->{status} != BA_REMOVED );

        my $addonbase = "$sel->{os}-$sel->{release}-$sel->{arch}";
        if ( $hostref->{distro} ne $addonbase ) {
            die "addon $item is for $addonbase not the specified $hostref->{distro}\n";
        }
        print $sel . "\n" if ($opts->{debug} > 1);

        $hostref->{addon} .= "\n" if ( $hostref->{addon} );
        $hostref->{addon} .="      <listentry>
        <media_url>$sel->{sharetype}://$sel->{shareip}$sel->{basepath}</media_url>
        <product>$sel->{distroid}</product>
        <product_dir>/</product_dir>\n";
        if ( $sel->{release} =~ m/11/ ) {
            $hostref->{addon} .="        <ask_on_error config:type=\"boolean\">false</ask_on_error> <!-- available since openSUSE 11.0 -->
        <name>$sel->{distroid}</name> <!-- available since openSUSE 11.1/SLES11 (bnc#433981) -->\n";
        }
        $hostref->{addon} .="      </listentry>"
    }
}


sub load_hardware
{
    my $opts    = shift;
    my $dbh     = shift;
    my $hostref = shift;

    my $sql_cols = get_cols(  $baTbls{'hardware'} );
    $sql_cols =~ s/[ \t]*//g;
    my $sql = qq|SELECT $sql_cols FROM $baTbls{'hardware'}
                 WHERE hardwareid = '| . $hostref->{'hardware'} . qq|'|;
    my $sel = $dbh->selectrow_hashref( $sql );
    die "Unable to find hardware entry for $hostref->{'hardware'}.\n"
        unless ( defined $sel );
    print $sel . "\n" if ( $opts->{debug} > 1 );
    while ( my ($key, $value) = each( %$sel ) ) {
        if (defined $value) {
            $hostref->{$key} = $value;
        } else {
            $hostref->{$key} = "";
        }
        print "hware: $key => $hostref->{$key}\n" if ( $opts->{debug} > 1 );
    }
}

sub check_modules
{
    my $opts    = shift;
    my $dbh     = shift;
    my $distro  = shift;
    my $modules = shift;

    my $sql = qq|SELECT '$distro'
                 FROM $baTbls{ 'modcert' }
                 WHERE moduleid = ? |;

    foreach my $item (split(/[,\s*]/, $modules)) {
        my $sth;
        unless ( $sth = $dbh->prepare( $sql ) ) {
            die "Unable to prepare 'module' statement\n" . $dbh->errstr;
        }
        unless( $sth->execute( $item ) ) {
            die "Unable to execute 'module' statement\n" . $sth->err;
        }

        my $rowcount = 0;
        while ( my $sel = $sth->fetchrow_hashref( ) ) {
            $rowcount += 1;
        }
        die "Module $item not certified for $distro.\n"
            unless ( $rowcount );
    }

}

sub load_modules
{
    my $opts    = shift;
    my $dbh     = shift;
    my $hostref = shift;
    my $modules = shift;

    my $sth;
    # incorporate modules passed into autoinstall formated xml

#   $hostref->{'module'} = "    <init-scripts config:type="list">\n";
    foreach my $item (split(/[,\s*]/, $modules)) {

        my $sql_cols = get_cols( $baTbls{ module } );
        $sql_cols =~ s/[ \t]*//g;
        my @cols = split(/,/, $sql_cols);
        my $sql = qq|SELECT $sql_cols FROM $baTbls{'module'}
                         WHERE moduleid = '| . $item . qq|' ORDER BY version|;
        unless ( $sth = $dbh->prepare( $sql ) ) {
            die "Unable to prepare 'module' statement\n" . $dbh->errstr;
        }
        unless( $sth->execute( ) ) {
            die "Unable to execute 'module' statement\n" . $sth->err;
        }

        my $rowcount = 0;
        my $found = undef;
        while ( my $sel = $sth->fetchrow_hashref( ) ) {
            $rowcount += 1;
            $found = $sel if ($sel->{'status'});
        }
        die "Unable to find module entry for $item.\n"
            unless ( $rowcount );
        die "Unable to find *enabled* module entry for $item.\n"
            unless ( defined $found );
        print $found . "\n" if ($opts->{debug} > 1);

        $hostref->{'module'} .="<script>
        <filename>$found->{'moduleid'}</filename>
        <source><![CDATA[";
        $hostref->{'module'} .= $found->{'data'};
        $hostref->{'module'} .="]]>\n        </source>\n      </script>";
    }
#   $hostref->{'module'} .= "\n    </init-scripts>"
}


sub add_autobuild
{
    use File::Temp qw/ tempdir /;

    my $opts    = shift;
    my $hostref = shift;
    my $dbtftp  = "sqltftp";

    my $deepdebug = $opts->{debug} > 2 ? 1 : 0;
    my $sqlfsOBJ = SqlFS->new( 'DataSource' => "DBI:Pg:dbname=$dbtftp;port=5162",
                               'User' => "baracus",
                               'debug' => $deepdebug )
        or die "Unable to create new instance of SqlFS\n";



    my $autobuildTemplate = join "/", $baDir{ 'templates' }, $hostref->{'os'}, $hostref->{'release'}, $hostref->{'arch'}, $hostref->{'autobuild'};

    if ($opts->{debug}) {
        print "autobuildTemplate = $autobuildTemplate\n";
    }

    if ( ! -f $autobuildTemplate ) {
        print "\nThe base template files for autobuild cannot be found here:\n";
        print "\n$autobuildTemplate\n";
        print "\nPlease refer to the README found in $baDir{ 'templates' }/\n";
        exit 1;
    }

    ## Read in autobuild template
    ##
    open(TEMPLATE, "<$autobuildTemplate") or die "Can't open autobuildTemplate $autobuildTemplate : $!";
    my $yastfile = join '', <TEMPLATE>;
    close(TEMPLATE);

    my $date    = &get_rundate();
    my $automac = &automac( $hostref->{'mac'} );

    # add files to sqlfstable for sqltftpd server

    my $tdir = tempdir( "baracus.XXXXXX", TMPDIR => 1, CLEANUP => 1 );
    print "using tempdir $tdir\n" if ($opts->{debug} > 1);

    if ( $sqlfsOBJ->find( $automac ) ) {
        print "$automac already exists\n";
    } else {
        while ( my ($key, $value) = each %$hostref ) {
            $key =~ tr/a-z/A-Z/;
            $key = "__$key\__";
            $yastfile =~ s/$key/$value/g;
        }
        open(FILE, ">$tdir/$automac") or
            die "Cannot open file $automac: $!\n";
        print FILE $yastfile;
        if ( $hostref->{os} ne "rhel"   &&
             $hostref->{os} ne "fedora" &&
             $hostref->{os} ne "centos" ) {
            print FILE "<!-- baracus.Hostname: $hostref->{'hostname'} -->\n";
            print FILE "<!-- baracus.MAC: $hostref->{'mac'}; -->\n";
            print FILE "<!-- baracus.Generated: $date -->\n";
        }
        close(FILE);

        if ( $sqlfsOBJ->store( "$tdir/$automac",
                               "autoinst $hostref->{'basedist'}" ) ) {
            warn "failed to store $tdir/$automac in sqlfs\n";
        }
        print $yastfile if ( $opts->{debug} > 2 );
        unlink "$tdir/$automac";

        if ($opts->{verbose}) {
            print "Successfully stored $automac\n";
        }
    }
    print "removing tempdir $tdir\n" if ($opts->{debug} > 1);
    rmdir $tdir;
}

sub remove_autobuild
{
    use File::Temp qw/ tempdir /;

    my $opts    = shift;
    my $hostref = shift;
    my $dbtftp  = "sqltftp";

    my $deepdebug = $opts->{debug} > 2 ? 1 : 0;
    my $sqlfsOBJ = SqlFS->new( 'DataSource' => "DBI:Pg:dbname=$dbtftp;port=5162",
                               'User' => "baracus",
                               'debug' => $deepdebug )
        or die "Unable to create new instance of SqlFS\n";

    my $automac = &automac( $hostref->{'mac'} );

    $sqlfsOBJ->remove( $automac );
}

sub db_get_mandatory
{
    my $opts   = shift;
    my $dbh    = shift;
    my $distro = shift;

    my $sql;
    my $sth;
    my $m_modules;
    my @modarray;

    $sql = qq|SELECT moduleid
              FROM $baTbls{ modcert }
              WHERE distroid = ?
              AND  mandatory = 't'
             |;

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} =
            "Unable to prepare 'mandatory' statement\n" . $dbh->errstr;
        return 1;
    }

    unless( $sth->execute( $distro ) ) {
        $opts->{LASTERROR} =
            "Unable to execute 'mandatory' statement\n" . $sth->err;
        return 1;
    }



    while( my $href = $sth->fetchrow_hashref( ) ) {
        push(@modarray, $href->{'moduleid'});
    }
    $m_modules = join " ", @modarray;

    $sth->finish;
    undef $sth;

    return $m_modules;
}


###########################################################################
##
## originally from baconfig

sub check_hwcert
{
    my $opts       = shift;
    my $dbh        = shift;
    my $hardwareid = shift;

    my $sth;
    my $href;

    my $sql = qq| SELECT distroid
                  FROM hardwareid
                  WHERE hardwareid = ?
                |;

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} =
            "Unable to prepare 'check_hwcert' statement\n" . $dbh->errstr;
        return 1;
    }

    unless( $sth->execute( $hardwareid ) ) {
        $opts->{LASTERROR} =
            "Unable to execute 'check_hwcert' statement\n" . $sth->err;
        return 1;
    }

    while( $href = $sth->fetchrow_hashref( ) ) {
        if ($href->{'distroid'}) {
            return 1;
        }
    }

    $sth->finish;
    undef $sth;

    return 0;
}

sub check_hwuse
{
    my $opts       = shift;
    my $dbh        = shift;
    my $hardwareid = shift;

    my $sth;
    my $href;

    my $sql = qq| SELECT hardwareid
                  FROM build
                  WHERE hardwareid = ?
                |;

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} =
            "Unable to prepare 'check_hwuse' statement\n" . $dbh->errstr;
        return 1;
    }

    unless( $sth->execute( $hardwareid ) ) {
        $opts->{LASTERROR} =
            "Unable to execute 'check_hwuse' statement\n" . $sth->err;
        return 1;
    }

    while( $href = $sth->fetchrow_hashref( ) ) {
        if ($href->{'hardareid'}) {
            return 1;
        }
    }

    $sth->finish;
    undef $sth;

    return 0;
}

sub check_enabled
{
    my $opts     = shift;
    my $dbh        = shift;
    my $moduleid = shift;

    my $sth;
    my $href;

    my $sql = qq| SELECT status
                  FROM $baTbls{ module }
                  WHERE moduleid = ?
                  AND version >= 1
                |;

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} =
            "Unable to prepare 'check_enabled' statement\n" . $dbh->errstr;
        return 1;
    }

    unless( $sth->execute( $moduleid ) ) {
        $opts->{LASTERROR} =
            "Unable to execute 'check_enabled' statement\n" . $sth->err;
        return 1;
    }

    while( $href = $sth->fetchrow_hashref( ) ) {
        if ($href->{'status'}) {
            return 1;
        }
    }

    $sth->finish;
    undef $sth;

    return 0;
}


sub check_mandatory
{
    my $opts     = shift;
    my $dbh        = shift;
    my $moduleid = shift;

    my $sth;
    my $href;

    my $sql = qq| SELECT mandatory
                  FROM $baTbls{ module }
                  WHERE moduleid = ?
                  AND version >= 1
                |;

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} =
            "Unable to prepare 'check_mandatory' statement\n" . $dbh->errstr;
        return 1;
    }

    unless( $sth->execute( $moduleid ) ) {
        $opts->{LASTERROR} =
            "Unable to execute 'check_mandatory' statement\n" . $sth->err;
        return 1;
    }

    while( $href = $sth->fetchrow_hashref( ) ) {
        if ($href->{'mandatory'}) {
            return 1;
        }
    }

    $sth->finish;
    undef $sth;

    return 0;
}

sub get_mandatory
{
    my $opts     = shift;
    my $dbh      = shift;
    my $moduleid = shift;
    my $cert     = shift;

    my $sql = qq|SELECT mandatory
                 FROM $baTbls{ modcert }
                 WHERE moduleid = ?
                |;

    if ( $cert eq "all" ) {
        $sql .= " AND distroid LIKE '%';";
    } else {
        $sql .= " AND distroid = '$cert';";
    }

    print $sql . "\n" if $opts->{debug};

    my $sth;
    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} = "Unable to prepare 'get_mandatory' statement\n" .
            $dbh->errstr;
        return 1;
    }
    unless ( $sth->execute( $moduleid ) ) {
        $opts->{LASTERROR} = "Unable to execute 'get_mandatory' statement\n" .
            $sth->err;
        return 1;
    }

    my $href = $sth->fetchrow_hashref();

    ## Return 3 if neither optional or mandatory
    ## 3 = new entry
    unless( defined $href->{'mandatory'} ) {
        $href->{'mandatory'} = 3;
    }

    $sth->finish;
    undef $sth;

    return  $href->{'mandatory'};
}

sub check_distroid
{
    my $opts     = shift;
    my $dbh      = shift;
    my $distroid = shift;

    my $sth;
    my $href;

    my $sql = qq| SELECT distroid
                  FROM $baTbls{ distro }
                  WHERE distroid = ?
                |;

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} =
            "Unable to prepare 'check_distroid' statement\n" . $dbh->errstr;
        return 1;
    }

    unless( $sth->execute( $distroid ) ) {
        $opts->{LASTERROR} =
            "Unable to execute 'check_distroid' statement\n" . $sth->err;
        return 1;
    }

    while( $href = $sth->fetchrow_hashref( ) ) {
        if ($href->{'distroid'}) {
            return 1;
        }
    }

    $sth->finish;
    undef $sth;

    return 0;
}

sub check_hardware
{
    my $opts       = shift;
    my $dbh        = shift;
    my $hardwareid = shift;

    my $sth;
    my $href;

    my $sql = qq| SELECT hardwareid
                  FROM $baTbls{ hardware }
                  WHERE hardwareid = ?
                |;

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} =
            "Unable to prepare 'check_hardwareid' statement\n" . $dbh->errstr;
        return 1;
    }

    unless( $sth->execute( $hardwareid ) ) {
        $opts->{LASTERROR} =
            "Unable to execute 'check_hardware' statement\n" . $sth->err;
        return 1;
    }

    while( $href = $sth->fetchrow_hashref( ) ) {
        if ($href->{'hardwareid'}) {
            return 1;
        }
    }

    $sth->finish;
    undef $sth;

    return 0;
}

sub check_module
{
    my $opts     = shift;
    my $dbh      = shift;
    my $moduleid = shift;

    my $sth;
    my $href;

    my $sql = qq| SELECT moduleid
                  FROM $baTbls{ module }
                  WHERE moduleid = ?
                |;

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} =
            "Unable to prepare 'check_module' statement\n" . $dbh->errstr;
        return 1;
    }

    unless( $sth->execute( $moduleid ) ) {
        $opts->{LASTERROR} =
            "Unable to execute 'check_module' statement\n" . $sth->err;
        return 1;
    }

    while( $href = $sth->fetchrow_hashref( ) ) {
        if ($href->{'moduleid'}) {
            return 1;
        }
    }

    $sth->finish;
    undef $sth;

    return 0;
}

sub check_cert
{
    my $opts    = shift;
    my $dbh     = shift;
    my $type    = shift;
    my $id      = shift;
    my $cert_in = shift;

    my $sth;
    my $href;
    my $sql;

    if ( $type eq "hwcert" ) {
        $sql = qq| SELECT distroid 
                      FROM $baTbls{ $type }
                      WHERE hardwareid = '$id'
                      AND distroid = '$cert_in'
                    |;
    }
    elsif ( $type eq "modcert" ) {
        $sql = qq| SELECT distroid 
                      FROM $baTbls{ $type }
                      WHERE moduleid = '$id'
                      AND distroid = '$cert_in'
                    |;
    }

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} =
            "Unable to prepare 'check_cert' statement\n" . $dbh->errstr;
        return 1;
    }

    unless( $sth->execute(  ) ) {
        $opts->{LASTERROR} =
            "Unable to execute 'check_cert' statement\n" . $sth->err;
        return 1;
    }

    while( $href = $sth->fetchrow_hashref( ) ) {
        if ($href->{'distroid'}) {
            return 0;
        }
    }

    $sth->finish;
    undef $sth;

    return 1;
}

# get_versions
#
# args: type (module, hardware, profile, tftp), $name, $version
# ret:  hash to entries found to specified, highest, enabled versions on match
#         or undef on error

sub get_versions
{
    my $opts = shift;
    my $dbh  = shift;
    my $type = shift;
    my $name = shift;
    my $vers = shift;

    my $sth;
    my $href;
    my $version_href;
    my $highest_href;
    my $enabled_href;

    $vers = 0 unless ( defined $vers );

    my $sql_cols = get_cols( $type );
    my $sql = qq| SELECT $sql_cols FROM $baTbls{ $type } |;

    if ( $type eq "module" ) {
        $sql .= "WHERE moduleid = ?";
    }
    elsif ( $type eq "profile" ) {
        $sql .= "WHERE profileid = ?";
    }
    else {
        print "Expected 'module' or 'profile'\n";
        exit 1;
    }

    $sql .= " ORDER BY version;";

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} = "Unable to prepare 'get_entry' statement\n" . $dbh->errstr;
        return ( undef, undef, undef );
    }

    unless( $sth->execute( $name ) ) {
        $opts->{LASTERROR} = "Unable to execute 'get_entry' statement\n" . $sth->err;
        return ( undef, undef, undef );
    }

    while( $href = $sth->fetchrow_hashref( ) ) {
        $version_href = $href if ( $href->{'version'} == $vers);
        $highest_href = $href;
        $enabled_href = $href if ( $href->{'status'} == 1 );
    }

    $sth->finish;
    undef $sth;

    return ( $version_href, $highest_href, $enabled_href );
}

# rendundant_data
#
#   when possibly adding a new version we make sure that the
#   'data' is not already pressent in another entry. if it is
#   return 1 - with LASTERROR of the version already present.

sub redundant_data
{
    my $opts = shift;
    my $dbh  = shift;
    my $type = shift;
    my $name = shift;
    my $data = shift;

    my $sth;
    my $href;

    my $sql_cols = get_cols( $type );
    my $sql = qq| SELECT $sql_cols FROM $baTbls{ $type } |;

    if ( $type eq "module" ) {
        $sql .= "WHERE moduleid = ?";
    }
    elsif ( $type eq "profile" ) {
        $sql .= "WHERE profileid = ?";
    }
    else {
        print "Expected 'module' or 'profile'\n";
        exit 1;
    }

    $sql .= " ORDER BY version;";

    unless ( $sth = $dbh->prepare( $sql ) ) {
        $opts->{LASTERROR} =
            "Unable to prepare 'redundant_data' statement\n" . $dbh->errstr;
        return 1;
    }

    unless( $sth->execute( $name ) ) {
        $opts->{LASTERROR} =
            "Unable to execute 'redundant_data' statement\n" . $sth->err;
        return 1;
    }

    while( $href = $sth->fetchrow_hashref( ) ) {
        if ($href->{'data'} eq $data) {
            $opts->{LASTERROR} =
                "Reject adding new version with content identical to this version: $href->{'version'}\n";
            return 1;
        }
    }

    $sth->finish;
    undef $sth;

    return 0;
}


1;

__END__
