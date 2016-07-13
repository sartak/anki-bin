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

sub _validate_prompt {
    my ($self, $note, $sgf) = @_;

    my $grove = eval { decode_sgf($sgf) };

    return $self->report_note($note, $@)
        if $@ || !$grove;

    my $game = $grove->[0][0];
    return $self->report_note($note, "No prompt for initial position")
        if !$game->{C};

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
    \z}x;

    return $self->report_note($note, "Unexpected rank '$rank'");
}

sub each_note_詰碁 {
    my ($self, $note) = @_;

    my $sgf = $note->field('SGF');
    $sgf =~ s{\A<div>(.*)</div>\z}{$1};

    return $self->_validate_CH($note, $sgf)
        || $self->_validate_html($note, $sgf)
        || $self->_validate_newlines($note, $sgf)
        || $self->_validate_prompt($note, $sgf)
        || $self->_validate_rank($note);
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
        || $self->_validate_syntax($note, $sgf);
}

1;

