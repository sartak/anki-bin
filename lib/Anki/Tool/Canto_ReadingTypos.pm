package Anki::Tool::Canto_ReadingTypos;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;
use List::MoreUtils 'uniq';
use Unicode::Normalize;

extends 'Anki::Tool';

my %readings_of_word;
my %nids_for_word;
my %kanji_for_word;

sub each_note_粵語文 {
    my ($self, $note) = @_;

    my $sentence = NFC($note->field('粵語'));
    my $reading_field = NFC($note->field('発音') || '');
    my $nid = $note->id;

    s/<.*?>//g for $sentence, $reading_field;

    my @sentence_kanji = $sentence =~ /\p{Han}|[a-zA-Z0-9]+/g;
    my @reading_kanji = split ' ', $reading_field;

    if (@sentence_kanji != @reading_kanji) {
        return $self->report_note($note, "Kanji readings\ngot      " . scalar(@reading_kanji) . ": @reading_kanji \nexpected " . scalar(@sentence_kanji) . ": @sentence_kanji");
    }

    for my $i (0..$#sentence_kanji) {
	    my $word = $sentence_kanji[$i];
	    my $reading = $reading_kanji[$i];

            $readings_of_word{$word}{$reading}++;
            push @{ $nids_for_word{$word}{$reading} }, $nid;
    }

    return 1;
}

sub each_note_漢字 {
    my ($self, $note) = @_;
    return if $note->has_tag('duplicate-kanji');

    my $cantonese = NFC($note->field('粵語') or return);
    my $kanji = NFC($note->field('漢字'));

    $kanji_for_word{$kanji} = [$cantonese, $note->id];
    $readings_of_word{$kanji}{$cantonese}++;
}

sub done {
    my ($self) = @_;

    for my $word (sort keys %readings_of_word) {
	    #if ($known_homographs{$word}) {
	    #$readings_of_word{$word}{$_} = 0 for @{ $known_homographs{$word} };
	    #}

        # only show words with more than one reading
        # or with kanji in the reading itself (probably over-eagerly converted)
        next if (grep { $_ } values %{ $readings_of_word{$word} }) <= 1
            && (join '', keys %{ $readings_of_word{$word} }) !~ /\p{Han}/;

        my $report = "$word: " . join ', ',
            map { "$_ ($readings_of_word{$word}{$_}x)" }
            sort { $readings_of_word{$word}{$b} <=> $readings_of_word{$word}{$a} }
            keys %{ $readings_of_word{$word} };

        for my $reading (keys %{ $readings_of_word{$word} }) {
            my @nids = @{ $nids_for_word{$word}{$reading} || next };
            if (@nids < 4) {
                $report .= "\n    $reading: " . join(', ', @nids);
            }
        }

	if ($kanji_for_word{$word}) {
            $report .= "\n    $kanji_for_word{$word}[0]: (漢字) " . $kanji_for_word{$word}[1]
	}

        $self->report($report);
    }
}

1;