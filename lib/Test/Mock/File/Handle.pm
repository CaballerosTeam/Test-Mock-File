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
