package Anki::Tool::MissingKanji;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;

extends 'Anki::Tool';

my %sentence_kanji;
my %studied_kanji;

sub each_note_文 {
    my ($self, $note) = @_;
    my $sentence = $note->field('日本語');

    $sentence_kanji{$_} = $note
        for $sentence =~ /\p{Han}/g;

    return 1;
}

sub each_note_漢字 {
    my ($self, $note) = @_;
    my $kanji = $note->field('漢字');
    $studied_kanji{$kanji}++;
}

sub done {
    my ($self) = @_;

    delete $sentence_kanji{'々'};
    delete $sentence_kanji{'〇'};

    for my $kanji (keys %sentence_kanji) {
        next if $studied_kanji{$kanji};
        my $note = $sentence_kanji{$kanji};
        $self->report_note($note, $note->field('日本語') . " - includes missing kanji $kanji");
    }
}

1;

