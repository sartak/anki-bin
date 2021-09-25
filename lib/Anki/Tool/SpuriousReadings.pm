package Anki::Tool::SpuriousReadings;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;

extends 'Anki::Tool';

sub each_note_文 {
    my ($self, $note) = @_;

    my $sentence = $note->field('日本語');

    return if $sentence =~ /<img/;

    my $context  = $note->field('前後関係');
    my $readings = $note->field('読み')
        or return;

    my @readings = $readings =~ m{(^|>)(.*?)【}g;
    my @spurious;
    for my $kanji (grep defined, map { /(\p{Unified_Ideograph}+)/g } @readings) {
        my $regex = join 'っ*', split '', $kanji;
        next if "$sentence$context" =~ $regex;
        push @spurious, $kanji;
    }

    if (@spurious) {
        return $self->report_note($note, "$sentence - has spurious readings for @spurious");
    }
}

1;

