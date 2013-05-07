PRO sigsrc, ref

;#######################
;#######################
;##    Set Options    ##
;#######################
;#######################

;# other options needed
verb = 1
datadir = "/mnt/SINISTER"
rootdir = "reprocessed"

;#######################
;#######################
;##   Main Program    ##
;#######################
;#######################

ciao = GETENV('ASCDS_BIN')
IF (ciao EQ '') THEN exit

ON_ERROR, 2
IF n_params() EQ 0 THEN BEGIN
   print, 'Syntax - sigsrc, <reference file>'
   print, 'Outputs region for point sources'
   RETURN
ENDIF

readcol, ref, FORMAT='A,A,F,F,F,F,F,F,F,F,F,A,F,A,F,A', comment='#',$
         cluster,obsids,x,y,rmax,mincts,z,nh,tx,fe,lbol,chip,eobs,diff,robs,loc

FOR i=0, n_elements(obsids)-1 DO BEGIN
   name = cluster[i]
   obsid = obsids[i]
   mydir = datadir+'/'+obsid+'/'+rootdir
   files = [mydir+'/'+name+'_'+obsid+'_src_core.fits'];, mydir+'/'+name+'_'+obsid+'_src.fits']
   outreg = mydir+'/'+obsid+'_sigsrc.reg'
   OPENW, /get_lun, OUTLUN, outreg
   printf, OUTLUN, '# Region file format: DS9 version 4.0'
   printf, OUTLUN, 'global color=green font="helvetica 8 normal" select=1 highlite=1 edit=1 move=1 delete=1 include=1 fixed=1 source'
;   printf, OUTLUN, 'fk5'
   FOR zz=0, n_elements(files)-1 DO BEGIN
      file = files[zz]
      srcfits = mrdfits(file, 1, hdr, /silent)
      naxis = sxpar(hdr,'NAXIS2')
      IF naxis LE 0 THEN GOTO, ERR
      ra = srcfits.ra
      dec = srcfits.dec
      sig = srcfits.src_significance
      x = srcfits.x
      y = srcfits.y
      r = srcfits.r
      rot = srcfits.rotang
      FOR j=0, naxis-1 DO BEGIN
;         printf, OUTLUN, FORMAT='(A,F,A,F,A,I4,A)','# text(',ra[j],',',dec[j],') text={',sig[j],'}'
         printf, OUTLUN, FORMAT='(A,F,A,F,A,I4,A)','# text(',x[j],',',y[j],') text={',sig[j],'}'
         tr = r[*,zz]
         r1 = tr[0]
         r2 = tr[1]
;         printf, OUTLUN, FORMAT='(A,F,A,F,A,F,A,F,A,F,A)','ellipse(',x[j],',',y[j],',',r1,',',r2,',',rot[j],')'
      ENDFOR
      ERR:
   ENDFOR
   FREE_LUN, OUTLUN
ENDFOR
END
