pro plot_multisb, reffile

datadir = '/Volumes/GALACTUS/merged'
sbdir = '~/research/pf_clusters/pf_fits/plots/sbr/'
bin = '10pix'
numpp = '4'

restore,"~/research/redux/scripts/doubles_template.sav"
ref = read_ascii(reffile, template = doubles_template)

; open a log
GET_LUN, LOGLUN                 ; Get logical unit number LUN
GET_LUN, OUTLUN                 ; Get logical unit number LUN
OPENW, LOGLUN, "err_plotsb.log"
OPENW, OUTLUN, "list"

FOR i = 0,n_elements(ref.name)-1 DO BEGIN
    void, temp
    void, obs
    push, temp, strcompress(ref.obsid1[i],/remove_all)
    push, temp, strcompress(ref.obsid2[i],/remove_all)
    push, temp, strcompress(ref.obsid3[i],/remove_all)
    push, temp, strcompress(ref.obsid4[i],/remove_all)
    obsstr = temp[0]
    push, obs, temp[0]
    FOR j=1,n_elements(temp)-1 DO BEGIN
        IF temp[j] NE 0000 THEN obsstr = obsstr+'_'+temp[j]
        IF temp[j] NE 0000 THEN push, obs, temp[j]
    ENDFOR
    name   = strcompress(ref.name[i],/remove_all)
    sbr    = datadir+'/'+name+'/'+obsstr+'_sbprof_'+bin+'.fits'

    ; check for file existance
    check = findfile(sbr,count=count)
    IF (count NE 1) THEN GOTO, err

    fits   = mrdfits(sbr,1)
    rmid   = fits.rmid*0.492
    exp    = fits.exposure
    bgexp  = fits.bg_exposure
    surbri = fits.sur_bri/exp/(0.492^2.)
    sbrerr = fits.sur_bri_err/exp/(0.492^2.)
    bgsbr  = fits.bg_sur_bri/bgexp/(0.492^2.)
    bgsbrerr = fits.bg_sur_bri_err/bgexp/(0.492^2.)

    ; plot the results
    loadct, 12, /silent
    set_plot, 'PS'
    device, filename = obsstr+'_sbprof_'+bin+'.ps', /color
    !fancy = 4
    !linetype = 0
    !p.font = 0
    !xtitle = textoidl('R_{mid} [arcsec]')
    !ytitle = textoidl('Surface Brightness [cts arcsec^{-2} sec^{-1}]')
    !mtitle = +name+"           "+obsstr
    plotsym, 0, 0.5, /fill, color=100
    plot, rmid, surbri, $
          /nodata, $
          xran = [0.90*min(rmid),1.1*max(rmid)], $
          yran = [0.90*min(bgsbr-bgsbrerr),1.1*max(surbri+sbrerr)], $
          /xlog, $
          /ylog, $
          /xsty, $
          /ysty, $
          charsize = 0.8
    oplot, rmid, surbri, psym=8, color=100
    oploterror, rmid, surbri, sbrerr, psym=8, errcolor=100
    plotsym, 8, 0.5, /fill, color=200
    oplot, rmid, bgsbr, psym=8, color=200
    oploterror, rmid, bgsbr, bgsbrerr, psym=8, errcolor=200
    device, /close
    printf, OUTLUN, obsstr+'_sbprof_'+bin+'.ps'

err:
    IF (count NE 1) THEN printf, LOGLUN, "",obsstr," : No ",strcompress(sbr,/remove_all)," file"
ENDFOR

close, LOGLUN
close, OUTLUN

SPAWN, 'cat list | perl pscat.pl '+numpp+' all.ps'
SPAWN, 'mv -f *sbprof_'+bin+'.ps '+sbdir
SPAWN, 'rm -f *sbprof_'+bin+'.ps'
;SPAWN, 'rm -f list'
set_plot, "X"

END
