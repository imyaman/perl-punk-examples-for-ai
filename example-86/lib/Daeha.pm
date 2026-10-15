package Daeha;

use Punk;
use JSON::PP;
use Time::HiRes ();
use Digest::SHA qw(sha256_hex);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my %LOCKS;   # name => { owner, token, expires_at, acquired_at }
my $MAX_TTL = 3600;

sub _now { Time::HiRes::time() }

sub _held {
    my ($name) = @_;
    my $l = $LOCKS{$name} or return undef;
    if ($l->{expires_at} <= _now()) {   # 만료 -> 자동 해제
        delete $LOCKS{$name};
        return undef;
    }
    return $l;
}

sub _view {
    my ($name, $l) = @_;
    return {
        name       => $name,
        owner      => $l->{owner},
        expires_at => $l->{expires_at},
        ttl        => sprintf('%.2f', $l->{expires_at} - _now()),
    };
}

post '/locks/:name' => sub {
    my ($c) = @_;
    my $name = $c->param('name');
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my $owner = defined $b->{owner} ? "$b->{owner}" : '';
    return $c->json({ error => 'owner required' }, 400) unless length $owner;

    my $ttl = defined $b->{ttl} ? 0 + $b->{ttl} : 30;
    return $c->json({ error => 'ttl must be between 0 and ' . $MAX_TTL }, 400)
        unless $ttl > 0 && $ttl <= $MAX_TTL;

    if (my $held = _held($name)) {
        $c->header('Retry-After' => int($held->{expires_at} - _now()) + 1);
        return $c->json({ error => 'locked', holder => _view($name, $held) }, 409);
    }

    my $token = sha256_hex($name . $owner . _now() . rand());
    $LOCKS{$name} = {
        owner        => $owner,
        token        => $token,
        acquired_at  => _now(),
        expires_at   => _now() + $ttl,
    };
    return $c->json({ name => $name, token => $token, ttl => $ttl, expires_at => $LOCKS{$name}{expires_at} }, 201);
};

get '/locks/:name' => sub {
    my ($c) = @_;
    my $name = $c->param('name');
    my $held = _held($name);
    return $c->json({ error => 'not locked' }, 404) unless $held;
    return $c->json(_view($name, $held));
};

put '/locks/:name/renew' => sub {
    my ($c) = @_;
    my $name = $c->param('name');
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my $token = defined $b->{token} ? "$b->{token}" : '';

    my $held = _held($name);
    return $c->json({ error => 'not locked' }, 404) unless $held;
    return $c->json({ error => 'token mismatch' }, 403) unless $token eq $held->{token};

    my $ttl = defined $b->{ttl} ? 0 + $b->{ttl} : 30;
    return $c->json({ error => 'invalid ttl' }, 400) unless $ttl > 0 && $ttl <= $MAX_TTL;

    $held->{expires_at} = _now() + $ttl;
    return $c->json({ name => $name, ttl => $ttl, expires_at => $held->{expires_at} });
};

del '/locks/:name' => sub {
    my ($c) = @_;
    my $name = $c->param('name');
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my $token = defined $b->{token} ? "$b->{token}" : '';

    my $held = _held($name);
    return $c->json({ error => 'not locked' }, 404) unless $held;
    return $c->json({ error => 'token mismatch' }, 403) unless $token eq $held->{token};

    delete $LOCKS{$name};
    return $c->text('', 204);
};

get '/locks' => sub {
    my ($c) = @_;
    my @out;
    for my $name (sort keys %LOCKS) {
        my $held = _held($name);
        push @out, _view($name, $held) if $held;
    }
    return $c->json({ count => scalar @out, locks => \@out });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 86: 분산 락 / 임대 + TTL)

=head1 SYNOPSIS

POST   /locks/:name        획득(owner, ttl)
GET    /locks/:name        보유자
PUT    /locks/:name/renew  갱신(token)
DELETE /locks/:name        해제(token)

=cut
