#!/usr/bin/perl
use Test::More;
use JSON::PP;

my $BASE = 'http://127.0.0.1:3015';
my $TMP = "/tmp/ut_$$";
system("mkdir -p $TMP 2>/dev/null");

sub _file {
    my ($name, $content) = @_;
    my $p = "$TMP/$name";
    open my $fh, '>', $p or die "write $p: $!";
    print $fh $content;
    close $fh;
    return $p;
}

sub _curl_upload {
    my ($path, $fields) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18',
        '-w', "\n%{http_code}", '-X', 'POST', "$BASE$path");
    for my $k (sort keys %$fields) {
        my $v = $fields->{$k};
        if ($k eq 'file') {
            push @cmd, '-F', "$k=@" . $v;
        } elsif ($k eq 'files') {
            for my $f (@$v) {
                push @cmd, '-F', "files[]=@" . $f;
            }
        } else {
            push @cmd, '-F', "$k=$v";
        }
    }
    my $raw = `"@cmd" 2>/dev/null`;
    my ($body, $code) = $raw =~ /^(.*)\n(\d{3})$/s;
    return { body => ($body // ''), code => ($code // '000') };
}

sub _curl_get {
    my ($path) = @_;
    my $raw = `curl -s --max-time 12 -w "\n%{http_code}" "$BASE$path" 2>/dev/null`;
    my ($body, $code) = $raw =~ /^(.*)\n(\d{3})$/s;
    return { body => ($body // ''), code => ($code // '000') };
}

sub _json { JSON::PP->new->decode(shift->{body}) }

# ============ 테스트 시작 ============
# 서버는 이미 실행 중이라고 가정 (호출 전 ./chroot-app-restart.sh restart 로 재시작)

# 헬스체크
{
    my $r = _curl_get('/api/ping');
    is($r->{code}, '200', 'ping 200');
    like($r->{body}, qr/ping/, 'ping body');
}

# ---- 단일 업로드: 성공 ----
{
    my $f = _file('hello.txt', "Hello upload\n");
    my $r = _curl_upload('/api/upload', { file => $f, title => 'doc A' });
    unlink $f;
    is($r->{code}, '201', 'single upload 201');
    my $d = _json($r);
    isnt($d->{uploaded}{id}, undef, 'has id');
    is($d->{uploaded}{filename}, 'hello.txt', 'filename');
    is($d->{uploaded}{size}, 13, 'size 13');
    is($d->{uploaded}{type}, 'text/plain', 'type');
    is($d->{uploaded}{title}, 'doc A', 'title');
}

# ---- 단일 업로드: 파일 없음 → 400 ----
{
    my $r = _curl_upload('/api/upload', { title => 'no file' });
    is($r->{code}, '400', 'missing file 400');
    my $d = _json($r);
    is($d->{error}{code}, 'NO_FILE', 'NO_FILE error');
}

# ---- 여러 파일 업로드: 성공 ----
{
    my $f1 = _file('f1.txt', "first\n");
    my $f2 = _file('f2.txt', "second file here\n");
    my $r = _curl_upload('/api/upload-multiple', { files => [$f1, $f2] });
    unlink $f1; unlink $f2;
    is($r->{code}, '201', 'multi upload 201');
    my $d = _json($r);
    is($d->{uploaded_count}, 2, 'count 2');
    is(scalar @{$d->{files}}, 2, 'files 2');
    is($d->{files}[0]{filename}, 'f1.txt', 'first fn');
    is($d->{files}[1]{filename}, 'f2.txt', 'second fn');
    is($d->{files}[0]{size}, 6, 'first size');
    is($d->{files}[1]{size}, 16, 'second size');
}

# ---- 여러 파일 업로드: 필드 없음 → 400 ----
{
    my $r = _curl_upload('/api/upload-multiple', { title => 'no files' });
    is($r->{code}, '400', 'missing files 400');
    my $d = _json($r);
    is($d->{error}{code}, 'NO_FILES', 'NO_FILES error');
}

# ---- 업로드 목록 조회 ----
{
    my $r = _curl_get('/api/uploads');
    is($r->{code}, '200', 'list 200');
    my $d = _json($r);
    is($d->{count}, 3, 'list count 3 (단일1 + 다중2)');
    is(scalar @{$d->{uploads}}, 3, 'list 3 items');
}

# ============ 정리 ============
unlink glob "$TMP/*";
system("rmdir $TMP 2>/dev/null");
done_testing();
