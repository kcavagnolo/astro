; NAME:
;     plot_lb.pro
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
; Main Program
;#####################
;#####################

PRO plot_lb, in1

output = 'radec.eps'
plotname = "no"

ON_ERROR, 2
IF n_params() EQ 0 THEN BEGIN
    print, 'Syntax - plot_lb, <ref file>'
    print, 'Plots given RA and Dec'
    print, 'Example: plot_lb, full_sample_L-50.list'
    return
ENDIF

restore, "../scripts/full_sample.sav"
dat = read_ascii(in1, template = full_sample)

; get the RA and Dec values
name = dat.name
obsid = dat.obsid
ra = dat.ra
dec = dat.dec

; Split them up based on colon delims
sep = string(9B)
openw, 1, 'galactic_coords.dat'
FOR i=0,n_elements(ra)-1 DO BEGIN
    tempname = name[i]
    tempobs = obsid[i]
    tempra = str2arr(ra[i],':')
    tempdec = str2arr(dec[i],':')
    tempra = (tempra[0]+(tempra[1]/60.)+(tempra[2]/3600.))*(360./24.)
    IF tempdec[0] LT 0. THEN term = -1. ELSE term = 1.
    tempdec = term*(abs(tempdec[0])+(tempdec[1]/60.)+(tempdec[2]/3600.))
    euler, tempra, tempdec, templ, tempb, select=1
    push, l, templ
    push, b, tempb
    push, names, tempname
    printf, 1, strcompress(tempname,/remove_all),sep,sep,strcompress(tempobs,/remove_all),sep,strcompress(templ,/remove_all),sep,strcompress(tempb,/remove_all)
ENDFOR
close, 1

; build color
red = REFORM([255,0,0],1,3)
TVLCT, red, 100

; setup the plotting device
set_plot, 'PS'
device, filename = output, $
  /color, $
  /encapsulated, $
  /portrait, $
  /helvetica
!FANCY    = 4
!LINETYPE = 0
!P.FONT   = 0
!X.THICK  = 3
!Y.THICK  = 3
!Z.THICK  = 3
!X.OMARGIN = [-4,0]
!Y.OMARGIN = [-1,0]

; create the grid
aitoff_grid, /label, charsize=0.8

; convert to x,y
aitoff, l, b, x, y

; plot the points
plotsym, 0, 0.8, /fill
oplot, x, y, psym=8, color=100

; labels
tit = textoidl('Distribution of ACCEPT Clusters on the Sky')
xtx = textoidl('Galactic Longitude [Deg.]')
ytx = textoidl('Galactic Latitude [Deg.]')
xyouts, 0.30, 0.95, tit, /normal, charsize=0.9
xyouts, 0.40, 0.05, xtx, /normal, charsize=0.9
xyouts, 0.05, 0.40, ytx, /normal, orientation=90, charsize=0.9
IF plotname EQ "yes" THEN xyouts, x, y, names, /data, charsize=0.1

device, /close

END
