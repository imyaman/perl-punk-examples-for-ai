package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my %POSTS;   # slug => { slug, title }

sub _slugify {
    my ($s) = @_;
    $s = lc($s // '');
    $s =~ s/[^a-z0-9]+/-/g;
    $s =~ s/^-+|-+$//g;
    $s = 'post' unless length $s;
    return $s;
}

sub _unique {
    my ($base) = @_;
    return $base unless exists $POSTS{$base};
    my $n = 2;
    $n++ while exists $POSTS{"$base-$n"};
    return "$base-$n";
}

post '/posts' => sub {
    my ($c) = @_;
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my $title = defined $b->{title} ? "$b->{title}" : '';
    return $c->json({ error => 'title required' }, 400) unless length $title;

    my $slug;
    if (defined $b->{slug} && length $b->{slug}) {
        $slug = _slugify($b->{slug});
        if (exists $POSTS{$slug}) {
            $c->header('Content-Type' => 'application/problem+json');
            return $c->json({
                type=>'about:blank', title=>'Conflict', status=>409,
                detail=>"slug '$slug' already exists",
            }, 409);
        }
    } else {
        $slug = _unique(_slugify($title));
    }

    $POSTS{$slug} = { slug => $slug, title => $title };
    $c->header('Location' => "/posts/$slug");
    return $c->json($POSTS{$slug}, 201);
};

get '/posts/:slug' => sub {
    my ($c) = @_;
    my $slug = $c->param('slug');
    my $p = $POSTS{$slug};
    return $c->json({ error => 'not found' }, 404) unless $p;
    return $c->json($p);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 71: 슬러그 생성과 유일성)

=head1 SYNOPSIS

POST /posts  제목으로 슬러그 자동 생성(중복 시 -2), 명시 슬러그 중복은 409

=cut
