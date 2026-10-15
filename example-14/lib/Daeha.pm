package Daeha;

use Punk;
use JSON::PP;

# ---- helper: 컨텍스트에 메서드 설치 ----
helper now_iso => sub {
    my ($c) = @_;
    my @t = gmtime(time);
    return sprintf '%04d-%02d-%02dT%02d:%02d:%02dZ',
        $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0];
};

helper sum => sub {
    my ($c, @n) = @_;
    my $s = 0;
    $s += $_ for @n;
    return $s;
};

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- helper 사용 ----
get '/api/time' => sub {
    my ($c) = @_;
    $c->json({ now => $c->now_iso, source => 'helper' });
};

get '/api/sum/:a/:b' => sub {
    my ($c) = @_;
    my ($a, $b) = ($c->param('a'), $c->param('b'));
    $c->json({ a => $a, b => $b, sum => $c->sum($a, $b) });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 14: helper 로 컨텍스트 메서드 추가)

=head1 SYNOPSIS

GET /api/time          $c->now_iso 헬퍼 사용
GET /api/sum/:a/:b     $c->sum(...) 헬퍼 사용
GET /api/ping|healthz|readyz  헬스체크

=cut
