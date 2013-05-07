pro bgd_histo, in1
; bgd_histo, '../fits/dat/all_bgd_9-12.dat'

; set the char size
csize = 1.0
xmin = 0.7
xmax = 1.8
ymin = 0.
ymax = 15.

; restore the fit template and read some variables
restore,"../scripts/bgd_ratio.sav"
dat1 = read_ascii(in1, template = bgd_ratio)

; define the labels for the plot axes
ytx = textoidl("Number of clusters")
xtx = textoidl("SRC_{ctr}/BGD_{ctr} (T_{[9.5-12]}keV)")

; make a hardcopy
odevice = !d.name
set_plot, 'PS'
device, filename="bgd_fig.ps"
!fancy = 4
!p.font=0
histogram_ez, dat1.ratio, $
  binsize=0.05, $
  ytickinterval=10, $
  xtitle = xtx, $
  ytitle = ytx, $
  /xsty, $
  /ysty, $
  xran = [xmin,xmax], $
  yran = [ymin,ymax], $
  charsize = csize

; overplot the lines y=0.8, 1, 1.2
y  = findgen(n_elements(dat1.ratio))+1.
x1 = replicate(1,n_elements(y))
x2 = replicate(1.2,n_elements(y))
x3 = replicate(0.8,n_elements(y))
oplot, x1, y, linestyle=3, psym=0
oplot, x2, y, linestyle=2, psym=0
oplot, x3, y, linestyle=2, psym=0

; draw arrow for adj reg
arrow, 1.2, 30, 1.45, 30, /DATA, thick=2

; write text for adj reg
xyouts, 1.21, 31, "Adjustment Region", charsize=csize*0.8

device, /close
set_plot, odevice

END
