package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my @RECORDS;
my $SEQ = 0;

sub _problem {
    my ($c, $status, $title, $detail) = @_;
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({ type => 'about:blank', title => $title, status => $status,
                      (defined $detail ? (detail => $detail) : ()) }, $status);
}

# 아주 작은 CSV 파서: 쉼표 구분, "..." 인용, "" 이스케이프 지원
sub _parse_csv {
    my ($text) = @_;
    $text = '' unless defined $text;
    $text =~ s/\r\n/\n/g;
    $text =~ s/\r/\n/g;

    my (@rows, @row, $field, $in_q);
    $field = '';
    my @ch = split //, $text;
    my $n = scalar @ch;
    for (my $i = 0; $i < $n; $i++) {
        my $ch = $ch[$i];
        if ($in_q) {
            if ($ch eq '"') {
                if ($i + 1 < $n && $ch[$i + 1] eq '"') { $field .= '"'; $i++ }
                else { $in_q = 0 }
            } else { $field .= $ch }
        } else {
            if    ($ch eq '"') { $in_q = 1 }
            elsif ($ch eq ',') { push @row, $field; $field = '' }
            elsif ($ch eq "\n") { push @row, $field; push @rows, [@row]; @row = (); $field = '' }
            else  { $field .= $ch }
        }
    }
    push @row, $field if length($field) || @row;
    push @rows, [@row] if @row;
    return \@rows;
}

sub _trim { my ($s) = @_; $s = '' unless defined $s; $s =~ s/^\s+//; $s =~ s/\s+$//; return $s }

post '/import' => sub {
    my ($c) = @_;
    my $up = $c->req->upload('file');
    return _problem($c, 400, 'Bad Request', 'file part is required')
        unless $up;
    return _problem($c, 415, 'Unsupported Media Type', 'only .csv is accepted')
        unless $up->filename =~ /\.csv$/i;

    my $rows = _parse_csv($up->content);
    return _problem($c, 400, 'Bad Request', 'empty CSV') unless @$rows;

    my $header = shift @$rows;
    my %idx;
    for my $i (0 .. $#{$header}) {
        my $name = lc _trim($header->[$i]);
        $idx{$name} = $i if length $name;
    }
    for my $need (qw(name price)) {
        return _problem($c, 422, 'Unprocessable Entity', "missing column: $need")
            unless exists $idx{$need};
    }

    my (@ok, @errs);
    my $line = 1;   # 헤더가 1행
    for my $r (@$rows) {
        $line++;
        my $name  = $r->[ $idx{name} ];
        my $price = $r->[ $idx{price} ];
        $name  = defined $name  ? $name  : '';
        $price = defined $price ? $price : '';
        $name  =~ s/^\s+|\s+$//g;
        $price =~ s/^\s+|\s+$//g;

        if (!length $name) {
            push @errs, { line => $line, error => 'name is empty' };
            next;
        }
        if ($price !~ /^\d+(?:\.\d+)?$/) {
            push @errs, { line => $line, error => 'price must be a non-negative number' };
            next;
        }
        push @ok, { name => $name, price => 0 + $price };
    }

    for my $rec (@ok) {
        $SEQ++;
        $rec->{id} = $SEQ;
        push @RECORDS, $rec;
    }

    return $c->json({
        imported => scalar @ok,
        skipped  => scalar @errs,
        errors   => \@errs,
        total    => scalar @RECORDS,
    });
};

get '/records' => sub {
    my ($c) = @_;
    return $c->json({ count => scalar @RECORDS, records => \@RECORDS });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 81: CSV 대량 가져오기)

=head1 SYNOPSIS

POST /import   CSV 업로드 후 행 단위 검증/적재
GET  /records  적재 결과

=cut
