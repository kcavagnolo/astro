; NAME:
;     view_ltcrv.pro
;
; PURPOSE:
;     display postscript of cumulative count profile
;
; EXPLANATION:
;     This script assumes the following directory structure:
;     all pertinent Chandra data files are in a dir labeled with
;     the obsid, which is then in a dir labeled acis/. The location
;     of acis/ relative to the dir from which this script is run is
;     set with the variable $datadir.
;
;     e.g.: for Abell 644 obsid 2211, this script will look to
;     $datadir/acis/2211/ for all the files needed to complete
;     the data reduction
;
; CALLING SEQUENCE:
;     view_ltcrv, '<reference list>'
;     view_ltcrv, 'ref.list'
;
; INPUTS:
;     <reference list> = file containing information about each cluster
;     the assumed format for the list is as follows:
;     Name                           ObsID        X        Y   Rmax     MinCts         z  Nh20     Tx     Fe  Lbol ChipID
;     ABELL_0644                      2211   3908.5   4332.5  243.9       5000    0.0704  6.41   8.64   0.35 45.00     s3
;     ABELL_1651                      4185   4222.5   4034.5  132.3       5000    0.0844  1.88   5.97   0.30 45.00     i2
;
; OUTPUTS:
;     nothing
;
; MODIFICATION HISTORY:
;
;#######################
;#######################
;##   Main Program    ##
;#######################
;#######################

pro load_ltcrv, reffile

datadir = 'reprocessed'

; open the reference file
readcol, reffile, FORMAT='A,A,F,F,F,F,F,F,F,F,F,A,F,A,F,A', comment='#', $
         cluster,obsids,x,y,rmax,mincts,zs,nhs,txs,fes,lbols,chips,eobss,diffs,robs,loc

FOR i = 0, n_elements(obsids)-1 DO BEGIN

; define data info
    obs    = strcompress(obsids[i],/remove_all)
    cname  = strcompress(cluster[i],/remove_all)
    rootdir = loc[i]

; define a file name
    ltfile = rootdir+'/'+obs+'/'+datadir+'/'+obs+'_lc.fits'
    psfile = 'temp.ps'

; get data needed to plot
    data = mrdfits(ltfile,1)
    time = data.time
    ctr = data.count_rate

; plot labels
    header = "Cluster: "+cname+" ; ObsID: "+obs
    xtx = textoidl("Time (sec)")
    ytx = textoidl("Count Rate (cts/sec)")

; make a hardcopy
    set_plot, 'PS'
    device, filename=psfile
    !FANCY    = 4
    !LINETYPE = 0
    !P.FONT   = 0
    !X.THICK  = 3
    !Y.THICK  = 3
    !Z.THICK  = 3
    xmin = min(time)
    xmax = max(time)
    ymin = 0.8*min(ctr)
    ymax = 1.2*max(ctr)
    plotsym, 0, 0.8, /fill
    plot, time, ctr, $
          /xsty, /ysty, $
          xrange = [xmin,xmax], $
          yrange = [ymin,ymax], $
          psym = 8, $
          title  = header, $
          xtitle = xtx, $
          ytitle = ytx, $
          charsize = 1.0
    
; close the device
    device, /close

; make all the log files into one log
    SPAWN, 'gv temp.ps'

; clean-up the resulting mess of files
    SPAWN, 'rm -f temp.ps'

ENDFOR

END
