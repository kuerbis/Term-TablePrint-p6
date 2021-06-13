use v6;
unit class Term::TablePrint:ver<1.5.4>;

use Term::Choose;
use Term::Choose::LineFold;
use Term::Choose::Screen;
use Term::Choose::Util :insert-sep, :unicode-sprintf;

has %!o;

subset Int_0_to_2 of Int where * == 0|1|2;
subset Int_0_or_1 of Int where * == 0|1;

has UInt       $.max-rows          = 50_000;
has UInt       $.min-col-width     = 30;
has UInt       $.progress-bar      = 5_000;
has UInt       $.tab-width         = 2;
has Int_0_or_1 $.choose-columns;                # removed 12.06.2021
has Int_0_or_1 $.keep-header;                   # removed 13.06.2021
has Int_0_or_1 $.loop              = 0; # private
has Int_0_or_1 $.mouse             = 0;
has Int_0_or_1 $.save-screen       = 0;
has Int_0_or_1 $.squash-spaces     = 0;
has Int_0_to_2 $.clear-screen;                  # removed 12.06.2021
has Int_0_to_2 $.color             = 0;
has Int_0_to_2 $.f3                = 1;
has Int_0_to_2 $.grid;                          # removed 13.06.2021
has Int_0_to_2 $.table-expand      = 1;
has Str        $.decimal-separator = '.';
has Str        $.table-name        = '';
has Str        $.prompt            = '';
has Str        $.undef             = '';

has     @!tbl_orig;
has     @!tbl_copy;
has Int @!w_heads;
has     @!w_cols;
has     @!w_int;
has     @!w_fract;
has Int @!w_cols_calc;
has     @!portions;

has $!filter = '';
has @!map_indexes;
has %!map_return_wr_table = :0last, :1window_width_changed, :2enter_search_string, :3returned_from_filtered_table;

has Int  $!row_count;
has Int  $!tab_w;
has Str  $!info_row;
has Str  $!thsd_sep = ',';
has Hash $!p_bar;

has Term::Choose $!tc;


method !_init_term {
    if ! $!loop {
        print hide-cursor;
    }
    if %!o<save-screen> {
        print save-screen;
    }
    $!tc = Term::Choose.new( :mouse( %!o<mouse> ), :0hide-cursor, :1clear-screen ); # c-s 
}


method !_end_term {
    if %!o<save-screen> {
        print restore-screen;
    }
    if ! $!loop {
        print show-cursor;
    }
}


sub print-table ( @orig_table, *%opt ) is export( :DEFAULT, :print-table ) {
    return Term::TablePrint.new().print-table( @orig_table, |%opt );
}


method print-table (
        @!tbl_orig,
        UInt       :$max-rows          = $!max-rows,
        UInt       :$min-col-width     = $!min-col-width,
        UInt       :$progress-bar      = $!progress-bar,
        UInt       :$tab-width         = $!tab-width,
        Int_0_or_1 :$choose-columns    = $!choose-columns,  # removed 12.06.2021
        Int_0_or_1 :$keep-header       = $!keep-header,     # removed 13.06.2021
        Int_0_or_1 :$mouse             = $!mouse,
        Int_0_or_1 :$save-screen       = $!save-screen,
        Int_0_or_1 :$squash-spaces     = $!squash-spaces,
        Int_0_to_2 :$clear-screen      = $!clear-screen,    # removed 12.06.2021
        Int_0_to_2 :$color             = $!color,
        Int_0_to_2 :$f3                = $!f3,
        Int_0_to_2 :$grid              = $!grid,            # removed 13.06.2021
        Int_0_to_2 :$table-expand      = $!table-expand,
        Str        :$decimal-separator = $!decimal-separator,
        Str        :$table-name        = $!table-name,
        Str        :$prompt            = $!prompt,
        Str        :$undef             = $!undef,
    ) {
    %!o = :$max-rows, :$min-col-width, :$progress-bar, :$tab-width, :$mouse, :$save-screen, :$squash-spaces,
          :$color, :$f3, :$table-expand, :$decimal-separator, :$table-name, :$prompt, :$undef;
    self!_init_term();

    #######################################################################################################
    if $clear-screen.defined {          # removed 12.06.2021
        $!tc.pause( ( 'Continue with ENTER', ), :prompt( 'The option `clear-screen` has been removed. See option `save-screen`' ) );
    }
    if $choose-columns.defined {        # removed 12.06.2021
        $!tc.pause( ( 'Continue with ENTER', ), :prompt( 'The option `choose-columns` has been removed.' ) );
    }
    if $keep-header.defined {           # removed 13.06.2021
        $!tc.pause( ( 'Continue with ENTER', ), :prompt( 'The option `keep-header` has been removed.' ) );
    }
    if $grid.defined {                  # removed 13.06.2021
        $!tc.pause( ( 'Continue with ENTER', ), :prompt( 'The option `grid` has been removed.' ) );
    }
    #######################################################################################################

    if ! @!tbl_orig.elems {
        $!tc.pause( ( 'Close with ENTER', ), :prompt( '"print-table": Empty table!' ) );
        self!_end_term;
        return;
    }
    if print-columns( %!o<decimal-separator> ) != 1 {
        %!o<decimal-separator> = '.';
    }
    if %!o<decimal-separator> ne '.' {
        $!thsd_sep = '_';
    }
    $!tab_w = %!o<tab-width>;
    if %!o<tab-width> %% 2 {
        $!tab_w++;
    }
    self!_row_count( @!tbl_orig.elems );
    self!_init_progress_bar( 3 );
    self!_split_work_for_threads();
    self!_copy_table();
    self!_calc_col_width();
    my ( Int $term_w, Int $table_w, Array $tbl_print, Array $header );

    loop {
        my $next = self!_write_table( $term_w, $table_w, $tbl_print, $header );
        if $next == %!map_return_wr_table<last> {
            last;
        }
        elsif $next == %!map_return_wr_table<window_width_changed> {
        }
        elsif $next == %!map_return_wr_table<enter_search_string> {
            self!_search();
        }
        elsif $next == %!map_return_wr_table<returned_from_filtered_table> {
            self!_reset_search();
        }
        next;
    }
    self!_end_term();
    return;
}


method !_write_table ( $term_w is rw, $table_w is rw, $tbl_print is rw, $header is rw ) {
    if ! $term_w || $term_w != get-term-size().[0] + 1 { # + 1 if not win32
        $term_w = get-term-size().[0] + 1;
        self!_init_progress_bar( 1 );
        my $ok = self!_calc_avail_col_width( $term_w );
        if ! $ok {
            return %!map_return_wr_table<last>;
        }
        $table_w = [+] |@!w_cols_calc, $!tab_w * @!w_cols_calc.end;
        if ! $table_w {
            return %!map_return_wr_table<last>;
        }
        $tbl_print = self!_table_row_to_string();
        $header = [];
        if %!o<prompt>.chars {
            $header.push: %!o<prompt>;
        }
        my $col_names = $tbl_print.shift;
        $header.push: $col_names, self!_header_separator();
        if $!info_row {
            if print-columns( $!info_row ) > $table_w {
                $tbl_print.push: to-printwidth( $!info_row, $table_w - 3 ).[0] ~ '...';
            }
            else {
                $tbl_print.push: $!info_row ~ ' ' x ( $table_w - $!info_row.chars ); #
            }
        }
    }
    my $return = %!map_return_wr_table<last>;
    my @idxs_tbl_print;
    if $!filter.chars {
        @idxs_tbl_print = @!map_indexes.map: { $_ - 1 }; # because of the removed header row from $tbl_print
        $return = %!map_return_wr_table<returned_from_filtered_table>;
    }
    my $footer;
    if %!o<table-name> {
        $footer = '- ' ~ %!o<table-name>;
        if $!filter.chars {
            $footer ~= '  ' ~ ( %!o<f3> == 1 ?? 'rx:i/' !! 'rx/' ) ~ $!filter ~ '/';
        }
    }
    my Int $old_row = 0;
    my Int $auto_jumped_to_row_0 = 2;
    my Int $row_is_expanded = 0;

    loop {
        if $term_w != get-term-size().[0] + 1 {
            return %!map_return_wr_table<window_width_changed>;
        }
        if ( $!row_count <= 1 ) {
            # Choose
            $!tc.pause( ( 'Empty table!', ), :prompt( $header.join: "\n" ), :0layout );
            return %!map_return_wr_table<last>;
        }
        %*ENV<TC_RESET_AUTO_UP> = 0;
        # Choose
        my Int $row = $!tc.choose(
            @idxs_tbl_print.elems ?? $tbl_print[@idxs_tbl_print] !! $tbl_print,
            :prompt( $header.join: "\n" ), :ll( $table_w ), :default( $old_row ),
            :1index, :2layout, :color( %!o<color> ), :$footer
        );
        if ! $row.defined {
            return $return;
        }
        if $row < 0 {
            if $row == -1 {         # with option `ll` set and changed window width `choose` returns -1;
                return %!map_return_wr_table<window_width_changed>;
            }
            elsif $row == -13 {     # `choose` returns -13 if `F3` was pressed
                if $!filter.chars {
                    self!_reset_search();
                }
                return %!map_return_wr_table<enter_search_string>;
            }
            else {
                return %!map_return_wr_table<last>;
            }
        }
        if ! %!o<table-expand> {
            if $row == 0 {
                return $return;
            }
            next;
        }
        else {
            if $old_row == $row {
                if $row == 0 {
                    if %!o<table-expand> {
                        if $row_is_expanded {
                            return $return;
                        }
                        if $auto_jumped_to_row_0 == 1 {
                            return $return;
                        }
                    }
                    $auto_jumped_to_row_0 = 0;
                }
                elsif %*ENV<TC_RESET_AUTO_UP> == 1 {
                    $auto_jumped_to_row_0 = 0;
                }
                else {
                    $old_row = 0;
                    $auto_jumped_to_row_0 = 1;
                    $row_is_expanded = 0;
                    next;
                }
            }
            $old_row = $row;
            $row_is_expanded = 1;
            if $!info_row && $row == $tbl_print.end {
                $!tc.pause( ( 'Close', ), :prompt( $!info_row ) );
                next;
            }
            my $orig_row;
            if @!map_indexes.elems {
                $orig_row = @!map_indexes[$row];
            }
            else {
                $orig_row = $row + 1; # because $tbl_print has no header row while $tbl_orig has a header row
            }
            self!_print_single_table_row( $orig_row, $footer );
        }
        %*ENV<TC_RESET_AUTO_UP>:delete;
    }
}


method !_print_single_table_row ( Int $row, Str $footer ) {
    my Int $term_w = get-term-size().[0] + 1;
    my Int $key_w = @!w_heads.max + 1; #
    if $key_w > $term_w div 100 * 33 {
        $key_w = $term_w div 100 * 33;
    }
    my Str $separator = ' : ';
    my Int $sep_w = $separator.chars;
    my $col_w = $term_w - ( $key_w + $sep_w + 1 ); #
    my @lines = ' Close with ENTER', ' ';
    for ^@!tbl_orig[0] -> $col {
        my $col_name = ( @!tbl_orig[0][$col] // %!o<undef> );
        if $col_name ~~ Buf {
            $col_name = $col_name.gist;
        }
        if %!o<color> { # elsif
            $col_name.=subst( / \e \[ <[\d;]>* m /, '', :g );
        }
        $col_name.=subst( / \t /,  ' ', :g );
        $col_name.=subst( / \v+ /,  '  ', :g );
        $col_name.=subst( / <:Cc+:Noncharacter_Code_Point+:Cs> /, '', :g );
        my Str $key = to-printwidth( $col_name, $key_w, False ).[0];
        my $cell = @!tbl_orig[$row][$col];
        if %!o<color> {
            $cell.=subst( / \e \[ <[\d;]>* m /, '', :g );
        }
        my Str $sep = $separator;
        for line-fold( $cell, $col_w ) -> $line { # color ?
            @lines.push: sprintf "%*.*s%*s%s", $key_w xx 2, $key, $sep_w, $sep, $line;
            $key = '' if $key;
            $sep = '' if $sep;
        }
        @lines.push: ' ';
    }
    @lines.pop;
    $!tc.pause( @lines, :prompt( '' ), :2layout, :$footer );
}


method !_copy_table {
    my ( Int $count, Int $step ) = self!_set_progress_bar;       #
    my @promise;
    my $lock = Lock.new();
    for @!portions -> $range {
        @promise.push: start {
            do for |$range -> $row {
                if $step {                                       #
                    $lock.protect( {                             #
                        ++$count;                                #
                        if $count %% $step {                     #
                            self!_update_progress_bar( $count ); #
                        }                                        #
                    } );                                         #
                }
                do for ^@!tbl_orig[0] -> $col {
                    my $str = ( @!tbl_orig.AT-POS($row).AT-POS($col) // %!o<undef> );  # this is where the copying happens
                    if $str ~~ Buf {
                        $str = $str.gist;
                    }
                    if %!o<color> { # elsif
                        $str.=subst( / \x[feff] /, '', :g );
                        $str.=subst( / \e \[ <[\d;]>* m /, "\x[feff]", :g ); # msg
                    }
                    if %!o<squash-spaces> {
                        $str.=subst( / ^ <:Space>+ /, '', :g );
                        $str.=subst( / <:Space>+ $ /, '', :g );
                        $str.=subst( / <:Space>+ /,  ' ', :g );
                    }
                    $str.=subst( / \t /,  ' ', :g );
                    $str.=subst( / \v+ /,  '  ', :g );
                    $str.=subst( / <:Cc+:Noncharacter_Code_Point+:Cs> /, '', :g );
                    $str;
                }
            }
        };
    }
    @!tbl_copy= [];
    for await @promise -> @portion {
        for @portion -> @p_rows {
            @!tbl_copy.push: @p_rows;
        }
    }
    if $step {                                                   #
        self!_last_update_progress_bar( $count );                #
    }                                                            #
    return;
}


method !_calc_col_width {
    my ( Int $count, Int $step ) = self!_set_progress_bar;       #
    my Int @idx_cols = 0 .. @!tbl_copy[0].end; # new indexes
    @!w_heads = ();
    for @idx_cols -> $col {
       @!w_heads.BIND-POS( $col, print-columns( @!tbl_copy.AT-POS(0).AT-POS($col) ) );
    }
    my $size = @!tbl_copy[0].elems;
    my @w_cols[$size]  = ( 1 xx $size );
    my @w_int[$size]   = ( 0 xx $size );
    my @w_fract[$size] = ( 0 xx $size );
    my $header_idx = @!portions[0].shift; # already done: w_heads 
    my $ds = %!o<decimal-separator>;
    my @promise;
    my $lock = Lock.new();
    for @!portions -> $range {
        my @cache;
        @promise.push: start {
            for |$range -> $row {
                if $step {                                       #
                    $lock.protect( {                             #
                        ++$count;                                #
                        if $count %% $step {                     #
                            self!_update_progress_bar( $count ); #
                        }                                        #
                    } );                                         #
                }                                                #
                for @idx_cols -> $col {
                    if @!tbl_copy.AT-POS($row).AT-POS($col).chars {
                        if @!tbl_copy.AT-POS($row).AT-POS($col) ~~ / ^ ( <[-+]>? <[0..9]>* ) ( $ds <[0..9]>+ )? $ / {
                            if @!tbl_copy.AT-POS($row).AT-POS($col).chars > @w_cols.AT-POS($col) {
                                @w_cols.BIND-POS( $col, @!tbl_copy.AT-POS($row).AT-POS($col).chars );
                            }
                            if $0.defined && $0.chars > @w_int.AT-POS($col) {
                                @w_int.BIND-POS( $col, $0.chars );
                            }
                            if $1.defined && $1.chars > @w_fract.AT-POS($col) {
                                @w_fract.BIND-POS( $col, $1.chars );
                            }
                        }
                        else {
                            my $width = print-columns( @!tbl_copy.AT-POS($row).AT-POS($col), @cache );
                            if $width > @w_cols.AT-POS($col) {
                                @w_cols.BIND-POS( $col, $width );
                            }
                        }
                    }
                }
            }
        };
    }
    await @promise;
    @!portions[0].unshift: $header_idx;
    @!w_cols  := @w_cols;
    @!w_int   := @w_int;
    @!w_fract := @w_fract;
    if $step {                                                   #
        self!_last_update_progress_bar( $count );                #
    }                                                            #
}


method !_calc_avail_col_width( $term_w ) {
    @!w_cols_calc = @!w_cols;
    my Int $avail_w = $term_w - $!tab_w * @!w_cols_calc.end;
    my Int $sum = [+] @!w_cols_calc;
    if $sum < $avail_w {
        HEAD: loop {
            my Int $count = 0;
            for ^@!w_heads -> $i {
                if @!w_heads.AT-POS($i) > @!w_cols_calc.AT-POS($i) {
                    ++@!w_cols_calc.AT-POS($i);
                    ++$count;
                    last HEAD if ( $sum + $count ) == $avail_w;
                }
            }
            last HEAD if $count == 0;
            $sum += $count;
        }
    }
    elsif $sum > $avail_w {
        my Int $mininum_w = %!o<min-col-width> || 1;
        if @!w_heads.elems > $avail_w {
            self!_print_term_not_wide_enough_message();
            return;
        }
        my Int @w_cols_tmp = @!w_cols_calc;
        my Int $percent = 0;

        MIN: while $sum > $avail_w {
            ++$percent;
            my Int $count = 0;
            for ^@w_cols_tmp -> $i {
                if $mininum_w >= @w_cols_tmp.AT-POS($i) {
                    next;
                }
                if $mininum_w >= _minus_x_percent( @w_cols_tmp.AT-POS($i), $percent ) {
                    @w_cols_tmp[$i] = $mininum_w;
                }
                else {
                    @w_cols_tmp[$i] = _minus_x_percent( @w_cols_tmp[$i], $percent );
                }
                ++$count;
            }
            $sum = @w_cols_tmp.sum;
            $mininum_w-- if $count == 0;
            #last MIN if $mininum_w == 0;
        }
        my Int $rest = $avail_w - $sum;
        if $rest {

            REST: loop {
                my $count = 0;
                for ^@w_cols_tmp -> $i {
                    if @w_cols_tmp.AT-POS($i) < @!w_cols_calc.AT-POS($i) {
                        @w_cols_tmp.BIND-POS( $i, @w_cols_tmp.AT-POS($i) + 1 );
                        $rest--;
                        $count++;
                        last REST if $rest == 0;
                    }
                }
                last REST if $count == 0;
            }
        }
        @!w_cols_calc = [ @w_cols_tmp ] if @w_cols_tmp.elems;
    }
    return 1;
}


method !_table_row_to_string {
    my Int @idx_cols = 0 .. @!tbl_copy[0].end;
    my Str $tab = ( ' ' x $!tab_w div 2 ) ~ '|' ~ ( ' ' x $!tab_w div 2 );
    my ( Int $count, Int $step ) = self!_set_progress_bar;       #
    my $ds = %!o<decimal-separator>;
    my @promise;
    my $lock = Lock.new();
    for @!portions -> $range {
        my @cache;
        @promise.push: start {
            do for |$range -> $row {
                my Str $str = '';
                for @idx_cols -> $col {
                    if ! @!tbl_copy.AT-POS($row).AT-POS($col).chars {
                            $str = $str ~ ' ' x @!w_cols_calc.AT-POS($col);
                    }
                    elsif @!tbl_copy.AT-POS($row).AT-POS($col) ~~ / ^ ( <[-+]>? <[0..9]>* ) ( $ds <[0..9]>+ )? $ / {
                        my Str $all = '';
                        if @!w_fract.AT-POS($col) {
                            if $1.defined {
                                if $1.chars > @!w_fract.AT-POS($col) {
                                    $all = $1.substr( 0, @!w_fract.AT-POS($col) );
                                }
                                else {
                                    $all = $1 ~ ( ' ' x ( @!w_fract.AT-POS($col) - $1.chars ) );
                                }
                            }
                            else {
                                $all = ' ' x @!w_fract.AT-POS($col);
                            }
                        }
                        if $0.defined {
                            if @!w_int.AT-POS($col) > $0.chars {
                                $all = ' ' x ( @!w_int.AT-POS($col) - $0.chars ) ~ $0 ~ $all;
                            }
                            else {
                                $all = $0 ~ $all;
                            }
                        }
                        if $all.chars > @!w_cols_calc.AT-POS($col) {
                            $str = $str ~ $all.substr( 0, @!w_cols_calc.AT-POS($col) );
                        }
                        else {
                            $str = $str ~ ' ' x ( @!w_cols_calc.AT-POS($col) - $all.chars ) ~ $all;
                        }
                    }
                    else {
                        $str = $str ~ unicode-sprintf( @!tbl_copy.AT-POS($row).AT-POS($col), @!w_cols_calc.AT-POS($col), @cache );
                    }
                    if %!o<color> && @!tbl_orig.AT-POS($row).AT-POS($col).defined { #
                        my @color = @!tbl_orig.AT-POS($row).AT-POS($col).comb( / \e \[ <[\d;]>* m / );
                        if @color.elems {
                            $str.=subst( / \x[feff] /, { @color.shift }, :g );
                            if @color.elems {
                                $str = $str ~ @color[*-1];
                            }
                        }
                    }
                    if $col != @!w_cols_calc.end {
                        $str = $str ~ $tab;
                    }
                }
                if $step {                                       #
                    $lock.protect( {                             #
                        ++$count;                                #
                        if $count %% $step {                     #
                            self!_update_progress_bar( $count ); #
                        }                                        #
                    } );                                         #
                }
                $row, $str;
            }
        };
    }
    my $tbl_print = [];
    for await @promise -> @portion {
        for @portion {
            $tbl_print.BIND-POS( .[0], .[1] );
        }
    }
    if $step {                                                   #
        self!_last_update_progress_bar( $count );                #
    }                                                            #
    return $tbl_print;
}


method !_search {
    if ! %!o<f3> {
        return;
    }
    print "\r", clr-lines-to-bot;
    print show-cursor;
    my $prompt = 'Search pattern: ';
    my ( $string, $regex );

    READ: loop {
        if ( try require Readline ) === Nil {
            $string = prompt( $prompt );
        }
        else {
            require Readline;
            my $rl = ::('Readline').new;
            $string = $rl.readline( $prompt );
        }
        if ! $string.chars {
            return;
        }
        print up( 1 );
        print "\r{$prompt}{$string}";
        try {
            $regex = %!o<f3> == 1 ?? rx:i/<$string>/ !! rx/<$string>/;
            'Teststring' ~~ $regex;
        }
        if $! {
            $!tc.pause( ( 'Continue with ENTER', ), :prompt( $!.Str ), :0layout );
            next READ;
        }
        last READ;
    }
    print hide-cursor;
    @!map_indexes = [];
    for 1 .. @!tbl_copy.end -> $idx {
        if @!tbl_copy[$idx].any ~~ $regex {
            @!map_indexes.push: $idx;
        }
    }
    if ! @!map_indexes.elems {
        $!tc.pause( ( 'Continue with ENTER', ), :prompt( 'No matches found.' ), :0layout );
        return;
    }
    $!filter = $string;
    return;
}


method !_reset_search {
    @!map_indexes = [];
    $!filter = '';
}


method !_row_count ( $orig_row_count ) {
    if %!o<max-rows> && $orig_row_count >= %!o<max-rows> + 1 {
        $!info_row = sprintf( 'ROW LIMIT %s (of %s)', insert-sep( %!o<max-rows>, $!thsd_sep ), insert-sep( $orig_row_count - 1, $!thsd_sep ) );
        $!row_count = %!o<max-rows> + 1; # + 1 for header row
    }
    else {
        $!info_row = '';
        $!row_count = $orig_row_count;
    }
}


method !_split_work_for_threads {
    my Int $threads = num-threads();
    while $threads * 2 > $!row_count {
        last if $threads == 1;
        $threads = $threads div 2;
    }
    my $size = $!row_count div $threads;
    if ( $!row_count % $threads ) {
        $size++;
    }
    my @idx_rows = 0 .. $!row_count - 1;
    @!portions = ( ^$threads ).map: { [ @idx_rows.splice: 0, $size ] };
}


method !_init_progress_bar ( $times ) {
    $!p_bar = {};
    my Int $count_cells = $!row_count * @!tbl_orig[0].elems;
    if %!o<progress-bar> && %!o<progress-bar> < $count_cells {
        print clear();
        print 'Computing: ';
        $!p_bar<count_progress_bars> = $times;
        if $count_cells / %!o<progress-bar> > 50 {
            $!p_bar<merge_progress_bars> = 0;
            $!p_bar<total> = $!row_count;
        }
        else {
            $!p_bar<merge_progress_bars> = 1;
            $!p_bar<total> = $!row_count * $!p_bar<count_progress_bars>;
        }
    }
}


method !_set_progress_bar {
    if ! $!p_bar<count_progress_bars> {
        return Int, Int;
    }
    my Int $term_w = get-term-size().[0] + 1;
    my Int $count;
    if $!p_bar<merge_progress_bars> {
        $!p_bar<fmt> = 'Computing: [%s%s]';
        $count = $!p_bar<so_far> // 0;
    }
    else {
        $!p_bar<fmt> = 'Computing: (' ~ $!p_bar<count_progress_bars> ~ ') [%s%s]';
        $count = 0;
    }
    $!p_bar<count_progress_bars>--;
    if $term_w < 25 {
        $!p_bar<fmt> = '[%s%s]';
    }
    $!p_bar<bar_w> = $term_w - ( sprintf $!p_bar<fmt>, '', '' ).chars - 1;
    my Int $step = $!p_bar<total> div $!p_bar<bar_w> || 1;
    return $count, $step;
}


method !_update_progress_bar( Int $count ) { # sub
    my $multi = ( $count / ( $!p_bar{'total'} / $!p_bar<bar_w> ) ).ceiling;
    print "\r" ~ sprintf( $!p_bar<fmt>, '=' x $multi, ' ' x $!p_bar<bar_w> - $multi );
}


method !_last_update_progress_bar( $count ) {
    if $!p_bar<count_progress_bars> && $!p_bar<merge_progress_bars> {
        $!p_bar<so_far> = $count;
    }
    else {
        self!_update_progress_bar( $!p_bar<total> );
    }
    print "\r";
}


method !_header_separator { 
    my Str $header_sep = '';
    my Str $tab = ( '-' x $!tab_w div 2 ) ~ '|' ~ ( '-' x $!tab_w div 2 );
    for ^@!w_cols_calc {
        $header_sep ~= '-' x @!w_cols_calc[$_];
        $header_sep ~= $tab if $_ != @!w_cols_calc.end;
    }
    return $header_sep;
}


method !_print_term_not_wide_enough_message {
    my $prompt1 = 'Terminal window is not wide enough to print this table.';
    $!tc.pause( [ 'Press ENTER to show the column names.' ], :prompt( $prompt1 ) );
    #my Str $prompt2 = 'Reduce the number of columns".' ~ "\n" ~ 'Close with ENTER.';
    my Str $prompt2 = 'Close with ENTER.';
    $!tc.pause( @!tbl_copy[0], :prompt( $prompt2 ) );
}


sub _minus_x_percent ( Int $value, Int $percent ) {
    my Int $new = ( $value - ( $value / 100 * $percent ) ).Int;
    return $new > 0 ?? $new !! 1; ##
}







=begin pod

=head1 NAME

Term::TablePrint - Print a table to the terminal and browse it interactively.

=head1 SYNOPSIS

=begin code

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

=end code

=head1 DESCRIPTION

C<print-table> shows a table and lets the user interactively browse it. It provides a cursor which highlights the row
on which it is located. The user can scroll through the table with the different cursor keys - see L<#KEYS>.

If the table has more rows than the terminal, the table is divided up on as many pages as needed automatically. If the
cursor reaches the end of a page, the next page is shown automatically until the last page is reached. Also if the
cursor reaches the topmost line, the previous page is shown automatically if it is not already the first one.

If the terminal is too narrow to print the table, the columns are adjusted to the available width automatically.

If the option table-expand is enabled and a row is selected with C<Return>, each column of that row is output in its own
line preceded by the column name. This might be useful if the columns were cut due to the too low terminal width.

The following modifications are made (at a copy of the original data) to the table elements before the output.

Tab characters (C<\t>) are replaces with a space.

Vertical spaces (C<\v>) are squashed to two spaces

Control characters, code points of the surrogate ranges and non-characters are removed.

If the option I<squash-spaces> is enabled leading and trailing spaces are removed from the array elements and spaces are squashed to a single space.

If an element looks like a number it is left-justified, else it is right-justified.

=head1 USAGE

=head2 KEYS

Keys to move around:

=item the C<ArrowDown> key (or the C<j> key) to move down and  the C<ArrowUp> key (or the C<k> key) to move up.

=item the C<PageUp> key (or C<Ctrl-B>) to go back one page, the C<PageDown> key (or C<Ctrl-F>) to go forward one page.

=item the C<Insert> key to go back 10 pages, the C<Delete> key to go forward 10 pages.

=item the C<Home> key (or C<Ctrl-A>) to jump to the first row of the table, the C<End> key (or C<Ctrl-E>) to jump to the last
row of the table.

If I<table-expand> is set to C<0>, the C<Return> key closes the table if the cursor is on the first row.

If I<table-expand> is enabled and the cursor is on the first row, pressing C<Return> three times in succession closes
the table. If I<table-expand> is set to C<1> and the cursor is auto-jumped to the first row, it is required only one
C<Return> to close the table.

If the cursor is not on the first row:

=item1 with the option I<table-expand> disabled the cursor jumps to the table head if C<Return> is pressed.

=item1 with the option I<table-expand> enabled each column of the selected row is output in its own line preceded by the
column name if C<Return> is pressed. Another C<Return> closes this output and goes back to the table output. If a row is
selected twice in succession, the pointer jumps to the first row.

If the width of the window is changed and the option I<table-expand> is enabled, the user can rewrite the screen by
choosing a row.

=head1 CONSTRUCTOR

The constructor method C<new> can be called with named arguments. For the valid options see L<#OPTIONS>. Setting the
options in C<new> overwrites the default values for the instance.

=head1 ROUTINES

=head2 print-table

C<print-table> prints the table passed with the first argument.

    print-table( @table, *%options );

The first argument is an list of arrays. The first array of these arrays holds the column names. The following arrays
are the table rows where the elements are the field values.

The following arguments set the options (key-values pairs).

=head1 OPTIONS

Defaults may change in future releases.

=head2 prompt

String displayed above the table.

=head2 color

If this option is enabled, SRG ANSI escape sequences can be used to color the screen output.

0 - off (default)

1 - on (current selected element not colored)

2 - on (current selected element colored)

=head2 decimal-separator

If set, numbers use I<decimal-separator> as the decimal separator instead of the default decimal separator.

Allowed values: a character with a print width of C<1>. If an invalid values is passed, I<decimal-separator> falls back
to the default value.

Default: . (dot)

=head2 max-rows

Set the maximum number of used table rows. The used table rows are kept in memory.

To disable the automatic limit set I<max-rows> to C<0>.

If the number of table rows is equal to or higher than I<max-rows>, the last row of the output says
C<REACHED LIMIT "MAX_ROWS": $limit> or C<=LIMIT= $limit> if the previous doesn't fit in the row.

Default: 50_000

=head2 min-col-width

The columns with a width below or equal I<min-col-width> are only trimmed if it is still required to lower the row width
despite all columns wider than I<min-col-width> have been trimmed to I<min-col-width>.

Default: 30

=head2 mouse

Set the I<mouse> mode (see option C<mouse> in L<Term::Choose|https://github.com/kuerbis/Term-Choose-p6>).

Default: 0

=head2 progress-bar

Set the progress bar threshold. If the number of fields (rows x columns) is higher than the threshold, a progress bar is
shown while preparing the data for the output. Setting the value to C<0> disables the progress bar.

Default: 5_000

=head2 save-screen

0 - off (default)

1 - use the alternate screen

=head2 squash-spaces

If I<squash-spaces> is enabled, consecutive spaces are squashed to one space and leading and trailing spaces are removed.

Default: 0

=head2 tab-width

Set the number of spaces between columns. If I<format> is set to C<2> and I<tab-width> is even, the spaces between the
columns are I<tab-width> + 1 print columns.

Default: 2

=head2 table-expand

If the option I<table-expand> is enabled and C<Return> is pressed, the selected table row is printed with each column in
its own line. Exception: if the cursor auto-jumped to the first row, the first row will not be expanded.

0 - off

1 - on (default)

=begin code

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

=end code

If I<table-expand> is set to C<0>, the cursor jumps to the to first row (if not already there) when C<Return> is pressed.

Default: 1

=head2 table-name

If set (string), I<table_name> is added in the bottom line.

=head2 undef

Set the string that will be shown on the screen instead of an undefined field.

Default: "" (empty string)

=head1 ENVIRONMET VARIABLES

=head2 multithreading

C<Term::TablePrint> uses multithreading when preparing the list for the output; the number of threads to use can be set
with the environment variable C<TC_NUM_THREADS>.

=head1 REQUIREMENTS

=head2 tput

The control of the cursor location, the highlighting of the cursor position and the marked elements and other options on
the terminal is done via escape sequences.

C<tput> is used to get the appropriate escape sequences.

Escape sequences to handle mouse input are hardcoded.

=head2 Monospaced font

It is required a terminal that uses a monospaced font which supports the printed characters.

=head1 CREDITS

Thanks to the people from L<Perl-Community.de|http://www.perl-community.de>, from
L<stackoverflow|http://stackoverflow.com> and from L<#perl6 on irc.freenode.net|irc://irc.freenode.net/#perl6> for the
help.

=head1 AUTHOR

Matthäus Kiem <cuer2s@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright 2016-2020 Matthäus Kiem.

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
