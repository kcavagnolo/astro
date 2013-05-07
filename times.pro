PRO TIMES

!quiet=1
;readcol,'../../redux/redux_info/master.list',FORMAT='A,A,F,F,F,F,F,F,F,F,F,A,F,A,F,A',$
;        cluster,obsids,x,y,rmax,mincts,z,nh,tx,fe,lbol,chip,eobs,diff,robs,loc, comment='#'
;readcol,'../../redux/redux_info/pf_ref.list',FORMAT='A,A,F,F,F,F,F,F,F,F,F,A,F,A,F,A',$
;        cluster,obsids,x,y,rmax,mincts,z,nh,tx,fe,lbol,chip,eobs,diff,robs,loc, comment='#'
;readcol,'../../redux/redux_info/me_ref.list',FORMAT='A,A,F,F,F,F,F,F,F,F,F,A,F,A,F,A',$
;        cluster,obsids,x,y,rmax,mincts,z,nh,tx,fe,lbol,chip,eobs,diff,robs,loc, comment='#'
;readcol,'../pf_info/alldone.list',FORMAT='A,A,F,F,F,F,F,F,F,F,F,A,F,A,F,A',$
;        cluster,obsids,x,y,rmax,mincts,z,nh,tx,fe,lbol,chip,eobs,diff,robs,loc, comment='#'
;readcol,'../pf_info/bad_kprof.list',FORMAT='A,A,F,F,F,F,F,F,F,F,F,A,F,A,F,A',$
;        cluster,obsids,x,y,rmax,mincts,z,nh,tx,fe,lbol,chip,eobs,diff,robs,loc, comment=''
readcol,'junk',FORMAT='A',obsids
loc = replicate('/mnt/DROBO/',n_elements(obsids))
;readcol,'junk',FORMAT='A,A,F,F,F,F,F,F,F,F,F,A,F,A,F,A',$
;        cluster,obsids,x,y,rmax,mincts,z,nh,tx,fe,lbol,chip,eobs,diff,robs,loc, comment=''

texp = 0.
FOR i = 0,n_elements(obsids)-1 DO BEGIN
    obs = strcompress(obsids[i],/remove_all)
    dir = strcompress(loc[i],/remove_all)
    file = FILE_SEARCH(dir+'/'+obs+'/secondary/*evt*',/FULLY_QUALIFY_PATH,count=count)
    IF (count NE 1) THEN GOTO,ERROR
    file = file[0]
    head = headfits(file,ext=1)
    texp = texp+sxpar(head,'EXPOSURE')
ERROR:
ENDFOR
print, format='(A-20,F10.2,A5)','Total observations:',n_elements(obsids)
print, format='(A-20,F10.2,A5)','Total exposure time:',texp/1d6,'Msec'
!quiet=0
END
