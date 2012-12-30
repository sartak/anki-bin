package Anki::Tool::NFC;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;
use Unicode::Normalize;

extends 'Anki::Tool';

sub each_field {
    my ($self, $field) = @_;
    my $value = $field->value;

    my $normalized = NFC($value);
    if ($value ne $normalized) {
        return $self->report_field($field);
    }

    return 1;
}

1;

