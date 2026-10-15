package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 정보 (GET/HEAD/OPTIONS) ----
any '/info' => sub {
    my ($c) = @_;
    my $m = $c->req->method // '';
    if ($m eq 'OPTIONS') {
        $c->header('Allow' => 'GET, HEAD, OPTIONS');
        return $c->text('');
    }
    if ($m eq 'HEAD') {
        $c->status(200);
        return $c->text('');
    }
    # GET
    return $c->json({ version => '1.0', env => 'dev' });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 37: HEAD & OPTIONS)

=head1 SYNOPSIS

GET     /info  정보(JSON)
HEAD    /info  같은 헤더, 빈 본문
OPTIONS /info  허용 메서드
GET /api/ping|healthz|readyz

=cut
