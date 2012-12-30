package Anki::Tool::ReadinglessKanji;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;
use List::MoreUtils 'uniq', 'any';

extends 'Anki::Tool';

my @full_blacklist = (
    qr/淋しい/, # dupe of 寂しい
);

my @no_readings;
my @sentences;

sub each_note_漢字 {
    my ($self, $note) = @_;
    return if $note->has_tag('duplicate-kanji');
    return if $note->field('読み');

    push @no_readings, $note;
}

sub each_card_文 {
    my ($self, $card) = @_;
    return if $card->suspended;

    push @sentences, $card->field('日本語');
}

sub done {
    my ($self) = @_;

    my $re = do {
        my $re = '([' . join('', map { $_->field('漢字') } @no_readings) . '])';
        qr/$re/;
    };

    my %sentences_for;
    for my $sentence (@sentences) {
        while ($sentence =~ m{$re}g) {
            push @{ $sentences_for{$1} }, $sentence;
        }
    }

    for my $note (@no_readings) {
        my $kanji = $note->field('漢字');
        my @sentences = uniq @{ $sentences_for{$kanji} || next };
        my @blacklist = grep { $_ =~ /$kanji/ } @full_blacklist;
        my %skip;

        for my $source_sentence (@sentences) {
            $skip{$source_sentence}++
                if any { $source_sentence =~ $_ } @blacklist;

            next if $skip{$source_sentence};

            for my $word ($source_sentence =~ /\p{Han}$kanji/g, $source_sentence =~ /$kanji\p{Han}/g) {
                for my $skip_sentence (@sentences) {
                    next if $source_sentence eq $skip_sentence;
                    if ($skip_sentence =~ $word) {
                        $skip{$skip_sentence}++;
                    }
                }
            }
        }

        @sentences = grep { !$skip{$_} } @sentences;

        next if @sentences <= 1;

        $self->report_note($note, "\e[35m$kanji\e[m has potential readings");
        for my $sentence (@sentences) {
            $sentence =~ s/(\p{Han}*)($kanji)(\p{Han}*)/\e[m$1\e[35m$2\e[m$3\e[37m/g;
            $self->report_hint("\e[37m$sentence\e[m");
        }
    }
}

1;

