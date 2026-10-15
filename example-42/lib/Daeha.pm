package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- METHOD OVERRIDE (X-HTTP-Method-Override) ----
any '/override' => sub {
    my ($c) = @_;
    my $m = $c->req->header('x-http-method-override') // $c->req->method;
    $m = uc($m);
    if ($m eq 'PATCH') {
        return $c->json({ method => 'PATCH', via => 'override' });
    }
    if ($m eq 'PUT') {
        return $c->json({ method => 'PUT', via => 'override' });
    }
    if ($m eq 'DELETE') {
        return $c->json({ method => 'DELETE', via => 'override' });
    }
    return $c->json({ method => $m });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 42: X-HTTP-Method-Override)

=head1 SYNOPSIS

POST /override?method= (미지원) 대신 X-HTTP-Method-Override 헤더로 PUT/PATCH/DELETE 흉내

=cut
