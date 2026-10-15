package Daeha;

use Punk;
use JSON::PP;
use Digest::SHA qw(sha1_hex);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my %FLAGS;   # name => { enabled => 0|1, rollout => 0..100, overrides => { key => 0|1 } }

sub _bucket {   # 이름+키를 0..99 로 안정적으로 매핑
    my ($name, $key) = @_;
    return hex(substr(sha1_hex("$name|$key"), 0, 4)) % 100;
}

# JSON boolean(디코더별 객체)을 안전하게 0/1 로 (eq 는 overload 없어 죽을 수 있음)
sub _bool {
    my ($v) = @_;
    return undef unless defined $v;
    return $v ? 1 : 0 if ref $v;          # boolean 객체는 진리값으로
    return 1 if $v eq '1';
    return 0 if $v eq '0';
    return undef;
}

sub _evaluate {
    my ($flag, $key) = @_;
    if (defined $key && exists $flag->{overrides}{$key}) {
        return ($flag->{overrides}{$key} ? 1 : 0, 'override');
    }
    return (0, 'disabled') unless $flag->{enabled};
    my $on = _bucket($flag->{name}, $key // '') < $flag->{rollout};
    return ($on ? 1 : 0, $on ? 'rollout' : 'not_in_rollout');
}

get '/flags/:name' => sub {
    my ($c) = @_;
    my $flag = $FLAGS{ $c->param('name') };
    return $c->json({ error => 'unknown flag' }, 404) unless $flag;
    my $key = $c->param('key');
    my ($on, $reason) = _evaluate($flag, $key);
    return $c->json({
        name    => $flag->{name},
        key     => defined $key ? $key : JSON::PP::null,
        enabled => $on ? JSON::PP::true : JSON::PP::false,
        reason  => $reason,
    });
};

get '/flags' => sub {
    my ($c) = @_;
    my @out;
    for my $n (sort keys %FLAGS) {
        my $f = $FLAGS{$n};
        push @out, {
            name       => $f->{name},
            enabled    => $f->{enabled} ? JSON::PP::true : JSON::PP::false,
            rollout    => $f->{rollout},
            overrides  => scalar keys %{ $f->{overrides} },
        };
    }
    return $c->json({ count => scalar @out, flags => \@out });
};

put '/flags/:name' => sub {
    my ($c) = @_;
    my $name = $c->param('name');
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';

    my $enabled = _bool($b->{enabled});
    return $c->json({ error => 'enabled must be boolean' }, 400)
        unless defined $enabled;

    my $rollout = exists $b->{rollout} ? $b->{rollout} : 100;
    return $c->json({ error => 'rollout must be 0..100' }, 400)
        unless defined $rollout && $rollout =~ /^\d+$/ && $rollout <= 100;

    my $f = $FLAGS{$name} ||= { name => $name, overrides => {} };
    $f->{enabled} = $enabled;
    $f->{rollout} = 0 + $rollout;
    return $c->json({
        name    => $name,
        enabled => $f->{enabled} ? JSON::PP::true : JSON::PP::false,
        rollout => $f->{rollout},
    });
};

post '/flags/:name/override' => sub {
    my ($c) = @_;
    my $name = $c->param('name');
    my $flag = $FLAGS{$name};
    return $c->json({ error => 'unknown flag' }, 404) unless $flag;
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my $key = defined $b->{key} ? "$b->{key}" : '';
    return $c->json({ error => 'key required' }, 400) unless length $key;
    my $val = _bool($b->{enabled});
    return $c->json({ error => 'enabled must be boolean' }, 400) unless defined $val;
    $flag->{overrides}{$key} = $val;
    return $c->json({ name => $name, key => $key, enabled => $val ? JSON::PP::true : JSON::PP::false });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 99: 기능 플래그)

=head1 SYNOPSIS

GET  /flags/:name?key=   플래그 평가
PUT  /flags/:name        설정(enabled/rollout)
POST /flags/:name/override  개별 키 강제

=cut
