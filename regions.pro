
rsize = 250 ; kpc radius

close,/all
color=['0000FF'x,'00FF00'x,'FF0000'x]

data = split(slurp('prop.list'))
;idx = where(data[6,*] EQ 'OK' OR data[6,*] EQ 'MAYBE')
;idx = where(data[6,*] EQ 'OK',n)
;data = data[*,idx] 

n = n_elements(data[0,*]) 
obsid = data[1,*]
ref_ra  = data[2,*]
ref_dec = data[3,*]

data2 = split(slurp('ascainfo.dat'))

m=0
openw,1,'counts.list'


;m=50  & n=m+1
FOR i=m,n-1 DO BEGIN

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; read in image and trim off nondata regions
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    image0 = readfits('../acis/'+obsid[i]+'/primary/image.fits',header0,/silent)
    adxy,header0,ref_ra[i],ref_dec[i],refx,refy

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; find cluster centriod, do twice, set flags
    ; cntrd better able to shift, bscentrd better for ragged objects
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    cntrd_fwhm = 20 
    cntrd,image0,refx,refy,xcen0,ycen0,cntrd_fwhm
    IF xcen0 EQ -1 OR ycen0 EQ -1 THEN BEGIN 
        bscentrd,image0,refx,refy,xcen,ycen 
        flag = 2000 
        print,'Trouble with cntrd'
    ENDIF ELSE BEGIN 
        bscentrd,image0,xcen0,ycen0,xcen,ycen
        flag = 1000 ; everything ok
    ENDELSE 
    xyad,header0,xcen,ycen,ra,dec
    hextract,image0,header0,image1,header1,xcen-100,xcen+100,ycen-100,ycen+100,/sil

    ; figure out regions to get counts
    idx = where(data[0,i] EQ data2[0,*] AND data[1,i] EQ data2[1,*],count)
    IF data2[2,idx[0]] EQ "-" THEN tx = 5.0 ELSE tx = float(data2[2,idx[0]])
    rcore = 0.1*rvir(tx,200.0)*2*1e3

    cdelt = sxpar(header1,'cdelt2')*3600. ; arcsec/pix

    IF (data[4,i] EQ '-') THEN z = 0.3 ELSE z = float(data[4,i])
;    bsize = zangx(rcore,z,H0=50,/silent)/cdelt
    bsize = 2.5*60/cdelt
    bsize = bsize < 100

    plotimage,bytscl(alog10(image1+1)),/iso
    tvcircle,bsize,100.5,100.5,/data,color=color[1]
    oplot,[100.5],[100.5],psym=1,color=color[2]
    oplot,[refx]-xcen+100,[refy]-ycen+100,psym=1,color=color[0]

    radmask = makemask(image1,100.5,100.5,bsize,/outside)

    exptime = sxpar(header1,'EXPOSURE')
    IF data[0,i] EQ 'ABELL_2142' AND data[1,i] EQ 1196 THEN exptime = 14361
    IF data[0,i] EQ 'ABELL_2142' AND data[1,i] EQ 1228 THEN exptime = 15588 
    ratio = !pi*(bsize*cdelt)^2/(8.3*60)^2
    IF (data[5,i] EQ 'ACIS-S') THEN BEGIN 
        bgd = 0.86*ratio*exptime
    ENDIF ELSE BEGIN 
        bgd = 2*0.31*ratio*exptime
    ENDELSE 
    
    totcts = total(image1[where(radmask EQ 1)]) - bgd
;    print,total(image1[where(radmask EQ 1)])
;    print,total(image1[where(radmask EQ 1)])-0.6*exptime

    printf,1,data[0,i],data[1,i],ra,dec,data[4,i],data[5,i],data[6,i],exptime/1e3,totcts,format='(a25,a10,2f10.4,a10,a8,a10,f6.1,i10)'
    print,data[0,i],data[1,i],ra,dec,data[4,i],data[5,i],data[6,i],exptime/1e3,totcts,format='(a25,a10,2f10.4,a10,a8,a10,f6.1,i10)'

    wwwpath = "../www/"
    saveimage,wwwpath+'/regions/'+data[0,i]+'_'+data[1,i]+'.png',/quiet,/png

ENDFOR 

;print,zang(1.05,0.0538,70,0.15,/kpc,/arcsec)
;print,zangx(1.05,0.0538,H0=50)
close,1

END 
