PRO make_source_reg, reffile

; NAME:
;     make_source_reg.pro
;
; PURPOSE:
;     Create CIAO region files for:
;          core = 0.15*r500
;          r200
;          r200 minus core
;          r500
;          r500 minus core
;          r1000
;          r1000 minus core
;          r2500
;          r2500 minus core
;          r5000
;          r5000 minus core
;          r7500
;          r7500 minus core
;          rlx minus core where rlx eq r500 if rmax lt r500, else rlx
;          eq rmax
;          rmax
;     Each region file is only constructed if the outer radius of the
;     region is less than the maximum radius defined in the reference file
;     (Rmax is typically the edge of the detector). The pixel and kpc
;     size of each created region is recorded in the make_source_reg.log file.
;
; EXPLANATION:
;     This script assumes the following directory structure:
;     all pertinent Chandra data files are in a dir labeled with
;     the obsid, which is then in a dir labeled acis/. The location
;     of acis/ relative to the dir from which this script is run is
;     assumed to be one level up.
;
;     e.g.: for Abell 644 obsid 2211, this script will look to
;     ../acis/2211/reprocessed for all the files needed to complete
;     the data reduction
;
;     New files will be placed in the same reprocessed/ dir
;
;     e.g.: after reduction, new annuli region files will be located in
;     ../acis/<obsid>/reprocessed
;
; CALLING SEQUENCE:
;     make_source_reg, 'reference_all.list'
;
; INPUTS:
;     Flare cleaned, point source excluded events file:             <obsid>_exclude.fits
;     Reference list of clusters to be used: <reference list>.list
;     the assumed format for the list is as follows:
;     #Name       ObsID        X        Y   Rmax MinCts         z  Nh20     Tx     Fe  Lbol ChipID   E_obs
;     ABELL_0644   2211   3908.5   4332.5  243.9   5000    0.0704  6.41   8.64   0.35 45.00     s3    3.22
;     ABELL_1651   4185   4222.5   4034.5  132.3   5000    0.0844  1.88   5.97   0.30 45.00     s3    2.39
;          
; OUTPUTS:
;     region file:   <obsid>_r200.reg
;     region file:   <obsid>_r200-50.reg
;     region file:   <obsid>_r500.reg
;     region file:   <obsid>_r500-50.reg
;     region file:   <obsid>_r2500.reg
;     region file:   <obsid>_r2500-50.reg
;     region file:   <obsid>_r5000.reg
;     region file:   <obsid>_r5000-50.reg
;     region file:   <obsid>_r7500.reg
;     region file:   <obsid>_r7500-50.reg
;     region file:   <obsid>_rlx-core.reg
;     region file:   <obsid>_rmax.reg
;
; MODIFICATION HISTORY:
;
;#####################
;#####################
; Main Program
;#####################
;#####################

rootdir = 'reprocessed/'

ON_ERROR, 2
IF n_params() EQ 0 THEN BEGIN
    print, 'Syntax - make_source, <reference file>'
    print, 'Outputs extraction regions'
    return
ENDIF

;# open the reference file
restore, "reflist_template.sav"
ref = read_ascii(reffile, template = reflist_template)

;# define some name inside of the loop
logfile = 'make_source_reg.log'
file_delete,[logfile],/quiet
close,7
openw,7,logfile,/append
printf, 7, format='(A-20,A10,7A10)',$
        "#Name","Obsid","r200","r500","r1000","r2500","r5000","r7500","rlx-core"

counter = n_elements(ref.obsid)
FOR i = 0, n_elements(ref.obsid)-1 DO BEGIN

   print, "# STATUS: ",num2str(counter)," clusters left."
   obs    = strcompress(ref.obsid[i],/remove_all)
   cname  = strcompress(ref.cluster[i],/remove_all)
   chipid = strcompress(ref.chip[i],/remove_all)
   x      = strcompress(ref.x[i],/remove_all)
   y      = strcompress(ref.y[i],/remove_all)
   rmax   = ref.rmax[i]
   z      = ref.z[i]
   tx     = ref.tx[i]
   datadir= ref.loc[i]

   ;# calc regions
   IF ((tx LE 0.) OR (z LE 0.)) THEN BEGIN
      printf, 7, format='(A-20,I10,7A10)',$
              cname,obs,"ERR","ERR","ERR","ERR","ERR","ERR","ERR"
      GOTO, ERR
   ENDIF
   r200  = (rdelta(200,z,tx,/silent))*1000.
   r500  = (rdelta(500,z,tx,/silent))*1000.
   r1000 = (rdelta(1000,z,tx,/silent))*1000.
   r2500 = (rdelta(2500,z,tx,/silent))*1000.
   r5000 = (rdelta(5000,z,tx,/silent))*1000.
   r7500 = (rdelta(7500,z,tx,/silent))*1000.

   ;# compute the size of 50, 70, and 100kpc in pixels using the eqaution
   ;# Region[kpc] / (0.492["/pixel] f(z)[kpc/"]) = Region[pixel]
   ;# where f(z) is the conversion factor from angular arcsec on the sky to kpc
   COSMOLOGY,z,result,/silent
;   corepix = 70. / (0.492 * result[4])
   corepix = (0.15*r500) / (0.492 * result[4])
   r2pix  = r200 / (0.492 * result[4])
   r5pix  = r500 / (0.492 * result[4])
   r10pix = r1000 / (0.492 * result[4])
   r25pix = r2500 / (0.492 * result[4])
   r50pix = r5000 / (0.492 * result[4])
   r75pix = r7500 / (0.492 * result[4])
   rmaxkpc = rmax * 0.492 * result[4]

   ;# define a region file name
   r2   = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_r200.reg'
   r5   = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_r500.reg'
   r10  = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_r1000.reg'
   r25  = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_r2500.reg'
   r50  = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_r5000.reg'
   r75  = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_r7500.reg'
   rm   = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_rmax.reg'

   r2L  = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_r200-core.reg'
   r5L  = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_r500-core.reg'
   r10L = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_r1000-core.reg'
   r25L = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_r2500-core.reg'
   r50L = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_r5000-core.reg'
   r75L = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_r7500-core.reg'
   rlx  = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_rlx-core.reg'

   hr200  = "n"
   hr500  = "n"
   hr1000 = "n"
   hr2500 = "n"
   hr5000 = "n"
   hr7500 = 'n'
   hrlx   = 'n'

   ;# set-up the r200-core region file
   IF (r2pix LE rmax) THEN BEGIN
      hr200 = "y"
      close,1

      ;# with core
      close,1
      openw,1,r2
      rout = round(r2pix)
      rout = strcompress(rout,/remove_all)
      printf,1,'circle(' ,x, ',' ,y, ',' ,rout, ')'
      close,1

      ;# without core
      openw,1,r2L
      rin = round(corepix)
      rout = round(r2pix)
      rin = strcompress(rin,/remove_all)
      rout = strcompress(rout,/remove_all)
      printf,1,'annulus(' ,x, ',' ,y, ',' ,rin, ',' ,rout, ')'
      close,1

   ENDIF

   ;# set-up the r500 region files
   IF (r5pix LE rmax) THEN BEGIN
      hr500 = "y"

      ;# with core
      close,1
      openw,1,r5
      rout = round(r5pix)
      rout = strcompress(rout,/remove_all)
      printf,1,'circle(' ,x, ',' ,y, ',' ,rout, ')'
      close,1

      ;# without core
      close,3
      openw,3,r5L
      rin = round(corepix)
      rout = round(r5pix)
      rin = strcompress(rin,/remove_all)
      rout = strcompress(rout,/remove_all)
      printf,3,'annulus(' ,x, ',' ,y, ',' ,rin, ',' ,rout, ')'
      close,3
   ENDIF

   ;# set-up the r1000 region files
   IF (r10pix LE rmax) THEN BEGIN
      hr1000 = "y"

      ;# with core
      close,1
      openw,1,r10
      rout = round(r10pix)
      rout = strcompress(rout,/remove_all)
      printf,1,'circle(' ,x, ',' ,y, ',' ,rout, ')'
      close,1

      ;# without core
      close,3
      openw,3,r10L
      rin = round(corepix)
      rout = round(r10pix)
      rin = strcompress(rin,/remove_all)
      rout = strcompress(rout,/remove_all)
      printf,3,'annulus(' ,x, ',' ,y, ',' ,rin, ',' ,rout, ')'
      close,3
   ENDIF

   ;# set-up the rlx-core region
   IF r5pix GT rmax THEN rout = round(rmax) ELSE rout = round(r5pix)
   rin = round(corepix)
   IF rout GT rin THEN BEGIN
      hrlx = 'y'
      close,3
      openw,3,rlx
      rin = strcompress(rin,/remove_all)
      rout = strcompress(rout,/remove_all)
      printf,3,'annulus(' ,x, ',' ,y, ',' ,rin, ',' ,rout, ')'
      close,3
   ENDIF

   ;# set-up the regions for r2500
   IF (r25pix LE rmax) THEN BEGIN
      hr2500 = "y"

      ;# with core
      close,5
      openw,5,r25
      rout = round(r25pix)
      rout = strcompress(rout,/remove_all)
      printf,5,'circle(' ,x, ',' ,y, ',' ,rout, ')'
      close,5

      ;# without core
      close,8
      openw,8,r25L
      rin = round(corepix) 
      rin = strcompress(rin,/remove_all)
      printf,8,'annulus(' ,x, ',' ,y, ',' ,rin, ',' ,rout, ')'
      close,8
   ENDIF

   ;# set-up the regions for r5000
   IF (r50pix LE rmax) THEN BEGIN
      hr5000 = "y"

      ;# with core
      rout = round(r50pix)
      close,6
      openw,6,r50
      rout = strcompress(rout,/remove_all)
      printf,6,'circle(' ,x, ',' ,y, ',' ,rout, ')'
      close,6

      ;# without core
      close,9
      openw,9,r50L
      rin = round(corepix) 
      rin = strcompress(rin,/remove_all)
      printf,9,'annulus(' ,x, ',' ,y, ',' ,rin, ',' ,rout, ')'
      close,9
   ENDIF

   ;# set-up the regions for r7500
   IF (r75pix LE rmax) THEN BEGIN
      hr7500 = "y"

      ;# with core
      rout = round(r75pix)
      close,6
      openw,6,r75
      rout = strcompress(rout,/remove_all)
      printf,6,'circle(' ,x, ',' ,y, ',' ,rout, ')'
      close,6

      ;# without core
      close,9
      openw,9,r75L
      rin = round(corepix) 
      rin = strcompress(rin,/remove_all)
      printf,9,'annulus(' ,x, ',' ,y, ',' ,rin, ',' ,rout, ')'
      close,9
   ENDIF

   ;# set-up the rlx-core region
   rout = round(rmax)
   close,3
   openw,3,rm
   rout = strcompress(rout,/remove_all)
   printf,3,'circle(' ,x, ',' ,y, ',' ,rout, ')'
   close,3

   ;# print all the results to log
   printf, 7, format='(A-20,I10,7A10)',$
           cname,obs,hr200,hr500,hr1000,hr2500,hr5000,hr7500,hrlx
ERR:
   counter--
ENDFOR

;# close the log file
close,7

END

