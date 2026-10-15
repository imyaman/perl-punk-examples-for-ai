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
sub _post {
    my ($body) = @_;
    my $out = _raw('curl', '-s', '--max-time', '18', '-i', '-X', 'POST',
                   '-H', 'Content-Type: application/json', '--data-raw', $body,
                   "$BASE/compute");
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_raw('curl','-s','-o','/dev/null','-w','%{http_code}',"$BASE/api/ping") eq '200' ? 1 : 0, 1, 'ping');

# 정확한 십진
{
    my $d = _json(_post('{"amount":"1.23","tax_rate":"10"}'));
    is($d->{amount_cents}, 123, '1.23 -> 123 cents');
    is($d->{tax_cents}, 12, '10% of 123 -> 12');
    is($d->{total_cents}, 135, 'total 135');
    is($d->{amount_formatted}, '1.23', 'formatted');
}

# 반올림 half-up
{
    is(_json(_post('{"amount":"1.235","tax_rate":"0"}'))->{amount_cents}, 124, '1.235 -> 124');
    is(_json(_post('{"amount":"1.234","tax_rate":"0"}'))->{amount_cents}, 123, '1.234 -> 123');
    is(_json(_post('{"amount":"0.005","tax_rate":"0"}'))->{amount_cents}, 1,    '0.005 -> 1');
}

# 정수 문자열
is(_json(_post('{"amount":"2","tax_rate":"0"}'))->{amount_cents}, 200, '2 -> 200');

# 소수 퍼센트 세금 7.5%
{
    my $d = _json(_post('{"amount":"10.00","tax_rate":"7.5"}'));
    is($d->{tax_cents}, 75, '7.5% of 1000 -> 75');
    is($d->{total_formatted}, '10.75', 'total 10.75');
}

# 큰 금액 부동소수점 오차 없음: 0.1 + 0.2 문제 회피
{
    my $d = _json(_post('{"amount":"0.10","tax_rate":"0"}'));
    is($d->{total_cents}, 10, '0.10 -> 10 cents exactly');
}

# 잘못된 입력
is(_post('{"amount":"abc","tax_rate":"10"}')->{code}, '422', 'bad amount 422');
is(_post('{"amount":"1.00","tax_rate":"x"}')->{code}, '422', 'bad rate 422');
is(_post('{"amount":"1.00","tax_rate":"10"')->{code}, '400', 'malformed JSON 400');

done_testing();
