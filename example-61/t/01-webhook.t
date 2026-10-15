#!/usr/bin/perl
use Test::More;
use JSON::PP;
use Digest::SHA qw(hmac_sha256_hex);

my $BASE   = 'http://127.0.0.1:3004';
my $SECRET = 'whsec_demo';

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
    my ($body, $sig) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', 'POST',
               '-H', 'Content-Type: application/json', "$BASE/webhooks/events");
    push @cmd, '-H', "X-Signature: $sig" if defined $sig;
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
sub _sig { 'sha256=' . hmac_sha256_hex($_[0], $SECRET) }

is(_raw('curl','-s','-o','/dev/null','-w','%{http_code}',"$BASE/api/ping") eq '200' ? 1 : 0, 1, 'ping');

my $body = '{"id":"evt_1","type":"paid"}';

# 정상 서명
{
    my $r = _post($body, _sig($body));
    is($r->{code}, '200', 'valid 200');
    is(_json($r)->{received}, 1, 'received');
    is(_json($r)->{duplicate}, 0, 'not duplicate');
}

# 중복 이벤트 (같은 id) -> duplicate
{
    my $r = _post($body, _sig($body));
    is($r->{code}, '200', 'duplicate 200');
    is(_json($r)->{duplicate}, 1, 'flagged duplicate');
}

# 잘못된 서명 -> 401
{
    my $r = _post($body, 'sha256=deadbeef');
    is($r->{code}, '401', 'bad signature 401');
}

# 서명 누락 -> 401
{
    my $r = _post($body, undef);
    is($r->{code}, '401', 'missing signature 401');
}

# 다른 이벤트
{
    my $b2 = '{"id":"evt_2","type":"refund"}';
    my $r = _post($b2, _sig($b2));
    is($r->{code}, '200', 'second event 200');
    my $seen = _json({ body => _raw('curl','-s','--max-time','18',"$BASE/webhooks/seen") });
    ok($seen->{count} >= 2, 'seen at least 2');
}

# 서명은 맞지만 id 없음 -> 400
{
    my $b3 = '{"type":"x"}';
    my $r = _post($b3, _sig($b3));
    is($r->{code}, '400', 'missing id 400');
}

done_testing();
