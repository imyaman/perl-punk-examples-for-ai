package Daeha;

use Punk;

# ---- 인메모리 노트 저장소 (예제용) ----
my %NOTES = ();
my $NEXT_ID = 1;

sub _now {
    my (@t) = localtime(time());
    $t[4] += 1;
    $t[3] += 1;
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $t[5] + 1900, @t[4, 3, 2, 1, 0]);
}

sub _build_note {
    my ($title, $body) = @_;
    my $id = $NEXT_ID++;
    return {
        id         => $id,
        title      => $title // '',
        body       => $body // '',
        created_at => _now(),
        updated_at => _now(),
    };
}

sub _find {
    my ($id) = @_;
    return $NOTES{$id} if exists $NOTES{$id};
    return;
}

sub _parse_json_body {
    my ($c) = @_;
    my $input = $c->req->json;
    return $input if $input && ref $input eq 'HASH';
    return undef;
}

sub _json_error {
    my ($c, $message, $status) = @_;
    $status //= 400;
    return $c->json({ error => $message }, $status);
}

# ---- 건강 확인 (기준선 유지) ----
get '/api/ping' => sub {
    my ($c) = @_;
    $c->json({ ping => 'pong' });
};

get '/api/healthz' => sub {
    my ($c) = @_;
    $c->json({ status => 'ok' });
};

get '/api/readyz' => sub {
    my ($c) = @_;
    $c->json({ status => 'ready' });
};

# ---- 노트 CRUD ----

# 목록
get '/api/notes' => sub {
    my ($c) = @_;
    my @notes = map { $NOTES{$_} } sort { $a <=> $b } keys %NOTES;
    $c->json({ notes => \@notes, count => scalar @notes });
};

# 상세
get '/api/notes/:id' => sub {
    my ($c) = @_;
    my $id = $c->param('id');
    my $note = _find($id);
    unless ($note) {
        return $c->json({ error => 'note not found' }, 404);
    }
    $c->json($note);
};

# 생성
post '/api/notes' => sub {
    my ($c) = @_;
    my $input = eval { $c->req->json };
    if ($@ || !defined $input || ref $input ne 'HASH') {
        return _json_error($c, 'invalid JSON body', 400);
    }
    my $title = $input->{title};
    my $body  = $input->{body};
    if (!defined $title && !defined $body) {
        return _json_error($c, 'title 또는 body가 필요합니다', 400);
    }
    my $note = _build_note($title, $body);
    $NOTES{$note->{id}} = $note;
    $c->json($note, 201);
};

# 갱신
put '/api/notes/:id' => sub {
    my ($c) = @_;
    my $id = $c->param('id');
    my $note = _find($id);
    unless ($note) {
        return $c->json({ error => 'note not found' }, 404);
    }
    my $input = eval { $c->req->json };
    if ($@ || !defined $input || ref $input ne 'HASH') {
        return _json_error($c, 'invalid JSON body', 400);
    }
    $note->{title} = $input->{title} // $note->{title};
    $note->{body}  = $input->{body}  // $note->{body};
    $note->{updated_at} = _now();
    $c->json($note);
};

# 삭제
del '/api/notes/:id' => sub {
    my ($c) = @_;
    my $id = $c->param('id');
    my $note = delete $NOTES{$id};
    unless ($note) {
        return $c->json({ error => 'note not found' }, 404);
    }
    $c->json({ deleted => $note->{id} });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 1: 노트 CRUD)

=head1 SYNOPSIS

POST   /api/notes             생성
GET    /api/notes             목록
GET    /api/notes/:id         상세
PUT    /api/notes/:id         갱신
DELETE /api/notes/:id         삭제
GET    /api/ping              ping/pong
GET    /api/healthz           k8s liveness
GET    /api/readyz            k8s readiness

=cut
