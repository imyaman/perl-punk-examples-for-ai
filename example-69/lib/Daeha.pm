package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

sub _bad {
    my ($c, $status, $detail) = @_;
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({ type=>'about:blank', title=>'Unprocessable Entity', status=>$status, detail=>$detail }, $status);
}

# "1.235" 같은 십진 문자열 -> 정수 센트 (반올림 round-half-up)
sub _to_cents {
    my ($s) = @_;
    return undef unless defined $s;
    $s =~ s/^\s+|\s+$//g;
    return undef unless $s =~ /^(-?)(\d+)(?:\.(\d*))?$/;
    my ($neg, $int, $frac) = ($1, $2, $3);
    $frac = '' unless defined $frac;
    my $fr = substr($frac . '00', 0, 3);       # 소수 3자리 확보
    my $cents = int($int) * 100 + int(substr($fr, 0, 2));
    $cents++ if substr($fr, 2, 1) ge '5';
    $cents = -$cents if $neg eq '-';
    return $cents;
}

# "7.5"(퍼센트) -> 만분율 정수 bp (750)
sub _rate_bp {
    my ($r) = @_;
    return undef unless defined $r;
    $r =~ s/^\s+|\s+$//g;
    return undef unless $r =~ /^(\d+)(?:\.(\d*))?$/;
    my $frac = defined $2 ? $2 : '';
    my $fr = substr($frac . '00', 0, 2);
    return int($1) * 100 + int($fr);
}

sub _tax_cents {                 # 반올림 round-half-up
    my ($cents, $bp) = @_;
    return int(($cents * $bp + 5000) / 10000);
}

sub _fmt {                       # 센트 -> "-12.34"
    my ($c) = @_;
    my $n = $c < 0 ? -$c : $c;
    return sprintf('%s%d.%02d', ($c < 0 ? '-' : ''), int($n / 100), $n % 100);
}

post '/compute' => sub {
    my ($c) = @_;
    my $b = eval { $c->req->json };
    return _bad($c, 400, q{malformed JSON}) if $@;
    return _bad($c, 400, q{JSON object expected}) unless ref $b eq q{HASH};

    my $cents = _to_cents($b->{amount});
    return _bad($c, 422, 'amount must be a decimal number') unless defined $cents;
    my $bp = _rate_bp($b->{tax_rate});
    return _bad($c, 422, 'tax_rate must be a percent') unless defined $bp;

    my $tax = _tax_cents($cents, $bp);
    my $total = $cents + $tax;

    return $c->json({
        amount_cents   => $cents,
        tax_rate       => $b->{tax_rate},
        tax_cents      => $tax,
        total_cents    => $total,
        amount_formatted   => _fmt($cents),
        tax_formatted      => _fmt($tax),
        total_formatted    => _fmt($total),
        currency       => 'USD',
    });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 69: 금액 계산 (정수 센트))

=head1 SYNOPSIS

POST /compute {amount, tax_rate}  부동소수점 없이 정수 센트로 계산, 반올림 규칙 명시

=cut
