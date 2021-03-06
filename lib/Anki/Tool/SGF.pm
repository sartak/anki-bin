package Anki::Tool::SGF;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;
use Games::Go::SGF::Grove 'decode_sgf';

extends 'Anki::Tool';

sub _validate_CH {
    my ($self, $note, $sgf) = @_;

    return $self->report_note($note, "Missing CH[1] correct answer indicator")
        if $sgf !~ m{\bCH\[1\]};
    return;
}

sub _validate_tenuki {
    my ($self, $note, $sgf) = @_;

    return $self->report_note($note, "Missing 'T' mark for tenuki.")
        if $sgf !~ m{LB\[\w\w:T\]};
    return;
}

sub _validate_html {
    my ($self, $note, $sgf) = @_;

    return $self->report_note($note, $sgf)
        if $sgf =~ s{(<.*?>)}{\e[1;41m$1\e[m}g;
    return;
}

sub _validate_duplicate {
    my ($self, $note, $sgf) = @_;

    return $self->report_note($note, "duplicate SGF")
        if $self->{seen_sgf}{$sgf}++;
    return;
}

sub _validate_newlines {
    my ($self, $note, $sgf) = @_;

    return $self->report_note($note, $sgf)
        if $sgf =~ /[\r\n]/;
    return;
}

sub _validate_syntax {
    my ($self, $note, $sgf) = @_;

    eval { decode_sgf($sgf) };

    return $self->report_note($note, $@)
        if $@;
    return;
}

sub _validate_alternatives {
    my ($self, $note, $sgf) = @_;

    my $grove = eval { decode_sgf($sgf) };
    my $game = $grove->[0];
    my (@variations, $varying_player);

    if (@$game == 1) {
        $varying_player = uc($game->[0]{PL} || 'B');
        push @variations, [$_, $varying_player] for @{$game->[0]{variations}};
    }
    else {
        my $meta = shift @$game;
        $varying_player = uc($meta->{PL} || 'B');
        push @variations, [$game, $varying_player];
    }

    while (my $variation = shift @variations) {
        my ($tree, $player) = @$variation;
        for my $node (@$tree) {
            if (!$node->{$player}) {
                use Data::Dumper;
                return $self->report_note($note, "Expected a node with $player; instead got " . Dumper($node));
            }

            $player = $player eq 'B' ? 'W' : 'B';
            if ($node->{variations}) {
                if ($player ne $varying_player) {
                    return $self->report_note($note, "Variations for non-varying player $player");
                }
                push @variations, [$_, $player] for @{ $node->{variations} };
            }
        }
    }

    return;
}

sub _validate_rank {
    my ($self, $note) = @_;
    my $rank = $note->field('Rank');

    return if $rank =~ m{\A
        (\d+) \  kyu
      | (\d+) \  dan
      | Double-digit \ kyu
      | Single-digit \ kyu
      | Low\ dan
      | High\ dan
      | Professional
      | AYD
    \z}x;

    return $self->report_note($note, "Unexpected rank '$rank'");
}

sub _validate_source {
    my ($self, $note) = @_;
    my $source = $note->field('Source');

    return $self->report_note($note, "source is empty")
        if !$source;

    return $self->report_note($note, "$source - has newlines")
        if $source =~ /\n|<br/;

    my $major_tags = 0;
    $major_tags++ if $note->has_tag('読み物');
    $major_tags++ if $note->has_tag('記事');
    $major_tags++ if $note->has_tag('動画');
    $major_tags++ if $note->has_tag('自己吟味');
    return $self->report_note($note, "$source - has multiple major tags: " . join(', ', @{$note->tags})) if $major_tags > 1;

    if ($source =~ m{\A
        Graded\ Go\ Problems\ for\ Beginners\ Volume\ (One|Two|Three|Four)\ \#\d+
      | Cho\ Chikun's\ Encyclopedia\ of\ Life\ and\ Death\ part\ 1\ \#\d+
      | Get\ Strong\ at\ (Attacking|Invading)\ (\#\d+|p\.[ivx]+)
      | Five\ Hundred\ and\ One\ Tesuji\ Problems\ \#\d+
      | One\ Thousand\ and\ One\ Life-and-Death\ Problems\ \#\d+
      | 中盤の基本\ \#\d+
      | 詰碁の基本\ \#\d+
      | 手筋の基本\ \#\d+
      | Making\ Good\ Shape\ \#\d+
      | Tricks\ in\ Joseki\ \#\d+
      | In\ the\ Beginning\ p\d+
      | Tesuji\ p\d+
      | The\ Monkey\ Jump\ section\ [123]\ chapter\ \d+
      | Relentless\ p\d+
      | Double\ Digit\ Kyu\ Games,\ game\ \#\d
      | Opening\ Theory\ Made\ Easy\ principle\ \d+:.+
      | Life\ and\ Death\ chapter\ \d+\ problem\ \d+
    \z}x) {
      return $self->report_note($note, "$source - didn't include tag 読み物") if !$note->has_tag('読み物');
      return;
    }

    if ($source =~ m{\A
        Nick\ Sibicky\ \#\d+
      | Andrew\ Jackson\ \d\d\d\d-\d\d-\d\d
      | https?://[^/]*yunguseng\.com/
      | https?://[^/]*youtube\.com/
    \z}x) {
      return $self->report_note($note, "$source - didn't include tag 動画") if !$note->has_tag('動画');
      return;
    }

    if ($source =~ m{\A
        https?://.+
    \z}x) {
      return $self->report_note($note, "$source - didn't include tag 読み物, 記事, 動画, 人工知能, or 自己吟味") if !$major_tags && !$note->has_tag('人工知能');
      return;
    }

    if ($source =~ m{\A
        \d\d\d\d-\d\d-\d\d[a-z]{1,3}
      | Kogo's\ Joseki\ Dictionary
    \z}x) {
      return;
    }

    return $self->report_note($note, "Unexpected source '$source'");
}

sub each_note_詰碁 {
    my ($self, $note) = @_;

    my $sgf = $note->field('SGF');
    $sgf =~ s{\A<div>(.*)</div>\z}{$1};

    return $self->_validate_CH($note, $sgf)
        || $self->_validate_html($note, $sgf)
        || $self->_validate_newlines($note, $sgf)
        || $self->_validate_alternatives($note, $sgf)
        || $self->_validate_rank($note)
        || $self->_validate_source($note)
        || $self->_validate_duplicate($note, $sgf);
}

sub each_note_定石 {
    my ($self, $note) = @_;

    my $sgf = $note->field('SGF');
    $sgf =~ s{\A<div>(.*)</div>\z}{$1};

    return $self->_validate_CH($note, $sgf)
        || $self->_validate_html($note, $sgf)
        || $self->_validate_newlines($note, $sgf)
        || $self->_validate_syntax($note, $sgf)
        || $self->_validate_tenuki($note, $sgf);
}

sub each_note_計算 {
    my ($self, $note) = @_;

    my $sgf = $note->field('SGF');
    $sgf =~ s{\A<div>(.*)</div>\z}{$1};

    return $self->_validate_html($note, $sgf)
        || $self->_validate_newlines($note, $sgf)
        || $self->_validate_syntax($note, $sgf)
        || $self->_validate_source($note);
}

1;

