package Daeha;

use Punk;
use JSON::PP;

# ---- 업로드 저장소 (예제용, 파일명 -> 정보) ----
my %UPLOAD_RECORDS = ();

sub _now_iso {
    my ($s,$m,$h,$d,$mo,$y) = gmtime(time());
    $mo += 1; $y += 1900;
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $y,$mo,$d,$h,$m,$s);
}

sub _safe_filename {
    my ($name) = @_;
    $name =~ s/[^a-zA-Z0-9._-]/_/g;
    return $name;
}

# ---- 헬프 (기준선 유지) ----
get '/api/ping' => sub {
    $_[0]->json({ ping => 'pong' });
};
get '/api/healthz' => sub {
    $_[0]->json({ status => 'ok' });
};
get '/api/readyz' => sub {
    $_[0]->json({ status => 'ready' });
};

# ---- 단일 파일 업로드 ----
post '/api/upload' => sub {
    my ($c) = @_;
    my $up = $c->upload('file');
    unless (defined $up) {
        return $c->json({
            error => { code => 'NO_FILE', message => 'file 필드가 필요합니다' },
        }, 400);
    }
    my $filename = _safe_filename($up->filename());
    my $size = $up->size();
    my $type = $up->type();
    my $content = eval { $up->content() };
    if ($@) {
        return $c->json({
            error => { code => 'READ_ERROR', message => '파일 읽기 중 오류' },
        }, 500);
    }
    my $id = 'upl_' . time() . '_' . int(rand(10000));
    $UPLOAD_RECORDS{$id} = {
        id         => $id,
        filename   => $filename,
        original   => $up->filename(),
        size       => $size,
        type       => $type,
        title      => $c->req->form()->{'title'} // undef,
        uploaded_at => _now_iso(),
    };
    $c->json({
        uploaded => {
            id         => $id,
            filename   => $filename,
            size       => $size,
            type       => $type,
            title      => $UPLOAD_RECORDS{$id}{title},
            uploaded_at => $UPLOAD_RECORDS{$id}{uploaded_at},
        },
    }, 201);
};

# ---- 여러 파일 업로드 ----
post '/api/upload-multiple' => sub {
    my ($c) = @_;
    my $uploads = $c->req->uploads();
    my $files_field = $uploads->{'files[]'};
    unless ($files_field) {
        return $c->json({
            error => { code => 'NO_FILES', message => 'files[] 필드가 필요합니다' },
        }, 400);
    }
    my @list = ref $files_field eq 'ARRAY' ? @$files_field : ($files_field);
    my @result;
    for my $up (@list) {
        my $filename = _safe_filename($up->filename());
        my $size = $up->size();
        my $type = $up->type();
        my $content = eval { $up->content() };
        if ($@) {
            push @result, { filename => $filename, error => 'read error' };
            next;
        }
        my $id = 'upl_' . time() . '_' . int(rand(10000));
        $UPLOAD_RECORDS{$id} = {
            id         => $id,
            filename   => $filename,
            original   => $up->filename(),
            size       => $size,
            type       => $type,
            uploaded_at => _now_iso(),
        };
        push @result, {
            id         => $id,
            filename   => $filename,
            size       => $size,
            type       => $type,
            uploaded_at => $UPLOAD_RECORDS{$id}{uploaded_at},
        };
    }
    $c->json({
        uploaded_count => scalar @result,
        files => \@result,
    }, 201);
};

# ---- 업로드 목록 조회 (예제용) ----
get '/api/uploads' => sub {
    my ($c) = @_;
    my @recs = map { $UPLOAD_RECORDS{$_} } sort keys %UPLOAD_RECORDS;
    $c->json({ uploads => \@recs, count => scalar @recs });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 5: 파일 업로드)

=head1 SYNOPSIS

POST /api/upload            단일 파일 업로드 (필드명: file)
POST /api/upload-multiple   여러 파일 업로드 (필드명: files[])
GET  /api/uploads           업로드 기록 조회
GET  /api/ping|healthz|readyz  헬스체크

파일 필드명 규칙:
- 단일: multipart form field name = "file"
- 여러개: "files[]" (Punk은 req->uploads 에서 해시로 제공)

응답 예시 (단일):
{
  "uploaded": {
    "id": "upl_...",
    "filename": "safe_name.txt",
    "size": 123,
    "type": "text/plain",
    "title": "optional title",
    "uploaded_at": "2026-09-15T13:00:00Z"
  }
}

=cut
