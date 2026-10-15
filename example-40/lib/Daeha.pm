package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 아이템 보관소 ----
my @ITEMS = ();
my $ID = 0;

sub _jsonp     { my ($d,$cb) = @_; $cb . '(' . JSON::PP->new->encode($d) . ');' }
sub _err400    { my ($c,$msg) = @_; $c->header('Content-Type'=>'application/problem+json'); $c->json({type=>'about:blank',title=>'Bad Request',status=>400,detail=>$msg},400); }
sub _err404    { my ($c,$msg,$inst) = @_; $c->header('Content-Type'=>'application/problem+json'); $c->json({type=>'about:blank',title=>'Not Found',status=>404,detail=>$msg,instance=>$inst},404); }

# ---- POST /items ----
post '/items' => sub {
    my ($c) = @_;
    my $body = $c->req->json // {};
    my $name = $body->{name};
    return _err400($c,'name is required') unless defined $name && $name ne '';
    $ID++;
    push @ITEMS, { id => $ID, name => $name };
    $c->header('Location' => "/items/$ID");
    return $c->json($ITEMS[-1], 201);
};

# ---- GET /items ----
get '/items' => sub {
    my ($c) = @_;
    my $cb = $c->param('callback');
    if (defined $cb && length $cb) {
        # 간단한 콜백 검증: 영숫자/_/./$
        return _err400($c,'invalid callback') unless $cb =~ /^[\w\.\$]+$/;
        $c->header('Content-Type' => 'application/javascript; charset=utf-8');
        return $c->text(_jsonp({ items => \@ITEMS }, $cb));
    }
    return $c->json({ items => \@ITEMS });
};

# ---- GET /items/:id ----
get '/items/:id' => sub {
    my ($c) = @_;
    my $id = int($c->param('id') // 0);
    my ($it) = grep { $_->{id} == $id } @ITEMS;
    return _err404($c,'item not found', "/items/$id") unless $it;
    return $c->json($it);
};

# ---- DELETE /items/:id ----
del '/items/:id' => sub {
    my ($c) = @_;
    my $id = int($c->param('id') // 0);
    my $i = 0;
    for (my $i=0; $i<@ITEMS; $i++) {
        if ($ITEMS[$i]{id} == $id) {
            splice @ITEMS, $i, 1;
            return $c->text('', 204);
        }
    }
    return _err404($c,'item not found', "/items/$id");
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 40: JSONP)

=head1 SYNOPSIS

GET /items?callback=foo  application/javascript + foo({...});
POST /items {name:...}  201 + Location

=cut
