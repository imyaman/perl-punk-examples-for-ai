package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my %USERS = (
    alice => { pass => 'alice-pass', roles => ['reader'] },
    bob   => { pass => 'bob-pass',   roles => ['reader', 'admin'] },
    carol => { pass => 'carol-pass', roles => [] },
);
my %SESS;   # token => username

sub _token { sprintf('tok-%08x%08x', int(rand(2**31)), int(rand(2**31))) }

sub _auth {
    my ($c) = @_;
    my ($tok) = ($c->req->header('authorization') // '') =~ /^Bearer\s+(\S+)$/i;
    return (undef, 401) unless defined $tok;
    my $u = $SESS{$tok};
    return (undef, 401) unless defined $u && exists $USERS{$u};
    return ($USERS{$u}, 0);
}

sub _has {
    my ($user, @want) = @_;
    my %r = map { $_ => 1 } @{ $user->{roles} // [] };
    return scalar grep { $r{$_} } @want;
}

sub _unauthorized {
    my ($c) = @_;
    $c->header('WWW-Authenticate' => 'Bearer');
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({ type => 'about:blank', title => 'Unauthorized', status => 401 }, 401);
}
sub _forbidden {
    my ($c, $need) = @_;
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({ type => 'about:blank', title => 'Forbidden', status => 403, required_role => $need }, 403);
}

post '/auth/login' => sub {
    my ($c) = @_;
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my ($u, $p) = (defined $b->{user} ? "$b->{user}" : '', defined $b->{pass} ? "$b->{pass}" : '');
    unless (exists $USERS{$u} && $USERS{$u}{pass} eq $p) {
        return _unauthorized($c);
    }
    my $tok = _token();
    $SESS{$tok} = $u;
    return $c->json({ token => $tok, roles => $USERS{$u}{roles} }, 201);
};

get '/resource/public' => sub {
    return $_[0]->json({ scope => 'public', ok => 1 });
};

get '/resource/reader' => sub {
    my ($c) = @_;
    my ($u, $err) = _auth($c);
    return _unauthorized($c) if $err;
    return _forbidden($c, 'reader') unless _has($u, 'reader');
    return $c->json({ scope => 'reader', ok => 1, roles => $u->{roles} });
};

get '/resource/admin' => sub {
    my ($c) = @_;
    my ($u, $err) = _auth($c);
    return _unauthorized($c) if $err;
    return _forbidden($c, 'admin') unless _has($u, 'admin');
    return $c->json({ scope => 'admin', ok => 1, roles => $u->{roles} });
};

get '/account/me' => sub {
    my ($c) = @_;
    my ($u, $err) = _auth($c);
    return _unauthorized($c) if $err;
    return $c->json({ roles => $u->{roles} });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 78: RBAC 역할 기반 접근 제어)

=head1 SYNOPSIS

POST /auth/login  토큰 발급
GET  /resource/*  역할에 따라 401/403/200

=cut
