;####################################
;####################################

FUNCTION nuint, X
common specval, alpha, nu0, nu1, nu2
y = (X/nu0)^(-alpha)
return, y
END

;####################################
;####################################

PRO summs, dat

;# set options
myhome  = GETENV('HOME')
catalog = myhome+'/research/pf_clusters/pf_fits/dat/summs.fits' ;location of summs catalog
mind    = 20                         ; min sep to be associated
Jy      = 1d-23                      ; 1Jy = 10**-23 ergs sec**-1 cm**-2 Hz**-1
cmMpc   = 3.08d24                    ; 1 Mpc = 3.08x10**24 cm
Watt    = 1.0d-7                     ; 1 W = 10,000,000 ergs

;# read in data
readcol, dat, FORMAT='F,F,F,F,F,F,F,F,A', $
         ra1, ra2, ra3, dec1, dec2, dec3, a, b, str
str = str_replace(str,'cluster--','')

;# open lof file
OPENW, /get_lun, LOGLUN, 'pf_summs_result_format.dat'
printf, LOGLUN, format='(A-25,A15,A10,A10,A10,A10,A10,A10,A10,A25,A10,A10,A10)', $
        '#Name','Obsid','z','LII','BII','SLII','BLII','Flux','Fluxerr','SUMMS Name','Ldiff','Bdiff','Stat'
OPENW, /get_lun, OUTLUN, 'pf_summs_radiolx.dat'
printf, OUTLUN, format='(A-25,A14,A6,A8,6A14,A10)','#Name','Obsid','type','z','flux','err','power','err','lum','err','surv'
printf, OUTLUN, format='(A-25,A14,A6,A8,6A14,A10)','# --', '--','--','--','Jy','Jy','10^40e/s','10^40e/s','10^40e/s','10^40e/s','--'

;# set cosmology
common cosmology, Omega_m, H0, lambda
H0      = 70.
Omega_m = 0.3
lambda  = 0.7

;# supply integration values
common specval, alpha, nu0, nu1, nu2
alpha = 0.8                     ;# assumed index for power law spectrum
nu0   = 843.d6                  ;# 1.4 GHz is the bandpass of the NVSS
nu1   = 1.0d6                   ;# 1 MHz as lower bound of intergration
nu2   = 5.0d9                   ;# 5 GHz as upper bound of integration
nuval = QROMB('nuint', nu1, nu2)

;# format RA and Dec to usable values
ra  = (ra1+(ra2/60.)+(ra3/3600.))*(360./24.)
dec = abs(dec1)+(dec2/60.)+(dec3/3600.)
ord = where(dec1 LT 1)
dec[ord] = -1*dec[ord]
euler, ra, dec, l, b, select=1

;# open the SUMMS catalogue
summs = mrdfits(catalog,1)
sl = double(summs.lii)
sb = double(summs.bii)
fl = double(summs.int_flux_36_cm)
ferr = double(summs.int_flux_36_cm_error)
names = summs.name

;# start looping
FOR i=0,n_elements(str)-1 DO BEGIN
   pars = strsplit(str[i],'--',/EXTRACT)
   z = pop(pars)
   obs = pop(pars)
   name = strjoin(pars,'_')
   cosmology, z, result, /silent
   dl = result[2]
   conv = result[4]
   d = sqrt((sl-l[i])^2.+(sb-b[i])^2.)
   ord = where(d EQ min(d))
   d = d[ord]*3600
   diff = d*conv
   IF (diff LE mind) THEN BEGIN
      stat = "good"
      type = "F"
   ENDIF ELSE BEGIN
      stat = "toofar"
      type = "NF"
   ENDELSE
   IF (stat EQ 'good') THEN BEGIN
      flux = fl[ord]*1e-3
      fluxerr = ferr[ord]*1e-3
   ENDIF ELSE BEGIN
      IF (dec1[i] LE -50) THEN BEGIN
         flux = 6e-3
         fluxerr = 0.05*flux
      ENDIF ELSE BEGIN
         flux = 10e-3
         fluxerr = 0.05*flux
      ENDELSE
   ENDELSE
   lum = 4 * !PI * (dl * cmMpc)^2 * (flux) * Jy * nuval
   lum = lum/1d40
   lumerr = 4 * !PI * (dl * cmMpc)^2 * (fluxerr) * Jy * nuval
   lumerr = lumerr/1d40
   pow = 4 * !PI * (dl * cmMpc)^2 * (flux) * Jy * nu0
   pow = pow/1d40
   powerr = 4 * !PI * (dl * cmMpc)^2 * (fluxerr) * Jy * nu0
   powerr = powerr/1d40

   ;# print to fit file
   printf, LOGLUN, format='(A-25,A15,F10.4,F10.3,F10.3,F10.3,F10.3,F10.3,F10.3,A25,F10.3,F10.3,A10)', $
           name, obs, z, l[i], b[i], sl[ord], sb[ord], fl[ord], ferr[ord], names[ord], sl[ord]-l[i], sb[ord]-b[i], stat
   printf, OUTLUN, format='(A-25,A14,A6,F8.4,6F14.5,A10)',$
           name, obs, type, z, flux, fluxerr, pow, powerr, lum, lumerr, 'SUMSS'
ENDFOR

FREE_LUN, LOGLUN
FREE_LUN, OUTLUN

END
