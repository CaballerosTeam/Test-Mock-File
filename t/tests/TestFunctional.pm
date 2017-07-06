package TestFunctional;

use strict;
use warnings FATAL => 'all';
use parent 'TestCase';

use Test::More;


sub setUp: Test(setup) {
    my ($self) = @_;

    $self->{mock_file} = Test::Mock::File->new();
}

sub test_read_file: Test {
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

#@property
#@returns Test::Mock::File
#@method
sub mock_file {
    my ($self) = @_;

    return $self->{mock_file};
}

1;
