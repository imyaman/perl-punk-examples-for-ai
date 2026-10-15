package Daeha;

use Punk;
use JSON::PP;
use MIME::Base64 qw(encode_base64url decode_base64url);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my @EVENTS;   # id 오름차순
my $SEQ = 0;

sub _encode_cursor {
    my $s = encode_base64url("$_[0]");
    $s =~ s/=+$//;   # URL 안전하게 패딩 제거
    return $s;
}
sub _decode_cursor {
    my ($c) = @_;
    return undef unless defined $c && $c =~ /^[A-Za-z0-9_-]+$/;
    my $padded = $c;
    $padded .= '=' x ((4 - length($padded) % 4) % 4);
    my $raw = eval { decode_base64url($padded) };
    return undef unless defined $raw && $raw =~ /^\d+$/;
    return 0 + $raw;
}

post '/events' => sub {
    my ($c) = @_;
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my $type = defined $b->{type} ? "$b->{type}" : '';
    return $c->json({ error => 'type required' }, 400) unless length $type;

    my $ts = (defined $b->{ts} && $b->{ts} =~ /^\d+$/) ? 0 + $b->{ts} : time();
    $SEQ++;
    my $ev = { id => $SEQ, ts => $ts, type => $type, data => $b->{data} };
    push @EVENTS, $ev;
    return $c->json($ev, 201);
};

get '/feed' => sub {
    my ($c) = @_;

    my $limit = $c->param('limit');
    $limit = 20 unless defined $limit;
    return $c->json({ error => 'limit must be an integer 1..100' }, 400)
        unless $limit =~ /^\d+$/ && $limit >= 1 && $limit <= 100;

    for my $p (qw(since until)) {
        my $v = $c->param($p);
        return $c->json({ error => "$p must be an epoch integer" }, 400)
            if defined $v && $v !~ /^\d+$/;
    }

    my $after_cursor = $c->param('cursor');
    my $after_id = 0;
    if (defined $after_cursor && length $after_cursor) {
        $after_id = _decode_cursor($after_cursor);
        return $c->json({ error => 'invalid cursor' }, 400) unless defined $after_id;
    }

    my $since = $c->param('since');
    my $until = $c->param('until');

    my @filtered = grep {
        $_->{id} > $after_id
        && (!defined $since || $_->{ts} >= $since)
        && (!defined $until || $_->{ts} <= $until)
    } @EVENTS;

    my $has_more = @filtered > $limit;
    my @page = @filtered > $limit ? @filtered[0 .. $limit - 1] : @filtered;

    return $c->json({
        events      => \@page,
        count       => scalar @page,
        has_more    => $has_more ? JSON::PP::true : JSON::PP::false,
        next_cursor => $has_more ? _encode_cursor($page[-1]{id}) : JSON::PP::null,
    });
};

get '/events/:id' => sub {
    my ($c) = @_;
    my $id = $c->param('id');
    my ($ev) = grep { $_->{id} == $id } @EVENTS;
    return $c->json({ error => 'unknown event' }, 404) unless $ev;
    return $c->json($ev);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 88: 시간창 피드 + 커서 페이지네이션)

=head1 SYNOPSIS

POST /events   이벤트 적재(ts 옵션)
GET  /feed     since/until/limit/cursor 로 조회

=cut
