package Anki::Tool::MissingKanji;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;

extends 'Anki::Tool';

my %sentence_kanji;
my %studied_kanji;

sub each_card_文 {
    my ($self, $card) = @_;
    return if $card->suspended;

    my $sentence = $card->field('日本語');

    $sentence_kanji{$_} = $card
        for $sentence =~ /\p{Han}/g;

    return 1;
}

sub each_note_漢字 {
    my ($self, $note) = @_;
    my $kanji = $note->field('漢字');

    if ($kanji =~ /[a-z]/i) {
        $self->report_note($note, "$kanji - romaji in the 漢字 field");
    }

    $studied_kanji{$kanji}++;
}

sub done {
    my ($self) = @_;

    delete $sentence_kanji{'々'};
    delete $sentence_kanji{'〇'};

    for my $kanji (keys %sentence_kanji) {
        next if $studied_kanji{$kanji};
        my $card = $sentence_kanji{$kanji};
        my $sentence = $card->field('日本語');
        $sentence =~ s/$kanji/\e[1;35m$kanji\e[m/g;
        $self->report_card($card, "$sentence - includes missing kanji $kanji");
    }
}

1;

