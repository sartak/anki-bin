package Anki::Tool::Decks;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;
use List::Util 'first';
use List::MoreUtils 'any';

extends 'Anki::Tool';

my %expected = (
  Cubing => ['Basic'],
  General => ['Basic', 'Date', 'Greek'],
  Mathematics => ['Basic', 'MathJax'],
  '囲碁' => ['詰碁', 'Basic'],
  '廣東話' => ['廣東話文', '廣東話聲調'],
  '日本語' => ['文', 'かな', '地図'],
  '漢字' => ['漢字'],
);

sub done {
  my ($self) = @_;
  my $dbh = $self->dbh;

  for my $deck (sort keys %expected) {
    my %ok = map { $_ => 1 } @{ $expected{$deck} };
    $dbh->each_card_for_deck(sub {
      my ($card) = @_;
      my $model = $card->model->name;
      if (!$ok{$model}) {
        $self->report_card($card, "Unexpected model $model for deck $deck");
      }
    }, $deck);
  }

  return 1;
}

1;

