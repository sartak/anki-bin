package Anki::Tool::StudyCards;
use utf8;
use 5.16.0;
use warnings;
use Any::Moose;
use DBI;
use URI::Escape;

extends 'Anki::Tool';

die "STUDY_PREFIX required" unless $ENV{STUDY_PREFIX};
my $study_prefix = $ENV{STUDY_PREFIX};

die "STUDY_URL_REGEX required" unless $ENV{STUDY_URL_REGEX};
my $study_url_regex = qr/$ENV{STUDY_URL_REGEX}/;

die "STUDY_DATABASE required" unless $ENV{STUDY_DATABASE};
my $dbh = DBI->connect("dbi:SQLite:dbname=" . $ENV{STUDY_DATABASE}, undef, undef, {
    RaiseError => 1,
});
$dbh->{sqlite_unicode} = 1;

my $sth = $dbh->prepare("SELECT content FROM sentences WHERE screenshot=(SELECT id FROM screenshots WHERE path=?)");

sub check_study {
    my ($self, $note, $sentence_field, $source_field) = @_;

    my $context = $note->field('前後関係')
        or return 1;

    my @imgs = $context =~ m/$study_url_regex/g;
    return 1 if !@imgs;

    my $expected = $note->field($sentence_field);
    my $source = $note->field($source_field);

    $expected =~ s/<.*?>//g;

    my $ok = 1;
    PATH: for my $path (@imgs) {
      $path =~ s/#.*//;

      $sth->execute($path);
      my @got = map { $_->[0] } @{ $sth->fetchall_arrayref };
      next PATH if grep { $expected eq $_ } @got;
      $ok = 0;

      $self->report_note($note, "Did not find sentence for screenshot $path");

      if (@got) {
        $self->report_hint("$study_prefix/game/@{[uri_escape($source, qq< >)]}/_all#$path");
        $self->report_hint("screenshot: $_") for @got;
      } else {
        $self->report_hint("The screenshot is missing");
      }

      $self->report_hint("card:       $expected");
    }

    return $ok;
}

sub each_note_文 {
    my ($self, $note) = @_;
    return $self->check_study($note, '日本語', '出所');
}

sub each_note_廣東話文 {
    my ($self, $note) = @_;
    return $self->check_study($note, '廣東話', '出所');
}

sub slice_info {
    my ($self, $slice_id, $width, $height, $polygon) = @_;
    my @polygon = split ',', $polygon;
    my $p = join ';', map { int $_ } @polygon;
    return "#slice:${slice_id};${width}x${height};${p}";
}

sub add_missing_links {
    my ($self) = @_;

    my $unlinked_sth = $dbh->prepare("
        SELECT sentences.content, GROUP_CONCAT(screenshots.path, char(10))
        FROM sentences
        LEFT JOIN screenshots ON sentences.screenshot = screenshots.id
        WHERE sentences.content IS NOT NULL
        AND sentences.content != ''
        AND screenshots.game IN (SELECT id FROM games WHERE visual=1)
        GROUP BY sentences.content;
    ");
    $unlinked_sth->execute;

    my $slice_sth = $dbh->prepare("
        SELECT slices.id, screenshots.width, screenshots.height, slices.polygon
	FROM sentences
        LEFT JOIN screenshots ON sentences.screenshot = screenshots.id
	LEFT JOIN slices ON sentences.slice = slices.id
	WHERE slices.id IS NOT NULL
	AND screenshots.path = ? AND sentences.content = ?
    ");

    my $anki = $self->dbh;
    while (my ($content, $paths) = $unlinked_sth->fetchrow_array) {
        my @paths = split /\n/, $paths;
	my $is_j = $paths[0] =~ m{^/j/};
        my ($model, $field) = $is_j ? ('文', '日本語') : ('廣東話文', '廣東話');

        # no note for this screenshot sentence, so skip
        my $note = $anki->find_notes($model, $field => $content)
            or next;

        my $context = $note->field('前後関係') || '';

        my @missing_paths = grep { $context !~ /\b\Q$_\E\b/ } grep { !!$is_j == !!m{^/j} } @paths
            or next;

        $self->report_note($note, "Matches content but does not link to @{[ join ', ', @missing_paths ]}");
        $self->report_hint("sentence: $content");
        $self->report_hint("context:  $context");

        for my $path (@missing_paths) {
            my $url = "$study_prefix$path";

            $slice_sth->execute($path, $content);
	    if (my (@slice) = $slice_sth->fetchrow_array) {
		$url .= $self->slice_info(@slice);
	    }

            if ($context !~ m{<img}) {
                $context = qq[<img src="$url" />];
            } else {
                ($context) = $context =~ /(<img [^>]+>)/;
                if ($context !~ m{data-or=}) {
                    $context =~ s{<img }{<img data-or="$url" };
                } else {
                    $context =~ s{(data-or=")}{$1$url,};
                }
            }
        }

        $self->report_hint("tag:      $context");
    }
}

sub update_stale_links {
    my $self = shift;

    my $sliced_sentences_sth = $dbh->prepare("
        SELECT sentences.content, screenshots.path, slices.id, screenshots.width, screenshots.height, slices.polygon
        FROM sentences
        LEFT JOIN screenshots ON sentences.screenshot = screenshots.id
	LEFT JOIN slices ON sentences.slice = slices.id
	WHERE slices.id IS NOT NULL
        AND sentences.content IS NOT NULL
        AND sentences.content != ''
        AND screenshots.game IN (SELECT id FROM games WHERE visual=1)
    ");
    $sliced_sentences_sth->execute;

    my $anki = $self->dbh;
    while (my ($content, $path, @slice) = $sliced_sentences_sth->fetchrow_array) {
	my $is_j = $path =~ m{^/j/};
        my ($model, $field) = $is_j ? ('文', '日本語') : ('廣東話文', '廣東話');

        # no note for this screenshot sentence, so skip
        my $note = $anki->find_notes($model, $field => $content)
            or next;

        my $context = $note->field('前後関係') || '';

	my $base = $study_prefix . $path;
        my $url = $base . $self->slice_info(@slice);

        next if $context =~ /\b\Q$url\E\b/;

	# no link to this yet, but it was already caught in ->add_missing_links
	next unless $context =~ /\b\Q$base\E/;

        $self->report_note($note, "Stale link to $path");
        $self->report_hint("sentence: $content");
        $self->report_hint("context:  $context");

	$context =~ s/\b\Q$base\E[^,"]*/$url/;
        $self->report_hint("tag:      $context");
    }
}

sub done {
    my $self = shift;
    $self->add_missing_links;
    $self->update_stale_links;
}

1;

