package Daeha;

use Punk;
use JSON::PP;
use Digest::SHA qw(sha256_hex);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my $MAX   = 64 * 1024;                          # 최대 업로드 크기
my %ALLOW = map { $_ => 1 } qw(txt csv json md); # 허용 확장자
my $DIR   = $ENV{DAEHA_UPLOAD_DIR} // '/tmp/daeha-uploads';
mkdir $DIR unless -d $DIR;

my %FILES;   # id => { id, filename, type, size, note, sha256, path }
my $SEQ = 0;

sub _problem {
    my ($c, $status, $title, $detail) = @_;
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({ type => 'about:blank', title => $title, status => $status,
                      detail => $detail }, $status);
}

# 클라이언트가 준 파일명은 절대 경로가 아니다. 경로 조작을 막고 안전한 이름으로 바꾼다.
sub _safe_name {
    my ($name) = @_;
    $name //= '';
    $name =~ s{^.*[/\\]}{};                    # 디렉터리 부분 제거
    $name =~ s/[^A-Za-z0-9._-]/_/g;           # 위험 문자 치환
    $name = 'file' unless length $name;
    return $name;
}

post '/files' => sub {
    my ($c) = @_;
    my $up = $c->req->upload('file');
    return _problem($c, 400, 'Bad Request', "multipart field 'file' is required") unless $up;

    my $size = $up->size;
    return _problem($c, 413, 'Payload Too Large', "max $MAX bytes") if $size > $MAX;
    return _problem($c, 400, 'Bad Request', 'file is empty')       if $size == 0;

    my ($ext) = $up->filename =~ /\.([A-Za-z0-9]+)$/;
    $ext = lc($ext // '');
    return _problem($c, 415, 'Unsupported Media Type', "extension '$ext' is not allowed")
        unless $ALLOW{$ext};

    my $safe  = _safe_name($up->filename);
    my $pnote = $c->param('note');
    my $note  = defined $pnote ? "$pnote" : undef;

    $SEQ++;
    my $id   = sprintf('f-%04d', $SEQ);
    my $path = "$DIR/$id-$safe";
    $up->save($path);

    $FILES{$id} = {
        id       => $id,
        filename => $safe,
        type     => $up->type,
        size     => $size,
        note     => $note,
        sha256   => sha256_hex($up->content),
        path     => $path,
    };

    $c->header('Location' => "/files/$id");
    return $c->json({
        id => $id, filename => $safe, type => $up->type,
        size => $size, sha256 => $FILES{$id}{sha256}, note => $note,
    }, 201);
};

get '/files' => sub {
    my ($c) = @_;
    my @out = map {
        +{ id => $_->{id}, filename => $_->{filename}, size => $_->{size}, type => $_->{type} }
    } map { $FILES{$_} } sort keys %FILES;
    return $c->json({ count => scalar @out, files => \@out });
};

get '/files/:id/meta' => sub {
    my ($c) = @_;
    my $f = $FILES{$c->param('id')};
    return _problem($c, 404, 'Not Found', 'unknown file') unless $f;
    return $c->json({ id => $f->{id}, filename => $f->{filename}, type => $f->{type},
                      size => $f->{size}, sha256 => $f->{sha256}, note => $f->{note} });
};

get '/files/:id' => sub {
    my ($c) = @_;
    my $f = $FILES{$c->param('id')};
    return _problem($c, 404, 'Not Found', 'unknown file') unless $f;

    open(my $fh, '<', $f->{path}) or return _problem($c, 500, 'Internal Server Error', 'read failed');
    local $/;
    my $data = <$fh>;
    close $fh;

    my $res = $c->res;
    $res->status(200);
    $res->type($f->{type});
    $res->header('ETag' => "\"$f->{sha256}\"");
    $res->body($data);
    return $res;
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 80: multipart 파일 업로드)

=head1 SYNOPSIS

POST /files            multipart 업로드(확장자/크기/빈 파일 검증)
GET  /files[/:id]      목록/내용/메타데이터

=cut
