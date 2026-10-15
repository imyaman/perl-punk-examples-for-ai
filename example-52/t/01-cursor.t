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
sub _get {
    my ($path) = @_;
    my $out = _raw('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_get('/api/ping')->{code}, '200', 'ping 200');

# 첫 페이지
my $d = _json(_get('/feed?limit=10'));
is(scalar @{ $d->{items} }, 10, '10 items');
is($d->{items}[0]{id}, 1, 'starts at 1');
is($d->{items}[9]{id}, 10, 'ends at 10');
ok($d->{next_cursor}, 'has next_cursor');

# 두번째 페이지
my $d2 = _json(_get('/feed?limit=10&cursor=' . $d->{next_cursor}));
is($d2->{items}[0]{id}, 11, 'second page starts 11');
is($d2->{items}[9]{id}, 20, 'second page ends 20');

# 마지막 페이지: next_cursor 없음
{
    my $cur = '';
    my $last;
    my $pages = 0;
    my $first = _json(_get('/feed?limit=10'));
    my @all = @{ $first->{items} };
    my $c = $first->{next_cursor};
    while ($c) {
        my $p = _json(_get("/feed?limit=10&cursor=$c"));
        push @all, @{ $p->{items} };
        $c = $p->{next_cursor};
        $pages++;
        last if $pages > 20;
    }
    is(scalar @all, 100, 'all 100 items across pages');
    is($all[-1]{id}, 100, 'last id 100');
}

# 잘못된 커서
{
    my $r = _get('/feed?cursor=not-base64!!');
    is($r->{code}, '400', 'invalid cursor 400');
}

done_testing();
