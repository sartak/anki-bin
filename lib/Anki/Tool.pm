# ABSTRACT: scripts to probe and heal my Anki decks
package Anki::Tool;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;

use Anki::Database;

has dbh => (
    is      => 'ro',
    lazy    => 1,
    default => sub { Anki::Database->new },
);

has name => (
    is      => 'ro',
    lazy    => 1,
    default => sub { blessed(shift) =~ s/.*:://r },
);

has report_count => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

sub inspect {
    my $self = shift;
    my $dbh = $self->dbh;

    my @methods = (
        'each_field',
        'each_note',
    );

    for my $method (@methods) {
        if ($self->can($method)) {
            $dbh->$method(sub { $self->$method(@_) });
        }
    }
}

sub report {
    my ($self, $message) = @_;
    $self->report_count($self->report_count + 1);
    warn $self->name . "|$message\n";
}

sub report_hint {
    my ($self, $message) = @_;
    warn((' ' x length $self->name) . "|$message\n");
}

sub report_field {
    my ($self, $field, $message) = @_;
    $self->report_count($self->report_count + 1);
    $message //= $field->value;
    warn $self->name . " nid:" . $field->note_id . "|$message\n";
}

sub report_note {
    my ($self, $note, $message) = @_;
    $self->report_count($self->report_count + 1);
    warn $self->name . " nid:" . $note->id . "|$message\n";
}

sub report_card {
    my ($self, $card, $message) = @_;
    $self->report_count($self->report_count + 1);
    warn $self->name . " nid:" . $card->note_id . "|$message\n";
}

1;

