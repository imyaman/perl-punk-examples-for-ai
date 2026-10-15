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
    my ($method, $path, %h) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, '-H', "Idempotency-Key: $h{idem}" if $h{idem};
    push @cmd, '-H', 'Content-Type: application/json';
    push @cmd, '--data-raw', '{}' if $method eq 'POST';
    my $out = _raw(@cmd);
    my ($head, $body) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    my %hdr;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $hdr{lc $1} = $2;
    }
    return { code => $code, headers => \%hdr, body => ($body // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_full('GET', '/api/ping')->{code}, '200', 'ping 200');

# 키 없음 400
is(_full('POST', '/charge')->{code}, '400', 'missing key 400');

# 최초 생성
my $r1 = _full('POST', '/charge', idem => 'key-1');
is($r1->{code}, '201', 'first 201');
is($r1->{headers}{'idempotent-replayed'} // '', 'false', 'first not replayed');
my $b1 = _json($r1);
ok($b1->{charge_id}, 'has charge_id');

# 재전송 - 캐시 재생
my $r2 = _full('POST', '/charge', idem => 'key-1');
is($r2->{code}, '201', 'replay 201');
is($r2->{headers}{'idempotent-replayed'} // '', 'true', 'replayed');
is(_json($r2)->{charge_id}, $b1->{charge_id}, 'same charge_id');

# 다른 키는 새로 생성
my $r3 = _full('POST', '/charge', idem => 'key-2');
is($r3->{code}, '201', 'different key 201');
isnt(_json($r3)->{charge_id}, $b1->{charge_id}, 'different id');

done_testing();
