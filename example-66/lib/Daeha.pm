package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my %MSG = (
    en => 'Hello',
    ko => '안녕하세요',
    ja => 'こんにちは',
    de => 'Hallo',
);
my $DEFAULT = 'en';

sub _negotiate {
    my ($hdr) = @_;
    return $DEFAULT unless defined $hdr && length $hdr;

    my @prefs;
    for my $part (split /,/, $hdr) {
        next unless $part =~ /^\s*([A-Za-z][A-Za-z-]*|\*)\s*(?:;\s*q=([0-9.]+))?/;
        push @prefs, [ lc($1), (defined $2 ? $2 + 0 : 1) ];
    }
    @prefs = sort { $b->[1] <=> $a->[1] } @prefs;

    for my $p (@prefs) {
        my ($tag, $q) = @$p;
        next if $q <= 0;
        return $tag if exists $MSG{$tag};
        my ($base) = split /-/, $tag;
        return $base if exists $MSG{$base};
        return $DEFAULT if $tag eq '*';
    }
    return $DEFAULT;
}

get '/greeting' => sub {
    my ($c) = @_;
    my $loc;
    my $override = $c->param('lang');
    if (defined $override && exists $MSG{$override}) {
        $loc = $override;
    } else {
        $loc = _negotiate($c->req->header('accept-language'));
    }

    $c->header('Content-Language' => $loc);
    $c->header('Vary' => 'Accept-Language');
    return $c->json({ locale => $loc, message => $MSG{$loc} });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 66: Accept-Language 협상)

=head1 SYNOPSIS

GET /greeting  Accept-Language 로 최적 언어 선택, Vary: Accept-Language

=cut
