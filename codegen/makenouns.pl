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

open(OUT, '>', "out/nouns.cs");

my $gen = Generator->new(\*OUT);

$gen->start_namespace_block("TypePad.Nouns");

foreach my $noun_name (sort keys %$mappings) {

    my $cs_noun_name = ucfirst($noun_name);
    my $methods = $mappings->{$noun_name};

    $gen->blank();
    $gen->start_class_block($cs_noun_name);

    {
        $gen->tab_write_line("private IAPIClient client;");
        $gen->start_block("public $cs_noun_name(client)");
        {
            $gen->tab_write_line("this.client = client;");
        }
        $gen->end_block();

        foreach my $method (@$methods) {
            my $method_name = $method->{methodName};
            my $cs_method_name = ucfirst($method_name);
            my $return_type = $method->{returnObjectType};
            my $return_type_name;
            if ($return_type) {
                if ($return_type->{name}) {
                    $return_type_name = $gen->api_type_as_cs_type($return_type->{name});
                }
                else {
                    # This is an anonymous type, so we need to generate a
                    # stub class for it here.
                    $return_type_name = $cs_method_name."Response";
                    $gen->write_object_type_class($return_type, $return_type_name);
                }
            }
            else {
                $return_type_name = "void";
            }

            my @cs_path_chunks = map { $_ ? $gen->quote_string($_) : 'null' } @{$method->{pathChunks}};

            my @main_params = ();
            my $has_payload = 0;
            my $dynamic_payload_class = undef;
            my $dynamic_payload_type = undef;
            foreach my $param_name (sort { $method->{pathParams}{$a} <=> $method->{pathParams}{$b} } keys %{$method->{pathParams}}) {
                my $index = $method->{pathParams}{$param_name};
                my $cs_param_name = ucfirst($param_name);
                my $param_type = "string";
                push @main_params, "$param_type $cs_param_name";
                $cs_path_chunks[$index] = $cs_param_name;
            }
            if (my $param_object_type = $method->{paramObjectType}) {
                if (my $type_name = $param_object_type->{name}) {
                    my $cs_type_name = $gen->api_type_as_cs_type($type_name);
                    push @main_params, "$cs_type_name Payload";
                    $has_payload = 1;
                }
                else {
                    foreach my $property (@{$param_object_type->{properties}}) {
                        my $cs_name = ucfirst($property->{name});
                        my $cs_type = $gen->api_type_as_cs_type($property->{type});
                        push @main_params, "$cs_type $cs_name";
                    }
                    my $payload_type_name = $cs_method_name."Request";
                    $gen->write_object_type_class($param_object_type, $payload_type_name);
                    $has_payload = 1;
                    $dynamic_payload_type = $param_object_type;
                    $dynamic_payload_class = $payload_type_name;
                }
            }
            my $main_params = join(", ", @main_params);

            # FIXME: Actually implement these optional query string arguments somehow.
            # This is just a placeholder.
            foreach my $param_name (keys %{$method->{queryParams}}) {
                my $cs_param_name = ucfirst($param_name);
                my $param_type;
                if ($param_name =~ m!^limit|offset$!) {
                    $param_type = "int";
                }
                else {
                    $param_type = "string";
                }
            }

            $gen->start_block("public $return_type_name $cs_method_name($main_params)");
            {
                $gen->tab_write_line("var pathChunks = new string[] { ".join(", ", @cs_path_chunks)." };");
                if ($dynamic_payload_class) {
                    $gen->tab_write_line("var Payload = new $dynamic_payload_class();");
                    foreach my $property (@{$dynamic_payload_type->{properties}}) {
                        my $cs_name = ucfirst($property->{name});
                        my $cs_type = $gen->api_type_as_cs_type($property->{type});
                        $gen->tab_write_line("Payload.$cs_name = $cs_name;");
                    }
                }
                $gen->tab_write_line(($return_type_name ne 'void' ? ("return ") : ()), "this.client.MakeRequest(".$gen->quote_string($method->{httpMethod}).", pathChunks, ".($has_payload ? "Payload" : "null").");");
            }
            $gen->end_block();
        }
    }

    $gen->end_block();

}

$gen->blank();

$gen->end_block();

