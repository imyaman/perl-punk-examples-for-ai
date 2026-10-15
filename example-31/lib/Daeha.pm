package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my @ITEMS = ('alpha', 'beta', 'gamma');

# ---- Accept 헤더로 응답 형식 결정 ----
get '/negotiate' => sub {
    my ($c) = @_;
    my $accept = lc($c->req->header('accept') // '');
    $accept = '*/*' if $accept eq '';

    # 명시적 타입 먼저, 와일드카드는 JSON(API 기본)으로
    if ($accept =~ m{text/html}) {
        return $c->html('<html><body><ul>'
             . join('', map { qq{<li>$_</li>} } @ITEMS)
             . '</ul></body></html>');
    }
    if ($accept =~ m{text/plain}) {
        return $c->text(join("\n", @ITEMS) . "\n");
    }
    if ($accept =~ m{application/json|text/json|\*/\*}) {
        return $c->json({ format => 'json', items => \@ITEMS });
    }
    return $c->json({ error => 'not acceptable', accept => $accept }, 406);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 31: Accept 헤더 콘텐츠 협상)

=head1 SYNOPSIS

GET /negotiate   Accept 에 따라 JSON / HTML / plain 응답
                 (지원되지 않으면 406)
GET /api/ping|healthz|readyz  헬스체크

=cut
