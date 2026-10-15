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
    my ($method, $path, $tenant, $body) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, '-H', "X-Tenant-Id: $tenant" if defined $tenant;
    if (defined $body) {
        push @cmd, '-H', 'Content-Type: application/json', '--data-raw', $body;
    }
    my $out = _raw(@cmd);
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_req('GET','/api/ping')->{code}, '200', 'ping 200');

is(_req('GET', '/tasks')->{code}, '400', 'no tenant 400');

my $aid;
{
    my $r = _req('POST', '/tasks', 'tenant-a', '{"title":"a-task"}');
    is($r->{code}, '201', 'A create 201');
    $aid = _json($r)->{id};
}

{
    my $d = _json(_req('GET', '/tasks', 'tenant-b'));
    is(scalar @{ $d->{items} }, 0, 'B isolated');
}

is(_req('GET', "/tasks/$aid", 'tenant-b')->{code}, '404', 'cross-tenant 404');
{
    my $r = _req('GET', "/tasks/$aid", 'tenant-a');
    is($r->{code}, '200', 'A can read own');
    is(_json($r)->{title}, 'a-task', 'title ok');
}
{
    my $d = _json(_req('GET', '/tasks', 'tenant-a'));
    is(scalar @{ $d->{items} }, 1, 'A has one');
    is($d->{tenant}, 'tenant-a', 'tenant echoed');
}
is(_req('GET', '/tasks', 'Bad Tenant!')->{code}, '400', 'invalid tenant 400');

done_testing();
