pro make_list, dat1

; open chaser file and store it as a data structure
restore,"chaser_template.sav"
a = read_ascii(dat1, template = chaser_template)

sep = string(9B)

openw,1,'download.list'
printf,1,'#Name'+sep+sep+'ObsID'+sep+'Instr'+sep+'ExpTime'+sep+'RA'+sep+'DEC'
FOR i=0,n_elements(a.obsid)-1 DO BEGIN
    printf,1,strcompress(a.target_name[i],/remove_all),sep,sep,strcompress(a.obsid[i],/remove_all),sep,strcompress(a.instr[i],/remove_all),sep,strcompress(a.expt[i],/remove_all),sep,sep,a.ra[i],sep,a.dec[i]
ENDFOR
close,1

END
