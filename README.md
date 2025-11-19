### method new-from-env

```raku
method new-from-env() returns Color::DirColors:D
```

Autodetect dircolors rules from env vars, returning a rule applier object

### method new-from-gnu

```raku
method new-from-gnu(
    Str:D $gnu-rules
) returns Color::DirColors:D
```

Parse dircolors rules from a GNU-formatted string, returning a rule applier object

### method new-from-bsd

```raku
method new-from-bsd(
    Str:D $bsd-rules
) returns Color::DirColors:D
```

Parse dircolors rules from a BSD-formatted string, returning a rule applier object

### method color-for

```raku
method color-for(
    IO::Path:D(Any):D $path
) returns Str:D
```

Apply parsed dircolors rules to an IO::Path object, returning a Terminal::ANSIColor color string (e.g. "bold red on_black")

### method sgr-for

```raku
method sgr-for(
    IO::Path:D(Any):D $path,
    Bool:D :$bare = Bool::False
) returns Str:D
```

Apply parsed dircolors rules to an IO::Path object, returning an ANSI SGR color string (e.g. "\e[1;31;40m"). If $bare is True, only include the SGR codes themselves, skipping the leading "\e[" and trailing "m".

NAME
====

Color::DirColors - Parse and apply GNU and BSD ls coloring rules

SYNOPSIS
========

```raku
use Color::DirColors;
```

DESCRIPTION
===========

Color::DirColors is a helper for working with "dircolors", the rules that determine colors and attributes for colorized output of the standard `ls` shell command.

Unfortunately the GNU and BSD implementations are wildly different, meaning that it is annoyingly finicky to correctly parse and apply these across even *nix variants. This module smoothes out these differences and allows you to determine correct ANSI SGR colors for any given IO::Path object.

AUTHOR
======

Geoffrey Broadwell <gjb@sonic.net>

COPYRIGHT AND LICENSE
=====================

Copyright 2025 Geoffrey Broadwell

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

