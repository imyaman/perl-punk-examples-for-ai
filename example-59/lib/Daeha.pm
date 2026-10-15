package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# 파일 기반 저장소 (DB 대체)
my $STORE = $ENV{DAEHA_STORE} // '/tmp/daeha-store.json';
my $J = JSON::PP->new->canonical->pretty;

sub _load {
    return { seq => 0, items => [] } unless -f $STORE;
    open(my $fh, '<', $STORE) or return { seq => 0, items => [] };
    local $/;
    my $raw = <$fh>;
    close $fh;
    my $d = eval { $J->decode($raw) };
    return ($d && ref $d eq 'HASH' && ref $d->{items} eq 'ARRAY')
        ? $d : { seq => 0, items => [] };
}

sub _save {
    my ($d) = @_;
    my $tmp = "$STORE.$$.tmp";
    open(my $fh, '>', $tmp) or die "open $tmp: $!";
    print $fh $J->encode($d);
    close $fh;
    rename($tmp, $STORE) or die "rename $tmp: $!";   # 원자적 교체
}

get '/notes' => sub {
    my ($c) = @_;
    my $d = _load();
    return $c->json({ items => $d->{items} });
};

post '/notes' => sub {
    my ($c) = @_;
    my $body = $c->req->json // {};
    my $text = defined $body->{text} ? $body->{text} : '';
    return $c->json({ error => 'text required' }, 400) unless length $text;

    my $d = _load();
    $d->{seq}++;
    my $rec = { id => $d->{seq}, text => "$text" };
    push @{ $d->{items} }, $rec;
    _save($d);

    $c->header('Location' => "/notes/$rec->{id}");
    return $c->json($rec, 201);
};

get '/notes/:id' => sub {
    my ($c) = @_;
    my $id = int($c->param('id') // 0);
    my ($rec) = grep { $_->{id} == $id } @{ _load()->{items} };
    return $c->json({ error => 'not found' }, 404) unless $rec;
    return $c->json($rec);
};

del '/notes/:id' => sub {
    my ($c) = @_;
    my $id = int($c->param('id') // 0);
    my $d = _load();
    my $before = scalar @{ $d->{items} };
    $d->{items} = [ grep { $_->{id} != $id } @{ $d->{items} } ];
    return $c->json({ error => 'not found' }, 404) if @{ $d->{items} } == $before;
    _save($d);
    return $c->text('', 204);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 59: 파일 기반 저장소)

=head1 SYNOPSIS

GET/POST /notes, GET/DELETE /notes/:id  JSON 파일에 원자적으로 저장

=cut
