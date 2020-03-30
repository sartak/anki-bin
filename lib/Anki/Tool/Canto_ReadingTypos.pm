package Anki::Tool::Canto_ReadingTypos;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;
use List::MoreUtils 'uniq';
use Unicode::Normalize;
use Anki::Morphology;

extends 'Anki::Tool';

my %readings_of_word;
my %nids_for_word;
my %kanji_for_word;
my $morph = Anki::Morphology->new;

sub each_note_廣東話文 {
    my ($self, $note) = @_;

    my $sentence = NFC($note->field('廣東話'));
    my $reading_field = NFC($note->field('発音') || '');
    my $nid = $note->id;

    s/<.*?>//g for $sentence, $reading_field;

    my @sentence_kanji = $sentence =~ /\p{Han}|[a-zA-Z0-9]+/g;
    my @reading_kanji = split ' ', $reading_field;

    if (@sentence_kanji > 0 && @reading_kanji == 0) {
        my @parses;
	for my $parse ($morph->canto_morphemes_of($sentence, {allow_unknown => 1})) {
          my @suggestions;
	  for my $morpheme (@$parse) {
	    my $word = $morpheme->{word};
	    my @s = $morph->canto_readings_for($word);
	    if (!@s) {
	      for my $character (split '', $word) {
	        my @r = $morph->canto_kanji_readings_for($character);
	        if (!@r) {
		  push @r, "$character??";
		}
		push @s, @r;
	      }
	    }
	    push @suggestions, join "/", @s;
	  }
	  push @parses, \@suggestions;
	}

        return $self->report_note(
		$note,
		"Missing reading for $sentence\n" .
		join('', uniq map { "perhaps: " .  join(' ', @$_) . "\n" } @parses)
	);
    }

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

    my $cantonese = NFC($note->field('廣東話') or return);
    my $kanji = NFC($note->field('漢字'));

    my @readings = split ', ', $cantonese;

    $kanji_for_word{$kanji} = [$cantonese, \@readings, $note->id];
    for my $reading (@readings) {
      $readings_of_word{$kanji}{$reading}++;
    }
}

sub done {
    my ($self) = @_;

    for my $word (sort keys %readings_of_word) {
	if ($kanji_for_word{$word}) {
            my %seen = %{$readings_of_word{$word}};
  	    $seen{$_} = 0 for @{ $kanji_for_word{$word}[1] };
	    next if !(grep { $_ } values %seen);
	}
	else {
            next if (grep { $_ } values %{ $readings_of_word{$word} }) <= 1;
	}

        my $report = "$word: " . join ', ',
            map { "$_ ($readings_of_word{$word}{$_}x)" }
            sort { $readings_of_word{$word}{$b} <=> $readings_of_word{$word}{$a} }
            keys %{ $readings_of_word{$word} };

	if ($kanji_for_word{$word}) {
            $report .= "\n    $kanji_for_word{$word}[0]: (漢字) " . $kanji_for_word{$word}[2];
	}

        for my $reading (keys %{ $readings_of_word{$word} }) {
            my @nids = @{ $nids_for_word{$word}{$reading} || next };
            $report .= "\n    $reading: " . join(', ', @nids);
        }

        $self->report($report);
    }
}

1;
