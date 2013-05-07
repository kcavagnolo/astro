#!/usr/bin/perl
# Made by Ming Sun, 2002
# Make surface brightness profile from the input
# photon image, flat field image, background image
# Will test the statatistics of each region
# (> ? counts ; size > size_min)
#
# First, input photon_im flat_field_im ba_im mask_im scale max_radius xc yc
# Second, measure_sbp cnt_min size_min

###############################################################
$ph_im =  "909_img.fits.gz";
$flat_im = "909_norm.fits.gz";
$ba_im = "909_bgdimg.fits.gz";
$mask_im = "909_expmap.fits.gz";

$max_ra = 100.;
$bin = 1.0;
$scale = 0.36128;
$xc = 4022.;
$yc = 4238.;
$ba_flux = 0.;
###############################################################

if (@ARGV eq 2) {
  ($cnt_min, $size_min) = @ARGV;
}
else {
  die "Usage: ./measure_sbp cnt_min size_min\n";
}

`rm jnk*`;

######## make regfiles

$rad_last = 0.;
$diff = $size_min;
$rad = $diff + $rad_last;
$i = 1;
while ($rad <= $max_ra) {
  `echo 'circle($xc,$yc,$rad)' > ${i}.reg`;
  if ($rad_last > 0.) {`echo '-circle($xc,$yc,$rad_last)' >> ${i}.reg`}
  `mkreg refimg=$ph_im out=${i}.img reg=file:${i}.reg`;
  `imarith $mask_im ${i}.img ${i}_mask.img "*"`;
  `imexam $ph_im sum reg=${i}_mask.img > jnk1`;
  `imexam $ba_im sum reg=${i}_mask.img > jnk2`;
  open(IN,jnk1);
  $res1 = <IN>;
  close(IN);
  open(IN,jnk2);
  $res = $res1 - <IN>;
  close(IN);
#
# For inner regions, use smaller cnt_min
#
  $cnt_min1 = $cnt_min;
#
#
  if ($res < $cnt_min1) {
    `rm -f ${i}.img`;
    $rad = $rad + 1.0;
  } else {
    `cat ${i}.reg >> all_reg.reg`;
    `imexam ${i}_mask.img sum > jnk3`;
    open(IN,jnk3);
    $area = <IN>;
    close(IN);
    `imexam $flat_im sum reg=${i}_mask.img > jnk4`;
    open(IN,jnk4);
    $sb = <IN>;
    close(IN);
    $area1 = $area * $bin * $bin *0.492*0.492*${scale}*${scale};
    $sb1 = $sb / $area1 - $ba_flux;
    $sb1_e = $sb1 * abs(sqrt($res1)) / $res ;
    $r_av = ($rad_last + $rad )* $bin *0.492*${scale}/2.0;
    $r_av1 = $rad_last * $bin *0.492*${scale};
    $r_av2 = $rad * $bin *0.492*${scale};
    printf "%8.3f %8.3f %8.3f %8.4e %8.4e\n", $r_av, $r_av1, $r_av2, $sb1,$sb1_e;
    $diff = $rad - $rad_last;
    $rad_last = $rad;
    $rad = $rad + $diff;
    `rm ${i}.img`;
    `rm ${i}_mask.img`;
    `rm ${i}.reg`;
    $i = $i + 1;
  }
}
