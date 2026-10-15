package Daeha;

use Punk;
use JSON::PP;
use MIME::Base64 qw(encode_base64url decode_base64url);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 데이터 (id 1..100) ----
my @FEED = map { { id => $_, title => "item-$_" } } 1 .. 100;

sub _enc_cursor { encode_base64url('id:' . $_[0]) }
sub _dec_cursor {
    my ($cur) = @_;
    return undef unless defined $cur && length $cur;
    my $s = eval { decode_base64url($cur) };
    return undef unless defined $s;
    return $1 if $s =~ /^id:(\d+)$/;
    return undef;
}

get '/feed' => sub {
    my ($c) = @_;

    my $limit = int($c->param('limit') // 10) || 10;
    $limit = 1  if $limit < 1;
    $limit = 50 if $limit > 50;

    my $after = 0;
    my $cursor = $c->param('cursor');
    if (defined $cursor && length $cursor) {
        my $id = _dec_cursor($cursor);
        unless (defined $id) {
            $c->header('Content-Type' => 'application/problem+json');
            return $c->json({
                type   => 'about:blank',
                title  => 'Bad Request',
                status => 400,
                detail => 'invalid cursor',
            }, 400);
        }
        $after = $id;
    }

    my @rows = grep { $_->{id} > $after } @FEED;
    my $more = (scalar @rows > $limit) ? 1 : 0;
    @rows = @rows[0 .. $limit - 1] if $more;

    my $next = $more ? _enc_cursor($rows[-1]{id}) : undef;
    return $c->json({ items => \@rows, next_cursor => $next });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 52: 커서 페이지네이션)

=head1 SYNOPSIS

GET /feed?limit=10&cursor=<opaque>  커서 기반 페이지네이션

=cut
