package Anki::Tool::DuplicateSentences;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;

extends 'Anki::Tool';

my %seen_j;
my %seen_c;

sub each_note_文 {
    my ($self, $note) = @_;
    my $sentence = $note->field('日本語');

    if ($seen_j{ $sentence }) {
        return $self->report_note($note, "$sentence - duplicate sentence with nid:$seen_j{$sentence}");
    }

    $seen_j{$sentence} = $note->id;

    return 1;
}

sub each_note_廣東話文 {
    my ($self, $note) = @_;
    my $sentence = $note->field('廣東話');

    if ($seen_c{ $sentence }) {
        return $self->report_note($note, "$sentence - duplicate sentence with nid:$seen_c{$sentence}");
    }

    $seen_c{$sentence} = $note->id;

    return 1;
}

1;

