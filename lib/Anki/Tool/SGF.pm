package Anki::Tool::SGF;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;
use Games::Go::SGF::Grove 'decode_sgf';

extends 'Anki::Tool';

sub each_note_詰碁 {
    my ($self, $note) = @_;

    my $sgf = $note->field('SGF');
    if ($sgf !~ m{\bCH\[1\]}) {
        $self->report_note($note, "Missing CH[1] correct answer indicator");
    }

    # validate
    eval { decode_sgf($sgf) };
    if ($@) {
        $self->report_note($note, $@);
    }
}

sub each_note_定石 {
    my ($self, $note) = @_;
    return $self->each_note_詰碁($note);
}

1;

