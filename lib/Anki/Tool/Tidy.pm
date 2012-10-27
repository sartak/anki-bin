package Anki::Tool::Tidy;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;

extends 'Anki::Tool';

sub each_field {
    my ($self, $field) = @_;
    my $value = $field->value;

    if ($value =~ s{
            ^(\s+)
          | (\s+)$
          | (?<!。)(。)$
    }{\e[1;41m$+\e[m}xg) {
        warn $field->note_id . '|' . $value . "\n";
        return 0;
    }

    return 1;
}

1;

