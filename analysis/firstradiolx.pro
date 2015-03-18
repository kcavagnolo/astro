;####################################
;####################################

FUNCTION nuint, X
common specval, alpha, nu0, nu1, nu2
y = (X/nu0)^(-alpha)
return, y
END

;####################################
;####################################

PRO firstradiolx, in1, output

Jy = 1.0d-23                    ;# 1Jy = 10**-23 ergs sec**-1 cm**-2 Hz**-1
cmMpc = 3.08d24                 ;# 1 Mpc = 3.08x10**24 cm
Watt = 1.0d-7                   ;# 1 W = 10,000,000 ergs

common specval, alpha, nu0, nu1, nu2
nu0 = 1.4d9                     ;# 1.4 GHz is the bandpass of the NVSS
nu1 = 10.d6                     ;# 10 MHz as lower bound of intergration
nu2 = 5.0d9                     ;# 5 GHz as upper bound of integration
alt = ['CYGNUS_A','HYDRA_A','ABELL_2597','MKW3S','ABELL_2052','ABELL_0133', $
       'ABELL_4059','ABELL_2199','ABELL_0426','RBS_0797','ABELL_1795','M87', $
       'CENTAURUS','ABELL_0478','M84','2A_0335+096','ABELL_0262','HCG_0062']
altalp = [0.7,0.92,1.35,2.3,1.2,1.9,1.43,1.37,1.0,1.0,0.98,0.81,0.7,1.0,0.63,0.9,0.6,1.0]

;# Read in file
readcol, in1, format='A,A,F,I,I,F,I,I,F,F,I,I,F,I,I,F,I,F,F,F,F,F,F,F,F,F,A',$
         name, obsid, z, nra1, nra2, nra3, ndec1, ndec2, ndec3,$
         sep, ra1, ra2, ra3, dec1, dec2, dec3, lobe, pflux, flux,$
         err, dmajor, dminor, dangle, mmajor, mminor, mangle, field, comment = '#'
pflux = flux*1e-3
flux = flux*1e-3
err = err*1e-3

;# write to a file
openw, /get_lun, lun, output
printf, lun, format='(A-25,A15,A12,A12,A12,A12,A12,A12)','#Name','Obsid','type','z','flux','err','rlum','rlumerr'
printf, lun, format='(A-25,A15,A12,A12,A12,A12,A12,A12)','# ---','---','----','---','Jy','Jy','10^40e/s','10^40e/s'

FOR i=0,n_elements(obsid)-1 DO BEGIN

    ;# print status
    print, '## Working on ',strcompress(name[i],/remove_all)
    print, '## ',num2str(n_elements(obsid)-(i+1)),' left to do.'

    ;# compute lum dist
    cosmology,z[i],result,/silent
    dl = result[2]

    ;# get power law index
    ord = where(alt EQ name[i])
    IF ord EQ -1 THEN alpha=1.0 ELSE alpha=altalp[ord]
    nuval = QROMB('nuint', nu1, nu2)
    
    ;# detection or not 
    IF (err[i] LT 0 AND flux[i] EQ 0) THEN BEGIN
       type = 'OA'
    ENDIF ELSE IF (err[i] GT 0 AND flux[i] NE 0) THEN BEGIN
       type = 'F'
    ENDIF ELSE IF (err[i] GT 0 AND flux[i] EQ 0) THEN BEGIN
       flux[i] = 0.7*1e-3
       type = 'NF'
    ENDIF

    ;# catch those entries with flux < 0
    ;# using L = integral(nu1->nu2) 4 * !PI * lum_dist^2 * f * (nu/nu0)^(-alpha) d(nu) [ergs/sec]
    IF (flux[i] GT 0) THEN BEGIN
       lum = 4 * !PI * (dl * cmMpc)^2 * flux[i] * Jy * nuval
       lum = lum/1d40
       lumerr = 4 * !PI * (dl * cmMpc)^2 * err[i] * Jy * nuval
       lumerr = lumerr/1d40
    ENDIF ELSE BEGIN
       lum = -0.00
       lumerr = -0.00
    ENDELSE
    printf, lun, format='(A-25,A15,A12,F12.4,F12.4,F12.4,F12.4,F12.4)',$
            name[i], obsid[i], type, z[i], flux[i], err[i], lum, lumerr
ENDFOR
FREE_LUN, LUN
END


