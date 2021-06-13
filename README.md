[![Build Status](https://travis-ci.org/kuerbis/Term-TablePrint-p6.svg?branch=master)](https://travis-ci.org/kuerbis/Term-TablePrint-p6)

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

`print-table` shows a table and lets the user interactively browse it. It provides a cursor which highlights the row on which it is located. The user can scroll through the table with the different cursor keys - see [KEYS](#KEYS).

If the table has more rows than the terminal, the table is divided up on as many pages as needed automatically. If the cursor reaches the end of a page, the next page is shown automatically until the last page is reached. Also if the cursor reaches the topmost line, the previous page is shown automatically if it is not already the first one.

If the terminal is too narrow to print the table, the columns are adjusted to the available width automatically.

If the option table-expand is enabled and a row is selected with `Return`, each column of that row is output in its own line preceded by the column name. This might be useful if the columns were cut due to the too low terminal width.

The following modifications are made (at a copy of the original data) to the table elements before the output.

Tab characters (`\t`) are replaces with a space.

Vertical spaces (`\v`) are squashed to two spaces

Control characters, code points of the surrogate ranges and non-characters are removed.

If the option *squash-spaces* is enabled leading and trailing spaces are removed from the array elements and spaces are squashed to a single space.

If an element looks like a number it is left-justified, else it is right-justified.

USAGE
=====

KEYS
----

Keys to move around:

  * the `ArrowDown` key (or the `j` key) to move down and the `ArrowUp` key (or the `k` key) to move up.

  * the `PageUp` key (or `Ctrl-B`) to go back one page, the `PageDown` key (or `Ctrl-F`) to go forward one page.

  * the `Insert` key to go back 10 pages, the `Delete` key to go forward 10 pages.

  * the `Home` key (or `Ctrl-A`) to jump to the first row of the table, the `End` key (or `Ctrl-E`) to jump to the last row of the table.

If *table-expand* is set to `0`, the `Return` key closes the table if the cursor is on the first row.

If *table-expand* is enabled and the cursor is on the first row, pressing `Return` three times in succession closes the table. If *table-expand* is set to `1` and the cursor is auto-jumped to the first row, it is required only one `Return` to close the table.

If the cursor is not on the first row:

  * with the option *table-expand* disabled the cursor jumps to the table head if `Return` is pressed.

  * with the option *table-expand* enabled each column of the selected row is output in its own line preceded by the column name if `Return` is pressed. Another `Return` closes this output and goes back to the table output. If a row is selected twice in succession, the pointer jumps to the first row.

If the width of the window is changed and the option *table-expand* is enabled, the user can rewrite the screen by choosing a row.

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

prompt
------

String displayed above the table.

color
-----

If this option is enabled, SRG ANSI escape sequences can be used to color the screen output.

0 - off (default)

1 - on (current selected element not colored)

2 - on (current selected element colored)

decimal-separator
-----------------

If set, numbers use *decimal-separator* as the decimal separator instead of the default decimal separator.

Allowed values: a character with a print width of `1`. If an invalid values is passed, *decimal-separator* falls back to the default value.

Default: . (dot)

max-rows
--------

Set the maximum number of used table rows. The used table rows are kept in memory.

To disable the automatic limit set *max-rows* to `0`.

If the number of table rows is equal to or higher than *max-rows*, the last row of the output says `REACHED LIMIT "MAX_ROWS": $limit` or `=LIMIT= $limit` if the previous doesn't fit in the row.

Default: 50_000

min-col-width
-------------

The columns with a width below or equal *min-col-width* are only trimmed if it is still required to lower the row width despite all columns wider than *min-col-width* have been trimmed to *min-col-width*.

Default: 30

mouse
-----

Set the *mouse* mode (see option `mouse` in [Term::Choose](https://github.com/kuerbis/Term-Choose-p6)).

Default: 0

progress-bar
------------

Set the progress bar threshold. If the number of fields (rows x columns) is higher than the threshold, a progress bar is shown while preparing the data for the output. Setting the value to `0` disables the progress bar.

Default: 5_000

save-screen
-----------

0 - off (default)

1 - use the alternate screen

squash-spaces
-------------

If *squash-spaces* is enabled, consecutive spaces are squashed to one space and leading and trailing spaces are removed.

Default: 0

tab-width
---------

Set the number of spaces between columns. If *format* is set to `2` and *tab-width* is even, the spaces between the columns are *tab-width* + 1 print columns.

Default: 2

table-expand
------------

If the option *table-expand* is enabled and `Return` is pressed, the selected table row is printed with each column in its own line. Exception: if the cursor auto-jumped to the first row, the first row will not be expanded.

0 - off

1 - on (default)

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

If *table-expand* is set to `0`, the cursor jumps to the to first row (if not already there) when `Return` is pressed.

Default: 1

table-name
----------

If set (string), *table_name* is added in the bottom line.

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

tput
----

The control of the cursor location, the highlighting of the cursor position and the marked elements and other options on the terminal is done via escape sequences.

`tput` is used to get the appropriate escape sequences.

Escape sequences to handle mouse input are hardcoded.

Monospaced font
---------------

It is required a terminal that uses a monospaced font which supports the printed characters.

CREDITS
=======

Thanks to the people from [Perl-Community.de](http://www.perl-community.de), from [stackoverflow](http://stackoverflow.com) and from [#perl6 on irc.freenode.net](irc://irc.freenode.net/#perl6) for the help.

AUTHOR
======

Matthäus Kiem <cuer2s@gmail.com>

LICENSE AND COPYRIGHT
=====================

Copyright 2016-2020 Matthäus Kiem.

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

