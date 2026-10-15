#!/usr/bin/perl
use Test::More;
use JSON::PP;
use MIME::Base64 ();
use URI::Escape ();

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
sub _full {
    my ($path, %hdr) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
    push @cmd, '-H', "$_: $hdr{$_}" for sort keys %hdr;
    my $out = _raw(@cmd);
    my ($head, $body) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    my %h;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { code => $code, headers => \%h, body => ($body // '') };
}
sub _basic { 'Basic ' . MIME::Base64::encode_base64($_[0], '') }
sub _json  { JSON::PP->new->decode(shift->{body}) }

is(_full('/api/ping')->{code}, '200', 'ping 200 (public)');

# 자격증명 없음 -> 401 + 챌린지 헤더
{
    my $r = _full('/api/basic/me');
    is($r->{code}, '401', 'no auth 401');
    like($r->{headers}{'www-authenticate'} // '', qr/^Basic /, 'WWW-Authenticate challenge');
}

# 잘못된 비밀번호 -> 401
{
    my $r = _full('/api/basic/me', Authorization => _basic('alice:wrong'));
    is($r->{code}, '401', 'wrong password 401');
}

# 존재하지 않는 사용자 -> 401
{
    is(_full('/api/basic/me', Authorization => _basic('nobody:x'))->{code}, '401', 'unknown user 401');
}

# 올바른 자격증명 -> 200
{
    my $r = _full('/api/basic/me', Authorization => _basic('alice:pass123'));
    is($r->{code}, '200', 'valid creds 200');
    is(_json($r)->{user}, 'alice', 'user resolved');
}
{
    my $r = _full('/api/basic/me', Authorization => _basic('bob:hunter2'));
    is(_json($r)->{user}, 'bob', 'second user resolved');
}

done_testing();
