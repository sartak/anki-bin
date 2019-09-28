package Anki::Tool::Canto_NeededFields;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;
use List::MoreUtils 'uniq';

extends 'Anki::Tool';

sub each_note_粵語文 {
    my ($self, $note) = @_;

    my @missing_fields = grep { !$note->field($_) } qw/出所/;
    if (@missing_fields) {
      return $self->report_note($note, "Missing " . join(', ', @missing_fields));
    }

    return 1;
}

1;

