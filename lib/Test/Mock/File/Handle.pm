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

    return shift(@{$self->lines});
}

#@method
sub READ ($\$$;$) {
    my $self = $_[0];
    my $buffer_ref = \$_[1];
    my ($length, $offset) = @_[2, 3];

    return 0 unless ($self->content);

    $offset //= 0;

    my @bytes = unpack('U*', $self->content);
    my @chunk = splice(@bytes, $offset, $length);

    $$buffer_ref = pack('U*', @chunk);

    return scalar(@chunk);
}

#@method
sub CLOSE {
    my ($self) = @_;
}

#@property
#@method
sub lines {
    my ($self) = @_;

    my $key = '_lines';
    unless (exists($self->{$key})) {
        my $content_copy = $self->content;
        my $line_separator = '<LINE SEPARATOR>';
        $content_copy =~ s|$/|$/$line_separator|g;
        $self->{$key} = [split($line_separator, $content_copy)];
    }

    return $self->{$key};
}

#@property
#@method
sub content {
    my ($self) = @_;

    return $self->{content};
}

1;
