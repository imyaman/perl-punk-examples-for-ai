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
    my ($path) = @_;
    my $out = _raw('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
    my ($head, $body) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    my %h;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { code => $code, headers => \%h, body => ($body // '') };
}

is(_full('/api/ping')->{code}, '200', 'ping 200');

# 처음 3번은 200
my @codes;
for (1..3) { push @codes, _full('/limited')->{code}; }
is_deeply(\@codes, [200,200,200], 'first 3 allowed');

# 4번째는 429
{
    my $r = _full('/limited');
    is($r->{code}, '429', 'fourth 429');
    ok(defined $r->{headers}{'retry-after'}, 'Retry-After present');
    is($r->{headers}{'x-ratelimit-limit'}, 3, 'limit header');
    like($r->{headers}{'content-type'} // '', qr/problem\+json/, 'problem type');
}

# 남은 횟수 헤더
{
    # 새 윈도우를 기다리지 않고 헤더 형식만 확인 (이미 초과 상태)
    my $r = _full('/limited');
    is($r->{code}, '429', 'still 429 in window');
    is($r->{headers}{'x-ratelimit-remaining'}, 0, 'remaining 0');
}

done_testing();
