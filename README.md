# Test-Mock-File

[![Build Status](https://travis-ci.org/CaballerosTeam/Test-Mock-File.svg?branch=master)](https://travis-ci.org/CaballerosTeam/Test-Mock-File)

## NAME

Test::Mock::File - Perl extension for mocking files in unit tests

## SYNOPSIS

```perl extension language
    use Test::Mock::File;

    my $file_path = 'foo/spam.txt';
    my $expected_content = <<TEXT;
bla-bla text
TEXT

    $self->mock_file->mock($file_path, content => $expected_content);

    open(my $fh, $file_path);

    my $actual_content = <$fh>; # $actual_content contains "bla-bla text\n"

    close($fh);
```

## DESCRIPTION

Test::Mock::File helps testing the code that depends on files.

## INSTALL

```bash
> perl Makefile.PL
> make
> make test
> sudo make install 
```

## DISCLAIMER

Module still under development.

## AUTHOR

Sergey Yurzin, E<lt>jurzin.s@gmail.comE<gt>

## COPYRIGHT AND LICENSE

Copyright (C) 2017 by Sergey Yurzin

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.
