#!/usr/bin/perl
use Test::More;
use JSON::PP;

my $BASE = 'http://127.0.0.1:3004';
my $TMP  = "/tmp/daeha-csv-test-$$";
mkdir $TMP unless -d $TMP;

sub _write {
    my ($name, $bytes) = @_;
    my $p = "$TMP/$name";
    open(my $fh, '>', $p) or die "$p: $!";
    binmode $fh; print {$fh} $bytes; close $fh;
    return $p;
}

my $CSV = <<'CSV';
name,price
"Widget, large",19.99
Gadget,5
,9.99
Thing,abc
"Say ""hi""",3.5
CSV

my $good   = _write('good.csv', $CSV);
my $badhdr = _write('badhdr.csv', "name\nfoo\n");
my $hdr    = _write('hdr.csv', "name,price\n");
my $empty  = _write('empty.csv', '');
my $txt    = _write('note.txt', "name,price\nx,1\n");

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
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_req('GET', '/api/ping')->{code}, '200', 'ping 200');

# 정상 가져오기
{
    my $d = _json(_req('POST', '/import', '-F', "file=\@$good"));
    is($d->{imported}, 3, 'three imported');
    is($d->{skipped}, 2, 'two skipped');
    is(scalar @{ $d->{errors} }, 2, 'two errors');
    is($d->{errors}[0]{line}, 4, 'error line 4');
    like($d->{errors}[0]{error}, qr/name/, 'name error');
    is($d->{errors}[1]{line}, 5, 'error line 5');
    like($d->{errors}[1]{error}, qr/price/, 'price error');
    is($d->{total}, 3, 'total 3');
}

# 적재 결과와 인용 처리 확인
{
    my $d = _json(_req('GET', '/records'));
    is($d->{count}, 3, 'records count');
    my ($w) = grep { $_->{name} eq 'Widget, large' } @{ $d->{records} };
    ok($w, 'quoted comma name');
    is($w->{price}, 19.99, 'price value');
    my ($s) = grep { $_->{name} eq 'Say "hi"' } @{ $d->{records} };
    ok($s, 'escaped quotes name');
    is($s->{price}, 3.5, 'escaped quotes price');
}

# 헤더만 있는 CSV
{
    my $d = _json(_req('POST', '/import', '-F', "file=\@$hdr"));
    is($d->{imported}, 0, 'header only imports 0');
    is($d->{total}, 3, 'total unchanged');
}

# 열 누락
is(_req('POST', '/import', '-F', "file=\@$badhdr")->{code}, '422', 'missing column 422');

# 빈 파일
is(_req('POST', '/import', '-F', "file=\@$empty")->{code}, '400', 'empty csv 400');

# file 파트 없음
is(_req('POST', '/import', '-F', 'x=1')->{code}, '400', 'no file 400');

# 확장자 거부
is(_req('POST', '/import', '-F', "file=\@$txt")->{code}, '415', 'non-csv 415');

done_testing();
