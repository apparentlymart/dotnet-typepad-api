
=head1 NAME

Generator - Utility functions for generating C# code

=cut

package Generator;

use strict;
use warnings;
use fields qw(fh indent);

my %primitive_type_map = (
    string => 'string',
    number => 'double',
    integer => 'int',
    boolean => 'bool',
    datetime => 'string',
);
my %generic_type_map = (
    array => 'System.Collections.Generic.IList',
    set => 'System.Collections.Generic.ISet',
    List => 'TypePad.ObjectTypes.List',
    Stream => 'TypePad.ObjectTypes.Stream',
);

sub new {
    my ($class, $fh) = @_;

    my $self = fields::new($class);

    $self->{fh} = $fh;
    $self->{indent} = 0;

    return $self;
}

sub write {
    my ($self, @parts) = @_;

    my $fh = $self->{fh};
    print $fh @parts;
}

sub write_line {
    my $self = shift;
    $self->write(@_, "\n");
}

sub tab_write {
    my $self = shift;

    my $indent = $self->{indent};
    $self->write("    " x $indent, @_);
}

sub tab_write_line {
    my $self = shift;

    my $indent = $self->{indent};
    $self->write("    " x $indent, @_, "\n");
}

sub blank {
    $_[0]->write("\n");
}

sub tab_in {
    $_[0]->{indent}++;
}

sub tab_out {
    $_[0]->{indent}--;
}

sub start_block {
    my ($self, $stuff) = @_;
    $self->tab_write_line("$stuff {");
    $self->tab_in();
}

sub end_block {
    $_[0]->tab_out();
    $_[0]->tab_write_line("}");
}

sub start_namespace_block {
    my ($self, $namespace_name) = @_;
    $self->start_block("namespace $namespace_name");
}

sub start_class_block {
    my ($self, $class_name, $parent_class_name) = @_;
    $self->start_block("public partial class $class_name : " . ($parent_class_name ? "$parent_class_name, " : "") . "TypePad.IObject");
}

sub write_object_type_class {
    my ($self, $type, $class_name) = @_;

    $class_name ||= $self->api_type_as_cs_type($type->{name});
    my $base_class_name = $type->{parentType} ? $self->api_type_as_cs_type($type->{parentType}) : undef;

    $self->start_class_block($class_name, $base_class_name);

    foreach my $property (@{$type->{properties}}) {
        my $type = $self->api_type_as_cs_type($property->{type});
        my $name = $property->{name};
        my $cs_name = ucfirst($property->{name});
        $self->tab_write_line("public $type $cs_name;");
    }

    $self->blank();

    $self->start_block("public void emitAsJSON(System.IO.TextWriter Writer)");
    
    $self->end_block();

    $self->start_block("public static $class_name parseFromJSON(System.IO.TextReader Reader)");
    
    $self->end_block();

    $self->end_block();
}

sub api_type_as_cs_type {
    my ($self, $api_type) = @_;

    if ($api_type =~ m!^(\w+)\<(.*)\>$!) {
        my $base_type = $1;
        my $param_type = $2;
        my $cs_param_type = $self->api_type_as_cs_type($param_type);

        if ($base_type eq 'map') {
            return "System.Collections.Generic.IDictionary<string, $cs_param_type>";
        }
        else {
            my $cs_base_type = $generic_type_map{$base_type};
            die "Don't know how to marshall the parameterized type $base_type to C#" unless $cs_base_type;
            return "$cs_base_type<$cs_param_type>";
        }

    }
    elsif (my $primitive_type = $primitive_type_map{$api_type}) {
        # Return a Nullable version of the primitive type,
        # since the TypePad data model allows anything
        # to be null.
        return $primitive_type."?";
    }
    else {
        return "TypePad.ObjectTypes.".$api_type;
    }

}

sub api_type_needs_generated_class {
    my ($self, $api_type) = @_;

    if ($api_type =~ m!^(\w+)\<(.*)\>$!) {
        return 0;
    }
    elsif (my $primitive_type = $primitive_type_map{$api_type}) {
        return 0;
    }
    else {
        return 1;
    }

}

sub quote_string {
    my ($self, $s) = @_;

    $s =~ s!\\!\\\\!g;
    $s =~ s!"!\\"!g;
    $s =~ s!\n!\\n!g;
    $s =~ s!\t!\\t!g;
    return '"'.$s.'"';
}

1;
