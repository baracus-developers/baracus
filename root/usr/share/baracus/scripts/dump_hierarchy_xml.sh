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
            (
              class
              os
            )
           ],
          KeyAttr =>
          {
           class  => 'name',
           os => 'name',
           },
         );

my $repoXML = $xs->XMLin( $file );

print Dumper( $repoXML );

