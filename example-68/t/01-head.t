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
sub _parse {
    my ($out) = @_;
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
sub _get {
    my ($path) = @_;
    return _parse(_raw('curl', '-s', '--max-time', '18', '-i', "$BASE$path"));
}
sub _head {
    my ($path) = @_;
    my $out = _raw('curl', '-s', '--max-time', '18', '-I', "$BASE$path");
    # -I 는 헤더만 출력한다
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

is(_get('/api/ping')->{code}, '200', 'ping 200');

# GET 기본 페이지
{
    my $r = _get('/things?limit=10');
    is($r->{code}, '200', 'get 200');
    is($r->{headers}{'x-total-count'}, '25', 'total count');
    is(scalar @{ _json($r)->{items} }, 10, '10 items');
    like($r->{headers}{link} // '', qr{rel="next"}, 'has next link');
    like($r->{headers}{link} // '', qr{rel="last"}, 'has last link');
    like($r->{headers}{link} // '', qr{rel="first"}, 'has first link');
}

# 마지막 페이지는 next 없음
{
    my $r = _get('/things?limit=10&page=3');
    is(scalar @{ _json($r)->{items} }, 5, 'last page 5 items');
    unlike($r->{headers}{link} // '', qr{rel="next"}, 'no next on last');
}

# 중간 페이지 올바른 항목
{
    my $d = _json(_get('/things?limit=5&page=2'));
    is($d->{items}[0]{id}, 6, 'page 2 starts at 6');
    is($d->{items}[-1]{id}, 10, 'page 2 ends at 10');
}

# HEAD
{
    my $r = _head('/things?limit=10');
    is($r->{code}, '200', 'head 200');
    is($r->{headers}{'x-total-count'}, '25', 'head total count');
    ok(exists $r->{headers}{link}, 'head Link');
    is($r->{body} // '', '', 'head has no body');
}

# HEAD /api/ping
is(_head('/api/ping')->{code}, '200', 'head ping 200');

done_testing();
