#!/usr/bin/perl
use Test::More;
use JSON::PP;

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
sub _req {
    my ($method, $path, %h) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    if (defined $h{body}) {
        push @cmd, '-H', 'Content-Type: application/json', '--data-raw', $h{body};
    }
    push @cmd, '-H', "Authorization: Bearer $h{token}" if defined $h{token};
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

# 로그인
my ($alice, $bob);
{
    my $r = _req('POST', '/auth/login', body => '{"user":"alice","pass":"alice-pass"}');
    is($r->{code}, '201', 'alice login 201');
    $alice = _json($r)->{token};
    ok($alice, 'alice token');
    is_deeply(_json($r)->{roles}, ['reader'], 'alice roles');

    my $r2 = _req('POST', '/auth/login', body => '{"user":"bob","pass":"bob-pass"}');
    is($r2->{code}, '201', 'bob login 201');
    $bob = _json($r2)->{token};
    is_deeply(_json($r2)->{roles}, ['reader', 'admin'], 'bob roles');
}

# 로그인 실패
is(_req('POST', '/auth/login', body => '{"user":"alice","pass":"wrong"}')->{code}, '401', 'bad pass 401');
is(_req('POST', '/auth/login', body => '{"user":"nobody","pass":"x"}')->{code}, '401', 'unknown user 401');
is(_req('POST', '/auth/login', body => '{}')->{code}, '401', 'empty body 401');

# public: 인증 불필요
is(_req('GET', '/resource/public')->{code}, '200', 'public 200');

# reader: 토큰 없음 -> 401 (WWW-Authenticate)
{
    my $r = _req('GET', '/resource/reader');
    is($r->{code}, '401', 'reader no token 401');
    is($r->{headers}{'www-authenticate'}, 'Bearer', 'WWW-Authenticate');
}
# 알 수 없는 토큰 -> 401
is(_req('GET', '/resource/reader', token => 'bogus-token')->{code}, '401', 'bad token 401');

# reader: 권한 있는 사용자
{
    my $r = _req('GET', '/resource/reader', token => $alice);
    is($r->{code}, '200', 'alice reader 200');
    is(_json($r)->{scope}, 'reader', 'scope reader');
}
# admin 도 reader 자원 접근 가능
is(_req('GET', '/resource/reader', token => $bob)->{code}, '200', 'bob reader 200');

# admin: 권한 없음 -> 403 + required_role
{
    my $r = _req('GET', '/resource/admin', token => $alice);
    is($r->{code}, '403', 'alice admin 403');
    is(_json($r)->{title}, 'Forbidden', 'title Forbidden');
    is(_json($r)->{status}, 403, 'problem status 403');
    is(_json($r)->{required_role}, 'admin', 'required_role');
    is($r->{headers}{'content-type'}, 'application/problem+json', 'problem+json');
}
# admin 자원, 토큰 없이 -> 401 (403 이 아니라 인증이 먼저)
is(_req('GET', '/resource/admin')->{code}, '401', 'admin no token 401');

# admin: 권한 있음
{
    my $r = _req('GET', '/resource/admin', token => $bob);
    is($r->{code}, '200', 'bob admin 200');
}

# /account/me
is(_req('GET', '/account/me')->{code}, '401', 'me no token 401');
{
    my $r = _req('GET', '/account/me', token => $alice);
    is($r->{code}, '200', 'me 200');
    is_deeply(_json($r)->{roles}, ['reader'], 'me roles');
}

done_testing();
