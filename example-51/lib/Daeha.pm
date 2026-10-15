package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 간단 검증 헬퍼 ----
# rules: field => { required=>1, type=>'int'|'string', min=>N, max=>N,
#                   pattern=>qr//, range=>[lo,hi] }
sub _validate {
    my ($data, $rules) = @_;
    my @errors;
    for my $f (sort keys %$rules) {
        my $r = $rules->{$f};
        my $v = $data->{$f};

        if (!defined $v) {
            push @errors, { field => $f, issue => 'required' } if $r->{required};
            next;
        }

        if (($r->{type} // '') eq 'int') {
            unless ($v =~ /^-?\d+$/) {
                push @errors, { field => $f, issue => 'not an integer' };
                next;
            }
            if ($r->{range}) {
                my ($lo, $hi) = @{ $r->{range} };
                push @errors, { field => $f, issue => "out of range $lo..$hi" }
                    if $v < $lo || $v > $hi;
            }
        }

        if (defined $r->{min} && length($v) < $r->{min}) {
            push @errors, { field => $f, issue => "too short (min $r->{min})" };
        }
        if (defined $r->{max} && length($v) > $r->{max}) {
            push @errors, { field => $f, issue => "too long (max $r->{max})" };
        }
        if ($r->{pattern} && $v !~ $r->{pattern}) {
            push @errors, { field => $f, issue => 'invalid format' };
        }
    }
    return @errors;
}

# ---- 사용자 생성 + 검증 ----
post '/users' => sub {
    my ($c) = @_;
    my $body = $c->req->json // {};

    my @errors = _validate($body, {
        name  => { required => 1, min => 2, max => 20 },
        email => { required => 1, pattern => qr/^[^@\s]+@[^@\s]+\.[^@\s]+$/ },
        age   => { type => 'int', range => [0, 200] },
    });

    if (@errors) {
        $c->header('Content-Type' => 'application/problem+json');
        return $c->json({
            type   => 'about:blank',
            title  => 'Unprocessable Entity',
            status => 422,
            detail => 'validation failed',
            errors => \@errors,
        }, 422);
    }

    return $c->json({ created => 1, user => { name => $body->{name}, email => $body->{email}, age => $body->{age} } }, 201);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 51: 입력 검증)

=head1 SYNOPSIS

POST /users  name(2..20), email(형식), age(0..200, 선택) 검증
             실패시 422 + errors[]

=cut
