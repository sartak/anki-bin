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

sub inspect {
    my $self = shift;
    my $dbh = $self->dbh;

    if ($self->can('each_field')) {
        $dbh->each_field(sub { $self->each_field(@_) });
    }
}

sub report_field {
    my ($self, $field, $message) = @_;
    warn "nid:" . $field->note_id . "|$message\n";
}

1;

