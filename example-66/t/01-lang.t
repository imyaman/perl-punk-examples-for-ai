#!/usr/bin/perl
use Test::More;
use utf8;
use JSON::PP;
use Encode qw(decode_utf8 encode_utf8);

my $BASE = 'http://127.0.0.1:3004';

sub _raw {
    my @cmd = @_;
    my $out = '';
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm(15);
        open(my $fh, "-|", @cmd) or die "open pipe: @cmd: $!";
        { local $/; $out = <$fh>; }
        close $fh;
        alarm(0);
    };
    return $@ ? '' : $out;
}
sub _get {
    my ($path, $al) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
    push @cmd, '-H', "Accept-Language: $al" if defined $al;
    my $out = _raw(@cmd);
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    my %h;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { code => $code, headers => \%h, body => ($b // '') };
}
sub _json {
    my $b = shift->{body};
    $b = decode_utf8($b) unless utf8::is_utf8($b);
    return JSON::PP->new->decode($b);
}

is(_get('/api/ping')->{code}, '200', 'ping 200');

# 기본
{
    my $r = _get('/greeting');
    is($r->{code}, '200', 'default 200');
    is(_json($r)->{locale}, 'en', 'default en');
    is($r->{headers}{'content-language'}, 'en', 'Content-Language');
    is($r->{headers}{vary}, 'Accept-Language', 'Vary header');
}

# 한국어
{
    my $r = _get('/greeting', 'ko');
    is(_json($r)->{locale}, 'ko', 'ko');
    is(_json($r)->{message}, '안녕하세요', 'korean message');
}

# q값 우선순위 (en 이 더 높음)
{
    my $r = _get('/greeting', 'ko;q=0.9, en;q=1.0');
    is(_json($r)->{locale}, 'en', 'q-value wins');
}
{
    my $r = _get('/greeting', 'en;q=0.2, ja');
    is(_json($r)->{locale}, 'ja', 'ja by q');
}

# 지역 태그 근본 언어 (ko-KR -> ko)
is(_json(_get('/greeting', 'ko-KR'))->{locale}, 'ko', 'subtag falls back');

# 지원 안 하는 언어 -> 기본값
is(_json(_get('/greeting', 'fr-FR'))->{locale}, 'en', 'unsupported fallback');

# 쿼리 override
{
    my $r = _get('/greeting?lang=ja');
    is(_json($r)->{locale}, 'ja', 'query override');
}
{
    my $r = _get('/greeting?lang=zz');
    is(_json($r)->{locale}, 'en', 'bad override falls back');
}

done_testing();
