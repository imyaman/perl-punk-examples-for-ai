package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

sub _problem {
    my ($c, $status, $title, $detail) = @_;
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({ type => 'about:blank', title => $title, status => $status, detail => $detail }, $status);
}

post '/echo' => sub {
    my ($c) = @_;

    my $ct = $c->req->header('content-type') // '';
    # application/json 또는 application/json; charset=... 허용
    unless ($ct =~ m{^\s*application/json\b}i) {
        return _problem($c, 415, 'Unsupported Media Type', "expected application/json, got '" . $ct . "'");
    }

    my $body = eval { $c->req->json };
    if ($@ || !defined $body) {
        return _problem($c, 400, 'Bad Request', 'malformed JSON body');
    }

    return $c->json({ received => $body, type => ref($body) || 'scalar' });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 54: Content-Type 검사와 415)

=head1 SYNOPSIS

POST /echo  Content-Type: application/json 요구. 아니면 415, 깨진 JSON 이면 400

=cut
