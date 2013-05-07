PRO plot_expcorr, ref

; NAME:
;     plot_expcorr.pro
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

makeann = 'no'
numpp = '6'
dir1 = '/Volumes/HD1/Users/cavagnolo/research/me_temp_proj/acis/'
dir2 = '/Volumes/MBRANE/'
cumprofdir = '/Volumes/HD1/Users/cavagnolo/research/pf_clusters/pf_fits/plots/cumprof/'

;#####################
;#####################
; Main Program
;#####################
;#####################

ON_ERROR, 2
IF n_params() EQ 0 THEN BEGIN
    print, 'Syntax - plot_expcorr, <ref file>'
    print, 'Plots exposure correction'
    print, 'Example: plot_expcorr, ../me_info/ref_loc.list'
    return
ENDIF

; open the ref file
restore,"reflist_template.sav"
ref = read_ascii(ref, template = reflist_template)

; open a log
GET_LUN, LOGLUN
OPENW, LOGLUN, "plot_excorr.log"

FOR i = 0,n_elements(ref.obsid)-1 DO BEGIN
    obsid = strcompress(ref.obsid[i],/remove_all)
    clustername = strcompress(ref.cluster[i],/remove_all)
    loc = ref.loc[i]
    IF loc EQ "NAZGUL" THEN datadir = dir1
    IF loc EQ "MBRANE" THEN datadir = dir2
    file1 = datadir+obsid+'/reprocessed/'+obsid+'_expcorr.fits'
    file2 = datadir+obsid+'/reprocessed/'+obsid+'_sbprof_10pix.fits'

    ; check for file existance
    check1 = findfile(file1,count=count1)
    check2 = findfile(file1,count=count2)
    IF (count1 NE 1 OR count2 NE 1) THEN BEGIN
        print,'## ERROR: check log file.'
        GOTO, err
    ENDIF

    a = mrdfits(file1,1)
    sfl = a.sur_bri
    rmid = a.rmid
    b = mrdfits(file2,1)
    sbr = b.sur_bri

    excr = sbr/sfl
    excr = excr/excr[0]

    plotfile = obsid+'_expcorr.ps'
    set_plot, 'PS'
    device, filename = plotfile
    plot, rmid, excr, $
          title = clustername+' '+obsid, $
          xtitle = textoidl('R_{mid} [Pixels]'), $
          ytitle = textoidl('Normalized Exposure Correction')

    device, /close
    set_plot, "X"
err:
    IF (count1 NE 1 OR count2 NE 1) THEN printf, LOGLUN, "",obsid,": No ",cummprof," file"
ENDFOR

close, LOGLUN

END
