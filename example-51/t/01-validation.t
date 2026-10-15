#!/usr/bin/perl
use Test::More;
use JSON::PP;

my $BASE = 'http://127.0.0.1:3004';

sub _raw {
    my @cmd = @_;
    my $out = '';
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm(15);
        open(my $fh, "-|", @cmd) or die "open pipe: @cmd: $!";
        { local $/; $out = <$fh>; }
        close $fh;
        alarm(0);
    };
    return $@ ? '' : $out;
}
sub _post {
    my ($body) = @_;
    my $out = _raw('curl', '-s', '--max-time', '18', '-i', '-X', 'POST',
                   '-H', 'Content-Type: application/json', '--data-raw', $body,
                   "$BASE/users");
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }
sub _fields { [ map { $_->{field} } @{ shift->{errors} } ] }

is(_raw('curl','-s','-o','/dev/null','-w','%{http_code}',"$BASE/api/ping") eq '200' ? 1 : 0, 1, 'ping');

# 정상
{
    my $r = _post('{"name":"alice","email":"a@example.com","age":30}');
    is($r->{code}, '201', 'valid 201');
    is(_json($r)->{user}{name}, 'alice', 'name stored');
}

# age 없이도 정상(선택)
{
    my $r = _post('{"name":"bob","email":"b@example.com"}');
    is($r->{code}, '201', 'age optional 201');
}

# 필수 누락
{
    my $r = _post('{"email":"x@y.com"}');
    is($r->{code}, '422', 'missing name 422');
    is_deeply(_fields(_json($r)), ['name'], 'name error');
}

# 이메일 형식 오류
{
    my $r = _post('{"name":"carol","email":"nope"}');
    is($r->{code}, '422', 'bad email 422');
    is_deeply(_fields(_json($r)), ['email'], 'email error');
}

# 짧은 이름 + 범위 밖 나이
{
    my $r = _post('{"name":"a","email":"c@d.com","age":999}');
    is($r->{code}, '422', 'multiple errors 422');
    my $fs = _fields(_json($r));
    is_deeply($fs, ['age','name'], 'age and name errors');
}

# 정수가 아닌 나이
{
    my $r = _post('{"name":"dan","email":"d@e.com","age":"abc"}');
    is($r->{code}, '422', 'non-int age 422');
}

done_testing();
