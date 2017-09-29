package TestFunctional;

use strict;
use warnings FATAL => 'all';
use parent 'TestCase';

use Scalar::Util;

use Test::More;


sub setUp: Test(setup) {
    my ($self) = @_;

    $self->{mock_file} = Test::Mock::File->new();
}

sub test_read_file__ok: Test {
    my ($self) = @_;

    my $file_path = 'foo/spam.txt';
    my $expected_content = <<TEXT;
bla-bla text
TEXT

    $self->mock_file->mock($file_path, content => $expected_content);

    open(my $fh, $file_path) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    my $actual_content = <$fh>;

    close($fh);

    is($actual_content, $expected_content, 'File content match');
}

sub test_read_file__handle_is_closed: Test {
    my ($self) = @_;

    my $file_path = 'foo/egg.log';
    $self->mock_file->mock($file_path, content => '');

    open(my $fh, $file_path) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    close($fh);

    eval {
        <$fh>;
    };

    if (my $err = $@) {
        like($err, qr/readline\(\) on closed filehandle/, 'Exception is thrown');
    }
    else {
        fail('Exceptioin is not thrown');
    }
}

sub test_fileno: Test(5) {
    my ($self) = @_;

    my $file_path = 'spam.conf';
    $self->mock_file->mock($file_path, content => 'bla');

    open(my $this, $file_path) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    open(my $that, $file_path) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    my ($this_fileno, $that_fileno) = (fileno($this), fileno($that));

    isnt($this_fileno, -1, 'File descriptor for a filehandle not -1');
    isnt($that_fileno, -1, 'File descriptor for a filehandle not -1');
    isnt($this_fileno, $that_fileno, 'File descriptors to the same file is not equal');

    close($this);

    $this_fileno = fileno($this);
    is($this_fileno, undef, 'Undefined returned if filehandle is closed');

    $that_fileno = fileno($that);
    ok(Scalar::Util::looks_like_number($that_fileno), 'Another filehandle still open');
}

#@property
#@returns Test::Mock::File
#@method
sub mock_file {
    my ($self) = @_;

    return $self->{mock_file};
}

1;
