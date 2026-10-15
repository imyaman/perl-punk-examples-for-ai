package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 데이터셋 ----
my @USERS = (
    { id => 1, name => 'alice', age => 30, city => 'seoul'   },
    { id => 2, name => 'bob',   age => 25, city => 'busan'   },
    { id => 3, name => 'carol', age => 41, city => 'seoul'   },
    { id => 4, name => 'dave',  age => 25, city => 'daegu'   },
    { id => 5, name => 'alice', age => 36, city => 'incheon' },
);

my %FILTERS = map { $_ => 1 } qw(name city);        # 정확 일치
my %RANGES  = (min_age => ['age', 'ge'], max_age => ['age', 'le']);

# ---- 정렬 + 필터링 ----
get '/users' => sub {
    my ($c) = @_;
    my @rows = @USERS;

    # 필터: 정확 일치
    for my $f (sort keys %FILTERS) {
        my $v = $c->param($f);
        next unless defined $v;
        @rows = grep { $_->{$f} eq $v } @rows;
    }

    # 필터: 범위
    for my $q (sort keys %RANGES) {
        my $v = $c->param($q);
        next unless defined $v;
        my ($field, $op) = @{ $RANGES{$q} };
        @rows = $op eq 'ge'
            ? grep { $_->{$field} >= $v } @rows
            : grep { $_->{$field} <= $v } @rows;
    }

    # 정렬: sort=-age,name
    my $sort = $c->param('sort');
    if (defined $sort && length $sort) {
        my @specs;
        for my $key (split /,/, $sort) {
            my $dir = ($key =~ s/^-//) ? -1 : 1;
            return $c->json({ error => "unknown sort field: $key" }, 400)
                unless exists $USERS[0]{$key};
            push @specs, [$key, $dir];
        }
        @rows = sort {
            my $r = 0;
            for my $s (@specs) {
                my ($f, $d) = @$s;
                my ($av, $bv) = ($a->{$f}, $b->{$f});
                $r = (($av =~ /^\d+$/ && $bv =~ /^\d+$/) ? ($av <=> $bv) : ($av cmp $bv)) * $d;
                last if $r;
            }
            $r
        } @rows;
    }

    return { data => \@rows, meta => { count => scalar @rows } };
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 35: 정렬과 필터링)

=head1 SYNOPSIS

GET /users?name=&city=&min_age=&max_age=&sort=-age,name
GET /api/ping|healthz|readyz  헬스체크

=cut
