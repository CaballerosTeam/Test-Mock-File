package Test::Mock::File;

use 5.010001;
use strict;
use warnings;

use Carp;
use Scalar::Util;
use IO::Handle;

use Test::Mock::File::Constant;
use Test::Mock::File::Handle;

our $VERSION = '0.0.1';

my $INSTANCE;

BEGIN {
    *CORE::GLOBAL::open = sub (\$;$@) {
        my $self = __PACKAGE__->_get_instance();
        return $self->_dispatch_open(@_);
    }
}


sub new {
    my ($class) = @_;

    my $self = $class->_get_instance();
    unless ($self) {
        $self = bless({verbosity => 1, mock_files => {}}, $class);
        $class->_set_instance($self);
    }

    return $self;
}

#@method
sub _get_instance {
    return $INSTANCE;
}

#@method
sub _set_instance {
    my (undef, $self) = @_;

    Carp::confess("Not a 'Test::Mock::File'")
        if (!Scalar::Util::blessed($self) || !$self->isa('Test::Mock::File'));

    $INSTANCE = $self;

    return 1;
}

#@method
sub mock {
    my ($self, $file_path, %kwargs) = @_;

    $self->{mock_files}->{$file_path} = \%kwargs;

    return 1;
}

#@method
sub _dispatch_open {
    my ($self, @args) = @_;

    my $filehandle = $self->_get_filehandle(@args);
    warn(Carp::longmess("Can't fetch filehandle, resume normal 'open' operation"))
        if (!$filehandle && $self->verbosity);

    my $mode = $self->_get_mode(@args);
    warn(Carp::longmess("Can't fetch mode, resume normal 'open' operation"))
        if (!$mode && $self->verbosity);

    my $file_path = $self->_get_file_path(@args);
    warn(Carp::longmess("Can't fetch file path, resume normal 'open' operation"))
        if (!$file_path && $self->verbosity);

    if ($filehandle && $mode && $file_path && $self->_is_mocked($file_path)) {
        my $mock_file_assets = $self->_get_mock_file_assets($file_path);
        Carp::confess("Not a 'HASH' ref in mock assets") if (ref($mock_file_assets) ne 'HASH');

        $mock_file_assets->{mode} = $mode;

        return $self->_open($filehandle, %{$mock_file_assets});
    }
    else {
        my $arguments_number = scalar(@args);
        if ($arguments_number == 3) {
            return CORE::open(${$args[0]}, $args[1], $args[2]);
        }
        else {
            Carp::confess('[!] Not implemented');
        }
    }
}

#@method
sub _get_filehandle {
    my (undef, @args) = @_;

    return $args[0];
}

#@method
sub _get_mode {
    my ($self, @args) = @_;

    my $result;
    if (@args == 3) {
        $result = $self->_parse_mode($args[1]);
    }
    elsif (@args == 2) {
        $result = MODE_INPUT;
    }

    return $result;
}

#@staticmethod
#@method
sub _parse_mode {
    my (undef, $mode) = @_;

    my ($actual_mode, undef) = split(":", $mode, 2); # TODO: second argument is 'layer', should be implemented

    my $is_extended_mode = 0;
    if (index($actual_mode, '+') == 0) {
        $is_extended_mode = 1;
        $actual_mode = substr($actual_mode, 1);
    }

    my $mode_map = {
        '<'  => MODE_INPUT,
        '>'  => MODE_OUTPUT,
        '>>' => MODE_APPEND,
    };

    my $result;
    if (exists($mode_map->{$actual_mode})) {
        $result = $mode_map->{$actual_mode};
    }
    else {
        Carp::confess("[!] Unknown MODE '%s'", $actual_mode);
    }

    if ($is_extended_mode) {
        if ($result & MODE_INPUT) {
            $result |= MODE_OUTPUT;
        }
        elsif ($result & MODE_OUTPUT || $result & MODE_APPEND) {
            $result |= MODE_INPUT;
        }
    }

    return $result;
}

#@method
sub _get_file_path {
    my ($self, @args) = @_;

    my $result;
    if (@args == 2) {
        $result = $args[1];
    }
    elsif (@args == 3) {
        if (!defined($args[2]) && $self->verbosity) {
            warn('Form of pipe open not supported');
        }
        else {
            $result = $args[2];
        }
    }

    return $result;
}

#@method
sub _is_mocked {
    my ($self, $file_path) = @_;

    return exists($self->{mock_files}->{$file_path});
}

#@method
sub _get_mock_file_assets {
    my ($self, $file_path) = @_;

    return $self->{mock_files}->{$file_path};
}

#@method
sub _open {
    my (undef, $fh, %kwargs) = @_;

    local *FH;
    tie(*FH, 'Test::Mock::File::Handle', %kwargs);

    $$fh = *FH;

    return 1;
}

#@property
#@method
sub verbosity {
    my ($self) = @_;

    return $self->{verbosity};
}

1;
__END__

=head1 NAME

Test::Mock::File - Perl extension for mocking files in unit tests

=head1 SYNOPSIS

    use Test::Mock::File;

    my $file_path = 'foo/spam.txt';
    my $expected_content = <<TEXT;
bla-bla text
TEXT

    my $mock_file = Test::Mock::File->new();
    $mock_file->mock($file_path, content => $expected_content);

    open(my $fh, $file_path);

    my $actual_content = <$fh>; # $actual_content contains "bla-bla text\n"

    close($fh);

=head1 DESCRIPTION

Test::Mock::File helps testing the code that depends on files.

=head1 DISCLAIMER

Module still under development.

=head1 AUTHOR

Sergey Yurzin, E<lt>jurzin.s@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2017 by Sergey Yurzin

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
