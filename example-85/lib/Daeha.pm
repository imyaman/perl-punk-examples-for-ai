package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my %DOCS;    # id => text
my %POST;    # term => { id => tf }
my $SEQ = 0;

# 소문자 영숫자 토큰으로 분해
sub _tokens {
    my ($text) = @_;
    $text = lc(defined $text ? $text : '');
    return grep { length } split /[^a-z0-9]+/, $text;
}

sub _index {
    my ($id, $text) = @_;
    my %tf;
    $tf{$_}++ for _tokens($text);
    $DOCS{$id} = $text;
    $POST{$_}{$id} = $tf{$_} for keys %tf;
}

sub _unindex {
    my ($id) = @_;
    delete $DOCS{$id};
    for my $term (keys %POST) {
        delete $POST{$term}{$id};
        delete $POST{$term} unless %{ $POST{$term} };
    }
}

post '/documents' => sub {
    my ($c) = @_;
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my $text = defined $b->{text} ? "$b->{text}" : '';
    return $c->json({ error => 'text required' }, 400) unless length $text;

    my $id = (defined $b->{id} && length $b->{id}) ? "$b->{id}" : 'doc-' . (++$SEQ);
    my $existed = exists $DOCS{$id};
    _unindex($id) if $existed;   # 교체 시 이전 색인 제거
    _index($id, $text);

    return $c->json({ id => $id, indexed_terms => (scalar _tokens($text)), updated => $existed ? 1 : 0 },
                    $existed ? 200 : 201);
};

get '/documents/:id' => sub {
    my ($c) = @_;
    my $id = $c->param('id');
    return $c->json({ error => 'unknown document' }, 404) unless exists $DOCS{$id};
    return $c->json({ id => $id, text => $DOCS{$id} });
};

del '/documents/:id' => sub {
    my ($c) = @_;
    my $id = $c->param('id');
    return $c->json({ error => 'unknown document' }, 404) unless exists $DOCS{$id};
    _unindex($id);
    return $c->text('', 204);
};

get '/search' => sub {
    my ($c) = @_;
    my $q = $c->param('q');
    return $c->json({ error => 'q required' }, 400) unless defined $q && length $q;

    my @terms = _tokens($q);
    return $c->json({ query => $q, count => 0, results => [] }) unless @terms;

    # 모든 질의어를 포함하는 문서의 교집합(AND)
    my %candidates;
    my $first = $POST{ $terms[0] } // {};
    %candidates = map { $_ => 1 } keys %$first;
    for my $t (@terms[1 .. $#terms]) {
        my $p = $POST{$t} // {};
        %candidates = map { $_ => 1 } grep { $p->{$_} } keys %candidates;
    }

    my @results;
    for my $id (keys %candidates) {
        my $score = 0;
        $score += ($POST{$_}{$id} // 0) for @terms;   # 단순 tf 합산
        push @results, { id => $id, score => $score, text => $DOCS{$id} };
    }
    @results = sort { $b->{score} <=> $a->{score} || $a->{id} cmp $b->{id} } @results;

    return $c->json({ query => $q, terms => \@terms, count => scalar @results, results => \@results });
};

get '/index/stats' => sub {
    my ($c) = @_;
    my $postings = 0;
    $postings += scalar keys %{ $POST{$_} } for keys %POST;
    return $c->json({ documents => scalar keys %DOCS, terms => scalar keys %POST, postings => $postings });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 85: 역색인 전문 검색)

=head1 SYNOPSIS

POST /documents   문서 색인
GET  /search      질의어 AND 검색 + tf 랭킹

=cut
