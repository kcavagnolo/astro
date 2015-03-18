#! /usr/bin/perl -w


while (<>) {
    chomp;
    if ($_ =~ /setrgbcolor/) {
	@color_line = split /\s+/;
	
	for ($i = 0; $i <= $#color_line; $i++) {
	    if ($color_line[$i] eq 'setrgbcolor') {
		if ($i < 3) {
		    die "Fix it yourself, command splitter!\n";
		}
		else {
		    $R = $color_line[$i - 3];
		    $G = $color_line[$i - 2];
		    $B = $color_line[$i - 1];

# 		    if   (($R == 1)&&($G == 0)&&($B == 0)) {
# 			$grey_value = 0.6;
# 		    }
# 		    elsif(($R == 0)&&($G == 1)&&($B == 0)) {
# 			$grey_value = 0.4;
# 		    }
# 		    elsif(($R == 0)&&($G == 0)&&($B == 1)) {
# 			$grey_value = 0.2;
# 		    }
# 		    else {
			$grey_value = (0.3 * $R + 0.59 * $G + 0.11 * $B);
# 		    }
		    $color_line[$i - 3] = '';
		    $color_line[$i - 2] = '';
		    $color_line[$i - 1] = $grey_value;
		    $color_line[$i] = "setgray";
		}
	    }
	}
	
	$_ = join ' ', @color_line;
    }
		
    print "$_\n";
}

	
