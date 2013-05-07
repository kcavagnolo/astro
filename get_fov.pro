pro get_fov

a=rd_tfile('chen12.table',/auto)
name=a[0,*]
z=a[1,*]
tx=a[2,*]
rd=(rdelta(2500,z,tx))*1000
FOR i=0,n_elements(z)-1 DO BEGIN
    cosmology,z[i],cosmo,/silent
    push,ang,cosmo[4]
ENDFOR
c=rd/ang
cc=c/0.492
FOR i=0,n_elements(cc)-1 DO BEGIN
    print,name[i],' ',cc[i]
ENDFOR
END
