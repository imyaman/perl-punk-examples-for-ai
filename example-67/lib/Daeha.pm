package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my %USERS;   # id => { id, name, email }

sub _valid {
    my ($b) = @_;
    return 0 unless ref $b eq 'HASH';
    my $name = $b->{name} // '';
    my $mail = $b->{email} // '';
    return 0 unless length $name >= 2 && length $name <= 40;
    return 0 unless $mail =~ /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
    return 1;
}

put '/users/:id' => sub {
    my ($c) = @_;
    my $id = int($c->param('id') // 0);
    return $c->json({ error => 'id must be positive' }, 400) if $id < 1;

    my $b = eval { $c->req->json };
    return $c->json({ error => 'malformed JSON' }, 400) if $@;
    unless (_valid($b)) {
        $c->header('Content-Type' => 'application/problem+json');
        return $c->json({
            type=>'about:blank', title=>'Unprocessable Entity', status=>422,
            detail=>'name (2-40) and a valid email are required',
        }, 422);
    }

    my $exists = exists $USERS{$id};
    $USERS{$id} = { id => $id, name => "$b->{name}", email => "$b->{email}" };

    $c->header('Location' => "/users/$id");
    return $c->json($USERS{$id}, $exists ? 200 : 201);
};

get '/users/:id' => sub {
    my ($c) = @_;
    my $id = int($c->param('id') // 0);
    my $u = $USERS{$id};
    return $c->json({ error => 'not found' }, 404) unless $u;
    return $c->json($u);
};

del '/users/:id' => sub {
    my ($c) = @_;
    my $id = int($c->param('id') // 0);
    return $c->json({ error => 'not found' }, 404) unless exists $USERS{$id};
    delete $USERS{$id};
    return $c->text('', 204);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 67: PUT 업서트)

=head1 SYNOPSIS

PUT /users/:id  없으면 201, 있으면 200 으로 생성 또는 대체

=cut
