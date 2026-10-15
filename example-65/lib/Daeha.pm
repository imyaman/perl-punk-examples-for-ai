package Daeha;

use Punk;
use JSON::PP;
use Digest::SHA qw(hmac_sha256_hex);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my $SECRET = 'link-signing-secret';
my %FILES = (
    'report.pdf' => "PDF-DATA-REPORT\n",
    'image.png'  => "PNGDATA",
);

sub _sign {
    my ($name, $exp) = @_;
    return hmac_sha256_hex("$name|$exp", $SECRET);
}

sub _eq {
    my ($a, $b) = @_;
    return 0 unless defined $a && defined $b;
    return 0 unless length($a) == length($b);
    my $d = 0;
    $d |= ord(substr($a, $_, 1)) ^ ord(substr($b, $_, 1)) for 0 .. length($a) - 1;
    return $d == 0;
}

post '/links' => sub {
    my ($c) = @_;
    my $b = $c->req->json // {};
    my $name = $b->{name} // '';
    return $c->json({ error => 'unknown file' }, 404) unless exists $FILES{$name};

    my $ttl = int($b->{ttl} // 3600);
    $ttl = 1      if $ttl < 1;
    $ttl = 86400  if $ttl > 86400;
    my $exp = time() + $ttl;
    my $sig = _sign($name, $exp);

    return $c->json({
        url      => "/dl/$name?exp=$exp&sig=$sig",
        expires  => $exp,
        ttl      => $ttl,
    }, 201);
};

get '/dl/:name' => sub {
    my ($c) = @_;
    my $name = $c->param('name');
    return $c->json({ error => 'unknown file' }, 404) unless exists $FILES{$name};

    my $exp = $c->param('exp');
    my $sig = $c->param('sig');

    unless (defined $exp && defined $sig && _eq($sig, _sign($name, $exp))) {
        return $c->json({ error => 'bad signature' }, 403);
    }
    if (int($exp) < time()) {
        return $c->json({ error => 'link expired' }, 410);
    }

    $c->header('Content-Type' => 'application/octet-stream');
    $c->header('Content-Disposition' => "attachment; filename=\"$name\"");
    return $c->text($FILES{$name}, 200);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 65: 서명된 만료 다운로드 링크)

=head1 SYNOPSIS

POST /links  {name, ttl} -> 서명된 URL
GET  /dl/:name?exp=&sig=  검증 후 전송

=cut
