package Anki::Tool::DuplicateSentences;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;

extends 'Anki::Tool';

my %seen;

sub each_note_文 {
    my ($self, $note) = @_;
    my $sentence = $note->field('日本語');

    if ($seen{ $sentence }) {
        return $self->report_note($note, "$sentence - duplicate sentence with nid:$seen{$sentence}");
    }

    $seen{$sentence} = $note->id;

    return 1;
}

1;

