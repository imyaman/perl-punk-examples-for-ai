#!/usr/bin/perl
use Test::More;
use JSON::PP;

my $BASE = 'http://127.0.0.1:3004';

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

sub _req {
    my ($method, $path, $json) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-w', '\n%{http_code}', '-X', $method, "$BASE$path");
    if (defined $json) {
        push @cmd, '-H', 'Content-Type: application/json', '-d', $json;
    }
    return _run(@cmd);
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_req('GET', '/api/ping')->{code}, '200', 'ping 200');

# ---- GET ----
{
    my $d = _json(_req('GET', '/api/item'));
    is($d->{item}{name}, 'widget', 'GET initial name');
    is($d->{item}{qty}, 5, 'GET initial qty');
}

# ---- PATCH (부분 갱신) ----
{
    my $d = _json(_req('PATCH', '/api/item', '{"qty":9}'));
    is($d->{patched}, 1, 'PATCH patched');
    is($d->{item}{qty}, 9, 'PATCH changed qty');
    is($d->{item}{name}, 'widget', 'PATCH left name');
    is_deeply($d->{changed}, ['qty'], 'PATCH changed keys');
}

# ---- PUT (전체 교체) ----
{
    my $d = _json(_req('PUT', '/api/item', '{"name":"gadget","qty":2}'));
    is($d->{replaced}, 1, 'PUT replaced');
    is($d->{item}{name}, 'gadget', 'PUT new name');
    is($d->{item}{qty}, 2, 'PUT new qty');
}

# ---- POST (생성) ----
{
    my $r = _req('POST', '/api/item', '{"name":"gizmo"}');
    is($r->{code}, '201', 'POST 201');
    my $d = _json($r);
    is($d->{created}, 1, 'POST created');
    is($d->{item}{name}, 'gizmo', 'POST new name');
}

# ---- DELETE ----
{
    my $d = _json(_req('DELETE', '/api/item'));
    is($d->{deleted}{name}, 'gizmo', 'DELETE returns prior state');
    my $after = _json(_req('GET', '/api/item'));
    is($after->{item}{name}, 'widget', 'state reset after DELETE');
}

# ---- any: 모든 메서드 ----
{
    is(_json(_req('GET',    '/api/echo'))->{method}, 'GET',    'any GET');
    is(_json(_req('POST',   '/api/echo'))->{method}, 'POST',   'any POST');
    is(_json(_req('PATCH',  '/api/echo'))->{method}, 'PATCH',  'any PATCH');
    is(_json(_req('DELETE', '/api/echo'))->{method}, 'DELETE', 'any DELETE');
}

done_testing();
