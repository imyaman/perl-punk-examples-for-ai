package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my @ROWS = (
    { region => 'KR', amount => 100 },
    { region => 'US', amount => 250 },
    { region => 'JP', amount => 175 },
);

# Accept 헤더에서 지원 형식을 고른다.
sub _negotiate {
    my ($header) = @_;
    return 'json' unless defined $header && length $header;
    my @ranked;
    for my $part (split /,/, $header) {
        my ($type, @params) = split /;/, $part;
        $type = lc $type;
        $type =~ s/^\s+|\s+$//g;
        next unless length $type;
        my $q = 1;
        for my $p (@params) { $q = $1 if $p =~ /q=([0-9.]+)/ }
        next if $q <= 0;
        push @ranked, [ $q, $type ];
    }
    @ranked = sort { $b->[0] <=> $a->[0] } @ranked;
    for my $r (@ranked) {
        my $type = $r->[1];
        return 'csv'  if $type eq 'text/csv';
        return 'text' if $type eq 'text/plain';
        return 'json' if $type eq 'application/json';
        return 'json' if $type eq 'application/*' || $type eq 'text/*' || $type eq '*/*';
    }
    return undef;   # 아무것도 못 맞춤
}

sub _csv {
    my @lines = ('region,amount');
    push @lines, join(',', $_->{region}, $_->{amount}) for @ROWS;
    return join("\n", @lines) . "\n";
}
sub _text {
    return join('', map { "$_->{region}: $_->{amount}\n" } @ROWS);
}

get '/report' => sub {
    my ($c) = @_;
    my $kind = _negotiate($c->req->header('Accept'));
    if (!defined $kind) {
        $c->res->status(406);
        $c->res->type('application/problem+json');
        return $c->res->body(JSON::PP->new->encode({
            type    => 'about:blank',
            title   => 'Not Acceptable',
            status  => 406,
            detail  => 'supported: application/json, text/csv, text/plain',
        }));
    }

    if ($kind eq 'csv') {
        $c->res->status(200);
        $c->res->type('text/csv');
        return $c->res->body(_csv());
    }
    if ($kind eq 'text') {
        $c->res->status(200);
        $c->res->type('text/plain');
        return $c->res->body(_text());
    }
    return $c->json({ count => scalar @ROWS, rows => \@ROWS });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 95: 콘텐츠 협상)

=head1 SYNOPSIS

GET /report   Accept 에 따라 json/csv/text, 그 외 406

=cut
