package Test::Mock::File::Handle;

use strict;
use warnings FATAL => 'all';
use parent 'Tie::Handle';

use Carp;
use Fcntl;
use Scalar::Util;

use Test::Mock::File::Constant;

my $FILE_DESCRIPTOR_MAP = {};


#@method
sub TIEHANDLE {
    my ($class, %kwargs) = @_;

    Carp::confess("Not a SCALAR ref in 'content'") if (ref($kwargs{content}) ne 'SCALAR');

    my $self = bless(\%kwargs, $class);

    $self->set_is_opened(1);

    if ($self->has_append_mode) {
        my $content_length = $self->content_length;
        $self->set_cursor($content_length);
    }

    return $self;
}

sub PRINTF {
    my ($self, $fmt, @list) = @_;

    my $string = sprintf($fmt, @list);

    return $self->PRINT($string);
}

sub PRINT {
    my ($self, @args) = @_;

    $self->check_handle(PRINT_METHOD);

    my $new_content = join('', @args);
    my $new_content_length = length($new_content); # TODO: probably should be replaced with bytes::length
    my $cursor = $self->cursor;
    my $content = $self->content;

    if ($cursor < $self->content_length) {
        substr($content, $cursor, $new_content_length, $new_content);
    }
    else {
        $content .= $new_content;
    }

    $self->set_content($content);
    $self->set_cursor($cursor + $new_content_length);
    $self->reset_content_length();

    return 1;
}

#@method
sub READLINE {
    my ($self) = @_;

    $self->check_handle(READLINE_METHOD);

    return shift(@{$self->lines});
}

#@method
sub READ ($\$$;$) {
    my $self = $_[0];
    my $buffer_ref = \$_[1];
    my ($length, $offset) = @_[2, 3];

    $self->check_handle(READ_METHOD);
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

    return $self->set_is_opened(0);
}

#@method
sub SEEK {
    my ($self, $offset, $whence) = @_;

    Carp::confess('Offset is undefined') unless (defined($offset));
    $self->check_handle(SEEK_METHOD);

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
        $content_copy =~ s|$/|$/$line_separator|g if (defined($/));
        $self->{$key} = [split($line_separator, $content_copy)];
    }

    return $self->{$key};
}

#@method
sub set_content {
    my ($self, $content) = @_;

    Carp::confess("Missing required argument 'content'") unless (defined($content));

    ${$self->{content}} = $content;

    $self->reset_content_length();

    return 1;
}

#@property
#@method
sub content {
    my ($self) = @_;

    return ${$self->{content}};
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

#@method
sub reset_content_length {
    my ($self) = @_;

    undef($self->{_content_length});

    return 1;
}

#@method
sub check_handle {
    my ($self, $method_name) = @_;

    Carp::confess(sprintf('%s() on closed filehandle', $method_name)) unless ($self->is_opened);

    if (
        ($method_name eq READ_METHOD || $method_name eq READLINE_METHOD)
        && !$self->has_input_mode
    ) {
        Carp::confess(sprintf('Filehandle opened only for %s', MODE_TITLE_MAP->{MODE_OUTPUT()}));
    }
    elsif (
        ($method_name eq PRINT_METHOD || $method_name eq PRINTF_METHOD)
        && !($self->has_output_mode || $self->has_append_mode)
    ) {
        Carp::confess(sprintf('Filehandle opened only for %s', $self->mode_title));
    }

    return 1;
}

#@method
sub FILENO {
    my ($self) = @_;

    return unless ($self->is_opened);

    my $uid = $self->uid;
    unless (exists($FILE_DESCRIPTOR_MAP->{$uid})) {
        my $files_number = scalar(keys(%{$FILE_DESCRIPTOR_MAP}));
        my $next_file_descriptor = $files_number + 1;
        $FILE_DESCRIPTOR_MAP->{$uid} = $next_file_descriptor;
    }

    return $FILE_DESCRIPTOR_MAP->{$uid};
}

#@property
#@method
sub is_opened {
    my ($self) = @_;

    return $self->{_is_opened};
}

#@method
sub set_is_opened {
    my ($self, $flag) = @_;

    Carp::confess("Missing required argument 'flag'") unless (defined($flag));

    $self->{_is_opened} = $flag ? 1 : 0;

    return 1;
}

#@property
#@method
sub uid {
    my ($self) = @_;

    my $key = '_uid';
    $self->{$key} = Scalar::Util::refaddr($self) unless (defined($self->{$key}));

    return $self->{$key};
}

#@property
#@method
sub has_input_mode {
    my ($self) = @_;

    return $self->mode & MODE_INPUT;
}

#@property
#@method
sub has_output_mode {
    my ($self) = @_;

    return $self->mode & MODE_OUTPUT;
}

#@property
#@method
sub has_append_mode {
    my ($self) = @_;

    return $self->mode & MODE_APPEND;
}

#@property
#@method
sub mode {
    my ($self) = @_;

    return $self->{mode} // MODE_INPUT;
}

#@property
#@method
sub mode_title {
    my ($self) = @_;

    return MODE_TITLE_MAP->{$self->mode};
}

1;
