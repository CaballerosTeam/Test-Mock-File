package TestFunctional;

use strict;
use warnings FATAL => 'all';
use parent 'TestCase';

use Cwd;
use File::Basename;
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

    open(my $fh, '<', $file_path) or do {
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

    open(my $fh, '<', $file_path) or do {
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

sub test_read_file__read_real_file_in_parallel: Test(2) {
    my ($self) = @_;

    my $mock_file_path = 'the/simpsons';
    my $expected_mock_content = <<TEXT;
Homer Simpson
TEXT

    $self->mock_file->mock($mock_file_path, content => $expected_mock_content);

    open(my $mock_fh, '<', $mock_file_path) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    my $package = 'TestCase';
    my $file_name = sprintf('%s.pm', $package);
    my $self_path = dirname(Cwd::realpath(__FILE__));
    my $file_path = join('/', $self_path, $file_name);
    
    open(my $fh, '<', $file_path) or do {
        fail(sprintf("Can't open file: %s: %s", $file_path, $!));
        return;
    };
    
    my $actual_real_content = readline($fh);
    my $actual_mock_content = readline($mock_fh);

    like($actual_real_content, qr/package $package/, 'Real content matches');
    is($actual_mock_content, $expected_mock_content, 'Mock content matches');

    close($fh);
    close($mock_fh);
}

sub test_fileno: Test(5) {
    my ($self) = @_;

    my $file_path = 'spam.conf';
    $self->mock_file->mock($file_path, content => 'bla');

    open(my $this, '<', $file_path) or do {
        fail(sprintf("'open' return error; error text: `%s`", $!));
        return;
    };

    open(my $that, '<', $file_path) or do {
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
