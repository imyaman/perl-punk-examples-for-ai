package Daeha;

use Punk;
use JSON::PP;
use Digest::SHA qw(sha256_hex hmac_sha256_hex);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my %KEYS = (
    keyA => 'secret-A',
    keyB => 'secret-B',
);
my %NONCE;              # "key:nonce" => ts   (재전송 방지)
my $WINDOW = 300;       # 허용 시계 오차(초)

sub _sign {
    my ($secret, $method, $path, $ts, $nonce, $body) = @_;
    my $canon = join("\n", $method, $path, $ts, $nonce, sha256_hex(defined $body ? $body : ''));
    return hmac_sha256_hex($canon, $secret);
}

sub _prune { my $now = time; for my $k (keys %NONCE) { delete $NONCE{$k} if $now - $NONCE{$k} > $WINDOW } }

# 성공 시 (key, 0) / 실패 시 (undef, [status, code, detail])
sub _verify {
    my ($c) = @_;
    my $key = $c->req->header('x-api-key');
    my $ts  = $c->req->header('x-timestamp');
    my $nonce = $c->req->header('x-nonce');
    my $sig = $c->req->header('x-signature');

    return (undef, [401, 'missing_signature', 'X-Api-Key/X-Timestamp/X-Nonce/X-Signature required'])
        unless defined $key && defined $ts && defined $nonce && defined $sig;
    return (undef, [401, 'unknown_key', 'unknown api key']) unless exists $KEYS{$key};
    return (undef, [401, 'timestamp_invalid', 'timestamp is not numeric']) unless $ts =~ /^\d+$/;

    my $skew = time() - $ts;
    return (undef, [401, 'timestamp_expired', "timestamp outside +-$WINDOW seconds"])
        if $skew > $WINDOW || $skew < -$WINDOW;

    my $expect = _sign($KEYS{$key}, $c->req->method, $c->req->path, $ts, $nonce, $c->req->body);
    return (undef, [401, 'bad_signature', 'signature mismatch']) unless $expect eq $sig;

    _prune();
    my $nkey = "$key:$nonce";
    return (undef, [409, 'replay', 'nonce already used']) if $NONCE{$nkey};
    $NONCE{$nkey} = time();

    return ($key, 0);
}

my %TITLE = (
    missing_signature => 'Unauthorized',
    unknown_key       => 'Unauthorized',
    timestamp_invalid => 'Unauthorized',
    timestamp_expired => 'Unauthorized',
    bad_signature     => 'Unauthorized',
    replay            => 'Conflict',
);

sub _guarded {
    my ($c, $cb) = @_;
    my ($key, $err) = _verify($c);
    if ($err) {
        my ($status, $code, $detail) = @$err;
        $c->header('Content-Type' => 'application/problem+json');
        return $c->json({ type => 'about:blank', title => ($TITLE{$code} // 'Error'),
                          status => $status, error => $code, detail => $detail }, $status);
    }
    return $cb->($key);
}

get '/resource' => sub {
    my ($c) = @_;
    return _guarded($c, sub { my ($key) = @_; return $c->json({ ok => 1, key => $key }) });
};

post '/resource' => sub {
    my ($c) = @_;
    return _guarded($c, sub {
        my ($key) = @_;
        my $b = $c->req->json;
        return $c->json({ ok => 1, key => $key, received => $b });
    });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 83: HMAC 서명 요청 + 재전송 방지)

=head1 SYNOPSIS

X-Api-Key / X-Timestamp / X-Nonce / X-Signature 로 요청 서명 검증

=cut
