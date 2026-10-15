package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# a..z 반복 200바이트
my $DATA = join '', map { chr(ord('a') + ($_ % 26)) } 0 .. 199;
my $LEN  = length $DATA;

get '/file' => sub {
    my ($c) = @_;
    $c->header('Accept-Ranges'  => 'bytes');
    $c->header('Content-Type'   => 'text/plain');

    my $range = $c->req->header('range');
    unless (defined $range && $range =~ /^bytes=(\d*)-(\d*)$/) {
        return $c->text($DATA, 200);
    }

    my ($s, $e) = ($1, $2);
    my ($start, $end);

    if ($s eq '' && $e eq '') {
        $c->header('Content-Range' => "bytes */$LEN");
        return $c->text('', 416);
    }
    elsif ($s eq '') {                     # suffix: bytes=-5
        my $n = int($e);
        $start = $LEN - $n;
        $start = 0 if $start < 0;
        $end = $LEN - 1;
    }
    elsif ($e eq '') {                     # open: bytes=10-
        $start = int($s);
        $end   = $LEN - 1;
    }
    else {                                 # bytes=10-19
        $start = int($s);
        $end   = int($e);
    }

    if ($start >= $LEN || $start > $end) {
        $c->header('Content-Range' => "bytes */$LEN");
        return $c->text('', 416);
    }
    $end = $LEN - 1 if $end >= $LEN;

    my $part = substr($DATA, $start, $end - $start + 1);
    $c->header('Content-Range' => "bytes $start-$end/$LEN");
    return $c->text($part, 206);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 58: Range 요청 / 206)

=head1 SYNOPSIS

GET /file           200 전체
GET /file Range:..  206 부분, 416 불가 범위

=cut
