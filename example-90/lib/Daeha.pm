package Daeha;

use Punk;
use JSON::PP;
use Digest::SHA qw(sha256_hex);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my $JSON = JSON::PP->new->canonical;
my %PAYMENTS;   # id => payment
my %IDEM;       # key => { fp, status, body }
my $SEQ = 0;

sub _fingerprint {
    my ($b) = @_;
    return sha256_hex(JSON::PP->new->canonical->encode($b));
}

post '/payments' => sub {
    my ($c) = @_;
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';

    my $amount = $b->{amount};
    my $currency = defined $b->{currency} ? uc "$b->{currency}" : '';
    return $c->json({ error => 'amount must be a positive integer' }, 400)
        unless defined $amount && $amount =~ /^\d+$/ && $amount > 0;
    return $c->json({ error => 'currency must be 3 letters' }, 400)
        unless $currency =~ /^[A-Z]{3}$/;

    my $key = $c->req->header('Idempotency-Key');
    my $fp  = JSON::PP->new->canonical->encode({ amount => 0 + $amount, currency => $currency });

    if (defined $key && length $key) {
        if (my $prev = $IDEM{$key}) {
            if ($prev->{fp} ne $fp) {
                return $c->json({ error => 'idempotency key reused with different payload' }, 409);
            }
            $c->header('Idempotency-Replayed' => 'true');
            return $c->json($IDEM{$key}{body}, $IDEM{$key}{status});
        }
    }

    my $id = ++$SEQ;
    my $body = { id => $id, amount => 0 + $b->{amount}, currency => uc($b->{currency}), status => 'created' };
    $PAYMENTS{$id} = $body;
    $IDEM{$key} = { fp => $fp, status => 201, body => $body } if defined $key && length $key;
    return $c->json($body, 201);
};

get '/payments/:id' => sub {
    my ($c) = @_;
    my $id = $c->param('id');
    my $pay = $PAYMENTS{$id};
    return $c->json({ error => 'unknown payment' }, 404) unless $pay;
    return $c->json($pay);
};

get '/payments' => sub {
    my ($c) = @_;
    my @all = sort { $a->{id} <=> $b->{id} } values %PAYMENTS;
    return $c->json({ count => scalar @all, payments => \@all });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 90: 멱등성 키)

=head1 SYNOPSIS

POST /payments   Idempotency-Key 로 중복 방지
GET  /payments   생성된 결제 목록

=cut
