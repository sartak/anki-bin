package Anki::Tool::ReadingTypos;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;
use Lingua::JA::Moji 'kana2katakana', 'kata2hira';
use List::MoreUtils 'uniq';
sub kana2hiragana { kata2hira(kana2katakana(shift)) }

extends 'Anki::Tool';

my %known_homographs = (
    '1日'    => [qw/いちにち   ついたち/],
    '4'      => [qw/し         よん/],
    '7'      => [qw/なな       しち/],
    '目'     => [qw/め         もく/],
    '娘'     => [qw/こ         むすめ/],
    '名'     => [qw/めい       な/],
    '後'     => [qw/あと       ご/],
    '我'     => [qw/われ       わ/],
    '下'     => [qw/した       もと/],
    '主'     => [qw/ぬし       おも/],
    '人'     => [qw/ひと       じん/],
    '何'     => [qw/なに       なん/],
    '側'     => [qw/かわ       そば/],
    '内'     => [qw/うち       ない/],
    '前'     => [qw/まえ       ぜん/],
    '君'     => [qw/きみ       くん/],
    '大'     => [qw/だい       おお/],
    '孫'     => [qw/そん       まご/],
    '家'     => [qw/いえ       うち/],
    '山'     => [qw/やま       さん/],
    '方'     => [qw/かた       ほう/],
    '星'     => [qw/ほし       せい/],
    '様'     => [qw/さま       よう/],
    '殿'     => [qw/との       どの/],
    '版'     => [qw/はん       ばん/],
    '玉'     => [qw/たま       だま/],
    '的'     => [qw/てき       まと/],
    '空'     => [qw/から       そら/],
    '訳'     => [qw/やく       わけ/],
    '金'     => [qw/かね       きん/],
    '頃'     => [qw/ころ       ごろ/],
    '風'     => [qw/かぜ       ふう/],
    '中'     => [qw/なか       じゅう/],
    '僕'     => [qw/ぼく       しもべ/],
    '城'     => [qw/しろ       じょう/],
    '敵'     => [qw/てき       かたき/],
    '月'     => [qw/つき       ムーン/],
    '牛'     => [qw/うし       ぎゅう/],
    '皆'     => [qw/みな       みんな/],
    '穴'     => [qw/あな       ホール/],
    '間'     => [qw/かん       あいだ/],
    '声'     => [qw/こえ       ヴォイス/],
    '虫'     => [qw/むし       ウォーム/],
    '剣'     => [qw/つるぎ     けん/],
    '位'     => [qw/くらい     ぐらい/],
    '超'     => [qw/ちょう     スーパー/],
    '吐く'   => [qw/つく       はく/],
    '空く'   => [qw/あく       すく/],
    '良い'   => [qw/いい       よい/],
    '行く'   => [qw/いく       ゆく/],
    '入る'   => [qw/いる       はいる/],
    '弾く'   => [qw/ひく       はじく/],
    '開く'   => [qw/あく       ひらく/],
    '明日'   => [qw/あした     あす/],
    '理由'   => [qw/りゆう     わけ/],
    'お腹'   => [qw/おなか     おはら/],
    '何か'   => [qw/なにか     なんか/],
    '紛れ'   => [qw/まぎれ     まぐれ/],
    '臭い'   => [qw/におい     くさい/],
    '辛い'   => [qw/からい     つらい/],
    '通り'   => [qw/とおり     どおり/],
    '日本'   => [qw/にっぽん   にほん/],
    '一日'   => [qw/いちにち   ついたち/],
    '砂丘'   => [qw/さきゅう   デューン/],
    '餃子'   => [qw/ぎょうざ   チャオズ/],
    '十分'   => [qw/じゅっぷん じゅっぶん/],
    '連中'   => [qw/れんちゅう れんじゅう/],
    '止める' => [qw/とめる     やめる/],
);

my %readings_of_word;
my %readings_of_kanji;
my %nids_for_word;

sub each_card_文 {
    my ($self, $card) = @_;

    my $sentence = $card->field('日本語');
    my $reading_field = $card->field('読み')
        or return;
    my $nid = $card->note_id;

    if (!$card->suspended) {
        my @sentence_kanji = uniq($sentence =~ /\p{Han}/g);
        my @reading_kanji = uniq($reading_field =~ /\p{Han}/g);

        my @sorted_sentence = sort @sentence_kanji;
        my @sorted_reading = sort @reading_kanji;

        if ("@sorted_sentence" eq "@sorted_reading" && "@sentence_kanji" ne "@reading_kanji") {
            return $self->report_card($card, "Kanji order:\ngot      @reading_kanji\nexpected @sentence_kanji");
        }
    }

    my @readings = split /<.*?>/, $reading_field;
    my %seen_this_field;
    for (grep length, @readings) {
        if (my ($word, $reading) = /^([^【]+)【([^】]+)】$/) {
            if ($seen_this_field{$_}++) {
                return $self->report_card($card, "Duplicate reading: $_");
            }

            $readings_of_word{$word}{$reading}++;
            push @{ $nids_for_word{$word}{$reading} }, $nid;

            for my $kanji ($word =~ /\p{Han}/g) {
                $readings_of_kanji{$kanji}{$reading}++;
            }
            next;
        }

        s/\n/\\n/g;
        return $self->report_card($card, "Malformed reading: $_");
    }

    return 1;
}

sub done {
    my ($self) = @_;

    for my $word (sort keys %readings_of_word) {
        if ($known_homographs{$word}) {
            $readings_of_word{$word}{$_} = 0 for @{ $known_homographs{$word} };
        }

        # only show words with more than one reading
        # or with kanji in the reading itself (probably over-eagerly converted)
        # or with only kana in the word (probably forgot to convert)
        next if (grep { $_ } values %{ $readings_of_word{$word} }) <= 1
            && (join '', keys %{ $readings_of_word{$word} }) !~ /\p{Han}/
            && $word !~ /^(\p{Hiragana}|\p{Katakana})+$/;

        my $report = "$word: " . join ', ',
            map { "$_ ($readings_of_word{$word}{$_}x)" }
            sort { $readings_of_word{$word}{$b} <=> $readings_of_word{$word}{$a} }
            keys %{ $readings_of_word{$word} };

        for my $reading (keys %{ $readings_of_word{$word} }) {
            my @nids = @{ $nids_for_word{$word}{$reading} };
            if (@nids < 4) {
                $report .= "\n    $reading: " . join(', ', @nids);
            }
        }

        $self->report($report);
    }
}

1;

