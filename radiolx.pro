;####################################
;####################################

FUNCTION nuint, X
common specval, alpha, nu0, nu1, nu2, nomalpha
y = (X/nu0)^(-alpha)
return, y
END

;####################################
;####################################

PRO radiolx, in1, output, mjy=mjy

;####################################
;####################################
;# usage:
;# for input file with mJy fluxes
;# IDL> radiolx, 'pf_nvss_result_format.dat', 'temp.dat', /mjy
;#
;# for input file with Jy fluxes
;# IDL> radiolx, 'pf_nvss_result_format.dat', 'temp.dat'
;####################################
;####################################

Jy     = 1.0d-23                ;# 1Jy = 10**-23 ergs sec**-1 cm**-2 Hz**-1
cmMpc  = 3.08568025d24          ;# 1 Mpc = 3.08x10**24 cm

common specval, alpha, nu0, nu1, nu2, nomalpha
nomalpha = 0.8                  ;# canonical value of alpha to use for integration
nu0 = 1.4d9                     ;# 1.4 GHz is the bandpass of the NVSS
nu1 = 1d7                       ;# 10 MHz as lower bound of intergration
nu2 = 1d10                      ;# 10 GHz as upper bound of integration
alt = ['CYGNUS_A','HYDRA_A','ABELL_2597','MKW3S','ABELL_2052','ABELL_0133', $
       'ABELL_4059','ABELL_2199','ABELL_0426','RBS_0797','ABELL_1795','M87', $
       'CENTAURUS','ABELL_0478','M84','2A_0335+096','ABELL_0262','HCG_0062','IRAS09']
altalp = [0.7,0.92,1.35,2.3,1.2,1.9,1.43,1.37,1.0,1.0,0.98,0.81,0.7,1.0,0.63,0.9,0.6,1.0,1.4]

;####################################
;####################################

;# Read in file
readcol, in1, format='A,I,A,A,F,F,F,F,F,F,A,F,A,A', $
         name, obsid, ra, dec, sep, major, minor, theta, flux, err, type, z, freq, notes

;# convert to mjy
IF keyword_set(mjy) THEN BEGIN
   corr = 1000.
   print, '## STATUS: Assuming input fluxes are in mJy'
ENDIF ELSE BEGIN
   corr = 1.0
   print, '## STATUS: Assuming input fluxes are in Jy'
ENDELSE
flux = flux/corr
err = err/corr

;# write to a file
openw, /get_lun, LUN, output
printf, LUN, format='(A-25,A14,A6,A10,6A16,A10)','#Name','Obsid','type','z','flux','err','power','err','lum','err','surv'
printf, LUN, format='(A-25,A14,A6,A10,6A16,A10)','# --', '--','--','--','Jy','Jy','10^40e/s','10^40e/s','10^40e/s','10^40e/s','--'

;# start loop
prevname = 'fsdfsdsdf'
tflux = 0.0
tferr = 0.0
tlum = 0.0
tlerr = 0.0
tpow = 0.0
tperr = 0.0
FOR i=0,n_elements(obsid)-1 DO BEGIN

   ;# sum or print
   IF ((i NE 0) AND (name[i] NE prevname)) THEN BEGIN
      printf, LUN, format='(A-25,A14,A6,F10.6,6F16.7,A10)',$
              name[i-1], obsid[i-1], type[i-1], z[i-1], tflux, tferr, tpow, tperr, tlum, tlerr, 'NVSS'
      tflux = 0.0
      tferr = 0.0
      tlum = 0.0
      tlerr = 0.0
      tpow = 0.0
      tperr = 0.0
   ENDIF

   ;# compute lum dist
   cosmology, z[i], result, /silent
   dl = result[2]

   ;# get power law index
   ord = where(alt EQ name[i])
   IF ord EQ -1 THEN alpha=nomalpha ELSE alpha=altalp[ord]
   nuval = QROMB('nuint', nu1, nu2)

   ;# catch those entries with flux < 0
   IF freq[i] NE 'na' THEN nu0 = freq[i]*1d6
   IF (flux[i] GT 0) THEN BEGIN
      lum = 4 * !PI * (dl * cmMpc)^2 * flux[i] * Jy * nuval
      lum = lum/1d40
      lumerr = 4 * !PI * (dl * cmMpc)^2 * err[i] * Jy * nuval
      lumerr = lumerr/1d40
      pow = 4 * !PI * (dl * cmMpc)^2 * flux[i] * Jy * nu0 * (1.0+z[i])^(alpha-1)
      pow = pow/1d40
      powerr = 4 * !PI * (dl * cmMpc)^2 * err[i] * Jy * nu0 * (1.0+z[i])^(alpha-1)
      powerr = powerr/1d40
   ENDIF ELSE BEGIN
      lum = -0.00
      lumerr = lum
      pow = lum
      powerr = lum
   ENDELSE

   ;# sum same objects
   tflux = tflux + flux[i]
   tferr = tferr + err[i]
   tlum = tlum + lum
   tlerr = tlerr + lumerr
   tpow = tpow + pow
   tperr = tperr + powerr

   ;# set name
   prevname = name[i]

ENDFOR

;# print last entry and close-out
printf, LUN, format='(A-25,A14,A6,F10.6,6F16.7,A10)',$
        name[i-1], obsid[i-1], type[i-1], z[i-1], tflux, tferr, tpow, tperr, tlum, tlerr, 'NVSS'
FREE_LUN, LUN
END
