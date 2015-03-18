pro bgd_comp, dat1, dat2

; ie:
; bgd_comp,'bgd_0.3-10.dat','bgd_9-12.dat'

; restore the fit template and read some variables
restore,"bgd_ratio.sav"
file1 = read_ascii(dat1, template = bgd_ratio)
file2 = read_ascii(dat2, template = bgd_ratio)

rat1 = file1.ratio
rat2 = file2.ratio

; plot commands for making a postscript file
; define the labels for the plot axes
xtx = textoidl("Obs Count Rate / Deep Bgd Count Rate T_{X} [0.3-10] keV")
ytx = textoidl("Obs Count Rate / Deep Bgd Count Rate T_{X} [9.5-12] keV")

; make a hardcopy
set_plot, 'PS'
device, filename="bgd_ratio.ps"
!fancy = 4
!p.font=0
!linetype = 0
!p.font=0
plot, rat1, rat2, $
  psym = 4, $
  symsize = 0.8, $
  xtitle = xtx, $
  ytitle = ytx, $
  xstyle = 9, $
  xrange = [0.,2.], $
  yrange = [0.,2.], $
  charsize = 1.0

; overplot the line x=y
x = findgen(20)
y = x
oplot, x, y, linestyle=2, psym=0

device, /close

; plot commands for making a postscript file
; define the labels for the plot axes
xtx = textoidl("Cluster")
ytx = textoidl("Obs Count Rate / Deep Bgd Count Rate T_{X} [9.5-12] keV")

; make a hardcopy
set_plot, 'PS'
device, filename="bgd_fig.ps"
!fancy = 4
!p.font=0
!linetype = 0
!p.font=0
plot, rat1, rat2, $
  psym = 4, $
  symsize = 0.8, $
  xtitle = xtx, $
  ytitle = ytx, $
  xstyle = 9, $
  xrange = [0.,2.], $
  yrange = [0.,2.], $
  charsize = 1.0

; overplot the line y=1
x = findgen(n_elements(rat1))
y = replicate(1,n_elements(x))
oplot, x, y, linestyle=2, psym=0

device, /close

END
