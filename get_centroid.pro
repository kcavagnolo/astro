PRO get_centroid, dat1

; estimate centroid coordinates for clusters

datadir = '/Volumes/GALACTUS/'
redir   = 'reprocessed'

IF !d.name EQ 'PS' THEN BEGIN 
    mycolors 
    color = [101,107,105,102,103,106]
    csize=1.5
    !p.font=0
ENDIF ELSE BEGIN 
    color = ['0000FF'x,'FF0000'x,'00FF00'x,'00FFFF'x,'00CCFF'x,'FFFF00'x]
    csize = 1
ENDELSE 

; get list of clusters
readcol, dat1, FORMAT='A,A,F,F,F,F,F,F,F,F,F,A,F,A,F,A',$
         names,obsids,x,y,rmax,mincts,z,nh,tx,fe,lbol,chip,eobs,diff,robs,loc

; loop through each cluster
FOR i=0,n_elements(obsids)-1 DO BEGIN
    multi = 'no'
    obsid = strcompress(obsids[i],/remove_all)
    name = strcompress(names[i],/remove_all)
    refx = x[i]
    refy = y[i]
    rout = rmax[i]
    ord = where(names EQ name)
    IF n_elements(ord) EQ 1 THEN obsid = obsid ELSE BEGIN
        temp = obsids[ord]
        FOR j=1,n_elements(temp)-1 DO BEGIN
            obsid = obsid+'_'+strcompress(temp[j],/remove_all)
        ENDFOR
        multi = 'yes'
    ENDELSE
;    IF multi EQ 'no' THEN $
;      imgfile = datadir+'/'+obsid+'/'+redir+'/'+obsid+'_sbprof_'+bin+'.fits' $
;    ELSE $
;      imgfile = datadir+'/merged/'+name+'/'+obsid+'_sbprof_'+bin+'.fits'

imgfile = '../../pf_clusters/temp/909/reprocessed/909_norm.fits.gz'

    ; read in cluster image (created during reprocess.pl)
    image0 = readfits(imgfile,header0,/silent)
    
;    ; convert input RA & DEC to X & Y, and Rmax to pixels
;    adxy,header0,ra[i],dec[i],refx,refy
;    cdelt = sxpar(header0,'cdelt2')*60. ; arcmin/pixel
;    rout = rmax[i]/cdelt

    hextract,image0,header0,image,header,refx-rout,refx+rout,refy-rout,refy+rout,/silent

    ; redo reference point for new image
;    adxy,header,ra[i],dec[i],refx,refy

    ; plot image
    Device, Decomposed=0
    atv, bytscl(sqrt(image))

    ; centroid image
    cntrd,image,refx,refy,xcen0,ycen0,50
    oplot,[xcen0],[ycen0],psym=1,color=color[0]
    print,xcen0,ycen0

    bscentrd,image,refx,refy,xcen1,ycen1 
    print,xcen1,ycen1
    oplot,[xcen1],[ycen1],psym=1,color=color[1]
ENDFOR
END
stop
    ; 2-D Beta model fit
    start = [1.0,1.0,7.5,7.5,refx,refy,0,1]
    yfit = mpfit2dpeak(image,a,weights=weights,estimates=start,/moffat, $
                       perror=perror,bestnorm=bestnorm,/circular)
    print,'Xcen        = '+string(format='(f9.5)',a[4])+' +/-'+ $
          string(format='(f9.5)',perror[4])
    print,'Ycen        = '+string(format='(f9.5)',a[5])+' +/-'+ $
          string(format='(f9.5)',perror[5])
    oplot,[a[4]],[a[5]],psym=1,color=color[2]

    ; fit ellipse with tilt
    yfit = mpfit2dpeak(image,a1,weights=weights,estimates=start,/moffat, $
                       perror=perror,bestnorm=bestnorm,/tilt)
    print,'Xcen        = '+string(format='(f9.5)',a1[4])+' +/-'+ $
          string(format='(f9.5)',perror[4])
    print,'Ycen        = '+string(format='(f9.5)',a1[5])+' +/-'+ $
          string(format='(f9.5)',perror[5])
    oplot,[a1[4]],[a1[5]],psym=1,color=color[3]

    xyad,header,xcen0,ycen0,ra0,dec0
    xyad,header,xcen1,ycen1,ra1,dec1
    xyad,header,a[4],a[5],ra2,dec2
    xyad,header,a1[4],a1[5],ra3,dec3

    print,ra0,dec0
    print,ra1,dec1
    print,ra2,dec2
    print,ra3,dec3
ENDFOR 

END 
