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
            ^(\s+)        # leading space
          | (\s+)$        # trailing space
          | (?<!。)(。)$  # trailing 。
          | ([“”])        # smart quotes
    }{\e[1;41m$+\e[m}xg) {
        return $self->report_field($field, $value);
    }

    return 1;
}

1;

