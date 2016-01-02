package Anki::Tool::Tags;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;

extends 'Anki::Tool';

my @allowed = qw(
    ゲーム
    カラオケ
    読み物
    映画
    記事
    文法
    動画
    写真
    テレビ

    地図
    日本
    東京

    自愛
    早口言葉

    rtk1
    rtk3
    rtks

    leech
    context-only
    from-corpus
    duplicate-kanji
);

sub each_note {
    my ($self, $note) = @_;

    my %tags = %{ $note->tags_as_hash };
    delete @tags{@allowed};

    if (%tags) {
        return $self->report_note($note, (join ' ', keys %tags));
    }

    return 1;
}

1;

