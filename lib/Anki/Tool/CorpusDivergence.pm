package Anki::Tool::CorpusDivergence;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;
use Anki::Corpus;

extends 'Anki::Tool';

my %anki_has;
sub each_note_文 {
    my ($self, $note) = @_;

    $anki_has{ $note->field('日本語') } = $note->field('出所');

    return 1;
}

sub each_note_四字熟語 {
    my ($self, $note) = @_;

    $anki_has{ $note->field('四字熟語') } = '四字熟語';

    return 1;
}

sub done {
    my ($self) = @_;
    my $corpus = Anki::Corpus->new;

    my @bad_source;

    my $printed_header = 0;
    $corpus->print_each("WHERE suspended = 0", sub {
        my $sentence = shift;
        if (my $anki_source = $anki_has{$sentence->japanese}) {
            if ($anki_source ne $sentence->source) {
                push @bad_source, [$sentence->japanese, $anki_source, $sentence->source, $sentence->id]
                    unless ($anki_source =~ /twitter.com|^@/ && $sentence->source eq 'Twitter')
                        || ($anki_source =~ /.+ - .+/ && $sentence->source eq '歌詞')
                        || $sentence->source eq '記事';
            }
            return 0;
        }
        say "=== MISSING FROM ANKI (add to anki) ===" unless $printed_header++;
        return 1;
    });

    if (@bad_source) {
        say "=== INCORRECT SOURCE (fix anki or delete from corpus) ===";
        for (@bad_source) {
            my ($sentence, $anki, $corpus, $id) = @$_;
            say "$id: $sentence";
            say "    expected: $corpus";
            say "         got: $anki";
            say "";
        }
    }

    $printed_header = 0;

    $corpus->print_each("WHERE suspended = 1", sub {
        my $sentence = shift;
        return 0 if !$anki_has{$sentence->japanese};
        say "=== UNEXPECTEDLY IN ANKI (unsuspend in corpus or delete from anki) ===" unless $printed_header++;
        return 1;
    });
}

1;


