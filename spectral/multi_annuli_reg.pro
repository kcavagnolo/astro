PRO multi_annuli_reg, reffile

; NAME:
;
; PURPOSE:
;
; EXPLANATION:
;
; CALLING SEQUENCE:
;
; INPUTS:
;          
; OUTPUTS:
;
; MODIFICATION HISTORY:
;
;#####################
;#####################
;      OPTIONS
;#####################
;#####################

myhome     = GETENV('HOME')
mkbackup   = 'no'
bkdir      = '/mnt/GIDEON/backup_ann/'
mkrm       = 'yes'
makeann    = 'yes'
ext        = ''
numpp      = '1'
runname    = 'annuli'
fiddir     = 'merged'
cumprofdir = myhome+'/research/smcs/analysis/cumprof/'

;#####################
;#####################

; open the cummulative profile and create shorthand variables
readcol, reffile, FORMAT='A,A,A,A,F,F,F,F,F,F,F,A,F,A,F,A,A', comment='#', $
         clusters,obsids,xs,ys,rmaxs,minctss,zs,nhs,txs,fes,$
         lbols,chips,eobss,diffs,robss,locs,trefs

; open a log
GET_LUN, LOGLUN                 ; Get logical unit number LUN
OPENW, LOGLUN, "multi_annuli_reg.log"
GET_LUN, LISTLUN
OPENW, LISTLUN, "list"

FOR i = 0,n_elements(clusters)-1 DO BEGIN
   obsid    = strsplit((strcompress(obsids[i],/remove_all)),'_',/EXTRACT)
   cname    = strcompress(clusters[i],/remove_all)
   x        = xs[i]
   y        = ys[i]
   z        = zs[i]
   tx       = txs[i]
   rmax     = rmaxs[i]
   mincts   = minctss[i]
   datadir  = locs[i]
   cummprof = datadir+'/'+fiddir+'/'+cname+'/'+cname+'_cumprof.fits'

   ;check for errors
   notxz = 'no'
   IF (tx LE 0 OR z LE 0) THEN BEGIN
      notxz = 'yes'
      GOTO, notxz
   ENDIF
   check = findfile(cummprof,count=count)
   IF (count NE 1) THEN BEGIN
      print,'## ERROR: no ',cummprof
      GOTO, err
   ENDIF

   ;calculate rdelta in kpc and pixels based on z and Tx
   count = 1
   rd = 0.5*((rdelta(180,z,tx,/silent))*1000.)
   COSMOLOGY,z,result,/silent
   rdpix = rd/(0.492*result[4])

   ;define the extraction radius
;   IF (rmax LT rdpix) THEN BEGIN
      rdet = rmax
      used = 'rmax'
;   ENDIF ELSE BEGIN
;      rdet = rdpix
;      used = 'rdelta'
;   ENDELSE
    
   ;grab fits info
   fits = mrdfits(cummprof,1,/silent)
   rmid = fits.rmid
   net_counts = fits.net_counts
   ord = [where(rmid LE rdet)]
   rmid = rmid(ord)
   net_counts = net_counts(ord)

   ;create annuli using mincts
   maxcts = max(net_counts)
   n_annuli = fix(maxcts/mincts)+1
   count_goals = (findgen(n_annuli)+1)*mincts
   annrout = fltarr(n_annuli)
   FOR j=0,n_annuli-2 DO BEGIN
      annrout[j] = min(rmid[where(net_counts GE count_goals[j])])
   ENDFOR

   ;last bin set to maximum radius
   annrout[n_annuli-1] = max(rmid)

   ;inner bins set to outer bins-2
   IF n_elements(annrout) LE 1 THEN BEGIN
      print,'## ERROR: only one annulus for ',cname
      GOTO, err
   ENDIF ELSE IF n_elements(annrout) LE 2 THEN BEGIN
      annrin = replicate(0.0,n_elements(annrout))
   ENDIF ELSE BEGIN
      annrin = [0.0, annrout[0:n_annuli-2]]
   ENDELSE

   ;check for last bins which are too small
   last = n_elements(annrout)-1
   lastbin = annrout[last] - annrin[last]
   prevbin = annrout[last-1] - annrin[last-1]
   IF (lastbin/prevbin) LE 0.75 THEN BEGIN
      annrout[last-1] = annrout[last]
      junk = pop(annrout)
      junk = pop(annrin)
      n_annuli = n_elements(annrout)
   ENDIF

   ; make the actual annuli
   IF makeann EQ "yes" THEN BEGIN
      FOR j=0,n_elements(obsid)-1 DO BEGIN

         ; where returns an array
         print, '## Removing files in the way...'
;         SPAWN, 'ls -1 '+datadir+obsid[j]+'/reprocessed/'+cname+'_'+obsid[j]+'_*'+runname+'*'+ext
         IF mkbackup EQ 'yes' THEN $
            SPAWN, 'mv -f '+datadir+'/'+obsid[j]+'/reprocessed/'+cname+'_'+obsid[j]+'_*'+runname+'*'+ext+' '+bkdir
         IF mkrm EQ 'yes' THEN $
            SPAWN, 'rm -f '+datadir+'/'+obsid[j]+'/reprocessed/'+cname+'_'+obsid[j]+'_*'+runname+'*'+ext
         printf,LOGLUN,"",obsid[j],": Num Annuli:", strcompress(n_annuli), "; Counts per:", strcompress(mincts)
         strx = strcompress(x,/remove_all)
         stry = strcompress(y,/remove_all)
         FOR k=0,n_annuli-1 DO BEGIN
            num = k+1
            filename = datadir+'/'+obsid[j]+'/reprocessed/'+cname+'_'+obsid[j]+'_'+runname+strcompress(num,/remove_all)+'.reg'
            close,1
            openw,1,filename
            str1 = strcompress((annrin(k)*0.492/60.),/remove_all)
            str2 = strcompress((annrout(k)*0.492/60.),/remove_all)
            printf,1,"annulus(" ,strx, "," ,stry, "," ,str1, "'," ,str2, "')"
            close,1
         ENDFOR
      ENDFOR
   ENDIF

    ; plot the results
    set_plot, 'PS'
    device, filename = cname+'_cumprof.ps'
    !fancy = 4
    !linetype = 0
    !p.font = 0
    !xtitle = textoidl('R_{mid} [Pixels]')
    !ytitle = "Cumulative Net Counts"
    !mtitle = cname
    plot, rmid, net_counts, $
          xran = [0,max(rmid)+10], $
          yran = [min(net_counts)-1000,max(net_counts)+1000], $
          /xsty, $
          /ysty, $
          charsize = 0.8, $
          psym = 10
    void, ctpts
    FOR l=0,n_annuli-1 DO BEGIN
        !linetype = 2
        !psym = 0
        y = [-1.e8,(l+1.)*mincts]
        x = replicate(annrout[l],n_elements(y))
        oplot, x, y
        push, ctpts, (l+1.)*mincts
    ENDFOR

    ; plot points on curve for annuli endpoints
    !linetype = 0
    !psym = 2
    oplot, annrout, ctpts

    ; plot a line demarcating net_cts=0
    !linetype = 3
    !psym = 0
    x = findgen(2000)
    y = replicate(0,2000)
    oplot, x, y

    ; draw a legend
    items = ['# annuli: '+num2str(round(n_annuli)), $
             'Min. cts: '+num2str(round(mincts)), $
             textoidl('0.5 R_{180}: '+num2str(round(rdpix))), $
             textoidl('R_{max}: '+num2str(round(rmax)))]
    linearr = replicate(-99,n_elements(items))
    psyarr = replicate(-99,n_elements(items))
    legend, items, linestyle=linearr, psym=psyarr, charsize=0.8, $
            /bottom, box=0, /right_legend
    device, /close
    printf, LISTLUN, cname+'_cumprof.ps'

err:
    IF count NE 1 THEN printf,LOGLUN,"",cname,": No ",cummprof
    IF n_elements(annrout) LE 1 THEN printf,LOGLUN,cname,": Only one annulus for", strcompress(mincts)," counts"
notxz:
    IF notxz EQ 'yes' THEN printf,LOGLUN,"",cname,": No Tx"
ENDFOR
close, LOGLUN
close, LISTLUN

SPAWN, 'cat list | pscat '+numpp+' all.ps'
SPAWN, 'mv -f *cumprof.ps '+cumprofdir
SPAWN, 'rm -f *cumprof.ps'
SPAWN, 'rm -f list'
set_plot, "X"

END

