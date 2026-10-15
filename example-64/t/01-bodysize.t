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
sub _post {
    my ($body, %h) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', 'POST',
               '-H', 'Content-Type: application/json', "$BASE/submit");
    push @cmd, '-H', 'Transfer-Encoding: chunked' if $h{chunked};
    push @cmd, '--data-raw', $body;
    my $out = _raw(@cmd);
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_raw('curl','-s','-o','/dev/null','-w','%{http_code}',"$BASE/api/ping") eq '200' ? 1 : 0, 1, 'ping');

# 작은 본문
{
    my $r = _post('{"a":1}');
    is($r->{code}, '200', 'small 200');
    is(_json($r)->{data}{a}, 1, 'data echoed');
}

# 한계 근처 (작게 통과)
{
    my $body = '{"x":"' . ('a' x 100) . '"}';
    is(length($body) < 1024 ? 1 : 0, 1, 'sanity body under limit');
    my $r = _post($body);
    is($r->{code}, '200', 'under limit 200');
}

# 초과 -> 413
{
    my $body = '{"x":"' . ('a' x 2000) . '"}';
    my $r = _post($body);
    is($r->{code}, '413', 'over limit 413');
    like(_json($r)->{title} // '', qr/Payload Too Large/, 'problem title');
}

# chunked 초과 -> 413 (Content-Length 없음 -> 본문 길이 검사 경로)
{
    my $body = '{"x":"' . ('b' x 2000) . '"}';
    my $r = _post($body, chunked => 1);
    is($r->{code}, '413', 'chunked over limit 413');
}

# 깨진 JSON (작음) -> 400
{
    is(_post('{bad')->{code}, '400', 'malformed 400');
}

done_testing();
