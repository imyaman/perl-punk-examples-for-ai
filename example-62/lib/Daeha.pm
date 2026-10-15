package Daeha;

use Punk;
use JSON::PP;
use POSIX qw(strftime);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my %MON = (Jan=>0,Feb=>1,Mar=>2,Apr=>3,May=>4,Jun=>5,Jul=>6,Aug=>7,Sep=>8,Oct=>9,Nov=>10,Dec=>11);

sub _http_date { strftime('%a, %d %b %Y %H:%M:%S GMT', gmtime($_[0])) }

sub _parse_http_date {
    my ($s) = @_;
    return undef unless defined $s;
    return undef unless $s =~ /^\w{3},\s+(\d{2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT$/;
    my ($d, $mon, $y, $h, $mi, $se) = ($1, $2, $3, $4, $5, $6);
    return undef unless exists $MON{$mon};
    return _days_from_civil($y, $MON{$mon} + 1, $d) * 86400 + $h * 3600 + $mi * 60 + $se;
}

sub _days_from_civil {
    my ($y, $m, $d) = @_;
    $y -= ($m <= 2) ? 1 : 0;
    my $era = int(($y >= 0 ? $y : $y - 399) / 400);
    my $yoe = $y - $era * 400;
    my $doy = int((153 * ($m + (($m > 2) ? -3 : 9)) + 2) / 5) + $d - 1;
    my $doe = $yoe * 365 + int($yoe / 4) - int($yoe / 100) + $doy;
    return $era * 146097 + $doe - 719468;
}

my $LASTMOD = _days_from_civil(2026, 1, 1) * 86400;   # 2026-01-01 00:00:00 GMT
my $CONTENT = 'hello world';

get '/page' => sub {
    my ($c) = @_;
    my $lm = _http_date($LASTMOD);

    my $ims = $c->req->header('if-modified-since');
    my $t = _parse_http_date($ims);
    if (defined $t && $t >= $LASTMOD) {
        $c->header('Last-Modified' => $lm);
        return $c->text('', 304);
    }

    $c->header('Last-Modified' => $lm);
    return $c->json({ content => $CONTENT, lastmod => $LASTMOD });
};

put '/page' => sub {
    my ($c) = @_;
    my $b = $c->req->json // {};
    $CONTENT = $b->{content} if exists $b->{content};
    $LASTMOD = time();
    $c->header('Last-Modified' => _http_date($LASTMOD));
    return $c->json({ content => $CONTENT, lastmod => $LASTMOD });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 62: Last-Modified / If-Modified-Since)

=head1 SYNOPSIS

GET /page  Last-Modified 반환, If-Modified-Since 가 최신이면 304
PUT /page  내용 변경 후 Last-Modified 갱신

=cut
