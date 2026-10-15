package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my %DATA;
my %SEQ;

sub _tenant {
    my ($c) = @_;
    my $t = $c->req->header('x-tenant-id');
    return undef unless defined $t && $t =~ /^[a-z0-9][a-z0-9-]{0,31}$/;
    return $t;
}

sub _bad_tenant {
    my ($c) = @_;
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({
        type => 'about:blank', title => 'Bad Request', status => 400,
        detail => 'X-Tenant-Id header required (lowercase, 1-32 chars)',
    }, 400);
}

get '/tasks' => sub {
    my ($c) = @_;
    my $t = _tenant($c);
    return _bad_tenant($c) unless defined $t;
    return $c->json({ tenant => $t, items => $DATA{$t} // [] });
};

post '/tasks' => sub {
    my ($c) = @_;
    my $t = _tenant($c);
    return _bad_tenant($c) unless defined $t;
    my $body = $c->req->json // {};
    my $title = defined $body->{title} ? $body->{title} : '';
    return $c->json({ error => 'title required' }, 400) unless length $title;
    $SEQ{$t}++;
    my $rec = { id => $SEQ{$t}, title => "$title" };
    push @{ $DATA{$t} ||= [] }, $rec;
    $c->header('Location' => "/tasks/$rec->{id}");
    return $c->json($rec, 201);
};

get '/tasks/:id' => sub {
    my ($c) = @_;
    my $t = _tenant($c);
    return _bad_tenant($c) unless defined $t;
    my $id = int($c->param('id') // 0);
    my ($rec) = grep { $_->{id} == $id } @{ $DATA{$t} // [] };
    return $c->json({ error => 'not found' }, 404) unless $rec;
    return $c->json($rec);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 63: 헤더 기반 멀티테넌시)

=head1 SYNOPSIS

모든 요청에 X-Tenant-Id 필수; 테넌트별로 데이터 격리

=cut
