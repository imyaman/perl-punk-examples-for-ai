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
sub _full {
    my ($method, $path, $body) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, '-H', 'Content-Type: application/json' if defined $body;
    push @cmd, '--data-raw', $body if defined $body;
    my $out = _raw(@cmd);
    my ($head, $body2) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    my %h;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { code => $code, headers => \%h, body => ($body2 // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_full('GET', '/api/ping')->{code}, '200', 'ping 200');

# 미존재 GET 404
is(_full('GET', '/kv/foo')->{code}, '404', 'get missing 404');

# POST 생성 201 + Location
{
    my $r = _full('POST', '/kv/foo', '{"value":"bar"}');
    is($r->{code}, '201', 'create 201');
    like($r->{headers}{location} // '', qr{/kv/foo}, 'Location header');
    is(_json($r)->{value}, 'bar', 'created value');
}

# GET 200
{
    my $r = _full('GET', '/kv/foo');
    is($r->{code}, '200', 'get 200');
    is(_json($r)->{value}, 'bar', 'get value');
}

# PUT 갱신 200
{
    my $r = _full('PUT', '/kv/foo', '{"value":"baz"}');
    is($r->{code}, '200', 'put 200');
    is(_json($r)->{value}, 'baz', 'updated value');
}

# 목록
{
    my $r = _full('GET', '/kv');
    is($r->{code}, '200', 'list 200');
    is(_json($r)->{count}, 1, 'count 1');
}

# DELETE 204, body empty
{
    my $r = _full('DELETE', '/kv/foo');
    is($r->{code}, '204', 'delete 204');
    is($r->{body}, '', '204 empty body');
}

# DELETE 없는 키 404
is(_full('DELETE', '/kv/foo')->{code}, '404', 'delete missing 404');

done_testing();
