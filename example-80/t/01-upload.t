#!/usr/bin/perl
use Test::More;
use JSON::PP;
use Digest::SHA qw(sha256_hex);

my $BASE = 'http://127.0.0.1:3004';
my $TMP  = '/tmp/daeha-upl-test-$$';
$TMP =~ s/\$\$/$$/;
mkdir $TMP unless -d $TMP;

sub _write {
    my ($name, $bytes) = @_;
    my $p = "$TMP/$name";
    open(my $fh, '>', $p) or die "$p: $!";
    binmode $fh;
    print {$fh} $bytes;
    close $fh;
    return $p;
}

my $CONTENT = "hello upload\nsecond line\n";
my $good    = _write('ok.txt', $CONTENT);
my $trav    = _write('trav.txt', "traversal\n");
my $exe     = _write('evil.exe', "MZ binary\n");
my $empty   = _write('empty.txt', '');
my $big     = _write('big.txt', 'x' x (70 * 1024));

sub _raw {
    my @cmd = @_;
    my $out = '';
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm(20);
        open(my $fh, "-|", @cmd) or die "open pipe: @cmd: $!";
        { local $/; $out = <$fh>; }
        close $fh;
        alarm(0);
    };
    return $@ ? '' : $out;
}
sub _req {
    my ($method, $path, @form) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, @form;
    my $out = _raw(@cmd);
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    my %hdr;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $hdr{lc $1} = $2;
    }
    return { code => $code, headers => \%hdr, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_req('GET', '/api/ping')->{code}, '200', 'ping 200');

# 정상 업로드
my $fid;
{
    my $r = _req('POST', '/files', "-F", "file=\@$good;type=text/plain", "-F", "note=hello");
    is($r->{code}, '201', 'upload 201');
    my $d = _json($r);
    $fid = $d->{id};
    is($d->{filename}, 'ok.txt', 'filename');
    is($d->{size}, length($CONTENT), 'size');
    is($d->{sha256}, sha256_hex($CONTENT), 'sha256');
    is($d->{type}, 'text/plain', 'content type');
    is($d->{note}, 'hello', 'note field');
    is($r->{headers}{location}, "/files/$fid", 'Location');
}

# 메타데이터
{
    my $d = _json(_req('GET', "/files/$fid/meta"));
    is($d->{id}, $fid, 'meta id');
    is($d->{size}, length($CONTENT), 'meta size');
    is($d->{note}, 'hello', 'meta note');
}

# 내용 조회
{
    my $r = _req('GET', "/files/$fid");
    is($r->{code}, '200', 'get 200');
    is($r->{body}, $CONTENT, 'content round-trip');
    is($r->{headers}{'content-type'}, 'text/plain', 'served content type');
    is($r->{headers}{etag}, '"' . sha256_hex($CONTENT) . '"', 'etag is sha256');
}

# 목록
{
    my $d = _json(_req('GET', '/files'));
    is($d->{count}, 1, 'one file listed');
}

# 경로 조작 방어
{
    my $r = _req('POST', '/files', "-F", "file=\@$trav;filename=../../evil.txt;type=text/plain");
    is($r->{code}, '201', 'traversal upload 201');
    is(_json($r)->{filename}, 'evil.txt', 'path stripped');
}

# 허용하지 않는 확장자
is(_req('POST', '/files', "-F", "file=\@$exe")->{code}, '415', 'bad extension 415');

# 빈 파일
is(_req('POST', '/files', "-F", "file=\@$empty")->{code}, '400', 'empty file 400');

# 크기 초과
{
    my $r = _req('POST', '/files', "-F", "file=\@$big");
    is($r->{code}, '413', 'oversized 413');
    like(_json($r)->{detail}, qr/max/, 'problem detail');
}

# file 파트 없음
is(_req('POST', '/files', "-F", "note=only")->{code}, '400', 'no file part 400');

# 없는 파일
is(_req('GET', '/files/f-9999')->{code}, '404', 'missing file 404');
is(_req('GET', '/files/f-9999/meta')->{code}, '404', 'missing meta 404');

done_testing();
