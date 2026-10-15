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
sub _get_full {
    my ($path) = @_;
    my $out = _raw('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
    my ($head, $body) = split /\r?\n\r?\n/, $out, 2;
    my %h;
    for my $line (split /\r?\n/, ($head // '')) {
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { headers => \%h, body => ($body // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

{
    my $r = _get_full('/api/work');
    is(_json($r)->{did}, 'work', 'handler ran');
    like($r->{headers}{'x-runtime-ms'} // '', qr/^\d+$/, 'X-Runtime-Ms is numeric');
}

{
    my $r = _get_full('/api/ping');
    ok(exists $r->{headers}{'x-runtime-ms'}, 'middleware wraps every response');
}

done_testing();
