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
    my (%h) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', 'POST',
               '-H', 'Content-Type: application/json', "$BASE/items");
    push @cmd, '-H', "Prefer: $h{prefer}" if $h{prefer};
    push @cmd, '--data-raw', $h{body} // '{}';
    my $out = _raw(@cmd);
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    my %hdr;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $hdr{lc $1} = $2;
    }
    return { code => $code, headers => \%hdr, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_raw('curl','-s','-o','/dev/null','-w','%{http_code}',"$BASE/api/ping") eq '200' ? 1 : 0, 1, 'ping');

# 기본: representation
{
    my $r = _post(body => '{"name":"a"}');
    is($r->{code}, '201', 'default 201');
    like($r->{headers}{'preference-applied'} // '', qr/return=representation/, 'applied representation');
    is(_json($r)->{name}, 'a', 'body present');
}

# minimal
{
    my $r = _post(prefer => 'return=minimal', body => '{"name":"b"}');
    is($r->{code}, '201', 'minimal 201');
    like($r->{headers}{'preference-applied'} // '', qr/return=minimal/, 'applied minimal');
    is($r->{body}, '', 'empty body');
    like($r->{headers}{location} // '', qr{/items/\d+}, 'location');
}

# Get created item shows it stored
{
    my $loc = _post(prefer => 'return=minimal', body => '{"name":"c"}')->{headers}{location};
    my $r = _raw('curl', '-s', '--max-time', '18', "$BASE$loc");
    like($r, qr/"name":"c"/, 'stored');
}

done_testing();
