PRO plot_arf, ref

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
; EXAMPLE:
;
; MODIFICATION HISTORY:
;
;#####################
;#####################
;      OPTIONS
;#####################
;#####################

ext = 'r5000-50'

;#####################
;#####################
; Main Program
;#####################
;#####################

ON_ERROR, 2
IF n_params() EQ 0 THEN BEGIN
   print, 'Syntax - plot_arf, <ref file>'
   print, 'Plots Auxiliary Response File (ARF)'
   print, 'Example: plot_arf, reference.list'
   return
ENDIF

; open the ref file
readcol, ref, FORMAT='A,A,F,F,F,F,F,F,F,F,F,A,F,A,F,A', comment='#',$
         clusters,obsids,xs,ys,rmaxs,minctss,zs,nhs,txs,fes,lbols,chips,eobss,diffs,robss,locs

FOR i = 0,n_elements(obsids)-1 DO BEGIN
   obsid = strcompress(obsids[i],/remove_all)
   clustername = strcompress(clusters[i],/remove_all)
   loc = locs[i]
   file = loc+'/'+obsid+'/reprocessed/'+clustername+'_'+obsid+'_'+ext+'_src1.warf'

   ;check for file existance
   check = findfile(file,count=count)
   IF (count NE 1) THEN BEGIN
      print,'## ERROR: No ',file,' found.'
      GOTO, err
   ENDIF

   a = mrdfits(file,1)
   x = a.energ_hi
   y = a.specresp
   plotfile = obsid+'_arf.ps'
   set_plot, 'PS'
   device, filename = plotfile, $
           /helvetica, $
           bits=16
   !FANCY    = 4
   !LINETYPE = 0
   !P.FONT   = 0
   !X.THICK  = 3
   !Y.THICK  = 3
   !Z.THICK  = 3
   xmin = 0.8*min(x)
   xmax = 1.2*max(x)
   ymin = min(y)
   ymax = 1.2*max(y)
   plot, x, y, $
         title = clustername+' '+obsid, $
         xtitle = textoidl('Energy [keV]'), $
         ytitle = textoidl('Spectral Response [cm^{-2} cts photon^{-1}]'), $
         xrange = [xmin,xmax], $
         yrange = [ymin,ymax],$
         /xsty, /ysty, $
         /xlog, /ylog, $
         charsize = 1.0
   device, /close
   set_plot, "X"
err:
ENDFOR
END
