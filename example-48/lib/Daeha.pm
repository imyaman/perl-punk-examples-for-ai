package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 조건부/배치 응답: Bulk operations ----
# POST /bulk  { "ops": [ {"op":"create","name":"x"}, {"op":"delete","id":2}, ... ] }
my @STORE = ();
my $SEQ = 0;

sub _find { my ($id) = @_; my $i=0; for ($i=0;$i<@STORE;$i++){ return $i if $STORE[$i]{id}==$id } return -1; }

post '/bulk' => sub {
    my ($c) = @_;
    my $body = $c->req->json // {};
    my $ops  = $body->{ops};
    unless (defined $ops && ref $ops eq 'ARRAY') {
        $c->header('Content-Type' => 'application/problem+json');
        return $c->json({ type=>'about:blank', title=>'Bad Request', status=>400, detail=>'ops[] is required' }, 400);
    }

    my @results;
    my $ok = 1;
    for my $op (@$ops) {
        my $kind = $op->{op} // '';
        if ($kind eq 'create') {
            $SEQ++;
            my $rec = { id => $SEQ, name => $op->{name} // '' };
            push @STORE, $rec;
            push @results, { op => 'create', status => 201, id => $rec->{id} };
        }
        elsif ($kind eq 'update') {
            my $i = _find($op->{id} // -1);
            if ($i >= 0) {
                $STORE[$i]{name} = $op->{name} if exists $op->{name};
                push @results, { op => 'update', status => 200, id => $STORE[$i]{id} };
            } else {
                $ok = 0;
                push @results, { op => 'update', status => 404, id => $op->{id} };
            }
        }
        elsif ($kind eq 'delete') {
            my $i = _find($op->{id} // -1);
            if ($i >= 0) {
                my $id = $STORE[$i]{id};
                splice @STORE, $i, 1;
                push @results, { op => 'delete', status => 204, id => $id };
            } else {
                $ok = 0;
                push @results, { op => 'delete', status => 404, id => $op->{id} };
            }
        }
        else {
            $ok = 0;
            push @results, { op => $kind, status => 400, error => 'unknown op' };
        }
    }

    return $c->json({ ok => ($ok ? 1 : 0), results => \@results }, $ok ? 200 : 207);
};

get '/store' => sub { $_[0]->json({ items => [ map { { %$_ } } @STORE ] }) };

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 48: 벌크 연산)

=head1 SYNOPSIS

POST /bulk   {"ops":[{op:create,name:..},{op:update,id:..},{op:delete,id:..}]}
GET  /store  현재 상태

=cut
