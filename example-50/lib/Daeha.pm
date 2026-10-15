package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 문서 상태 ----
my $DOC = {
    title  => 'hello',
    tags   => ['a', 'b'],
    author => { name => 'alice', email => 'a@example.com' },
};

# ---- JSON Merge Patch (RFC 7396) ----
sub _merge_patch {
    my ($target, $patch) = @_;
    return $patch unless ref $patch eq 'HASH';
    $target = {} unless ref $target eq 'HASH';
    for my $k (keys %$patch) {
        my $v = $patch->{$k};
        if (!defined $v) {
            delete $target->{$k};
        }
        elsif (ref $v eq 'HASH') {
            $target->{$k} = _merge_patch($target->{$k}, $v);
        }
        else {
            $target->{$k} = $v;
        }
    }
    return $target;
}

get '/doc' => sub { $_[0]->json($DOC) };

put '/doc' => sub {
    my ($c) = @_;
    my $body = $c->req->json // {};
    $DOC = $body if ref $body eq 'HASH';
    return $c->json($DOC);
};

patch '/doc' => sub {
    my ($c) = @_;
    my $body = $c->req->json // {};
    $DOC = _merge_patch($DOC, $body);
    return $c->json($DOC);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 50: JSON Merge Patch)

=head1 SYNOPSIS

GET   /doc   현재 문서
PUT   /doc   전체 교체
PATCH /doc   JSON Merge Patch (null=삭제, 객체=재귀 병합)

=cut
