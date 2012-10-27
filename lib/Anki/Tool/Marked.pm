package Anki::Tool::Marked;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;

extends 'Anki::Tool';

sub each_note {
    my ($self, $note) = @_;

    if ($note->has_tag('marked')) {
        return $self->report_note($note, $note->tags_as_string);
    }

    return 1;
}

1;

