package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my @USERS = (
    { id => 1, name => 'Alice',   email => 'alice@example.com',   note => 'plain' },
    { id => 2, name => 'Bob, Jr', email => 'bob@example.com',     note => 'has "quotes"' },
    { id => 3, name => 'Carol',   email => 'carol@example.com',   note => "multi\nline" },
);

sub _csv_field {
    my ($v) = @_;
    $v = '' unless defined $v;
    if ($v =~ /[",\r\n]/) {
        $v =~ s/"/""/g;
        return qq{"$v"};
    }
    return $v;
}

get '/users' => sub {
    my ($c) = @_;
    return $c->json({ items => \@USERS });
};

get '/export.csv' => sub {
    my ($c) = @_;

    my @cols = qw(id name email note);
    my $out = join(',', @cols) . "\n";
    for my $u (@USERS) {
        $out .= join(',', map { _csv_field($u->{$_}) } @cols) . "\n";
    }

    $c->header('Content-Type' => 'text/csv; charset=utf-8');
    $c->header('Content-Disposition' => 'attachment; filename="users.csv"');
    return $c->text($out, 200);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 72: CSV 내보내기)

=head1 SYNOPSIS

GET /export.csv  text/csv 로 내려주며 콤마/따옴표/줄바꿈을 이스케이프

=cut
