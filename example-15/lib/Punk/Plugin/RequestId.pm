package Punk::Plugin::RequestId;

use strict;
use warnings;
use parent 'Punk::Plugin';

my $seq = 0;

sub register {
    my ($self, $app, $opts) = @_;
    my $prefix = $opts->{prefix} // 'req';

    $app->helper(request_id => sub {
        my ($c) = @_;
        return $c->stash->{request_id};
    });

    $app->hook(before_dispatch => sub {
        my ($c) = @_;
        $c->stash->{request_id} = sprintf '%s-%06d', $prefix, ++$seq;
        return;
    });

    return;
}

1;

__END__

=head1 NAME

Punk::Plugin::RequestId - 앱에 request id 헬퍼와 훅을 설치하는 플러그인

=cut
