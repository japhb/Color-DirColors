# ABSTRACT: Parse and apply GNU or BSD dircolors rules

unit class Color::DirColors;


=begin pod

=head1 NAME

Color::DirColors - Parse and apply GNU and BSD ls coloring rules


=head1 SYNOPSIS

=begin code :lang<raku>

use Color::DirColors;

=end code


=head1 DESCRIPTION

Color::DirColors is a helper for working with "dircolors", the rules that
determine colors and attributes for colorized output of the standard C<ls>
shell command.

Unfortunately the GNU and BSD implementations are wildly different, meaning
that it is annoyingly finicky to correctly parse and apply these across even
*nix variants.  This module smoothes out these differences and allows you to
determine correct ANSI SGR colors for any given IO::Path object.


=head1 AUTHOR

Geoffrey Broadwell <gjb@sonic.net>


=head1 COPYRIGHT AND LICENSE

Copyright 2025 Geoffrey Broadwell

This library is free software; you can redistribute it and/or modify it under
the Artistic License 2.0.

=end pod
