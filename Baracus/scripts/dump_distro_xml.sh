#!/usr/bin/perl -w

use strict;
use XML::Simple qw(:strict);
use Data::Dumper;

my $file = shift;

#my $xs = XML::Simple->new( SuppressEmpty => 1, ForceArray => [], KeyAttr => [] );

my $xs = XML::Simple->new
    ( SuppressEmpty => 1,
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

my $repoXML = $xs->XMLin( $file );

print Dumper( $repoXML );

