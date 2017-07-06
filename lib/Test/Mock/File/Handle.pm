package Test::Mock::File::Handle;

use strict;
use warnings FATAL => 'all';
use parent 'Tie::Handle';


#@method
sub TIEHANDLE {
    my ($class, %kwargs) = @_;

    return bless(\%kwargs, $class);
}

#@method
sub READLINE {
    my ($self) = @_;

    return $self->content;
}

#@method
sub CLOSE {
    my ($self) = @_;
}

#@property
#@method
sub content {
    my ($self) = @_;

    return $self->{content};
}

1;
