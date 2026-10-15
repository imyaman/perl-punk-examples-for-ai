package Daeha;

use Punk;
use JSON::PP;

my $SERVICE = 'daeha-api';
my $VERSION = '1.0.0';
my $STARTED = time();

# ---- 헬스체크 ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok', uptime => time() - $STARTED }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 자기서술 루트 ----
get '/' => sub {
    my ($c) = @_;
    return $c->json({
        service       => $SERVICE,
        version       => $VERSION,
        api_version   => 'v1',
        status        => 'ok',
        documentation => '/openapi.json',
        endpoints     => [
            { method => 'GET', path => '/',             description => '서비스 서술' },
            { method => 'GET', path => '/openapi.json', description => 'OpenAPI 명세' },
            { method => 'GET', path => '/_smoke',       description => '스모크 체크' },
            { method => 'GET', path => '/api/ping',     description => '핑' },
            { method => 'GET', path => '/api/healthz',  description => '라이브니스' },
            { method => 'GET', path => '/api/readyz',   description => '레디니스' },
        ],
        links => { self => '/', openapi => '/openapi.json', health => '/api/healthz' },
    });
};

# ---- 최소 OpenAPI 명세 ----
get '/openapi.json' => sub {
    my ($c) = @_;
    my %spec_paths;
    for my $p ('/api/ping', '/api/healthz', '/api/readyz', '/_smoke') {
        $spec_paths{$p} = {
            get => {
                summary   => "GET $p",
                responses => { 200 => { description => 'OK' } },
            },
        };
    }
    return $c->json({
        openapi => '3.0.3',
        info    => { title => $SERVICE, version => $VERSION },
        servers => [ { url => 'http://127.0.0.1:3004' } ],
        paths   => \%spec_paths,
    });
};

# ---- 스모크 체크 ----
get '/_smoke' => sub {
    my ($c) = @_;
    my @checks = (
        { name => 'json_encode', ok => _json_ok() ? JSON::PP::true : JSON::PP::false },
        { name => 'uptime',      ok => (time() - $STARTED) >= 0 ? JSON::PP::true : JSON::PP::false },
    );
    my $all_ok = !grep { !$_->{ok} } @checks;
    $c->header('X-Smoke' => $all_ok ? 'pass' : 'fail');
    return $c->json({ ok => $all_ok ? JSON::PP::true : JSON::PP::false, checks => \@checks });
};

sub _json_ok {
    my $encoded = eval { JSON::PP->new->encode({ ok => 1 }) };
    return defined $encoded && $encoded =~ /ok/;
}

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 100: 자기서술 API)

=head1 SYNOPSIS

GET /              서비스 서술
GET /openapi.json  OpenAPI 명세
GET /_smoke        스모크 체크

=cut
