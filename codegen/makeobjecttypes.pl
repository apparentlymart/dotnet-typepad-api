#!/usr/bin/perl

use strict;
use warnings;

use JSON::Any;
use FindBin qw($Bin);
BEGIN { chdir($Bin); }
use Generator;

my $json = JSON::Any->new();

open(IN, '<', 'method-mappings.json');
my $mappings_raw = join('', <IN>);
my $mappings = $json->decode($mappings_raw);

open(OUT, '>', "out/object_types.cs");

my $gen = Generator->new(\*OUT);

my %generated_types = ();

foreach my $noun_name (sort keys %$mappings) {

    foreach my $method (@{$mappings->{$noun_name}}) {

        my $return_object_type = $method->{returnObjectType};
        my $param_object_type = $method->{paramObjectType};

        generate_class_for_type($return_object_type);
        generate_class_for_type($param_object_type);

    }

}

sub generate_class_for_type {
    my ($type) = @_;

    return unless $type;

    my $type_name = $type->{name};
    return unless $type_name && $gen->api_type_needs_generated_class($type_name);
    return if $generated_types{$type_name};

    $gen->write_object_type_class($type);

    $generated_types{$type_name} = 1;
}

