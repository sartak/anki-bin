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
    '４'     => [qw/し         よん/],
    '７'     => [qw/なな       しち/],
    '一日'   => [qw/いちにち   ついたち/],
    '下'     => [qw/した       もと/],
    '中'     => [qw/なか       じゅう/],
    '主'     => [qw/ぬし       おも/],
    '人'     => [qw/ひと       じん/],
    '位'     => [qw/くらい     ぐらい/],
    '何'     => [qw/なに       なん/],
    '何か'   => [qw/なにか     なんか/],
    '側'     => [qw/かわ       そば/],
    '僕'     => [qw/ぼく       しもべ/],
    '入る'   => [qw/いる       はいる/],
    '内'     => [qw/うち       ない/],
    '前'     => [qw/まえ       ぜん/],
    '剣'     => [qw/つるぎ     けん/],
    '十分'   => [qw/じゅっぷん じゅっぶん/],
    '名'     => [qw/めい       な/],
    '吐く'   => [qw/つく       はく/],
    '君'     => [qw/きみ       くん/],
    '地'     => [qw/ち         じ/],
    '城'     => [qw/しろ       じょう/],
    '声'     => [qw/こえ       ヴォイス/],
    '大'     => [qw/だい       おお/],
    '娘'     => [qw/こ         むすめ/],
    '孫'     => [qw/そん       まご/],
    '家'     => [qw/いえ       うち/],
    '山'     => [qw/やま       さん/],
    '布石'   => [qw/ぬのいし   ふせき/],
    '弾く'   => [qw/ひく       はじく/],
    '後'     => [qw/あと       ご/],
    '我'     => [qw/われ       わ/],
    '敵'     => [qw/てき       かたき/],
    '方'     => [qw/かた       ほう/],
    '日本'   => [qw/にっぽん   にほん/],
    '明日'   => [qw/あした     あす/],
    '星'     => [qw/ほし       せい/],
    '月'     => [qw/つき       ムーン/],
    '本気'   => [qw/ほんき     マジ/],
    '様'     => [qw/さま       よう/],
    '止める' => [qw/とめる     やめる/],
    '歳'     => [qw/さい       とし/],
    '殿'     => [qw/との       どの/],
    '版'     => [qw/はん       ばん/],
    '牛'     => [qw/うし       ぎゅう/],
    '玉'     => [qw/たま       だま/],
    '理由'   => [qw/りゆう     わけ/],
    '的'     => [qw/てき       まと/],
    '皆'     => [qw/みな       みんな/],
    '目'     => [qw/め         もく/],
    '砂丘'   => [qw/さきゅう   デューン/],
    '穴'     => [qw/あな       ホール/],
    '空'     => [qw/から       そら/],
    '空く'   => [qw/あく       すく/],
    '紛れ'   => [qw/まぎれ     まぐれ/],
    'お腹'   => [qw/おなか     おはら/],
    '臭い'   => [qw/におい     くさい/],
    '良い'   => [qw/いい       よい/],
    '虫'     => [qw/むし       ウォーム/],
    '行く'   => [qw/いく       ゆく/],
    '訳'     => [qw/やく       わけ/],
    '超'     => [qw/ちょう     スーパー/],
    '辛い'   => [qw/からい     つらい/],
    '辺'     => [qw/あたり     へん/],
    '通り'   => [qw/とおり     どおり/],
    '連中'   => [qw/れんちゅう れんじゅう/],
    '金'     => [qw/かね       きん/],
    '開く'   => [qw/あく       ひらく/],
    '間'     => [qw/かん       あいだ/],
    '頃'     => [qw/ころ       ごろ/],
    '風'     => [qw/かぜ       ふう/],
    '餃子'   => [qw/ぎょうざ   チャオズ/],
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
        my @sentence_kanji = uniq($sentence =~ /\p{Unified_Ideograph}/g);
        my @reading_kanji = uniq($reading_field =~ /\p{Unified_Ideograph}/g);

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

	    if ($reading =~ /\?|？/) {
                return $self->report_card($card, "Incomplete reading: $_");
	    }

            $readings_of_word{$word}{$reading}++;
            push @{ $nids_for_word{$word}{$reading} }, $nid;

            for my $kanji ($word =~ /\p{Unified_Ideograph}/g) {
                $readings_of_kanji{$kanji}{$reading}++;
            }
            next;
        }

        s/\n/\\n/g;

        s{
            ^ (\s+)        # leading space
            | (\s+) $      # trailing space
        }{\e[1;41m$+\e[m}xg;

        return $self->report_card($card, "Malformed reading: $_");
    }

    return 1;
}

sub each_note_漢字 {
    my ($self, $note) = @_;
    if (my $japanese = $note->field('読み')) {
        if ($japanese =~ s{
            ([^\p{Unified_Ideograph}|々|\p{Hiragana}\p{Katakana}ー・、]+) # Non-Japanese
        }{\e[1;41m$+\e[m}xg) {
            return $self->report_note($note, "Malformed 読み: $japanese");
        }
    }

    if (my $cantonese = $note->field('廣東話')) {
        if ($cantonese =~ s{
              ^ (\s+)                # leading space
              | (\s+) $              # trailing space
              | (<.*?>)              # HTML
              | ([\p{Unified_Ideograph}\p{Hiragana}\p{Katakana}ー]+) # Japanese
          }{\e[1;41m$+\e[m}xg) {
            return $self->report_note($note, "Malformed 廣東話: $cantonese");
        }
    }
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
            && (join '', keys %{ $readings_of_word{$word} }) !~ /\p{Unified_Ideograph}/
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

