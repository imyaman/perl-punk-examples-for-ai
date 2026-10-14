#!/usr/bin/perl
use Test::More;
use File::Temp qw(tempfile);

use_ok('Daeha');

my $app = Daeha->to_app;
ok($app, "the application compiles to a PSGI coderef");

# ---- 헬프 체크 (기준선 유지) ----
{
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => '/api/ping',
        SERVER_NAME    => 'localhost',
    });
    is($res->[0], 200, "GET /api/ping is 200");
    like(join("", @{$res->[2]}), qr/pong/, "...returns pong");
}

sub _post {
    my ($app, $path, $body) = @_;
    my ($fh, $filename) = tempfile();
    print $fh $body;
    close $fh;
    open my $in, '<', $filename or die "open tempfile: $!";
    my $res = $app->({
        REQUEST_METHOD => 'POST',
        PATH_INFO      => $path,
        CONTENT_TYPE   => 'application/json',
        CONTENT_LENGTH => length($body),
        SERVER_NAME    => 'localhost',
        'psgi.input'   => $in,
    });
    close $in;
    unlink $filename;
    return $res;
}

sub _put {
    my ($app, $path, $body) = @_;
    my ($fh, $filename) = tempfile();
    print $fh $body;
    close $fh;
    open my $in, '<', $filename or die "open tempfile: $!";
    my $res = $app->({
        REQUEST_METHOD => 'PUT',
        PATH_INFO      => $path,
        CONTENT_TYPE   => 'application/json',
        CONTENT_LENGTH => length($body),
        SERVER_NAME    => 'localhost',
        'psgi.input'   => $in,
    });
    close $in;
    unlink $filename;
    return $res;
}

sub _decode_json {
    my ($res) = @_;
    my $raw = join("", @{$res->[2]});
    return eval {
        require JSON::PP;
        JSON::PP->new->decode($raw);
    } || {};
}

# ---- 노트 생성 ----
my $created;
{
    my $res = _post($app, '/api/notes', '{"title":"hello","body":"world"}');
    is($res->[0], 201, "POST /api/notes creates 201");
    my $data = _decode_json($res);
    $created = $data;
    ok($data->{id}, "...returns id");
    is($data->{title}, 'hello', "...title preserved");
    is($data->{body},  'world',  "...body preserved");
    like($data->{created_at}, qr/\d{4}-\d{2}-\d{2}/, "...has created_at");
    like($data->{updated_at}, qr/\d{4}-\d{2}-\d{2}/, "...has updated_at");
}

# ---- 노트 목록 ----
{
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => '/api/notes',
        SERVER_NAME    => 'localhost',
    });
    is($res->[0], 200, "GET /api/notes is 200");
    my $data = _decode_json($res);
    is($data->{count}, 1, "...count is 1");
    is(scalar @{ $data->{notes} }, 1, "...notes array has 1 item");
    is($data->{notes}[0]{title}, 'hello', "...note title match");
}

# ---- 노트 상세 ----
{
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => "/api/notes/$created->{id}",
        SERVER_NAME    => 'localhost',
    });
    is($res->[0], 200, "GET /api/notes/:id is 200");
    my $data = _decode_json($res);
    is($data->{id}, $created->{id}, "...id match");
    is($data->{title}, 'hello', "...title match");
}

# ---- 존재하지 않는 노트 = 404 ----
{
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => '/api/notes/99999',
        SERVER_NAME    => 'localhost',
    });
    is($res->[0], 404, "GET /api/notes/99999 is 404");
    my $data = _decode_json($res);
    is($data->{error}, 'note not found', "...error message");
}

# ---- 갱신 ----
{
    my $res = _put($app, "/api/notes/$created->{id}", '{"title":"updated","body":"new body"}');
    is($res->[0], 200, "PUT /api/notes/:id is 200");
    my $data = _decode_json($res);
    is($data->{title}, 'updated', "...title updated");
    is($data->{body},  'new body', "...body updated");
    like($data->{updated_at}, qr/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/, "...updated_at present");
}

# ---- 갱신 후 목록 재확인 ----
{
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => '/api/notes',
        SERVER_NAME    => 'localhost',
    });
    my $data = _decode_json($res);
    is($data->{notes}[0]{title}, 'updated', "...list reflects update");
    is($data->{count}, 1, "...count still 1");
}

# ---- 삭제 ----
{
    my $res = $app->({
        REQUEST_METHOD => 'DELETE',
        PATH_INFO      => "/api/notes/$created->{id}",
        SERVER_NAME    => 'localhost',
    });
    is($res->[0], 200, "DELETE /api/notes/:id is 200");
    my $data = _decode_json($res);
    is($data->{deleted}, $created->{id}, "...deleted id returned");
}

# ---- 삭제 후 조회 = 404 ----
{
    my $res = $app->({
        REQUEST_METHOD => 'GET',
        PATH_INFO      => "/api/notes/$created->{id}",
        SERVER_NAME    => 'localhost',
    });
    is($res->[0], 404, "GET deleted note is 404");
}

# ---- 잘못된 JSON 바디 = 400 ----
{
    my $res = _post($app, '/api/notes', 'notjson');
    is($res->[0], 400, "POST with bad JSON is 400");
    my $data = _decode_json($res);
    like($data->{error}, qr/invalid JSON/, "...error message");
}

# ---- 빈 바디 (title/body 없음) = 400 ----
{
    my $res = _post($app, '/api/notes', '{}');
    is($res->[0], 400, "POST with empty object is 400");
    my $data = _decode_json($res);
    like($data->{error}, qr/title.*body/i, "...requires title or body");
}

done_testing();
