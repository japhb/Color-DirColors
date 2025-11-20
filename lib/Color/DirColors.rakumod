# ABSTRACT: Parse and apply GNU or BSD dircolors rules

unit class Color::DirColors;

use File::Stat < stat lstat >;
use Terminal::ANSIColor;


has %.type-rules;
has %.ext-rules;
has %.glob-rules;


#| Autodetect dircolors rules from env vars, returning a rule applier object
method new-from-env(--> Color::DirColors:D) {
    my $gnu = %*ENV<LS_COLORS>;
    my $bsd = %*ENV<LSCOLORS>;

    # This prioritizes GNU dircolors over BSD if both are found, because the
    # GNU rules are more expressive overall.  If neither are found, return an
    # empty rule applier object with no rules set.
    $gnu ?? self.new-from-gnu($gnu) !!
    $bsd ?? self.new-from-bsd($bsd) !!
            self.new
}

#| Parse dircolors rules from a GNU-formatted string, returning a rule applier object
method new-from-gnu(Str:D $gnu-rules --> Color::DirColors:D) {
    # Special two-character name mode/type GNU rules
    my constant %type-map =
        rs => 'reset', di => 'dir', ln => 'symlink', mh => 'multi_hardlink',
        pi => 'pipe', so => 'socket', do => 'door', bd => 'block', cd => 'char',
        or => 'orphan', mi => 'missing', su => 'setuid', sg => 'setgid',
        tw => 'dir_o+w_sticky', ow => 'dir_o+w', st => 'dir_sticky',
        ca => 'cap', ex => 'exe';

    # Split and categorize rules
    my @rules = $gnu-rules.split(':');
    my @type  = @rules.grep(/^ [a..z][a..z] '=' /);
    my @ext   = @rules.grep(/^ '*.' \w+     '=' /);
    my @glob  = keys @rules.grep(*.contains('*')) (-) @ext;

    # Convert rules to common format
    my %type-rules = @type.map({ my ($t, $r) = .split('=', 2);
                                 my $type = %type-map{$t};
                                 $type => self!color-from-gnu($r) if $type });
    my %glob-rules = @glob.map({ my ($g, $r) = .split('=', 2);
                                 $g => self!color-from-gnu($r) });
    my %ext-rules  = @ext.map({  my ($e, $r) = .substr(2).split('=', 2);
                                 $e => self!color-from-gnu($r) });

    # Build a Color::DirColors object with these GNU rules encoded
    self.new(:%type-rules, :%glob-rules, :%ext-rules)
}

#| Parse dircolors rules from a BSD-formatted string, returning a rule applier object
method new-from-bsd(Str:D $bsd-rules --> Color::DirColors:D) {
    # Order of rules in packed BSD string
    my constant @bsd-order = < dir symlink socket pipe exe block char
                               exe_setuid exe_setgid dir_o+w_sticky dir_o+w >;

    # Convert rules to common format
    my %rules = @bsd-order Z=> $bsd-rules.comb(2).map({ self!color-from-bsd-pair($_) });

    # Build a Color::DirColors object with the BSD type rules encoded
    self.new(type-rules => %rules)
}

#| Apply parsed dircolors rules to an IO::Path object, returning a
#| Terminal::ANSIColor color string (e.g. "bold red on_black")
method color-for(::?CLASS:D: IO::Path:D() $path --> Str:D) {
    self!best-color-rule($path);
}

#| Apply parsed dircolors rules to an IO::Path object, returning an ANSI SGR
#| color string (e.g. "\e[1;31;40m").  If $bare is True, only include the
#| SGR codes themselves, skipping the leading "\e[" and trailing "m".
method sgr-for(::?CLASS:D: IO::Path:D() $path, Bool:D :$bare = False --> Str:D) {
    my $rule = self!best-color-rule($path);
    my $sgr  = color($rule);
    $sgr    .= substr(2, *-1) if $bare;
    $sgr
}

# (PRIVATE) Find the coloring rule that best applies to a given path
method !best-color-rule(::?CLASS:D: IO::Path:D $path --> Str:D) {
    my constant @mtypes =
        '', 'pipe', 'char', '', 'dir', '', 'block', '',
        '', '', 'symlink', '', 'socket', '', 'whiteout', '';

    # First try rules based on mode (inode type info and permission bits);
    # failure to stat a mode at all indicates an orphan.
    my ($mtype, $type);
    my $stat   = lstat($path);
    my $mode   = $stat.mode;
    if $mode.defined {
        $mtype = ($mode +& 0o170000) +> 12;
        $type  = @mtypes[$mtype];
    }
    else {
        $mode  = 0;
        $mtype = 0;
        $type  = 'orphan';
    }

    # Specialize 'dir' type if non-empty rules for sticky/o+w and mode matches
    if $type eq 'dir' {
        my $ow = $mode +& 0o0002;
        my $st = $mode +& 0o1000;
        $type  = 'dir_sticky'     if        $st && %.type-rules{'dir_sticky'};
        $type  = 'dir_o+w'        if $ow        && %.type-rules{'dir_o+w'};
        $type  = 'dir_o+w_sticky' if $ow && $st && %.type-rules{'dir_o+w_sticky'};
    }
    # Check for orphaned symlinks
    elsif $type eq 'symlink' {
        $type  = 'orphan' if !$path.readlink.e && %.type-rules<orphan>;
    }

    # Check for multiple hardlinks
    unless %.type-rules{$type} {
        $type = 'multi_hardlink' if $stat.nlink > 1 && %.type-rules<multi_hardlink>;
    }

    # Check for setuid/setgid, and whether they are on something executable
    my $exe    = $mode +& 0o0111;
    my $setuid = $mode +& 0o4000;
    my $setgid = $mode +& 0o2000;

    $type = 'setgid' if $setgid && %.type-rules<setgid>;
    $type = 'setuid' if $setuid && %.type-rules<setuid>;
    if $exe {
        $type = 'exe_setgid' if $setgid && %.type-rules<exe_setgid>;
        $type = 'exe_setuid' if $setuid && %.type-rules<exe_setuid>;
    }

    # If we've got a non-empty mode/type rule, choose that one
    return %.type-rules{$type} if %.type-rules{$type};

    # Nothing special found in mode matches, try extension and return if found
    my $ext      = $path.ext;
    my $ext-rule = %.ext-rules{$ext};
    return %.ext-rules{$ext} if %.ext-rules{$ext};

    # Extension didn't match, try a general glob if any match
    my $basename  = $path.basename;
    my $glob-rule; # = %glob-rules.keys.first({ ... });  # XXXX: Glob match basename

    # Glob or bust
    $glob-rule // ''
}

# (PRIVATE) Convert a BSD two-letter code to a Terminal::ANSIColor color string
method !color-from-bsd-pair(Str:D $pair where *.chars == 2 --> Str:D) {
    constant %bsd-map = a => 'black', b => 'red',     c => 'green', d => 'yellow',
                        e => 'blue',  f => 'magenta', g => 'cyan',  h => 'white',
                        A => 'black bold',  B => 'red bold',  C => 'green bold',
                        D => 'yellow bold', E => 'blue bold', F => 'magenta bold',
                        G => 'cyan bold',   H => 'white bold';

    my ($fg, $bg) = $pair.comb;
    my $fg-rule   = %bsd-map{$fg} // '';
    my $bg-rule   = %bsd-map{$bg} // '';

    (($fg-rule if $fg-rule), ('on_' ~ $bg-rule if $bg-rule)).join(' ')
}

# (PRIVATE) Convert GNU pseudo-SGR codes to a Terminal::ANSIColor color string
method !color-from-gnu(Str:D $gnu --> Str:D) {
    # XXXX: Need to fill in conversions
    # XXXX: Sadly can't just use uncolor() because GNU codes aren't quite SGR

    my constant %color-map =
        # XXXX: blink (05) and concealed (08) not supported by Terminal::ANSIColor
        # XXXX: Codes > 47 not yet supported
        '00' => '', '01' => 'bold', '04' => 'underscore', '07' => 'inverse',
        30 => 'black', 31 => 'red', 32 => 'green', 33 => 'yellow',
        34 => 'blue', 35 => 'magenta', 36 => 'cyan', 37 => 'white',
        40 => 'on_black', 41 => 'on_red', 42 => 'on_green', 43 => 'on_yellow',
        44 => 'on_blue', 45 => 'on_magenta', 46 => 'on_cyan', 47 => 'on_white';

    $gnu.split(';').map({ %color-map{$_} }).grep(?*).join(' ')
}


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
