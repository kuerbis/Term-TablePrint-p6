use v6;
unit class Term::TablePrint:ver<1.6.5>;

use Term::Choose;
use Term::Choose::Constant;
use Term::Choose::LineFold;
use Term::Choose::Screen;
use Term::Choose::Util :insert-sep;

has %!o;

has UInt       $.max-rows          = 0;
has UInt       $.max-width-exp     = 0;
has UInt       $.min-col-width     = 30;
has UInt       $.progress-bar      = 5_000;
has UInt       $.tab-width         = 2;
has Int_0_or_1 $.loop              = 0; # private
has Int_0_or_1 $.mouse             = 0;
has Int_0_or_1 $.pad-row-edges     = 0;
has Int_0_or_1 $.save-screen       = 0;
has Int_0_or_1 $.squash-spaces     = 0;
has Int_0_or_1 $.table-expand      = 1;
has Int_0_or_1 $.trunc-fract-first = 1;
has Int_0_to_2 $.binary-filter     = 0;
has Int_0_to_2 $.color             = 0;
has Int_0_to_2 $.search            = 1;
has Str        $.decimal-separator = '.';
has Str        $.footer            = '';
has Str        $.prompt            = '';
has Str        $.undef             = '';

has     @!tbl_orig;
has     @!tbl_copy;
has Int @!w_heads;
has     @!w_cols;
has Int @!w_cols_calc;
has     @!w_int;
has     @!w_fract;
has Int @!w_fract_calc;

has Array @!portions;

has Str $!filter_string = '';
has Int @!map_indexes;
has     %!map_return_wr_table = :0last, :1window_width_changed, :2enter_search_string, :3returned_from_filtered_table;

has Int  $!row_count;
has Int  $!tab_w;
has Int $!edge_w = 0;
has Str $!binary-string = 'BNRY';
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
        UInt       :$max-width-exp     = $!max-width-exp,
        UInt       :$min-col-width     = $!min-col-width,
        UInt       :$progress-bar      = $!progress-bar,
        UInt       :$tab-width         = $!tab-width,
        Int_0_or_1 :$mouse             = $!mouse,
        Int_0_or_1 :$pad-row-edges     = $!pad-row-edges,
        Int_0_or_1 :$save-screen       = $!save-screen,
        Int_0_or_1 :$squash-spaces     = $!squash-spaces,
        Int_0_or_1 :$table-expand      = $!table-expand,
        Int_0_or_1 :$trunc-fract-first = $!trunc-fract-first,
        Int_0_to_2 :$binary-filter     = $!binary-filter;
        Int_0_to_2 :$color             = $!color,
        Int_0_to_2 :$search            = $!search,
        Str        :$decimal-separator = $!decimal-separator,
        Str        :$footer            = $!footer,
        Str        :$prompt            = $!prompt,
        Str        :$undef             = $!undef,
    ) {
    %!o = :$max-rows, :$max-width-exp, :$min-col-width, :$progress-bar, :$tab-width, :$mouse, :$pad-row-edges,
          :$save-screen, :$squash-spaces, :$binary-filter, :$color, :$search, :$table-expand, :$decimal-separator,
          :$footer, :$prompt, :$undef, :$trunc-fract-first;
    self!_init_term();
    if ! @!tbl_orig.elems {
        $!tc.pause( ( 'Close with ENTER', ), :prompt( '"print-table": Empty table!' ) );
        self!_end_term;
        return;
    }
    if ! @!tbl_orig[0].elems {
        $!tc.pause( ( 'Close with ENTER', ), :prompt( '"print-table": No columns!' ) );
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
    if %!o<pad-row-edges> {
        $!edge_w = 1;
    }
    self!_row_count( @!tbl_orig.elems );
    self!_init_progress_bar( $!row_count * 3 - 1 );
    self!_split_work_for_threads();
    self!_copy_table();
    self!_calc_col_width();
    my ( Int $term_w, Int $table_w, Array $tbl_print, Array $header );

    loop {
        my Int $next = self!_write_table( $term_w, $table_w, $tbl_print, $header );
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
        self!_init_progress_bar( $!row_count );
        next;
    }
    self!_end_term();
    return;
}


method !_write_table ( $term_w is rw, $table_w is rw, $tbl_print is rw, $header is rw ) {
    if ! $term_w || $term_w != get-term-size().[0] + extra-w {
        $term_w = get-term-size().[0] + extra-w;
        my $ok = self!_calc_avail_col_width( $term_w );
        if ! $ok {
            return %!map_return_wr_table<last>;
        }
        $table_w = [+] |@!w_cols_calc, $!tab_w * @!w_cols_calc.end, 2 * $!edge_w;
        if ! $table_w {
            return %!map_return_wr_table<last>;
        }
        $tbl_print = self!_table_row_to_string();
        $header = [];
        if %!o<prompt>.chars {
            $header.push: %!o<prompt>;
        }
        my Str $col_names = $tbl_print.shift;
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
    my Int $return = %!map_return_wr_table<last>;
    my Int @idxs_tbl_print;
    if $!filter_string.chars {
        @idxs_tbl_print = @!map_indexes.map: { $_ - 1 }; # because of the removed header row from $tbl_print
        $return = %!map_return_wr_table<returned_from_filtered_table>;
    }
    my Str $footer = '';
    if %!o<footer> {
        $footer = '  ' ~ %!o<footer>;
        if $!filter_string.chars {
            $footer ~= '  ' ~ ( %!o<search> == 1 ?? 'rx:i/' !! 'rx/' ) ~ $!filter_string ~ '/';
        }
    }
    my Int $old_row = 0;
    my Int $auto_jumped_to_row_0 = 0;
    my Int $row_was_expanded = 0;

    loop {
        if $term_w != get-term-size().[0] + extra-w {
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
            :prompt( $header.join: "\n" ), :ll( $table_w ), :default( $old_row ), :1index, :2layout,
            :color( %!o<color> ), :$footer
        );
        if ! $row.defined {
            return $return;
        }
        if $row < 0 {
            if $row == -1 {         # with option `ll` set and changed window width `choose` returns -1;
                return %!map_return_wr_table<window_width_changed>;
            }
            elsif $row == -13 {     # `choose` returns -13 if `F3` was pressed
                if $!filter_string.chars {
                    self!_reset_search();
                }
                return %!map_return_wr_table<enter_search_string>;
            }
            else {
                return %!map_return_wr_table<last>;
            }
        }
        if ! %!o<table-expand> {
            return $return if $row == 0;
            next;
        }
        if %*ENV<TC_RESET_AUTO_UP> == 1 {  # 1 if any key other than Return/Enter was pressed
            $auto_jumped_to_row_0 = 0;
            $row_was_expanded = 0;
        }
        if $row_was_expanded {
            if $row == 0 {
                return $return;
            }
            $old_row = 0;
            $auto_jumped_to_row_0 = 1;
            $row_was_expanded = 0;
            next;
        }
        if $auto_jumped_to_row_0 {
            return $return;
        }
        $old_row = $row;
        $row_was_expanded = 1;
        if $!info_row && $row == $tbl_print.end {
            $!tc.pause( ( 'Close', ), :prompt( $!info_row ) );
            next;
        }
        my Int $orig_row;
        if @!map_indexes.elems {
            $orig_row = @!map_indexes[$row];
        }
        else {
            $orig_row = $row + 1; # because $tbl_print has no header row while $tbl_orig has a header row
        }
        self!_print_single_table_row( $orig_row, $footer, %!o<search> );
        %*ENV<TC_RESET_AUTO_UP>:delete;
    }
}


method !_print_single_table_row ( Int $row, Str $footer, Int $search ) {
    my Int $avail_w = get-term-size().[0];
    if %!o<max-width-exp> && %!o<max-width-exp> < $avail_w {
        $avail_w = %!o<max-width-exp>;
    }
    my Int $max_key_w = @!w_heads.max + 1; #
    if $max_key_w > $avail_w div 3 {
        $max_key_w = $avail_w div 3;
    }
    my Str $separator = ' : ';
    my Int $sep_w = $separator.chars;
    my Int $max_value_w = $avail_w - ( $max_key_w + $sep_w );
    my Str @lines = ' Close with ENTER', ' ';

    for ^@!tbl_orig[0] -> $col {
        my $key = ( @!tbl_orig[0][$col] // %!o<undef> );
        if $key ~~ Buf {
            $key = $key.raku; ##
        }
        elsif %!o<color> {
            $key.=subst( / $(ph-char) /, '', :g );
            $key.=subst( &rx-color, ph-char, :g );
        }
        if %!o<binary-filter> && $key.substr( 0, 100 ).match: &rx-is-binary { ##
            if %!o<binary-filter> == 2 {
                $key = ( @!tbl_orig[0][$col] // %!o<undef> ).encode>>.fmt('%02X').Str;
            }
            else {
                $key = $!binary-string;
            }
        }
        elsif $key ~~ &rx-invalid-char {
            $key.=subst( / \t /,  ' ', :g );
            $key.=subst( / \v+ /,  '  ', :g );
            $key.=subst( &rx-invalid-char, '', :g );
        }
        my Int $key_w = print-columns( $key );
        if $key_w > $max_key_w {
            $key = to-printwidth( $key, $max_key_w );
        }
        elsif $key_w < $max_key_w { # >
            $key = ( ' ' x ( $max_key_w - $key_w ) ) ~ $key;
        }
        if %!o<color> && @!tbl_orig[0][$col] !~~ Buf {
            my Str @colors = @!tbl_orig[0][$col].comb( &rx-color );
            if @colors.elems {
                $key.=subst( / $(ph-char) /, { @colors.shift }, :g );
            }
        }
        my $value = @!tbl_orig[$row][$col] // $!undef;
        if $value ~~ Buf {
            $value = $value.raku;
        }
        my Str $subseq_tab = ' ' x ( $max_key_w + $sep_w );
        my Int $count = 0;

        for line-fold( $value, :width( $max_value_w ), :color( %!o<color> ), :binary-filter( %!o<binary-filter> ), :0join ) -> $line {
            if ! $count++ {
                @lines.push: $key ~ $separator ~ $line;
            }
            else {
                @lines.push: $subseq_tab ~ $line;
            }
        }
        @lines.push: ' ';
    }
    @lines.pop;
    $!tc.pause( @lines, :prompt( '' ), :2layout, :$footer, :$search, :color( %!o<color> ) );
}


method !_copy_table {
    my Int $show_pg = self!_set_progress_bar;
    my Promise @promise;
    my Lock $lock = Lock.new();
    for @!portions -> $range {
        @promise.push: start {
            do for |$range -> $row {
                if $show_pg {
                    $lock.protect( {
                        if ++$!p_bar<count> > $!p_bar<next_update> {
                            self!_update_progress_bar();
                        }
                    } );
                }
                do for ^@!tbl_orig[0] -> $col {
                    my $str = ( @!tbl_orig[$row][$col] // %!o<undef> );  # this is where the copying happens
                    if $str ~~ Buf {
                        $str = $str.raku; ##
                    }
                    elsif %!o<color> {
                        $str.=subst( / $(ph-char) /, '', :g );
                        $str.=subst( &rx-color, ph-char, :g );
                    }
                    if %!o<binary-filter> && $str.substr( 0, 100 ).match: &rx-is-binary { ##
                        if %!o<binary-filter> == 2 {
                            $str = ( @!tbl_orig[$row][$col] // %!o<undef> ).encode>>.fmt('%02X').Str;
                        }
                        else {
                            $str = $!binary-string;
                        }
                    }
                    elsif $str ~~ &rx-invalid-char {
                        $str.=subst( / \t /,  ' ', :g );
                        $str.=subst( / \v+ /,  '  ', :g );
                        $str.=subst( &rx-invalid-char, '', :g );
                    }
                    if %!o<squash-spaces> {
                        $str.=trim;
                        $str.=subst( / <:Space>+ /,  ' ', :g );
                    }
                    $str;
                }
            }
        };
    }
    @!tbl_copy = ();
    for await @promise -> @portion {
        for @portion -> @p_rows {
            @!tbl_copy.push: @p_rows;
        }
    }
    return;
}


method !_calc_col_width {
    my Int $show_pg = self!_set_progress_bar;
    my Int @idx_cols = 0 .. @!tbl_copy[0].end; # new indexes
    @!w_heads = ();
    for @idx_cols -> $col {
       @!w_heads[$col] = print-columns( @!tbl_copy[0][$col] );
    }
    my Int $size = @!tbl_copy[0].elems;
    my Int @w_cols[$size]  = ( 1 xx $size );
    my Int @w_int[$size]   = ( 0 xx $size );
    my Int @w_fract[$size] = ( 0 xx $size );
    my Int $header_idx = @!portions[0].shift; # already done: w_heads
    my Str $ds = %!o<decimal-separator>;
    my Promise @promise;
    my Lock $lock = Lock.new();
    for @!portions -> $range {
        @promise.push: start {
            my Int %cache;
            for |$range -> $row {
                if $show_pg {
                    $lock.protect( {
                        if ++$!p_bar<count> > $!p_bar<next_update> {
                            self!_update_progress_bar();
                        }
                    } );
                }
                for @idx_cols -> $col {
                    if @!tbl_copy[$row][$col].chars {
                        if @!tbl_copy[$row][$col] ~~ / ^ ( <[-+]>? <[0..9]>+ )? ( $ds <[0..9]>+ )? $ / {
                            if $0.defined && $0.chars > @w_int[$col] {
                                @w_int[$col] = $0.chars;
                            }
                            if $1.defined && $1.chars > @w_fract[$col] {
                                @w_fract[$col] = $1.chars;
                            }
                        }
                        else {
                            my $width = print-columns( @!tbl_copy[$row][$col], %cache );
                            if $width > @w_cols[$col] {
                                @w_cols[$col] = $width;
                            }
                        }
                    }
                }
            }
        };
    }
    await @promise;
    @!portions[0].unshift: $header_idx;
    for @idx_cols -> $col {
        if @w_int[$col] + @w_fract[$col] > @w_cols[$col] {
            @w_cols[$col] = @w_int[$col] + @w_fract[$col];
        }
    }
    @!w_cols  := @w_cols;
    @!w_int   := @w_int;
    @!w_fract := @w_fract;
}


method !_calc_avail_col_width( $term_w ) {
    @!w_cols_calc = @!w_cols;
    @!w_fract_calc = @!w_fract;
    my Int $avail_w = $term_w - ( $!tab_w * @!w_cols_calc.end + 2 * $!edge_w );
    my Int $sum = [+] @!w_cols_calc;
    if $sum < $avail_w {
        HEAD: loop {
            my Int $count = 0;
            for ^@!w_heads -> $i {
                if @!w_heads[$i] > @!w_cols_calc[$i] {
                    ++@!w_cols_calc[$i];
                    ++$count;
                    last HEAD if ( $sum + $count ) == $avail_w;
                }
            }
            last HEAD if $count == 0;
            $sum += $count;
        }
    }
    elsif $sum > $avail_w {

        if @!w_heads.elems > $avail_w { ##
            self!_print_term_not_wide_enough_message();
            return;
        }
        if %!o<trunc-fract-first> {

            TRUNC_FRACT: while $sum > $avail_w {
                my Int $prev_sum = $sum;
                for ^@!w_cols_calc -> $col {
                    if @!w_fract_calc[$col] && @!w_fract_calc[$col] > 3 {
                       # 3 == 1 decimal separator + 2 decimal places
                        --@!w_fract_calc[$col];
                        --@!w_cols_calc[$col];
                        --$sum;
                        if $sum == $avail_w {
                            last TRUNC_FRACT;
                        }
                    }
                }
                if $sum == $prev_sum {
                    last TRUNC_FRACT;
                }
            }
        }
        my Int $min_col_w = %!o<min-col-width> < 2 ?? 2 !! %!o<min-col-width>;
        my Int $percent = 0;

        TRUNC_COLS: while $sum > $avail_w {
            ++$percent;
            for ^@!w_cols_calc -> $col {
                if @!w_cols_calc[$col] > $min_col_w {
                    my Int $reduced_col_w = _minus_x_percent( @!w_cols_calc[$col], $percent );
                    if $reduced_col_w < $min_col_w {
                        $reduced_col_w = $min_col_w;
                    }
                    if @!w_fract_calc[$col] > 2 {
                        @!w_fract_calc[$col] = @!w_fract_calc[$col] - @!w_cols_calc[$col] - $reduced_col_w;
                        if @!w_fract_calc[$col] < 2 {
                            @!w_fract_calc[$col] = 2;
                        }
                    }
                    @!w_cols_calc[$col] = $reduced_col_w;
                }
            }
            my Int $prev_sum = $sum;
            $sum = @!w_cols_calc.sum;
            if $sum == $prev_sum {
                --$min_col_w;
                if $min_col_w < 2 { # a character could have a print width of 2
                    self!_print_term_not_wide_enough_message();
                    return;
                }
            }
        }
        my Int $remainder_w = $avail_w - $sum;
        if $remainder_w {

            REMAINDER_W: loop {
                my Int $prev_remainder_w = $remainder_w;
                for ^@!w_cols_calc -> $col {
                    if @!w_cols_calc[$col] < @!w_cols[$col] {
                        @!w_cols_calc[$col] = @!w_cols_calc[$col] + 1;
                        --$remainder_w;
                        if $remainder_w == 0 {
                            last REMAINDER_W;
                        }
                    }
                }
                if $remainder_w == $prev_remainder_w {
                    last REMAINDER_W;
                }
            }
        }
    }
    return 1;
}


method !_table_row_to_string {
    my Int @idx_cols = 0 .. @!tbl_copy[0].end;
    my Str $tab = ( ' ' x $!tab_w div 2 ) ~ '|' ~ ( ' ' x $!tab_w div 2 );
    my Int $show_pg = self!_set_progress_bar;
    my Str $ds = %!o<decimal-separator>;
    my Int $one_precision_w = sprintf( "%.1e", 123 ).chars;
    my Str $lrb = ' ' x $!edge_w;
    my Promise @promise;
    my Lock $lock = Lock.new();
    for @!portions -> $range {
        @promise.push: start {
            my Int %cache;
            do for |$range -> $row {
                my Str $str = $lrb;
                for @idx_cols -> $col {
                    if ! @!tbl_copy[$row][$col].chars {
                            $str ~= ' ' x @!w_cols_calc[$col];
                    }
                    elsif @!tbl_copy[$row][$col] ~~ / ^ ( <[-+]>? <[0..9]>+ )? ( $ds <[0..9]>+ )? ( <[eE]> <[-+]>? <[0..9]>+ )? $ / {
                        my Str $number;
                        if $2 {
                            if $0 || $1 {
                                $number = @!tbl_copy[$row][$col];
                                if $2.starts-with( 'E' ) {
                                    $number ~~ s/E/e/;
                                }
                            }
                            else {
                                # not a number
                                $number = sprintf "%-*.*s", @!w_cols_calc[$col], @!w_cols_calc[$col], @!tbl_copy[$row][$col];
                            }
                        }
                        else {
                            # all $fract's of a column must have the same length
                            my Str $fract = ''; 
                            if @!w_fract_calc[$col] {
                                if $1.defined {
                                    if $1.chars > @!w_fract_calc[$col] {
                                        $fract = $1.substr( 0, @!w_fract_calc[$col] );
                                    }
                                    elsif $1.chars < @!w_fract_calc[$col] {
                                        $fract = $1 ~ ( ' ' x ( @!w_fract_calc[$col] - $1.chars ) );
                                    }
                                    else {
                                        $fract = $1.Str;
                                    }
                                }
                                else {
                                    $fract = ' ' x @!w_fract_calc[$col];
                                }
                            }
                            $number = $0.defined ?? $0 ~ $fract !! $fract;
                        }
                        if $number.chars > @!w_cols_calc[$col] {
                            my Int $signed_1_precision_w = $one_precision_w + ( $number.starts-with( '-' ) ?? 1 !! 0 );
                            my Int $precision;
                            if @!w_cols_calc[$col] < $signed_1_precision_w {
                                # special treatment because zero precision has no dot
                                $precision = 0;
                            }
                            else {
                                $precision = @!w_cols_calc[$col] - ( $signed_1_precision_w - 1 ); # -1 for the dot
                            }
                            $number = sprintf "%.*e", $precision, $number;
                            if $number.chars > @!w_cols_calc[$col] { # not enough space to print the number
                                $str ~= ( '-' x @!w_cols_calc[$col] );
                            }
                            elsif $number.chars < @!w_cols_calc[$col] { # @!w_cols_calc[$col] == zero_precision_w + 1
                                #$str ~= ' ' ~ $number;
                                $str ~= $number ~ ' ';
                            }
                            else {
                                $str ~= $number;
                            }
                        }
                        elsif $number.chars < @!w_cols_calc[$col] {
                            $str ~= ' ' x ( @!w_cols_calc[$col] - $number.chars ) ~ $number;
                        }
                        else {
                            $str ~= $number;
                        }
                    }
                    else {
                        my Int $width = print-columns( @!tbl_copy[$row][$col], %cache );
                        if $width > @!w_cols_calc[$col] {
                            $str ~= to-printwidth( @!tbl_copy[$row][$col], @!w_cols_calc[$col], False, %cache ).[0];
                        }
                        elsif $width < @!w_cols_calc[$col] {
                            $str =  $str ~ @!tbl_copy[$row][$col] ~ ' ' x ( @!w_cols_calc[$col] - $width );
                        }
                        else {
                            $str ~= @!tbl_copy[$row][$col];
                        }
                    }
                    if %!o<color> && @!tbl_orig[$row][$col].defined && @!tbl_orig[$row][$col] !~~ Buf {
                        my Str @colors = @!tbl_orig[$row][$col].comb( &rx-color );
                        if @colors.elems {
                            $str.=subst( / $(ph-char) /, { @colors.shift }, :g );
                            $str ~= "\e[0m";
                        }
                    }
                    $str ~= $col == @!w_cols_calc.end ?? $lrb !! $tab;
                }
                if $show_pg {
                    $lock.protect( {
                        if ++$!p_bar<count> > $!p_bar<next_update> {
                            self!_update_progress_bar();
                        }
                    } );
                }
                $row, $str;
            }
        };
    }
    my $tbl_print = [];
    for await @promise -> @portion {
        for @portion {
            $tbl_print[.[0]] = .[1];
        }
    }
    if $show_pg {
        self!_update_progress_bar();
    }
    return $tbl_print;
}


method !_search {
    if ! %!o<search> {
        return;
    }
    print "\r", clear-to-end-of-screen();
    print show-cursor;
    my Str $prompt = 'Search pattern: ';
    my ( Str $string, Regex $regex );

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
            $regex = %!o<search> == 1 ?? rx:i/<$string>/ !! rx/<$string>/;
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
    $!filter_string = $string;
    return;
}


method !_reset_search {
    @!map_indexes = [];
    $!filter_string = '';
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
    if $threads > $!row_count {
        $threads = $!row_count;
    }
    my Int $size = $!row_count div $threads;
    if $!row_count % $threads {
        $size++;
    }
    my Int @idx_rows = 0 .. $!row_count - 1;
    @!portions = ( ^$threads ).map: { [ @idx_rows.splice: 0, $size ] };
}


method !_init_progress_bar ( Int $total ) {
    $!p_bar = {};
    my Int $count_cells = $!row_count * @!tbl_orig[0].elems;
    if %!o<progress-bar> && %!o<progress-bar> < $count_cells {
        print clear-screen();
        print 'Computing: ';
        $!p_bar<total> = $total;
    }
}


method !_set_progress_bar {
    if ! $!p_bar<total> {
        return 0;
    }
    my Int $term_w = get-term-size().[0] + extra-w;
    $!p_bar<fmt> = "\rComputing: %3d%% [%s]";
    if $term_w < 25 {
        $!p_bar<short_print> = 1;
        $!p_bar<bar_w> = $term_w;
    }
    else {
        $!p_bar<short_print> = 0;
        $!p_bar<bar_w> = $term_w - ( sprintf $!p_bar<fmt>, 100, '' ).chars + 1; # +1: "\r".chars == 1
    }
    $!p_bar<step> = ( $!p_bar<total> div $!p_bar<bar_w> ).floor || 1;
    $!p_bar<count> //= 0;
    $!p_bar<next_update> ||= $!p_bar<step>;
    return 1;
}


method !_update_progress_bar() {
    my $multi = ( $!p_bar<count> / ( $!p_bar<total> / $!p_bar<bar_w> ) ).floor;
    if $!p_bar<short_print> {
        print "\r", clear-to-end-of-line();
        print( ( '=' x $multi ) ~ ( ' ' x ( $!p_bar<bar_w> - $multi ) ) );
    }
    else {
        printf( $!p_bar<fmt>, ( $!p_bar<count> / $!p_bar<total> * 100 ), ( '=' x $multi ) ~ ( ' ' x $!p_bar<bar_w> - $multi ) );
    }
    $!p_bar<next_update> += $!p_bar<step>;
}


method !_header_separator {
    my Str $lrb = '-' x $!edge_w;
    my Str $header_sep = $lrb;
    my Str $tab = ( '-' x $!tab_w div 2 ) ~ '|' ~ ( '-' x $!tab_w div 2 );
    for ^@!w_cols_calc {
        $header_sep ~= '-' x @!w_cols_calc[$_];
        $header_sep ~= $_ == @!w_cols_calc.end ?? $lrb !! $tab;
    }
    return $header_sep;
}


method !_print_term_not_wide_enough_message {
    my Str $prompt1 = 'Terminal window is not wide enough to print this table.';
    $!tc.pause( [ 'Press ENTER to show the column names.' ], :prompt( $prompt1 ) );
    #my Str $prompt2 = 'Reduce the number of columns".' ~ "\n" ~ 'Close with ENTER.';
    my Str $prompt2 = 'Close with ENTER.';
    $!tc.pause( @!tbl_copy[0], :prompt( $prompt2 ) );
}


sub _minus_x_percent ( Int $value, Int $percent ) {
    ( $value - ( $value / 100 * $percent ) ).Int || 1;
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
on which it is located. The user can scroll through the table with the different cursor keys.

=head2 KEYS

Keys to move around:

=item the K<ArrowDown> key (or the K<j> key) to move down and  the K<ArrowUp> key (or the K<k> key) to move up.

=item the K<PageUp> key (or K<Ctrl-P>) to go to the previous page, the K<PageDown> key (or K<Ctrl-N>) to go to the next
page.

=item the K<Insert> key to go back 10 pages, the K<Delete> key to go forward 10 pages.

=item the K<Home> key (or K<Ctrl-A>) to jump to the first row of the table, the K<End> key (or K<Ctrl-E>) to jump to the
last row of the table.

If I<table-expand> is set to C<0>, the K<Enter> key closes the table if the cursor is on the first row.

If I<table-expand> is enabled and the cursor is on the first row, pressing K<Enter> three times in succession closes
the table. If the cursor is auto-jumped to the first row, it is required only one K<Enter> to close the table.

If the cursor is not on the first row:

=item1 with the option I<table-expand> disabled the cursor jumps to the table head if K<Enter> is pressed.

=item1 with the option I<table-expand> enabled each column of the selected row is output in its own line preceded by the
column name if K<Enter> is pressed. Another K<Enter> closes this output and goes back to the table output. If a row is
selected twice in succession, the pointer jumps to the first row.

If the size of the window has changed, the screen is rewritten as soon as the user presses a key.

K<Ctrl-F> opens a prompt. A regular expression is expected as input. This enables one to only display rows where at
least one column matches the entered pattern. See option L<#search>.

=head2 Output

If the option table-expand is enabled and a row is selected with K<Enter>, each column of that row is output in its own
line preceded by the column name.

If the table has more rows than the terminal, the table is divided up on as many pages as needed automatically. If the
cursor reaches the end of a page, the next page is shown automatically until the last page is reached. Also if the
cursor reaches the topmost line, the previous page is shown automatically if it is not already the first page.

For the output on the screen the table elements are modified. All the modifications are made on a copy of the original
table data.

=item If an element is not defined the value from the option I<undef> is assigned to that element.

=item Each character tabulation (C<\t>) is replaces with a space.

=item Vertical tabulations (C<\v+>) are squashed to two spaces.

=item Code points from the ranges of C<control>, C<surrogate> and C<noncharacter> are removed.

=item If the option I<squash-spaces> is enabled leading and trailing spaces are removed and multiple consecutive spaces are
squashed to a single space.

=item If an element looks like a number it is right-justified, else it is left-justified.

If the terminal is too narrow to print the table, the columns are adjusted to the available width automatically.

=item First, if the option I<trunc-fract-first> is enabled and if there are numbers that have a fraction, the fraction is
truncated up to two decimal places.

=item Then columns wider than I<min-col-width> are trimmed. See option L<#min-col-width>.

=item If it is still required to lower the row width all columns are trimmed until they fit into the terminal.

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

If this option is enabled, SRG ANSI escape sequences can be used to color the screen output. Colors are reset to normal
after each table cell.

0 - off (default)

1 - on (current selected element not colored)

2 - on (current selected element colored)

=head2 decimal-separator

If set, numbers use I<decimal-separator> as the decimal separator instead of the default decimal separator.

Allowed values: a character with a print width of C<1>. If an invalid values is passed, I<decimal-separator> falls back
to the default value.

Default: . (dot)

=head2 footer

If set (string), I<footer> is added in the bottom line.

=head2 max-rows

Set the maximum number of used table rows. The used table rows are kept in memory.

To disable the automatic limit set I<max-rows> to C<0>.

If the number of table rows is equal to or higher than I<max-rows>, the last row of the output says
C<REACHED LIMIT "MAX_ROWS": $limit> or C<=LIMIT= $limit> if the previous doesn't fit in the row.

Default: 50_000

=head2 max-width-exp

Set a maximum width of the expanded table row output. (See option L<#table-expand>).

=head2 min-col-width

The columns with a width below or equal I<min-col-width> are only trimmed if it is still required to lower the row width
despite all columns wider than I<min-col-width> have been trimmed to I<min-col-width>.

Default: 30

=head2 mouse

Set the I<mouse> mode (see option C<mouse> in L<Term::Choose|https://github.com/kuerbis/Term-Choose-p6>).

Default: 0

=head2 pad-row-edges

Add a space at the beginning and end of each row.

0 - off (default)

1 - enabled

=head2 progress-bar

Set the progress bar threshold. If the number of fields (rows x columns) is higher than the threshold, a progress bar is
shown while preparing the data for the output. Setting the value to C<0> disables the progress bar.

Default: 5_000

=head2 save-screen

0 - off (default)

1 - use the alternate screen

=head2 search

Set the behavior of K<Ctrl-F>.

0 - off

1 - case-insensitive search (default)

2 - case-sensitive search

=head2 squash-spaces

If I<squash-spaces> is enabled, consecutive spaces are squashed to one space and leading and trailing spaces are
removed.

Default: 0

=head2 tab-width

Set the number of spaces between columns. If I<format> is set to C<2> and I<tab-width> is even, the spaces between the
columns are I<tab-width> + 1 print columns.

Default: 2

=head2 table-expand

If I<table-expand> is enabled and K<Enter> is pressed, the selected table row prints with each column on a new line.
Pressing K<Enter> again closes this view. The next K<Enter> key press will automatically jump the cursor to the first
row. If the cursor has automatically jumped to the first row, pressing K<Enter> will close the table instead of
expanding the first row. Pressing any key other than K<Enter> resets these special behaviors.

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

If I<table-expand> is set to C<0>, the cursor jumps to the to first row (if not already there) when K<Enter> is
pressed.

0 - off

1 - on (default)

=head2 trunc-fract-first

If the terminal width is not wide enough and this option is enabled, the first step to reduce the width of the columns
is to truncate the fraction part of numbers to 2 decimal places.

=head2 undef

Set the string that will be shown on the screen instead of an undefined field.

Default: "" (empty string)

=head1 ENVIRONMET VARIABLES

=head2 multithreading

C<Term::TablePrint> uses multithreading when preparing the list for the output; the number of threads to use can be set
with the environment variable C<TC_NUM_THREADS>.

=head1 REQUIREMENTS

=head2 Escape sequences

The control of the cursor location, the highlighting of the cursor position is done via escape sequences.

By default C<Term::Choose> uses C<tput> to get the appropriate escape sequences. If the environment variable
C<TC_ANSI_ESCAPES> is set to a true value, hardcoded ANSI escape sequences are used directly without calling C<tput>.

The escape sequences to enable the I<mouse> mode are always hardcoded.

If the environment variable C<TERM> is not set to a true value, C<vt100> is used instead as the terminal type for
C<tput>.

=head2 Monospaced font

It is required a terminal that uses a monospaced font which supports the printed characters.

=head2 Restrictions

Term::TablePrint is not installable on Windows.

=head1 CREDITS

Thanks to the people from L<Perl-Community.de|http://www.perl-community.de>, from
L<stackoverflow|http://stackoverflow.com> and from L<#perl6 on irc.freenode.net|irc://irc.freenode.net/#perl6> for the
help.

=head1 AUTHOR

Matthäus Kiem <cuer2s@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright 2016-2025 Matthäus Kiem.

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
