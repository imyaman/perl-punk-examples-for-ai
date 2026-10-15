package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 간단한 파일 다운로드 ----
get '/download/text' => sub {
    my ($c) = @_;
    my $body = "Hello from Punk\nLine 2\n";
    $c->header('Content-Type' => 'text/plain; charset=utf-8');
    $c->header('Content-Disposition' => 'attachment; filename="hello.txt"');
    return $c->text($body);
};

get '/download/json' => sub {
    my ($c) = @_;
    my $data = { file => 'data.json', items => [1, 2, 3] };
    $c->header('Content-Disposition' => 'attachment; filename="data.json"');
    return $c->json($data);
};

get '/download/csv' => sub {
    my ($c) = @_;
    my $csv = "id,name\n1,alice\n2,bob\n";
    $c->header('Content-Type' => 'text/csv; charset=utf-8');
    $c->header('Content-Disposition' => 'attachment; filename="users.csv"');
    return $c->text($csv);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 45: 파일 다운로드)

=head1 SYNOPSIS

GET /download/text  text/plain 첨부
GET /download/json  application/json 첨부
GET /download/csv   text/csv 첨부

=cut
