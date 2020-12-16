package Anki::Tool::Canto_Sources;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;
use List::Util 'first';
use List::MoreUtils 'any';

extends 'Anki::Tool';

my %sources = (
    games => [
      '超時空之鑰',
      '夢幻之星IV 千年紀的終結',
      qr/^魔女與勇者\d*$/,
      qr/^太空戰士[IVX]+$/,
    ],
    novels => [
      '迷霧之子首部曲：最後帝國',
      qr/^沙丘\d$/,
      '沙丘救世主',
      '沙丘之子',
    ],
    manga => [
      qr/^龍珠(撒亞人篇\d+)?$/,
    ],
    movies => [
    ],
    television => [
      'Cheap Eats 3D',
      qr/^龍珠 episode \d+$/,
    ],
    tools => [
    ],
    references => [
      'ゼロから話せる広東語',
    ],
    songs => [
    ],
    apps => [
    ],
    podcasts => [
    ],
    conversations => [
      'Edith',
      'Albert',
      'Joan',
      'Thomas',
      'Irene',
    ],
    real_life => [
      qr/^(Sign|Announcement|Conversation|Pamphlet) (at|in|on|with|from) .+/,
      'MTR',
    ],
);

my %expected_tags = (
    games      => 'ゲーム',
    songs      => 'カラオケ',
    movies     => '映画',
    television => 'テレビ',

    novels     => '読み物',
    manga      => '読み物',
);

my (%known_sources, @regex_sources, %type_of);
for my $type (keys %sources) {
    for my $source (@{ $sources{$type} }) {
        $type_of{$source} = $type;

        if (ref($source) eq 'Regexp') {
            push @regex_sources, $source;
        }
        else {
            $known_sources{$source} = $source;
        }
    }
}

my %reverse_tags;
for my $type (keys %expected_tags) {
    my $tag = $expected_tags{$type};
    next if $tag eq '話' || $tag eq '読み物';
    push @{ $reverse_tags{$tag} }, $type;
}

sub type_of {
    my $source = shift;
    my $source_template = $known_sources{$source} || first { $source =~ $_ } @regex_sources;
    return if !$source_template;

    my $type = $type_of{$source_template};
    die "$source_template has no type ??\n" if !$type;

    return $type;
}

sub each_note_廣東話文 {
    my ($self, $note) = @_;
    my $source = $note->field('出所');

    return $self->report_note($note, "source is empty")
        if !$source;

    return $self->report_note($note, "$source - has newlines")
        if $source =~ /\n|<br/;

    return $self->report_note($note, "$source - has spurious #!")
        if $source =~ m{(twitter|facebook)\.com/\#\!};

    return $self->report_note($note, "$source - links to mobile site")
        if $source =~ m{\.m\.wikipedia};

    my $type = type_of($source);

    my @tags = @{ $note->tags };
    my $has_tag = sub {
        my ($tag) = @_;
        return any { $_ eq $tag } @tags;
    };

    return $self->report_note($note, "$source - didn't include either 話 or 読み物 tag") unless $has_tag->('話') || $has_tag->('読み物');

    if ($type) {
        my $expected = $expected_tags{$type};
        if ($expected && !$has_tag->($expected)) {
            return $self->report_note($note, "$source - didn't include tag $expected expected of $type");
        }
    }

    # make sure each note has no spurious tags
    return if $source =~ m{^http};
    for my $tag (grep { $has_tag->($_) } keys %reverse_tags) {
        unless ($type && grep { $type eq $_ } @{ $reverse_tags{$tag} }) {
            return $self->report_note($note, "$source - has spurious $tag tag");
        }
    }

    return 1;
}

1;
