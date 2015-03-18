FUNCTION  vv, r1, r2
IF (r1 LE r2) THEN return,0.0 ELSE return,4.*!pi/3. * (r1^2 - r2^2)^(1.5)
END

PRO entropy

; set cosmo.
H0 = 70
OM = 0.3
L0 = 0.7

; read in the temperature fits
restore,"../scripts/xspectemp_rin_normerr_src.sav"
fitdata = read_ascii('de.dat',template=xspectemp_rin_normerr_src)

; get list of unique obsids
uidx  = uniq(fitdata.obsid,sort(fitdata.cluster))
name  = fitdata.cluster(uidx)
obsid = fitdata.obsid(uidx)
ncl   = n_elements(name)

; go through each cluster
m=0 & n=ncl
FOR i=m,n-1 DO BEGIN 

    ; get annuli info
    idx2 = where(fitdata.cluster EQ name[i] AND fitdata.obsid EQ obsid[i])

    ; get fit data
    tin   = fitdata.rin[idx2]*60
    tout  = fitdata.rout[idx2]*60
    tx    = fitdata.tx[idx2]
    tlo   = fitdata.tlo[idx2]
    thi   = fitdata.thi[idx2]
    norm  = fitdata.norm[idx2]
    cr    = fitdata.cr[idx2]
    z     = fitdata.z[idx2[0]]
    
    ; get surf brightness profile
    surfdata = mrdfits('sb.fits', 1, hdr)
    idx    = reverse(sort(surfdata.rout))
    rin    = surfdata.rin
    rin    = rin[idx]*0.492
    rout   = surfdata.rout
    rout   = rout[idx]*0.492
    sb     = surfdata.sur_bri
    sb     = sb[idx]/(0.492^2)
    sberr  = surfdata.sur_bri_err
    sberr  = sberr[idx]/(0.492^2)
    sbrint = sb*!pi* (rout^2 - rin^2) ; sbrint units cts/sec
    nbins  = n_elements(idx) 

    ; get Tx and cr/norm ratio to use in each SB bin
    tbin   = dblarr(nbins)
    tbinlo = dblarr(nbins)
    tbinhi = dblarr(nbins)
    kxspec = dblarr(nbins)
    FOR j=0,nbins-1 DO BEGIN 
        tidx = where(rin[j] LT tout AND rin[j] GE tin)
        IF tidx LT 0 THEN tidx = n_elements(tout)-1
        tbin[j] = tx[tidx[0]]
        tbinlo[j] = tlo[tidx[0]]
        tbinhi[j] = thi[tidx[0]]
        kxspec[j] = norm[tidx[0]]/cr[tidx[0]]
    ENDFOR  

    ; deproject surface brightness to get ne profile  
    cosmology, z, kosmo, /silent
    angtolin = kosmo[4]         ; kpc/arcsec
    toutmpc = tout*angtolin/1000
    tinmpc  = tin*angtolin/1000
    tmidmpc = (tinmpc+toutmpc)/2
    routmpc = rout*angtolin/1000
    rinmpc  = rin*angtolin/1000
    
    ; array of all r values
    vsum = dblarr(nbins,nbins)
    rall = [reform(routmpc),[0]]
    FOR m=0,nbins-1 DO BEGIN 
        FOR j=0,nbins-1 DO BEGIN 
            v1 = vv(rall[j+0], rall[m+1])
            v2 = vv(rall[j+1], rall[m+1])
            v3 = vv(rall[j+0], rall[m+0])
            v4 = vv(rall[j+1], rall[m+0])
            vsum[j,m] = (v1-v2) - (v3-v4)
        ENDFOR  
    ENDFOR 
    cc = dblarr(nbins)
    cc[0] = sbrint[0]/vsum[0,0]
    FOR m=1,nbins-1 DO BEGIN 
        interv = 0.0
        FOR j=0,m-1 DO BEGIN 
            interv = interv + cc[j]*vsum[j,m]
        ENDFOR 
        lastv = vsum[m,m]
	cc[m] = (sbrint[m] - interv)/lastv
    ENDFOR  

    nedivnp = 1.4/1.167         ; fully ionized plasma
    d = kosmo[2]                ; luminosity distance
    nelec = sqrt( nedivnp*(kxspec)*cc*4.0*!pi* d^2 * (1+z)^2/ 3.0856e10)
    nerr = sberr/sb*nelec*2.71

    kidx    = where(finite(nelec) EQ 1,nbins)
    nelec   = nelec[kidx]
    nerr    = nerr[kidx]
    routmpc = routmpc[kidx]
    rinmpc  = rinmpc[kidx]
    rmidmpc = (rinmpc+routmpc)/2
    rin     = rin[kidx]
    rout    = rout[kidx]
    rmid    = (rin+rout)/2
    tbin    = tbin[kidx]
    tbinlo  = tbinlo[kidx]
    tbinhi  = tbinhi[kidx]
    sb      = sb[kidx]
    sberr   = sberr[kidx]

    ; convert ne profile to pressure profile
    pp  = tbin*nelec*1.60   ; 1 keV/cm^3 = 1.60d-10 Pascals 
    plo = pp - pp* sqrt( ((tbin-tbinlo)/tbin)^2 + (nerr/nelec)^2)
    phi = pp + pp* sqrt( ((tbinhi-tbin)/tbin)^2 + (nerr/nelec)^2)

    ; convert ne profile to entropy profile
    ss  = tbin/nelec^(2/3.)
    slo = ss - ss* sqrt( ((tbin-tbinlo)/tbin)^2 + 4/9.*(nerr/nelec)^2)
    shi = ss + ss* sqrt( ((tbinhi-tbin)/tbin)^2 + 4/9.*(nerr/nelec)^2)

    ; get mgas profile
    mgas  = dblarr(nbins)
    mgper = 4/3. * !pi * 1.167 * 1.673d-24 * nelec * (routmpc^3-rinmpc^3) * (3.085678d24)^3 / 1.99d33 ; gas mass in solar units
    mgerr = 4/3. * !pi * 1.167 * 1.673d-24 * nerr * (routmpc^3-rinmpc^3) * (3.085678d24)^3 / 1.99d33
    FOR j=0,nbins-1 DO BEGIN 
        mgas[j] = total(mgper[where(rout LE rout[j])])
        mgerr[j] = total(mgerr[where(rout LE rout[j])])
    ENDFOR 

    ; print results to file
    openw,  1, name[i]+'_'+strcompress(obsid[i],/remove_all)+'_info3.dat'
    printf, 1, format='($,a1)','#'
    printf, 1, ' Name = '+name[i]+', Obsid = '+strtrim(string(format='(a10)',obsid[i]),2)+', z = '+strtrim(string(format='(f10.4)',z),2)
    printf, 1, format='($,a1)','#'
    printf, 1, format='(1a9,15a10)','Rin','Rout','Tx','-err','+err','Ne','Ne_err','P','-err','+err','Mgas','M_err','S','-err','+err'
    printf, 1, format='($,a1)','#'
    printf, 1, format='(1a9,15a10)','["]','["]','[keV]',' ',' ','[cm^-3]',' ','[Pa 1e-10]',' ',' ','[Msun]',' ','[keV cm^2]',' ',' '
    printf, 1, format='($,a1)','#'
    printf, 1, format='(1a9,15a10)','(1)','(2)','(3)','(4)','(5)','(6)','(7)','(8)','(9)','(10)','(11)','(12)','(13)','(14)','(15)'

    FOR jj = 0,n_elements(ss)-1 DO BEGIN  
        printf,1, rin[jj],rout[jj],$
          tbin[jj],tbin[jj]-tbinlo[jj],tbinhi[jj]-tbin[jj],$
          nelec[jj],nerr[jj],$
          pp[jj],pp[jj]-plo[jj],phi[jj]-pp[jj],$
          mgas[jj],mgerr[jj],$
          ss[jj],ss[jj]-slo[jj],shi[jj]-ss[jj], $
          format='(2f10.2,3f10.2,7e10.2,3f10.2)'
    ENDFOR 
    close,1
    
    ; plot all the profiles
    plotsym, 0, 0.75, /fill
    Set_Plot, 'PS'
    !fancy = 4
    !linetype = 0
    !p.font = 0
    !p.charsize = 0.9
    !p.title = name[i]+' '+strcompress(obsid[i],/remove_all)
    device, filename='temp1.ps', /color
    plot, $
      rmid, sb, $
      /xlog, /ylog, $
      xtitle = textoidl('R_{mid} [arcsec]'), $
      ytitle = textoidl('S_{X} [cts arcsec^{-2}]'), $
      psym = 10, $
      xran = [min(rmid)-0.1*min(rmid), max(rmid)+0.1*max(rmid)], $
      yran = [min(sb)-0.1*min(sb),max(sb)+0.1*max(sb)], $
      /xsty, /ysty
    oploterror, rmid, sb, sberr, psym=8
    device,/close

    device, filename='temp11.ps', /color
    plot, $
      tmidmpc, tx, $
      xtitle = textoidl('R_{mid} [Mpc]'), $
      ytitle = textoidl('T_{X} [keV]'), $
      psym = 10, $
      xran = [min(tmidmpc)-0.1*min(tmidmpc), max(tmidmpc)+0.1*max(tmidmpc)], $
      yran = [min(tx)-0.1*min(tx),max(tx)+0.1*max(tx)], $
      /xsty, /ysty
    oploterror, tmidmpc, tx, tx-tlo, psym=8, /lobar
    oploterror, tmidmpc, tx, thi-tx, psym=8, /hibar
    device,/close

    device, filename='temp2.ps', /color
    plot, $
      rmidmpc, nelec, $
      /xlog, /ylog, $
      xtitle = textoidl('R_{mid} [Mpc]'), $
      ytitle = textoidl('n_{elec} [cm^{-3}]'), $
      psym = 10, $
      xran = [min(rmidmpc)-0.1*min(rmidmpc), max(rmidmpc)+0.1*max(rmidmpc)], $
      yran = [min(nelec)-0.1*min(nelec),max(nelec)+0.1*max(nelec)], $
      /xsty, /ysty
    oploterror, rmidmpc, nelec, nerr, psym=8
    device,/close

    device, filename='temp3.ps', /color
    plot, $
      rmidmpc, pp, $
      /xlog, /ylog, $
      xtitle = textoidl('R_{mid} [Mpc]'), $
      ytitle = textoidl('Pressure [10^{-10} Pa]'), $
      psym = 10, $
      xran = [min(rmidmpc)-0.1*min(rmidmpc), max(rmidmpc)+0.1*max(rmidmpc)], $
      yran = [min(pp)-0.1*min(pp),max(pp)+0.1*max(pp)], $
      /xsty, /ysty
    oploterror, rmidmpc, pp, pp-plo, psym=8, /lobar
    oploterror, rmidmpc, pp, phi-pp, psym=8, /hibar
    device,/close

    device, filename='temp4.ps', /color
    plot, $
      rmidmpc, ss, $
      /xlog, /ylog, $
      xtitle = textoidl('R_{mid} [Mpc]'), $
      ytitle = textoidl('K [keV cm^{-2}]'), $
      psym = 10, $
      xran = [min(rmidmpc)-0.1*min(rmidmpc), max(rmidmpc)+0.1*max(rmidmpc)], $
      yran = [min(ss)-0.1*min(ss),max(ss)+0.1*max(ss)], $
      /xsty, /ysty
    oploterror, rmidmpc, ss, ss-slo, psym=8, /lobar
    oploterror, rmidmpc, ss, shi-ss, psym=8, /hibar
    device, /close

    device, filename='temp5.ps', /color
    plot, $
      rmidmpc, mgas, $
      /xlog, /ylog, $
      xtitle = textoidl('R_{mid} [Mpc]'), $
      ytitle = textoidl('M_{gas} [M_{solar}]'), $
      psym = 10, $
      xran = [min(rmidmpc)-0.1*min(rmidmpc), max(rmidmpc)+0.1*max(rmidmpc)], $
      yran = [min(mgas)-0.1*min(mgas),max(mgas)+0.1*max(mgas)], $
      /xsty, /ysty
    oploterror, rmidmpc, mgas, mgerr, psym=8
    device,/close

    ; make all these ps files into one ps file
    SPAWN, 'ls temp*.ps > list'
    SPAWN, 'cat list | perl pscat.pl 6 '+name[i]+'_'+strcompress(obsid[i],/remove_all)+'_plots.ps'
    SPAWN, 'rm -f temp*.ps'
    SPAWN, 'rm -f list'

ENDFOR

close,/all

END
