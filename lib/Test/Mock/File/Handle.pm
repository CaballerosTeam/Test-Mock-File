package Test::Mock::File::Handle;

use strict;
use warnings FATAL => 'all';
use parent 'Tie::Handle';

use Fcntl;
use Carp;


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

#@method
sub SEEK {
    my ($self, $offset, $whence) = @_;

    Carp::confess('Offset is undefined') unless (defined($offset));

    $whence //= Fcntl::SEEK_SET;

    Carp::confess('Unknow WHENCE value') if (
        $whence ne Fcntl::SEEK_SET
        && $whence ne Fcntl::SEEK_CUR
        && $whence ne Fcntl::SEEK_END
    );

    Carp::confess('Offset should be negative if SEEK_END in use') if (
        $whence eq Fcntl::SEEK_END
        && $offset > 0
    );

    my $new_offset = 0;
    if ($whence eq Fcntl::SEEK_SET) {
        $new_offset = $offset;
    }
    elsif ($whence eq Fcntl::SEEK_CUR) {
        $new_offset = $self->cursor + $offset;
    }
    else {
        # $whence eq Fcntl::SEEK_END
        $new_offset = $self->content_length + $offset;
    }

    $new_offset = 0 if ($new_offset < 0);
    $new_offset = $self->content_length if ($new_offset > $self->content_length);

    $self->set_cursor($new_offset);

    return 1;
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

#@method
sub set_cursor {
    my ($self, $offset) = @_;

    Carp::confess("Missing required argument 'offset'") unless (defined($offset));

    $self->{_cursor} = $offset;

    return 1;
}

#@property
#@method
sub cursor {
    my ($self) = @_;

    my $key = '_cursor';
    unless (exists($self->{$key})) {
        $self->{$key} = 0;
    }

    return $self->{$key};
}

#@property
#@method
sub content_length {
    my ($self) = @_;

    my $key = '_content_length';
    unless (defined($self->{$key})) {
        my $length = 0;

        if ($self->content) {
            my @bytes = unpack('U*', $self->content);
            $length = scalar(@bytes);
        }

        $self->{$key} = $length;
    }

    return $self->{$key};
}

1;
