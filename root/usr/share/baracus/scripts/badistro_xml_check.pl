#!/usr/bin/perl -w

use strict;

use XML::Simple qw( :strict);
use Data::Dumper;

my $debug = 0;

my $xs = XML::Simple->new
    (
     SuppressEmpty => 1,
     ForceArray =>
     [ qw
       ( distro
	 product
	 iso
	 sharefile
       )
     ],
     KeyAttr =>
     {
	 distro    => 'name',
	 product   => 'name',
	 iso       => 'name',
	 sharefile => 'name',
     },
    );

my $ref = $xs->XMLin( "/usr/share/baracus/badistro.xml" );

print Dumper($ref) if $debug;

foreach my $dname
    (
     sort
     keys
     %{$ref->{'distro'}}
     ) {
    print "distro => $dname\n";
    &showdistro( '    ', $dname );
    foreach my $pname
        (
         sort
         keys
         %{$ref->{'distro'}->{$dname}->{'product'}}
         ) {
        print "    product => $pname\n";
        &showproduct( '        ', $dname, $pname );
        foreach my $iname
            (
             sort
             keys
             %{$ref->{'distro'}->{$dname}->{'product'}->{$pname}->{'iso'}}
             ) {
            print "        iso => $iname\n";
            &showiso( '            ', $dname, $pname, $iname );
	    foreach my $sname
		(
		 sort
		 keys
		 %{$ref->{'distro'}->{$dname}->{'product'}->{$pname}->{'iso'}->{$iname}->{sharefiles}->{sharefile}}
		) {
		    print "          share => $sname\n";
		    &showshare( '              ', $dname, $pname, $iname, $sname );
	    }
        }
    }
    print "\n";
}

exit 0;

die "DOES NOT EXECUTE";

sub showdistro {
    my $indent = shift;
    my $dname = shift;
    while ( my ($key, $val) = each %{$ref->{'distro'}->{$dname}} ) {
        next if ( $key eq "product" );
	my $error = &checkval( \$key, \$val );
	if ( defined $val ) {
	    print "${indent}$key => $val\n";
	} else {
	    print "\nWARNING $key HAS NO ASSIGNED VALUE\n";
	}
	if ($error) {
	    print "ERROR <<<<<\n";
	    exit 1;
	}
    }
}

sub showproduct {
    my $indent = shift;
    my $dname = shift;
    my $pname = shift;
    while ( my ($key, $val) = each %{$ref->{'distro'}->{$dname}->{'product'}->{$pname}} ) {
        next if ( $key eq "iso" );
	my $error = &checkval( \$key, \$val );
	if ( defined $val ) {
	    print "${indent}$key => $val\n";
	} else {
	    print "\nWARNING $key HAS NO ASSIGNED VALUE\n";
	}
	if ($error) {
	    print "ERROR <<<<<\n";
	    exit 1;
	}
    }
}

sub showiso {
    my $indent = shift;
    my $dname = shift;
    my $pname = shift;
    my $iname = shift;
    while ( my ($key, $val) = each %{$ref->{'distro'}->{$dname}->{'product'}->{$pname}->{'iso'}->{$iname}} ) {
        next if ( $key eq "sharefiles" );
        my $error = &checkval( \$key, \$val );
        if ( defined $val ) {
            print "${indent}$key => $val\n";
        } else {
            print "\nWARNING $key HAS NO ASSIGNED VALUE\n";
        }
        if ($error) {
            print "ERROR <<<<<\n";
            exit 1;
        }
    }
}

sub showshare {
    my $indent = shift;
    my $dname = shift;
    my $pname = shift;
    my $iname = shift;
    my $sname = shift;
    while ( my ($key, $val) = each %{$ref->{'distro'}->{$dname}->{'product'}->{$pname}->{'iso'}->{$iname}->{sharefiles}->{sharefile}->{$sname}} ) {
	
#        my $error = &checkval( \$key, \$val );
        if ( defined $val ) {
            print "${indent}$key => $val\n";
        } else {
            print "\nWARNING $key HAS NO ASSIGNED VALUE\n";
        }
#        if ($error) {
#            print "ERROR <<<<<\n";
#            exit 1;
#        }
    }
}

sub checkval {
    my $key = ${$_[0]};
    my $val = ${$_[1]};

    if (defined $val and ( $val eq "ARRAY" or ref($val) eq "ARRAY")) {
        print "ERROR >>>>> $key has unexpected ARRAY value\n";
        print "ERROR >>>>> did you mean give it an id in KeyAttr\n";
        return 1;
    }
    if (defined $val and ( $val eq "HASH" or ref($val) eq "HASH")) {
        print "ERROR >>>>> $key has unexpected HASH value\n";
        print "ERROR >>>>> do you need a new level of encapsulation in this checker\n";
        return 1;
    }
    return 0;
}

__END__
