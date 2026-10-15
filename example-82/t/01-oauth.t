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
sub _run {
    my @cmd = @_;
    my $out = _raw(@cmd);
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my ($code, %h);
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { code => $code, headers => \%h, body => ($b // '') };
}
sub _form {
    my ($path, $body) = @_;
    return _run('curl', '-s', '--max-time', '18', '-i', '-X', 'POST', "$BASE$path", '-d', $body);
}
sub _auth {
    my ($path, $tok) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
    push @cmd, '-H', "Authorization: Bearer $tok" if defined $tok;
    return _run(@cmd);
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_run('curl', '-s', '--max-time', '18', '-i', "$BASE/api/ping")->{code}, '200', 'ping 200');

# 정상 토큰 발급
my $tok_a;
{
    my $r = _form('/oauth/token', 'grant_type=client_credentials&client_id=appA&client_secret=s3cr3t');
    is($r->{code}, '200', 'token 200');
    my $d = _json($r);
    $tok_a = $d->{access_token};
    ok($tok_a, 'access token');
    is($d->{token_type}, 'Bearer', 'token type');
    is($d->{expires_in}, 3600, 'expires_in');
    my %sc = map { $_ => 1 } split / /, $d->{scope};
    ok($sc{read} && $sc{write}, 'default scopes');
}

# 보호 자원 접근
{
    my $r = _auth('/resource/data', $tok_a);
    is($r->{code}, '200', 'resource 200');
    my $d = _json($r);
    is($d->{client}, 'appA', 'client shown');
    is_deeply($d->{data}, [1, 2, 3], 'payload');
}

# scope 요청 (부분집합)
{
    my $r = _form('/oauth/token', 'grant_type=client_credentials&client_id=appA&client_secret=s3cr3t&scope=read');
    is($r->{code}, '200', 'scope subset 200');
    is(_json($r)->{scope}, 'read', 'only read');
}

# appB 는 write 만 -> read 자원 403
{
    my $r = _form('/oauth/token', 'grant_type=client_credentials&client_id=appB&client_secret=b-secret');
    is($r->{code}, '200', 'appB token');
    my $tb = _json($r)->{access_token};

    my $res = _auth('/resource/data', $tb);
    is($res->{code}, '403', 'insufficient scope 403');
    is(_json($res)->{error}, 'insufficient_scope', 'error code');
    like($res->{headers}{'www-authenticate'}, qr/insufficient_scope/, 'WWW-Authenticate');
}

# 허용되지 않은 scope 요청 -> 400 invalid_scope
{
    my $r = _form('/oauth/token', 'grant_type=client_credentials&client_id=appB&client_secret=b-secret&scope=read');
    is($r->{code}, '400', 'invalid scope 400');
    is(_json($r)->{error}, 'invalid_scope', 'invalid_scope');
}

# 잘못된 시크릿 / 없는 클라이언트 -> 401
is(_form('/oauth/token', 'grant_type=client_credentials&client_id=appA&client_secret=nope')->{code}, '401', 'bad secret 401');
is(_form('/oauth/token', 'grant_type=client_credentials&client_id=ghost&client_secret=x')->{code}, '401', 'unknown client 401');

# grant_type 오류 -> 400
is(_form('/oauth/token', 'grant_type=password&client_id=appA&client_secret=s3cr3t')->{code}, '400', 'bad grant 400');
is(_form('/oauth/token', 'client_id=appA&client_secret=s3cr3t')->{code}, '400', 'missing grant 400');

# 토큰 없음/위조 -> 401
{
    my $r = _auth('/resource/data', undef);
    is($r->{code}, '401', 'no token 401');
    is($r->{headers}{'www-authenticate'}, 'Bearer', 'WWW-Authenticate Bearer');
}
is(_auth('/resource/data', 'tok_bogus')->{code}, '401', 'bogus token 401');

# introspection
{
    my $r = _form('/introspect', "token=$tok_a");
    my $d = _json($r);
    ok($d->{active}, 'active token');
    is($d->{client_id}, 'appA', 'introspect client');

    my $bad = _json(_form('/introspect', 'token=tok_bogus'));
    ok(!$bad->{active}, 'inactive token');
}

done_testing();
