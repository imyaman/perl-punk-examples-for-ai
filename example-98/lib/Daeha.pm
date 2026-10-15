package Daeha;

use Punk;
use JSON::PP;
use Digest::SHA qw(sha1_hex);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my $COUNTER = 0;
sub _gen { my ($n) = @_; return substr(sha1_hex(rand() . time() . $$ . ++$COUNTER), 0, $n) }

# traceparent: 00-<32hex trace-id>-<16hex parent-id>-<2hex flags>
sub _parse_traceparent {
    my ($tp) = @_;
    return undef unless defined $tp && $tp =~ /^([0-9a-f]{2})-([0-9a-f]{32})-([0-9a-f]{16})-([0-9a-f]{2})$/i;
    my ($ver, $trace, $span, $flags) = (lc $1, lc $2, lc $3, lc $4);
    return undef unless $ver eq '00';
    return undef if $trace =~ /^0+$/ || $span =~ /^0+$/;   # all-zero = invalid
    my $sampled = (hex($flags) & 0x01) ? 1 : 0;
    return { trace_id => $trace, parent_id => $span, sampled => $sampled };
}

get '/traced' => sub {
    my ($c) = @_;

    my $incoming = $c->req->header('traceparent');
    my $ctx = _parse_traceparent($incoming);

    my $restarted = 0;
    if (!$ctx) {
        $ctx = { trace_id => _gen(32), parent_id => undef, sampled => 1 };
        $restarted = 1 if defined $incoming && length $incoming;
    }

    my $span_id = _gen(16);
    my $flags   = $ctx->{sampled} ? '01' : '00';
    my $out     = "00-$ctx->{trace_id}-$span_id-$flags";

    $c->header('traceparent' => $out);
    return $c->json({
        trace_id       => $ctx->{trace_id},
        parent_span_id => defined $ctx->{parent_id} ? $ctx->{parent_id} : JSON::PP::null,
        span_id        => $span_id,
        sampled        => $ctx->{sampled} ? JSON::PP::true : JSON::PP::false,
        restarted      => $restarted ? JSON::PP::true : JSON::PP::false,
        traceparent    => $out,
    });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 98: W3C traceparent 전파)

=head1 SYNOPSIS

GET /traced   traceparent 헤더를 이어받거나 새로 시작

=cut
