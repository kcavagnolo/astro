PRO fstat_plot
ffid = 97.79
name = 'Abell 520'
a = rd_tfile('test.dat',/convert)
set_plot,'ps'
device, filename='fstat.ps'
histogram_ez, a, binsize=10, xtitle='F-statistic', title=name
oplot, replicate(ffid,500), findgen(500), linestyle=2
over  = double(n_elements(a[where(a GT ffid)]))
total = double(n_elements(a))
frac  = double(over/total*100.)
print, sigfig(frac,4),"% above F_fiducial"
xyouts, ffid+0.1*ffid, 40, 'F_data='+sigfig(ffid,4)
xyouts, ffid+0.1*ffid, 30, sigfig(frac,4)+'%'
device, /close
END
