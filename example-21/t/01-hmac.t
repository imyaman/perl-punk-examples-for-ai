#!/usr/bin/perl
use Test::More;
use JSON::PP;
use Digest::SHA qw(hmac_sha256_hex);

my $BASE   = 'http://127.0.0.1:3004';
my $SECRET = 'webhook-shared-secret';

sub _run {
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
    if ($@) { return { body => '', code => '000' }; }
    my ($body, $code) = $out =~ /^(.*)\n(\d{3})$/s;
    return { body => ($body // ''), code => ($code // '000') };
}
sub _post {
    my ($path, $body, %hdr) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-w', '\n%{http_code}',
               '--data-raw', $body, "$BASE$path");
    push @cmd, '-H', "$_: $hdr{$_}" for sort keys %hdr;
    _run(@cmd);
}
sub _json { JSON::PP->new->decode(shift->{body}) }
sub _sign { 'sha256=' . hmac_sha256_hex($_[0], $SECRET) }

is(_run('curl','-s','--max-time','18','-w','\n%{http_code}',"$BASE/api/ping")->{code}, '200', 'ping 200');

my $body = '{"event":"deploy"}';

# 서명 없음 -> 401
{
    my $r = _post('/webhook/event', $body);
    is($r->{code}, '401', 'no signature 401');
}

# 잘못된 서명 -> 401
{
    my $r = _post('/webhook/event', $body, 'X-Signature' => 'sha256=deadbeef');
    is($r->{code}, '401', 'bad signature 401');
    is(_json($r)->{error}, 'bad signature', 'bad signature message');
}

# 올바른 서명 -> 200
{
    my $r = _post('/webhook/event', $body, 'X-Signature' => _sign($body));
    is($r->{code}, '200', 'valid signature 200');
    my $d = _json($r);
    is($d->{received}, 1, 'webhook processed');
    is($d->{event}, 'deploy', 'payload parsed');
}

# 본문이 바뀌면 서명도 무효
{
    my $r = _post('/webhook/event', '{"event":"tampered"}', 'X-Signature' => _sign($body));
    is($r->{code}, '401', 'tampered body rejected');
}

done_testing();
