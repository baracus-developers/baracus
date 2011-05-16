package Baracus::User;

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
use strict;
use warnings;

use Dancer qw( :syntax );
use Dancer::Plugin::Database;

use Baracus::Sql   qw( :subs :vars );
use Baracus::State qw( :vars );
use Baracus::Core  qw( :subs );
use Baracus::Config qw( :subs :vars );

=pod

=head1 NAME

B<Baracus::Auth> - subroutines for managing Baracus users

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
                @baAuths
                %baAuth
                %encrypt2cmdopt
            )],
         subs   =>
         [qw(
                add_db_user
                remove_db_user
                update_db_user
                get_db_user
                list_start_user
                list_next_user
            )],
         const =>
         [qw(
                BA_AUTH_PLAINTEXT
                BA_AUTH_MD5
                BA_AUTH_CRYPT
                BA_AUTH_SHA1
            )],
         );
    Exporter::export_ok_tags('vars');
    Exporter::export_ok_tags('subs');
    Exporter::export_ok_tags('const');
}

our $VERSION = '0.01';

use constant BA_ENCRYPT_PLAINTEXT => 1;
use constant BA_ENCRYPT_MD5       => 2;
use constant BA_ENCRYPT_CRYPT     => 3;
use constant BA_ENCRYPT_SHA1      => 4;

use vars qw ( @baAuths %baAuth %encrypt2cmdopt );

@baAuths =
    (
     'plaintext',
     'md5',
     'crypt',
     'sha1',
     );

%baAuth =
    (
     1                    => 'plaintext'          ,
     2                    => 'md5'                ,
     3                    => 'crypt'              ,
     4                    => 'sha1'               ,
     'plaintext'          => BA_ENCRYPT_PLAINTEXT ,
     'md5'                => BA_ENCRYPT_MD5       ,
     'crypt'              => BA_ENCRYPT_CRYPT     ,
     'sha1'               => BA_ENCRYPT_SHA1      ,
     BA_ENCRYPT_PLAINTEXT => 'plaintext'          ,
     BA_ENCRYPT_MD5       => 'md5'                ,
     BA_ENCRYPT_CRYPT     => 'crypt'              ,
     BA_ENCRYPT_SHA1      => 'sha1'               ,
     );

#
#         Taken from man htpasswd
#
#  -m     Use  MD5  encryption  for passwords. On Windows, Netware and TPF,
#         this is the default.
#
#  -d     Use crypt() encryption for passwords. The default  on  all  plat-
#         forms  but Windows, Netware and TPF. Though possibly supported by
#         htpasswd on all platforms, it  is  not  supported  by  the  httpd
#         server on Windows, Netware and TPF.
#
#  -s     Use  SHA  encryption for passwords. Facilitates migration from/to
#         Netscape servers using  the  LDAP  Directory  Interchange  Format
#         (ldif).
#
#  -p     Use plaintext passwords. Though htpasswd will support creation on
#         all platforms, the httpd daemon will only accept plain text pass-
#         words on Windows, Netware and TPF.
#

%encrypt2cmdopt =
    (
     'plaintext'          => ' -p ' ,
     'md5'                => ' -m ' ,
     'crypt'              => ' -d ' ,
     'sha1'               => ' -s ' ,
     );


# Subs

#
# sub is_user($opts, $username)
#
sub is_user
{
    my $opts     = shift;
    my $username = shift;

    my $href = undef;
    my $sql = qq|SELECT username FROM $baTbls{ user } WHERE username='$username'|;

    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;
        $href = $sth->fetchrow_hashref();
        $sth->finish;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    if ( $href ) {
        return 1;
    } else {
        return 0;
    }
}
    

#
# add_db_user($opts, $href)
#

sub add_db_user
{
    my $opts = shift;
    my $href = shift;

   ## Does user already exist
   if ( &is_user( $opts,  $href->{username} ) ) { return 1; }

    use POSIX;
    use Crypt::SaltedHash;
    my $csh = Crypt::SaltedHash->new(algorithm => 'SHA-1');
    $csh->add($href->{password});
    my $salted = $csh->generate;

    $href->{creation} = strftime("%m-%d-%Y %H:%M:%S\n", localtime);
    $href->{password} = $salted;

    my %Hash = %{$href};

    my $fields = lc get_cols( $baTbls{ user } );
    $fields =~ s/[ \t]*//g;
    my @fields = split( /,/, $fields );
    my $values = join(', ', (map { database->quote($_) } @Hash{@fields}));

    my $sql = qq|INSERT INTO $baTbls{ user } ( $fields ) VALUES ( $values )|;

    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;
        $sth->finish;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    return 0;
}

#
# remove_db_user($opts, $username)
#

sub remove_db_user
{
    my $opts = shift;
    my $username = shift;

    my $sql = qq|DELETE FROM $baTbls{'user'} WHERE username='$username'|;

    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;
        $sth->finish;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    return 0;
}

#
# update_db_user($opts, $hashref)
#

sub update_db_user
{
    my $opts  = shift;
    my $href = shift;
    my %Hash = %{$href};

    my $fields = lc get_cols( $baTbls{ user } );
    $fields =~ s/[ \t]*//g;
    my @fields;

    foreach my $field ( split( /,/, $fields ) ) {
        next if ( $field eq "username" ); # skip key
        next if ( $field eq "change" );   # skip change timestamp
        next if ( $field eq "creation" ); # skip creation timestamp
        push @fields, $field;
    }
    $fields = join(', ', @fields);
    my $values = join(', ', (map { database->quote($_) } @Hash{@fields}));

    $fields .= ", change";
    $values .= ", CURRENT_TIMESTAMP(0)";

    my $sql = qq|UPDATE $baTbls{ user }
                SET ( $fields ) = ( $values )
                WHERE username = '$href->{username}' |;

    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;
        $sth->finish;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    return 0;
}

#
# get_db_user($opts, $username)
#

sub get_db_user
{
    my $opts     = shift;
    my $username = shift;

    my $href = undef;
    my $sql = qq|SELECT * FROM $baTbls{ user } WHERE username = '$username' |;

    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;
        $href = $sth->fetchrow_hashref();
        $sth->finish;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    return $href;
}

#
# list_start_user($opts, $username_filter)
#

sub list_start_user
{
    my $opts  = shift;
    my $fval = shift;
    my $fkey;
    my $is_fkey_valid = 0;

    if ( defined $fval ) {
        if ( $fval =~ /:/ ) {
            ( $fkey, $fval ) = split ( /:/, $fval, 2 );
        } else {
            $fkey = "username";
            $is_fkey_valid = 1;
        }
        if ( $fval =~ m{\*|\?} ) {
            $fval =~ s|\*|%|g;
            $fval =~ s|\?|_|g;
        }
    } else {
        $fval = "%";
        $fkey = "username";
        $is_fkey_valid = 1;
    }

    my $fields = lc get_cols( $baTbls{ user } );
    $fields =~ s/[ \t]*//g;
    unless( $is_fkey_valid ) {
        foreach my $field ( split( /,/, $fields ) ) {
            if ( $fkey =~ m/^$field$/ ) {
                $is_fkey_valid = 1;
                last;
            }
        }
    }
    unless ( $is_fkey_valid ) {
        print "Unable to find column $fkey to search for $fkey\n";
        print "Instead try one of: $fields\n";
        exit 1;
    }

    my $sql = qq|SELECT * FROM user WHERE $fkey = '$fval' ORDER BY username|;

    my $sth;
    eval {
        my $sth = database->prepare( $sql );
        $sth->execute;
        $sth->finish;
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    return $sth;
}

#
# list_next_user($opts, $sth)
#

sub list_next_user
{
    my $opts = shift;
    my $sth = shift;
    my $href;

    eval {
        $href = $sth->fetchrow_hashref();
    };
    if ($@) {
        $opts->{LASTERROR} = subroutine_name." : ".$@;
        error $opts->{LASTERROR};
    }

    unless ($href) {
        $sth->finish;
        undef $sth;
        undef $href;
    }

    return $href;
}

1;

__END__

=head1 AUTHOR

Daniel Westervelt, E<lt>dwestervelt@novellE<gt>
David Bahi, E<lt>dbahi@novellE<gt>

=cut

