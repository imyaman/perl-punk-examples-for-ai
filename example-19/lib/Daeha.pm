package Daeha;

use Punk;
use JSON::PP;

# ---- 토큰 저장소 (데모용 인메모리) ----
my %TOKENS = (
    'tok-alice' => { user => 'alice', role => 'admin' },
    'tok-bob'   => { user => 'bob',   role => 'user'  },
);

# ---- Bearer 토큰 가드 ----
my $bearer = sub {
    my ($c) = @_;
    my $h = $c->req->header('authorization') // '';
    my ($tok) = $h =~ /^Bearer\s+(\S+)\s*$/i;
    return $c->json({ error => 'missing bearer token' }, 401) unless defined $tok;
    my $who = $TOKENS{$tok}
        or return $c->json({ error => 'invalid token' }, 401);
    $c->stash->{user} = $who;
    return;
};

# ---- 헬스체크 (기준선, 공개) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 보호 구역 ----
my $priv = under '/api/private' => $bearer;

$priv->get('/me' => sub {
    my ($c) = @_;
    $c->json({ user => $c->stash->{user}{user}, role => $c->stash->{user}{role} });
});

$priv->get('/secret' => sub {
    my ($c) = @_;
    $c->json({ secret => 'the answer is 42' });
});

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 19: Bearer 토큰 인증)

=head1 SYNOPSIS

GET /api/private/me      Authorization: Bearer <token>
GET /api/private/secret  Authorization: Bearer <token>
GET /api/ping|healthz|readyz  헬스체크(공개)

토큰: tok-alice (admin), tok-bob (user)

=cut
