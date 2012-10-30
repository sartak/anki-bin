package Anki::Tool::Sources;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;
use List::Util 'first';
use List::MoreUtils 'any';

extends 'Anki::Tool';

my %sources = (
    games => [
        'jNetHack',
        'クロノ・トリガー',
        'ブレス オブ ファイア 竜の戦士',
        'ブレス オブ ファイア III',
        'マックスウェルの不思議なノート',
        'ポケットモンスター ファイアレッド',
        'ファンタシースター 千年紀の終りに',
        'ファンタシースターII 還らざる時の終わりに',
        'Halo Reach',
        qr/^ファイナルファンタジー[IVX]+$/,
        'ファイナルファンタジータクティクス 獅子戦争',
        'ファイナルファンタジーUSA ミスティッククエスト',
        'ゼルダの伝説 大地の汽笛',
        'ゴッドハンド',
        '大江戸タウンズ',
        'MOTHER2 ギーグの逆襲',
        'バハムート ラグーン',
        qr/^ドラゴンクエスト[IVX]+$/,
        'ドラゴンクエストIX 星空の守り人',
        'エピックハーツ',
        'もじとも',
        '大きな字の漢字ナンクロ',
        'Cut the Rope',
        '魔女と勇者',
    ],
    novels => [
        qr/^デューン砂の惑星[1-4]$/,
        'ハリー・ポッターと賢者の石',
        'ハリー・ポッターと秘密の部屋',
        'ハリー・ポッターとアズカバンの囚人',
        'ハリー・ポッターと炎のゴブレット',
        'ハリー・ポッターと不死鳥の騎士団',
        'ハリー・ポッターと謎のプリンス',
        'ハリー・ポッターと死の秘宝',
        'ホビットの冒険',
        '指輪物語',
        '坑夫',
        '吾輩は猫である',
        'こゝろ',
        '坊っちゃん',
    ],
    manga => [
        qr/^ドラゴンボール\d+$/,
        qr/^北斗の拳\d+$/,
        qr/^天才バカボン\d+$/,
        qr/^ヒカルの碁\d+$/,
        qr/^バガボンド\d+$/,
        qr/^鋼の錬金術師\d+$/,
        qr/^ブリーチ\d+$/,
    ],
    movies => [
        'マトリックス',
        'マトリックス リローデッド',
        'マトリックス レボリューションズ',
        'ブレイド',
        'ブレイド2',
        'アキラ',
        'ダイ・ハード2',
        qr{^ロード・オブ・ザ・リング/(旅の仲間|二つの塔|王の帰還)$},
        "Ocean's 11",
        'Constantine',
        'Babel',
        'ハリー・ポッターと賢者の石(映画)',
        'ゴールデンアイ',
        '乱',
        'グラディエーター',
        '用心棒',
        'Queen of the Damned',
        'The Simpsons Movie',
        '魔女の宅急便',
        'ボーン・スプレマシー',
        'キル・ビル',
        'トロイ',
        '千と千尋の神隠し',
    ],
    television => [
        qr/^ドラゴンボール改\d+$/,
        qr/^北斗の拳\d+話目$/,
        'あやかの突撃英会話',
        'ドラゴンボール改',
        'ロス・タイム・ライフ',
    ],
    tools => [
        'プログレッシブ英和・和英中辞典',
        'Tae Kim',
        'Smart.fm',
        'MFSP',
        'Making Out in Japanese',
        'Dirty Guide to Japanese',
        'Genki',
        'A Dictionary of Japanese Particles',
        'ドラえもん四字熟語100',
        '大辞泉',
        '大辞林',
        'ドラえもんのまんがで英語辞典覚える',
        'goo',
        'ARES-3',
    ],
    references => [
        'モダンPerl入門',
        'CPANモジュールガイド',
        qr/^WEB\+DB Press: .+/,
        qr/^第\d+回国語分科会漢字小委員会$/,
    ],
    songs => [
        qr/^Mr\. Children - .*$/,
        qr/^L'Arc~en~Ciel - .*$/,
        qr/^Gackt - .*$/,
        qr/^高田雅史 - .*$/,
        qr/^分島花音 - .*$/,
        qr/^Malice Mizer - .*$/,
        qr/^Perfume - .*$/,
        qr/^浜崎あゆみ - .*$/,
        qr/^Pizzicato Five - .*$/,
        qr/^Rumi - .*$/,
        qr/^宇多田ヒカル - .*$/,
    ],
    apps => [
        'RT',
        'Jifty',
        'Facebook',
        'OS X',
        'Gmail',
        'Echofon',
        'YouTube',
        'Twitter',
        'Foursquare',
        'Google Reader',
        'Firefox',
        'Skype',
        'NetNewsWire',
        'Last.fm',
        'iOS',
        'Japanese.app',
        'Amazon',
        'Anki',
        'ニコニコ動画',
        'Siri',
    ],
    podcasts => [
        '読売ニュースポッドキャスト',
        'モヤモヤとーく',
        'ヒデラジ',
    ],
    conversations => [
        qr/^Personal correspondence with .+/,
        qr/^@\w+$/,
    ],
    real_life => [
        '中村先生',
        '高橋先生',
        '公共交通機関',
        qr/^(Sign|Announcement|Conversation|Pamphlet) (at|in|on|with|from) .+/,
        'YAPC::Asia',
        '広告',
    ],
);

my %expected_tags = (
    games      => 'ゲーム',
    songs      => 'カラオケ',
    novels     => '読み物',
    manga      => '読み物',
    references => '読み物',
    movies     => '映画',
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

sub each_note_文 {
    my ($self, $note) = @_;
    my $source = $note->fields->{'出所'};
    my @tags = @{ $note->tags };

    my $has_tag = sub {
        my ($tag) = @_;
        return any { $_ eq $tag } @tags;
    };

    return if $has_tag->('from-corpus');

    if (my $type = type_of($source)) {
        my $expected = $expected_tags{$type};
        if ($expected && !$has_tag->($expected)) {
            return $self->report_note($note, "$source - didn't include tag $expected expected of $type");
        }
    }
    return 1;
}

1;

