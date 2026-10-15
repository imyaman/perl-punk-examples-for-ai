package Daeha;

use Punk;
use JSON::PP;
use Digest::SHA qw(hmac_sha256);
use MIME::Base64 qw(encode_base64url decode_base64url);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my $SECRET = 'jwt-demo-secret';

sub _b64 { encode_base64url($_[0]) }

sub _eq {
    my ($a, $b) = @_;
    return 0 unless defined $a && defined $b && length($a) == length($b);
    my $d = 0;
    $d |= ord(substr($a, $_, 1)) ^ ord(substr($b, $_, 1)) for 0 .. length($a) - 1;
    return $d == 0;
}

sub _issue {
    my ($header, $payload) = @_;
    my $input = _b64(JSON::PP->new->encode($header)) . '.' . _b64(JSON::PP->new->encode($payload));
    my $sig = _b64(hmac_sha256($input, $SECRET));
    return "$input.$sig";
}

sub _verify {
    my ($token) = @_;
    my ($h64, $p64, $s64) = split /\./, ($token // '');
    return undef unless defined $h64 && defined $p64 && defined $s64;
    my $input = "$h64.$p64";
    return undef unless _eq($s64, _b64(hmac_sha256($input, $SECRET)));
    my $payload = eval { JSON::PP->new->decode(decode_base64url($p64)) };
    return undef unless ref $payload eq 'HASH';
    return $payload;
}

sub _unauthorized {
    my ($c, $detail) = @_;
    $c->header('WWW-Authenticate' => 'Bearer');
    return $c->json({ error => 'unauthorized', detail => $detail }, 401);
}

post '/auth/login' => sub {
    my ($c) = @_;
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my $user = defined $b->{user} ? "$b->{user}" : '';
    return $c->json({ error => 'user required' }, 400) unless length $user;

    my $ttl = int($b->{ttl} // 3600);
    $ttl = 1     if $ttl < 1;
    $ttl = 86400 if $ttl > 86400;

    my $now = time();
    my $token = _issue(
        { alg => 'HS256', typ => 'JWT' },
        { sub => $user, iat => $now, exp => $now + $ttl },
    );
    return $c->json({ token => $token, token_type => 'Bearer', expires_in => $ttl }, 201);
};

get '/me' => sub {
    my ($c) = @_;
    my $auth = $c->req->header('authorization') // '';
    my ($token) = $auth =~ /^Bearer\s+(\S+)$/i;
    return _unauthorized($c, 'missing bearer token') unless defined $token;

    my $payload = _verify($token);
    return _unauthorized($c, 'invalid signature') unless $payload;
    return _unauthorized($c, 'token expired') if ($payload->{exp} // 0) < time();

    return $c->json({ sub => $payload->{sub}, exp => $payload->{exp} });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 73: JWT HS256 발급/검증)

=head1 SYNOPSIS

POST /auth/login  HS256 JWT 발급
GET  /me          Authorization: Bearer <jwt> 검증

=cut
