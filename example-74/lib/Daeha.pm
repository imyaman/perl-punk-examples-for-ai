package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my %ITEMS;   # id => { id, name, deleted_at(undef|epoch) }
my $SEQ = 0;

sub _view {
    my ($it) = @_;
    return { id => $it->{id}, name => $it->{name}, deleted => ($it->{deleted_at} ? 1 : 0) };
}

post '/items' => sub {
    my ($c) = @_;
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my $name = defined $b->{name} ? "$b->{name}" : '';
    return $c->json({ error => 'name required' }, 400) unless length $name;
    $SEQ++;
    $ITEMS{$SEQ} = { id => $SEQ, name => $name, deleted_at => undef };
    $c->header('Location' => "/items/$SEQ");
    return $c->json(_view($ITEMS{$SEQ}), 201);
};

get '/items' => sub {
    my ($c) = @_;
    my $inc  = $c->param('include_deleted');
    my $only = $c->param('only_deleted');
    my @out;
    for my $id (sort { $a <=> $b } keys %ITEMS) {
        my $it = $ITEMS{$id};
        if ($only)  { push @out, _view($it) if $it->{deleted_at} }
        elsif ($inc) { push @out, _view($it) }
        else        { push @out, _view($it) unless $it->{deleted_at} }
    }
    return $c->json({ items => \@out });
};

get '/items/:id' => sub {
    my ($c) = @_;
    my $id = int($c->param('id') // 0);
    my $it = $ITEMS{$id};
    return $c->json({ error => 'not found' }, 404) unless $it;
    return $c->json({ error => 'not found' }, 404) if $it->{deleted_at} && !$c->param('include_deleted');
    return $c->json(_view($it));
};

del '/items/:id' => sub {
    my ($c) = @_;
    my $id = int($c->param('id') // 0);
    my $it = $ITEMS{$id};
    return $c->json({ error => 'not found' }, 404) unless $it && !$it->{deleted_at};
    $it->{deleted_at} = time();
    return $c->text('', 204);
};

post '/items/:id/restore' => sub {
    my ($c) = @_;
    my $id = int($c->param('id') // 0);
    my $it = $ITEMS{$id};
    return $c->json({ error => 'not found' }, 404) unless $it;
    return $c->json({ error => 'not deleted' }, 409) unless $it->{deleted_at};
    $it->{deleted_at} = undef;
    return $c->json(_view($it));
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 74: 소프트 삭제와 복구)

=head1 SYNOPSIS

DELETE /items/:id  실제 삭제 대신 deleted_at 기록; POST /items/:id/restore 로 복구

=cut
