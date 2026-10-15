package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my @ITEMS = ();
my $SEQ = 0;

post '/items' => sub {
    my ($c) = @_;
    my $body = $c->req->json // {};
    $SEQ++;
    push @ITEMS, { id => $SEQ, name => $body->{name} // '' };
    my $rec = $ITEMS[-1];

    my $prefer = $c->req->header('prefer') // '';
    $c->header('Location' => "/items/$rec->{id}");

    if ($prefer =~ /return\s*=\s*minimal/i) {
        $c->header('Preference-Applied' => 'return=minimal');
        return $c->text('', 201);
    }

    $c->header('Preference-Applied' => 'return=representation');
    return $c->json($rec, 201);
};

get '/items/:id' => sub {
    my ($c) = @_;
    my $id = int($c->param('id') // 0);
    my ($it) = grep { $_->{id} == $id } @ITEMS;
    unless ($it) {
        $c->header('Content-Type' => 'application/problem+json');
        return $c->json({ type=>'about:blank', title=>'Not Found', status=>404, detail=>'not found' }, 404);
    }
    return $c->json($it);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 55: Prefer 헤더)

=head1 SYNOPSIS

POST /items  Prefer: return=minimal 이면 201 빈 본문, 아니면 대표 표현

=cut
