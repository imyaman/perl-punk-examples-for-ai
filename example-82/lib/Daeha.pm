package Daeha;

use Punk;
use JSON::PP;
use Digest::SHA qw(sha256_hex);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my %CLIENTS = (
    appA => { secret => 's3cr3t', scopes => ['read', 'write'] },
    appB => { secret => 'b-secret', scopes => ['write'] },
);
my %TOKENS;   # token => { client, scopes, exp }

my $TTL = 3600;

sub _token { 'tok_' . sha256_hex(time() . rand() . $$) }

sub _oauth_error {
    my ($c, $status, $error, $desc) = @_;
    return $c->json({ error => $error, (defined $desc ? (error_description => $desc) : ()) }, $status);
}

sub _bearer {
    my ($c) = @_;
    my ($t) = ($c->req->header('authorization') // '') =~ /^Bearer\s+(\S+)$/i;
    return $t;
}

sub _scope_list {
    my ($s) = @_;
    return () unless defined $s && length $s;
    return grep { length } split /\s+/, $s;
}

# ---- 토큰 발급 (client_credentials) ----
post '/oauth/token' => sub {
    my ($c) = @_;
    return _oauth_error($c, 400, 'unsupported_grant_type')
        unless ($c->param('grant_type') // '') eq 'client_credentials';

    my $cid = $c->param('client_id') // '';
    my $sec = $c->param('client_secret') // '';
    return _oauth_error($c, 401, 'invalid_client')
        unless exists $CLIENTS{$cid} && $CLIENTS{$cid}{secret} eq $sec;

    my @allowed = @{ $CLIENTS{$cid}{scopes} };
    my %allowed = map { $_ => 1 } @allowed;

    my @want = _scope_list($c->param('scope'));
    @want = @allowed unless @want;   # 요청 없으면 허용된 전체

    for my $s (@want) {
        return _oauth_error($c, 400, 'invalid_scope', "not granted: $s")
            unless $allowed{$s};
    }

    my $tok = _token();
    $TOKENS{$tok} = { client => $cid, scopes => [@want], exp => time() + $TTL };

    return $c->json({
        access_token => $tok,
        token_type   => 'Bearer',
        expires_in   => $TTL,
        scope        => join(' ', @want),
    });
};

# ---- 보호 자원 ----
get '/resource/data' => sub {
    my ($c) = @_;
    my $tok = _bearer($c);
    return $c->header('WWW-Authenticate' => 'Bearer')
              ->json({ error => 'invalid_token' }, 401)
        unless defined $tok;

    my $rec = $TOKENS{$tok};
    return $c->header('WWW-Authenticate' => 'Bearer error="invalid_token"')
              ->json({ error => 'invalid_token' }, 401)
        unless $rec;
    return $c->header('WWW-Authenticate' => 'Bearer error="invalid_token"')
              ->json({ error => 'invalid_token' }, 401)
        if $rec->{exp} < time();

    my %has = map { $_ => 1 } @{ $rec->{scopes} };
    return $c->header('WWW-Authenticate' => 'Bearer error="insufficient_scope", scope="read"')
              ->json({ error => 'insufficient_scope' }, 403)
        unless $has{read};

    return $c->json({ data => [1, 2, 3], client => $rec->{client} });
};

# ---- 토큰 introspection ----
post '/introspect' => sub {
    my ($c) = @_;
    my $tok = $c->param('token') // '';
    my $rec = $TOKENS{$tok};
    if (!$rec || $rec->{exp} < time()) {
        return $c->json({ active => JSON::PP::false });
    }
    return $c->json({
        active    => JSON::PP::true,
        client_id => $rec->{client},
        scope     => join(' ', @{ $rec->{scopes} }),
        exp       => $rec->{exp},
    });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 82: OAuth2 client_credentials)

=head1 SYNOPSIS

POST /oauth/token  client_credentials 로 access token 발급
GET  /resource/data  Bearer 토큰 + scope 검사
POST /introspect     토큰 상태 조회

=cut
