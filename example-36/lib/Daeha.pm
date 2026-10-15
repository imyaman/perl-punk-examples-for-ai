package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 데이터 ----
my %USER = (
    id    => 1,
    name  => 'alice',
    age   => 30,
    email => 'alice@example.com',
    city  => 'seoul',
);

# ---- 부분 필드 응답: ?fields=id,name ----
get '/users/:id' => sub {
    my ($c) = @_;
    my @all = qw(id name age email city);
    my %valid = map { $_ => 1 } @all;

    my $fields = $c->param('fields');
    if (defined $fields && length $fields) {
        my @want = split /,/, $fields;
        for my $w (@want) {
            return $c->json({ error => "unknown field: $w", allowed => \@all }, 400)
                unless $valid{$w};
        }
        return { data => { map { $_ => $USER{$_} } @want } };
    }

    $c->json({ data => { %USER } });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 36: 부분 필드 선택)

=head1 SYNOPSIS

GET /users/:id?fields=id,name   지정한 필드만 반환
GET /api/ping|healthz|readyz     헬스체크

=cut
