package Daeha;

use Punk;
use JSON::PP;

# ---- 뷰 엔진 등록 (Stencil) ----
views Stencil => { template_dir => 'templates' };

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 템플릿 렌더 ----
get '/page' => sub {
    my ($c) = @_;
    $c->render('page', {
        title => 'Fruits',
        items => [ 'apple', 'banana', 'cherry' ],
    });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 25: views + render 템플릿)

=head1 SYNOPSIS

GET /page   templates/page.tmpl 렌더
GET /api/ping|healthz|readyz  헬스체크

=cut
