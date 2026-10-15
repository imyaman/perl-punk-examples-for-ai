package Daeha;

use Punk;
use JSON::PP;
use MIME::Base64 ();

# ---- 사용자 저장소 (데모) ----
my %USERS = (
    'alice' => 'pass123',
    'bob'   => 'hunter2',
);

sub _challenge {
    my ($c, $msg) = @_;
    $c->header('WWW-Authenticate' => 'Basic realm="Daeha"');
    return $c->json({ error => $msg }, 401);
}

# ---- HTTP Basic 인증 가드 ----
my $basic = sub {
    my ($c) = @_;
    my $h = $c->req->header('authorization') // '';
    my ($b64) = $h =~ /^Basic\s+(\S+)\s*$/i;
    return _challenge($c, 'missing basic credentials') unless defined $b64;

    my $dec = eval { MIME::Base64::decode_base64($b64) };
    return _challenge($c, 'malformed credentials')
        unless defined $dec && $dec =~ /:/;

    my ($user, $pass) = split /:/, $dec, 2;
    return _challenge($c, 'invalid credentials')
        unless exists $USERS{$user} && $USERS{$user} eq $pass;

    $c->stash->{user} = $user;
    return;
};

# ---- 헬스체크 (기준선, 공개) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 보호 구역 ----
my $priv = under '/api/basic' => $basic;

$priv->get('/me' => sub {
    my ($c) = @_;
    $c->json({ user => $c->stash->{user} });
});

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 20: HTTP Basic 인증)

=head1 SYNOPSIS

GET /api/basic/me   Authorization: Basic base64(user:pass)
GET /api/ping|healthz|readyz  헬스체크(공개)

사용자: alice/pass123, bob/hunter2

=cut
