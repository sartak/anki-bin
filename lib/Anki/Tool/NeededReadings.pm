package Anki::Tool::NeededReadings;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;
use Anki::Morphology;

extends 'Anki::Tool';

my $morph = Anki::Morphology->new;

sub each_card_文 {
    my ($self, $card) = @_;

    return if $card->suspended;

    my $sentence      = $card->field('日本語');
    my $reading_field = $card->field('読み') || '';

    my @needed;
    for my $kanji ($sentence =~ /(\p{Han}|[０１２３４５６７８９])/g) {
        next if $reading_field =~ $kanji;
        push @needed, $kanji;
    }

    if (@needed) {
        my $readings = $morph->readings_for($sentence, 1);
        return $self->report_card($card, "$sentence - needs readings for @needed\n$readings");
    }
}

1;

