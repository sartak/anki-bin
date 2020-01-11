package Anki::Tool::Canto_ReadinglessKanji;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;
use List::MoreUtils 'uniq', 'any';

extends 'Anki::Tool';

my @no_readings;
my @sentences;

sub each_note_漢字 {
    my ($self, $note) = @_;
    return if $note->has_tag('duplicate-kanji');
    return if $note->field('粵語');

    push @no_readings, $note;
}

sub each_note_粵語文 {
    my ($self, $note) = @_;

    push @sentences, [$note->field('粵語'), $note->field('発音')];
}

sub done {
    my ($self) = @_;

    my $re = do {
        my $re = '([' . join('', map { $_->field('漢字') } @no_readings) . '])';
        qr/$re/;
    };

    my %sentences_for;
    for my $sentence (@sentences) {
        while ($sentence->[0] =~ m{$re}g) {
            push @{ $sentences_for{$1} }, $sentence;
        }
    }

    for my $note (@no_readings) {
        my $kanji = $note->field('漢字');
        my @sentences = uniq @{ $sentences_for{$kanji} || next };

        $self->report_note($note, "\e[35m$kanji\e[m has potential readings");
        for my $sentence (@sentences) {
	    my ($cantonese, $readings) = @$sentence;
	    $cantonese =~ s/<.*?>//g;
	    $readings =~ s/<.*?>//g;

           my @sentence_kanji = $cantonese =~ /\p{Han}|[a-zA-Z0-9]+/g;
	    my $index;
	    for my $i (0..$#sentence_kanji) {
		    if ($sentence_kanji[$i] =~ $kanji) {
			    $index = $i;
			    last;
                    }
	    }

	    my $reading = (split ' ', $readings)[$index];

            $cantonese =~ s/(\p{Han}*)($kanji)(\p{Han}*)/\e[m$1\e[35m$2\e[m$3\e[37m/g;
            $self->report_hint("\e[37m$cantonese\e[m - \e[35m$reading\e[m");
        }
    }
}

1;

