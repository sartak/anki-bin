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

sub report_field {
    my ($self, $field, $message) = @_;
    $message //= $field->value;
    warn $self->name . " nid:" . $field->note_id . "|$message\n";
}

sub report_note {
    my ($self, $note, $message) = @_;
    warn $self->name . " nid:" . $note->id . "|$message\n";
}

1;

