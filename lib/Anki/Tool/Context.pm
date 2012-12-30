package Anki::Tool::Context;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;

extends 'Anki::Tool';

sub each_note_文 {
    my ($self, $note) = @_;
    my $context = $note->field('前後関係');

    if ($context =~ /ibid/ || $context =~ /連続/) {
        return $self->report_note($note, "$context - invalid context");
    }

    return 1;
}

1;

