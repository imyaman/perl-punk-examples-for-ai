package Daeha;

use Punk;
use JSON::PP;
use Time::HiRes;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my $LOG = $ENV{DAEHA_ACCESS_LOG} // '/tmp/daeha-access.jsonl';
my $J   = JSON::PP->new->canonical;

hook before_dispatch => sub {
    my ($c) = @_;
    my $rid = $c->req->header('x-request-id');
    $rid = sprintf('%032x', int(rand(2**16))) unless defined $rid && length $rid;
    $c->stash->{rid}  = $rid;
    $c->stash->{t0}   = Time::HiRes::time();
    $c->header('X-Request-Id' => $rid);
    return;
};

hook after_dispatch => sub {
    my ($c, $resp) = @_;
    my $ms = sprintf('%.1f', (Time::HiRes::time() - ($c->stash->{t0} // Time::HiRes::time())) * 1000);
    my $line = $J->encode({
        ts     => time(),
        rid    => $c->stash->{rid},
        method => $c->req->method,
        path   => $c->req->path,
        status => ref $resp eq 'ARRAY' ? $resp->[0] : 0,
        ms     => $ms + 0,
    });
    if (open(my $fh, '>>', $LOG)) {
        print {$fh} "$line\n";
        close $fh;
    }
    return;
};

get '/logs/tail' => sub {
    my ($c) = @_;
    my $n = int($c->param('n') // 5) || 5;
    $n = 1  if $n < 1;
    $n = 50 if $n > 50;

    my @lines;
    if (open(my $fh, '<', $LOG)) {
        local $/;
        my $all = <$fh>;
        close $fh;
        @lines = grep { length } split /\n/, ($all // '');
    }
    splice(@lines, 0, @lines - $n) if @lines > $n;

    my @entries;
    for my $l (@lines) {
        my $e = eval { JSON::PP->new->decode($l) };
        push @entries, $e if $e;
    }
    return $c->json({ count => scalar @entries, entries => \@entries });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 77: 구조화된 접근 로그)

=head1 SYNOPSIS

after_dispatch 에서 JSONL 로 접근 로그를 남기고 /logs/tail 로 조회

=cut
