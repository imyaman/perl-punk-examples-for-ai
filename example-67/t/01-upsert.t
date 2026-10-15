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
    my ($method, $path, $body) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, '-H', 'Content-Type: application/json';
    push @cmd, '--data-raw', $body if defined $body;
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
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_req('GET','/api/ping')->{code}, '200', 'ping 200');

# 최초 PUT -> 201
my $u = { id => 900, name => 'Alice', email => 'a@ex.com' };
{
    my $r = _req('PUT', '/users/900', JSON::PP->new->encode($u));
    is($r->{code}, '201', 'create 201');
    like($r->{headers}{location} // '', qr{/users/900}, 'location');
    is(_json($r)->{name}, 'Alice', 'name');
}

# 같은 id PUT -> 200 (대체)
{
    my $u2 = { id => 900, name => 'Alicia', email => 'b@ex.com' };
    my $r = _req('PUT', '/users/900', JSON::PP->new->encode($u2));
    is($r->{code}, '200', 'replace 200');
    is(_json($r)->{name}, 'Alicia', 'replaced');
}

# GET 확인
is(_json(_req('GET', '/users/900'))->{email}, 'b@ex.com', 'persisted');

# 검증 실패 -> 422
{
    my $r = _req('PUT', '/users/901', '{"name":"x"}');
    is($r->{code}, '422', 'invalid 422');
    like(_json($r)->{title} // '', qr/Unprocessable/, 'problem title');
}

# id 비정상 -> 400
is(_req('PUT', '/users/0', '{}')->{code}, '400', 'bad id 400');

# 삭제 -> 204, 이후 404
is(_req('DELETE', '/users/900')->{code}, '204', 'delete 204');
is(_req('GET', '/users/900')->{code}, '404', 'gone 404');

done_testing();
