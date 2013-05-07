PRO make_cen_ann, reffile

rootdir = 'reprocessed'

ON_ERROR, 2
IF n_params() NE 1 THEN BEGIN
    print, 'Syntax - make_source, <reference file>'
    print, 'Outputs extraction regions'
    return
ENDIF

;# read the input reference file
readcol, reffile, FORMAT='A,A,F,F,F,F,F,F,F,F,F,A,F,A,F,A', comment='#', $
         clusters,obsids,xs,ys,rmaxs,minctss,zs,nhs,txs,fes,lbols,chips,eobss,diffs,robs,locs

FOR i = 0, n_elements(obsids)-1 DO BEGIN
   obs    = strcompress(obsids[i],/remove_all)
   x      = strcompress(xs[i],/remove_all)
   y      = strcompress(ys[i],/remove_all)
   z      = zs[i]
   datadir =locs[i]

   ;# compute the size of 50, 70, and 100kpc in pixels using the eqaution
   ;# Region[kpc] / (0.492["/pixel] f(z)[kpc/"]) = Region[pixel] where f(z)
   ;# is the conversion factor from angular arcsec on the sky to kpc
   COSMOLOGY, z, result, /silent
   twepix = 20. / (0.492 * result[4])
   fifpix = 50. / (0.492 * result[4])
   sevpix = 70. / (0.492 * result[4])
   hunpix = 100. / (0.492 * result[4])

    ;# define a region file name
    inner20 = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_inner20.reg'
    inner50 = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_inner50.reg'
    inner70 = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_inner70.reg'
    inner100 = datadir+'/'+obs+'/'+rootdir+'/'+obs+'_inner100.reg'

    ;# set-up the regions for inner 20 kpc
    close,1
    openw,1,inner20
    rout = round(twepix)
    rout = strcompress(rout,/remove_all)
    printf,1,'circle(' ,x, ',' ,y, ',' ,rout, ')'
    close,1

    ;# set-up the regions for inner 50 kpc
    close,1
    openw,1,inner50
    rout = round(fifpix)
    rout = strcompress(rout,/remove_all)
    printf,1,'circle(' ,x, ',' ,y, ',' ,rout, ')'
    close,1

    ;# set-up the regions for inner 70 kpc
    close,1
    openw,1,inner70
    rout = round(sevpix) 
    rout = strcompress(rout,/remove_all)
    printf,1,'circle(' ,x, ',' ,y, ',' ,rout, ')'
    close,1

    ;# set-up the regions for inner 100 kpc
    close,1
    openw,1,inner100
    rout = round(hunpix) 
    rout = strcompress(rout,/remove_all)
    printf,1,'circle(' ,x, ',' ,y, ',' ,rout, ')'
    close,1

ENDFOR

END

