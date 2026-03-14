NAME
====

Term::TablePrint - Print a table to the terminal and browse it interactively.

SYNOPSIS
========

        use Term::TablePrint :print-table;


        my @table = ( [ 'id', 'name' ],
                      [    1, 'Ruth' ],
                      [    2, 'John' ],
                      [    3, 'Mark' ],
                      [    4, 'Nena' ], );


        # Functional style:

        print-table( @table );


        # or OO style:

        my $pt = Term::TablePrint.new();

        $pt.print-table( @table, :mouse(1) );

DESCRIPTION
===========

`print-table` shows a table and lets the user interactively browse it. It provides a cursor which highlights the row on which it is located. The user can scroll through the table with the different cursor keys.

KEYS
----

Keys to move around:

  * the ArrowDown key (or the j key) to move down and the ArrowUp key (or the k key) to move up.

  * the PageUp key (or Ctrl-P) to go to the previous page, the PageDown key (or Ctrl-N) to go to the next page.

  * the Insert key to go back 10 pages, the Delete key to go forward 10 pages.

  * the Home key (or Ctrl-A) to jump to the first row of the table, the End key (or Ctrl-E) to jump to the last row of the table.

If *table-expand* is set to `0`, the Enter key closes the table if the cursor is on the first row.

If *table-expand* is enabled and the cursor is on the first row, pressing Enter three times in succession closes the table. If the cursor is auto-jumped to the first row, it is required only one Enter to close the table.

If the cursor is not on the first row:

  * with the option *table-expand* disabled the cursor jumps to the table head if Enter is pressed.

  * with the option *table-expand* enabled each column of the selected row is output in its own line preceded by the column name if Enter is pressed. Another Enter closes this output and goes back to the table output. If a row is selected twice in succession, the pointer jumps to the first row.

If the size of the window has changed, the screen is rewritten as soon as the user presses a key.

Ctrl-F opens a prompt. A regular expression is expected as input. This enables one to only display rows where at least one column matches the entered pattern. See option [search](#search).

Output
------

If the option table-expand is enabled and a row is selected with Enter, each column of that row is output in its own line preceded by the column name.

If the table has more rows than the terminal, the table is divided up on as many pages as needed automatically. If the cursor reaches the end of a page, the next page is shown automatically until the last page is reached. Also if the cursor reaches the topmost line, the previous page is shown automatically if it is not already the first page.

For the output on the screen the table elements are modified. All the modifications are made on a copy of the original table data.

  * If an element is not defined the value from the option *undef* is assigned to that element.

  * Each character tabulation (`\t`) is replaces with a space.

  * Vertical tabulations (`\v+`) are squashed to two spaces.

  * Code points from the ranges of `control`, `surrogate` and `noncharacter` are removed.

  * If the option *squash-spaces* is enabled leading and trailing spaces are removed and multiple consecutive spaces are squashed to a single space.

  * If an element looks like a number it is right-justified, else it is left-justified.

If the terminal is too narrow to print the table, the columns are adjusted to the available width automatically.

  * First, if the option *trunc-fract-first* is enabled and if there are numbers that have a fraction, the fraction is truncated up to two decimal places.

  * Then columns wider than *col-trim-threshold* are trimmed. See option [col-trim-threshold](#col-trim-threshold).

  * If it is still required to lower the row width all columns are trimmed until they fit into the terminal.

CONSTRUCTOR
===========

The constructor method `new` can be called with named arguments. For the valid options see [OPTIONS](#OPTIONS). Setting the options in `new` overwrites the default values for the instance.

ROUTINES
========

print-table
-----------

`print-table` prints the table passed with the first argument.

    print-table( @table, *%options );

The first argument is an list of arrays. The first array of these arrays holds the column names. The following arrays are the table rows where the elements are the field values.

The following arguments set the options (key-values pairs).

OPTIONS
=======

Defaults may change in future releases.

binary-filter
-------------

How to print arbitrary binary data:

0 - Print the binary data as it is.

1 - "BNRY" is printed instead of the binary data.

2 - The binary data is printed in hexadecimal format.

If the substring of the first 100 characters of the data matches the repexp `/<[\x00..\x08\x0B..\x0C\x0E..\x1F]>/`, the data is considered arbitrary binary data.

Printing unfiltered arbitrary binary data could break the output.

Default: 0

choose-columns
--------------

Controls whether the user can choose which columns to display.

0 - Disabled

The user is never prompted to select columns.

1 - Always

The user is always prompted to select which columns to display.

In this mode, `print_table` runs in an internal loop: after the table is displayed, the user is returned to the column selection screen. This allows for iterative viewing until the user exits by selecting the `" << "` (Back) menu entry.

If the chosen columns exceed the terminal width, `print_table` falls back to the behavior described in item 2 (treating the chosen columns as the new "full" set).

2 - Smart

The user is prompted to select columns only if the table is too wide for the current terminal.

Even if columns are hidden in the multi-row view:

- The single-row view still displays all columns.

- Searching with `Ctrl-F` scans all columns, including hidden ones.

color
-----

If this option is enabled, SRG ANSI escape sequences can be used to color the screen output. Colors are reset to normal after each table cell.

0 - off (default)

1 - on (current selected element not colored)

2 - on (current selected element colored)

col-trim-threshold
------------------

The columns with a width below or equal *col-trim-threshold* are only trimmed, if it is still required to lower the row width despite all columns wider than *col-width-treshold* have been trimmed to *col-trim-threshold*.

decimal-separator
-----------------

If set, numbers use *decimal-separator* as the decimal separator instead of the default decimal separator.

Allowed values: a character with a print width of `1`. If an invalid values is passed, *decimal-separator* falls back to the default value.

Default: . (dot)

expanded-line-spacing
---------------------

0 - Disabled

1 - Insert a blank line between columns when a row is expanded.

Default: 1

expanded-max-width
------------------

Set a maximum width of the expanded table row output. (See option [table-expand](#table-expand)).

footer
------

If set (string), *footer* is added in the bottom line.

max-rows
--------

Set the maximum number of used table rows. The used table rows are kept in memory.

To disable the automatic limit set *max-rows* to `0`.

If the number of table rows is equal to or higher than *max-rows*, the last row of the output says `REACHED LIMIT "MAX_ROWS": $limit` or `=LIMIT= $limit` if the previous doesn't fit in the row.

Default: 50_000

max-width-exp
-------------

This option has been renamed to [expanded-max-width](#expanded-max-width).

min-col-width
-------------

This options has been renamed to [col-trim-threshold](#col-trim-threshold).

mouse
-----

Set the *mouse* mode (see option `mouse` in [Term::Choose](https://github.com/kuerbis/Term-Choose-p6)).

Default: 0

pad-row-edges
-------------

Add a space at the beginning and end of each row.

0 - off (default)

1 - enabled

progress-bar
------------

Set the progress bar threshold. If the number of fields (rows x columns) is higher than the threshold, a progress bar is shown while preparing the data for the output. Setting the value to `0` disables the progress bar.

Default: 5_000

prompt
------

String displayed above the table.

save-screen
-----------

0 - off (default)

1 - use the alternate screen

search
------

Set the behavior of Ctrl-F.

0 - off

1 - case-insensitive search (default)

2 - case-sensitive search

squash-spaces
-------------

If *squash-spaces* is enabled, consecutive spaces are squashed to one space and leading and trailing spaces are removed.

Default: 0

table-expand
------------

If *table-expand* is enabled and Enter is pressed, the selected table row prints with each column on a new line. Pressing Enter again closes this view. The next Enter key press will automatically jump the cursor to the first row. If the cursor has automatically jumped to the first row, pressing Enter will close the table instead of expanding the first row. Pressing any key other than Enter resets these special behaviors.

        .----------------------------.        .----------------------------.
        |col1 | col2   | col3 | col3 |        |                            |
        |-----|--------|------|------|        |col1 : ..........           |
        |.... | ...... | .... | .... |        |                            |
        |.... | ...... | .... | .... |        |col2 : .....................|
       >|.... | ...... | .... | .... |        |       ..........           |
        |.... | ...... | .... | .... |        |                            |
        |.... | ...... | .... | .... |        |col3 : .......              |
        |.... | ...... | .... | .... |        |                            |
        |.... | ...... | .... | .... |        |col4 : .............        |
        |.... | ...... | .... | .... |        |                            |
        '----------------------------'        '----------------------------'

If *table-expand* is set to `0`, the cursor jumps to the to first row (if not already there) when Enter is pressed.

0 - off

1 - on (default)

tab-width
---------

Set the number of spaces between columns. If *format* is set to `2` and *tab-width* is even, the spaces between the columns are *tab-width* + 1 print columns.

Default: 2

trunc-fract-first
-----------------

If the terminal width is not wide enough and this option is enabled, the first step to reduce the width of the columns is to truncate the fraction part of numbers to 2 decimal places.

undef
-----

Set the string that will be shown on the screen instead of an undefined field.

Default: "" (empty string)

ENVIRONMET VARIABLES
====================

multithreading
--------------

`Term::TablePrint` uses multithreading when preparing the list for the output; the number of threads to use can be set with the environment variable `TC_NUM_THREADS`.

REQUIREMENTS
============

Escape sequences
----------------

The control of the cursor location, the highlighting of the cursor position is done via escape sequences.

By default `Term::Choose` uses `tput` to get the appropriate escape sequences. If the environment variable `TC_ANSI_ESCAPES` is set to a true value, hardcoded ANSI escape sequences are used directly without calling `tput`.

The escape sequences to enable the *mouse* mode are always hardcoded.

If the environment variable `TERM` is not set to a true value, `vt100` is used instead as the terminal type for `tput`.

Monospaced font
---------------

It is required a terminal that uses a monospaced font which supports the printed characters.

Restrictions
------------

Term::TablePrint is not installable on Windows.

CREDITS
=======

Thanks to the people from [Perl-Community.de](http://www.perl-community.de), from [stackoverflow](http://stackoverflow.com) and from [#perl6 on irc.freenode.net](irc://irc.freenode.net/#perl6) for the help.

AUTHOR
======

Matthäus Kiem <cuer2s@gmail.com>

LICENSE AND COPYRIGHT
=====================

Copyright 2016-2026 Matthäus Kiem.

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

