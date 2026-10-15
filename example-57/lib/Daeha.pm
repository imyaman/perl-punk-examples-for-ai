package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

sub _gen_rid {
    my @c = ('0' .. '9', 'a' .. 'f');
    join '', map { $c[rand @c] } 1 .. 32;
}

hook before_dispatch => sub {
    my ($c) = @_;
    my $rid = $c->req->header('x-request-id');
    $rid = _gen_rid() unless defined $rid && $rid =~ /^[\x21-\x7e]{1,100}$/;
    $c->stash->{request_id} = $rid;
    $c->header('X-Request-Id' => $rid);
    return;
};

get '/whoami' => sub {
    my ($c) = @_;
    return $c->json({ request_id => $c->stash->{request_id} });
};

get '/echo' => sub {
    my ($c) = @_;
    return $c->json({
        request_id => $c->stash->{request_id},
        path       => $c->req->path,
    });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 57: 요청 ID / 상관관계)

=head1 SYNOPSIS

모든 응답에 X-Request-Id 부여(들어온 값이 유효하면 그대로 사용)

=cut
