package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my @USERS = (
    { id => 1, name => 'alice' },
    { id => 2, name => 'bob' },
);

# ---- 버전 1 (구): 배열 기반 응답, 사용 중단 예정 ----
get '/v1/users' => sub {
    my ($c) = @_;
    $c->header('Deprecation' => 'true');
    $c->header('Sunset'      => 'Sat, 01 Jan 2027 00:00:00 GMT');
    $c->header('Link'        => '</v2/users>; rel="successor-version"');
    return $c->json({ users => [ map { $_->{name} } @USERS ] });
};

# ---- 버전 2 (현): 객체 + 메타데이터 ----
get '/v2/users' => sub {
    my ($c) = @_;
    return $c->json({
        data => \@USERS,
        meta => { count => scalar @USERS, version => 'v2' },
    });
};

# ---- 버전 발견 ----
get '/version' => sub {
    my ($c) = @_;
    return $c->json({
        current    => 'v2',
        supported  => [ 'v1', 'v2' ],
        deprecated => ['v1'],
        sunset     => { v1 => '2027-01-01' },
    });
};

# 알 수 없는 버전
get '/v3/users' => sub { $_[0]->json({ error => 'unsupported version' }, 404) };

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 92: 경로 기반 API 버전관리)

=head1 SYNOPSIS

GET /v1/users   구 버전(Deprecation/Sunset/Link)
GET /v2/users   현 버전
GET /version    지원 버전 목록

=cut
