pro plot_cm, reffile

datadir = '/mnt/DROBO'
redir = 'reprocessed'
cumdir = '~/research/pf_clusters/pf_fits/plots/cumprof/recheck/'
numpp = '4'

restore,"~/research/redux/scripts/reflist_template.sav"
ref = read_ascii(reffile, template = reflist_template)

; open a log
GET_LUN, LOGLUN                 ; Get logical unit number LUN
GET_LUN, OUTLUN                 ; Get logical unit number LUN
OPENW, LOGLUN, "err_plotnet.log"
OPENW, OUTLUN, "list"

obsids = ref.obsid
FOR i = 0,n_elements(obsids)-1 DO BEGIN
    obsid = strcompress(obsids[i],/remove_all)
    name  = strcompress(ref.cluster[i],/remove_all)
    net   = datadir+'/'+obsid+'/'+redir+'/'+obsid+'_cumprof.fits'

    ; check for file existance
    check = findfile(net,count=count)
    IF (count NE 1) THEN GOTO, err

    fits = mrdfits(net,1)
    rmid = fits.rmid
    srcnet = fits.net_counts
    srcneterr = fits.net_err

    ; plot the results
    loadct, 12, /silent
    set_plot, 'PS'
    device, filename = obsid+'_cumprof.ps', /color
    !fancy = 4
    !linetype = 0
    !p.font = 0
    !xtitle = textoidl('R_{mid} [arcsec]')
    !ytitle = textoidl('Cumulative Counts [ct]')
    !mtitle = +name+"           "+obsid
    plotsym, 0, 0.5, /fill, color=100
    plot, rmid, srcnet, $
          /nodata, $
          xran = [0.90*min(rmid),1.1*max(rmid)], $
          yran = [0.90*min(srcnet-srcneterr),1.1*max(srcnet+srcneterr)], $
          /xlog, /ylog, $
          /xsty, /ysty, $
          charsize = 0.8
    oplot, rmid, srcnet, psym=8, color=100
    oploterror, rmid, srcnet, srcneterr, psym=8, errcolor=100
    plotsym, 8, 0.5, /fill, color=200
    device, /close
    printf, OUTLUN, obsid+'_cumprof.ps'

err:
    IF (count NE 1) THEN printf, LOGLUN, "",obsid," : No ",strcompress(net,/remove_all)," file"
ENDFOR

close, LOGLUN
close, OUTLUN

SPAWN, 'cat list | pscat '+numpp+' all.ps'
SPAWN, 'mv -f *cumprof.ps '+cumdir
SPAWN, 'rm -f *cumprof.ps'
SPAWN, 'rm -f list'
set_plot, "X"

END
