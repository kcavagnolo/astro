FUNCTION makemask,image,x0,y0,r0,centriod=centriod,cntrd_fwhm=cntrd_fwhm,outside=outside

; makes a mask image
on_error,2

sz = size(image)
count = n_elements(x0) 

radmask = lindgen(sz[1],sz[2])
xarray = radmask MOD sz[1]
yarray = radmask /   sz[2]

radmask[*,*] = 1.0

FOR j=0,count-1 DO BEGIN 
    IF x0[j] GE 0 AND x0[j] LT sz[1] AND y0[j] GE 0 AND y0[j] LT sz[2] THEN BEGIN 
        IF keyword_set(centriod) THEN BEGIN 
            IF NOT keyword_set(cntrd_fwhm) THEN BEGIN 
                print,'Assuming a FWHM of 20 for the centriod routine'
                cntrd_fwhm = 20
            ENDIF 
            cntrd,image,x0[j],y0[j],xx,yy,cntrd_fwhm
            IF xx EQ -1 OR yy EQ -1 THEN BEGIN
                xx = x0[j] 
                yy = y0[j]
            ENDIF 
        ENDIF  ELSE BEGIN 
            xx = x0[j] 
            yy = y0[j]
        ENDELSE  
        
        rdist=sqrt((xarray-long(xx))^2 + (yarray-long(yy))^2)
        IF keyword_set(outside) THEN  index=where(rdist GT r0[j])  $
        ELSE index=where(rdist LT r0[j])
        rdist[*,*]=1.0
        rdist[index]=0.0
        radmask = radmask*rdist              
    ENDIF 
ENDFOR 
    

return,radmask

END
