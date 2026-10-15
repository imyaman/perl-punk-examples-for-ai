#!/usr/bin/perl
use Test::More;

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
    my ($method, $path, %h) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, '-H', "X-HTTP-Method-Override: $h{ov}" if $h{ov};
    my $out = _raw(@cmd);
    my ($head, $body) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($body // '') };
}
use JSON::PP;
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_full('GET', '/api/ping')->{code}, '200', 'ping 200');

# 기본 POST
is(_json(_full('POST', '/override'))->{method}, 'POST', 'post default');

# override to PUT
is(_json(_full('POST', '/override', ov=>'PUT'))->{method}, 'PUT', 'override PUT');

# override to PATCH
is(_json(_full('POST', '/override', ov=>'PATCH'))->{method}, 'PATCH', 'override PATCH');

# override to DELETE
is(_json(_full('POST', '/override', ov=>'DELETE'))->{method}, 'DELETE', 'override DELETE');

done_testing();
