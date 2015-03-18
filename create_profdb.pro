PRO create_profdb, dat1, output

;# name error log file
myhome = GETENV('HOME')
redir   = 'reprocessed'
bin     = '10pix'
keVdyne = 1.62d-9
err_log = 'createdb_err.log'
file_delete, err_log, /allow_nonexistent, /quiet

;# default files to use
restore,myhome+'/research/redux/scripts/xspectemp_rin_normerr_src.sav'
restore,myhome+'/research/redux/scripts/s_resultstemplate.sav'
restore,myhome+'/research/redux/scripts/s_tabletemplate.sav'
restore,myhome+'/research/redux/scripts/tcooltemplate.sav'
dat2 = myhome+'/research/pf_clusters/pf_fits/dat/pf_temp_profs.dat'

;# these params should not change very often
get_date, date, /timetag
creator = 'Kenneth W. Cavagnolo'
cosmo = '70, 0.3, 0.7'

;# read the input reference file
readcol, dat1, FORMAT='A,A,F,F,F,F,F,F,F,F,F,A,F,A,F,A', comment='#', /silent, $
         clusters, obsids, xs, ys, rmaxs, minctss, zs, nhs, txs, fes, lbols, chips, eobss, diffs, robs, locs

;# read the Tx(r) file
trfile = read_ascii(dat2,template=xspectemp_rin_normerr_src)

;# write the generic header for extension-1 in general
SXADDPAR, hdr, 'COMMENT', '-------------------------------------------------------'
SXADDPAR, hdr, 'CREATOR', creator, 'Creator of this file'
SXADDPAR, hdr, 'CREATED', date, 'File creation date'
SXADDPAR, hdr, 'COMSO', cosmo, 'Assumed cosmology: H0, Omega_Matter, Omega_Lambda'
SXADDPAR, hdr, 'COMMENT', '-------------------------------------------------------'
SXADDPAR, hdr, 'TX', 'Temperature profile', format='F'
SXADDPAR, hdr, 'TX[0]', 'Midpoint of radial bin', format='F'
SXADDPAR, hdr, 'UNIT', 'kpc'
SXADDPAR, hdr, 'TX[1]', 'Lower bound of radial bin', format='F'
SXADDPAR, hdr, 'TX[2]', 'Upper bound of radial bin', format='F'
SXADDPAR, hdr, 'TX[3]', 'Temperature', format='F'
SXADDPAR, hdr, 'UNIT', 'keV'
SXADDPAR, hdr, 'TX[4]', '90% confidence lower bound of temperature', format='F'
SXADDPAR, hdr, 'TX[5]', '90% confidence upper bound of temperature', format='F'
SXADDPAR, hdr, 'FE', 'Abundance profile', format='F'
SXADDPAR, hdr, 'FE[0]', 'Midpoint of radial bin', format='F'
SXADDPAR, hdr, 'UNIT', 'kpc'
SXADDPAR, hdr, 'FE[1]', 'Lower bound of radial bin', format='F'
SXADDPAR, hdr, 'FE[2]', 'Upper bound of radial bin', format='F'
SXADDPAR, hdr, 'FE[3]', 'Abundance', format='F'
SXADDPAR, hdr, 'UNIT', 'Z/Z_solar'
SXADDPAR, hdr, 'FE[4]', '90% confidence lower bound of abundance', format='F'
SXADDPAR, hdr, 'FE[5]', '90% confidence upper bound of abundance', format='F'
SXADDPAR, hdr, 'SBR', 'Sur bri profile', format='F'
SXADDPAR, hdr, 'SBR[0]', 'Midpoint of radial bin', format='F'
SXADDPAR, hdr, 'UNIT', 'kpc'
SXADDPAR, hdr, 'SBR[1]', 'Lower bound of radial bin', format='F'
SXADDPAR, hdr, 'SBR[2]', 'Upper bound of radial bin', format='F'
SXADDPAR, hdr, 'SBR[3]', 'Sur bri', format='F'
SXADDPAR, hdr, 'UNIT', 'cts/sec/arcsec**2'
SXADDPAR, hdr, 'SBR[4]', '1-sigma errors for sur bri', format='F'
SXADDPAR, hdr, 'DENS', 'Density profile', format='F'
SXADDPAR, hdr, 'DENS[0]', 'Midpoint of radial bin', format='F'
SXADDPAR, hdr, 'UNIT', 'kpc'
SXADDPAR, hdr, 'DENS[1]', 'Lower bound of radial bin', format='F'
SXADDPAR, hdr, 'DENS[2]', 'Upper bound of radial bin', format='F'
SXADDPAR, hdr, 'DENS[3]', 'Density', format='F'
SXADDPAR, hdr, 'UNIT', 'cm**-3'
SXADDPAR, hdr, 'DENS[4]', '1-sigma errors for density', format='F'
SXADDPAR, hdr, 'PFLAT', 'Pressure profile using flat TX0', format='F'
SXADDPAR, hdr, 'PFLAT[0]', 'Midpoint of radial bin', format='F'
SXADDPAR, hdr, 'UNIT', 'kpc'
SXADDPAR, hdr, 'PFLAT[1]', 'Lower bound of radial bin', format='F'
SXADDPAR, hdr, 'PFLAT[2]', 'Upper bound of radial bin', format='F'
SXADDPAR, hdr, 'PFLAT[3]', 'Pressure', format='F'
SXADDPAR, hdr, 'UNIT', 'dynes cm**-2'
SXADDPAR, hdr, 'PFLAT[4]', '1-sigma errors for pressure', format='F'
SXADDPAR, hdr, 'PEXTR', 'Pressure profile using extrap TX0', format='F'
SXADDPAR, hdr, 'PEXTR[0]', 'Midpoint of radial bin', format='F'
SXADDPAR, hdr, 'UNIT', 'kpc'
SXADDPAR, hdr, 'PEXTR[1]', 'Lower bound of radial bin', format='F'
SXADDPAR, hdr, 'PEXTR[2]', 'Upper bound of radial bin', format='F'
SXADDPAR, hdr, 'PEXTR[3]', 'Pressure', format='F'
SXADDPAR, hdr, 'UNIT', 'dynes cm**-2'
SXADDPAR, hdr, 'PEXTR[4]', '1-sigma errors for pressure', format='F'
SXADDPAR, hdr, 'KFLAT', 'Entropy profile using flat TX0', format='F'
SXADDPAR, hdr, 'KFLAT[0]', 'Midpoint of radial bin', format='F'
SXADDPAR, hdr, 'UNIT', 'kpc'
SXADDPAR, hdr, 'KFLAT[1]', 'Lower bound of radial bin', format='F'
SXADDPAR, hdr, 'KFLAT[2]', 'Upper bound of radial bin', format='F'
SXADDPAR, hdr, 'KFLAT[3]', 'Entropy', format='F'
SXADDPAR, hdr, 'UNIT', 'keV cm**2'
SXADDPAR, hdr, 'KFLAT[4]', '1-sigma errors for entropy', format='F'
SXADDPAR, hdr, 'KEXTR', 'Entropy profile using extrap TX0', format='F'
SXADDPAR, hdr, 'KEXTR[0]', 'Midpoint of radial bin', format='F'
SXADDPAR, hdr, 'UNIT', 'kpc'
SXADDPAR, hdr, 'KEXTR[1]', 'Lower bound of radial bin', format='F'
SXADDPAR, hdr, 'KEXTR[2]', 'Upper bound of radial bin', format='F'
SXADDPAR, hdr, 'KEXTR[3]', 'Entropy', format='F'
SXADDPAR, hdr, 'UNIT', 'keV cm**2'
SXADDPAR, hdr, 'KEXTR[4]', '1-sigma errors for entropy', format='F'
SXADDPAR, hdr, 'TCOOL', 'Cooling time profile', format='F'
SXADDPAR, hdr, 'TCOOL[0]', 'Midpoint of radial bin', format='F'
SXADDPAR, hdr, 'UNIT', 'kpc'
SXADDPAR, hdr, 'TCOOL[1]', 'Lower bound of radial bin', format='F'
SXADDPAR, hdr, 'TCOOL[2]', 'Upper bound of radial bin', format='F'
SXADDPAR, hdr, 'TCOOL[3]', 'Cooling time', format='F'
SXADDPAR, hdr, 'UNIT', 'Gyr'
SXADDPAR, hdr, 'TCOOL[4]', '1-sigma errors for cooling time', format='F'
SXADDPAR, hdr, 'MGRAV', 'Grav mass profile', format='F'
SXADDPAR, hdr, 'MGRAV[0]', 'Midpoint of radial bin', format='F'
SXADDPAR, hdr, 'UNIT', 'kpc'
SXADDPAR, hdr, 'MGRAV[1]', 'Lower bound of radial bin', format='F'
SXADDPAR, hdr, 'MGRAV[2]', 'Upper bound of radial bin', format='F'
SXADDPAR, hdr, 'MGRAV[3]', 'Grav mass', format='F'
SXADDPAR, hdr, 'UNIT', 'M_grav/M_solar'
SXADDPAR, hdr, 'MGRAV[4]', '1-sigma errors for grav mass', format='F'

;# add an entry in the db for each cluster
prevname = 'dsf@#!$!@#$sdf'
tcount = n_elements(clusters)
FOR i = 0, n_elements(clusters)-1 DO BEGIN

   ;# to keep the user busy
   print, FORMAT='(I10,A-20)', tcount, ' clusters left...'

   ;# get info from ref file
   err = 'F'
   offend = 'none'
   name = strcompress(clusters[i],/remove_all)
   IF name EQ prevname THEN GOTO, NEXT
   SXADDPAR, hdr, 'EXTNAME', name, 'Cluster data'
   datadir = locs[i]
   obsid = strcompress(obsids[i],/remove_all)
   ord = where(clusters EQ name)
   multi = 'no'
   void, myobs
   push, myobs, obsid
   IF n_elements(ord) EQ 1 THEN obsid = obsid ELSE BEGIN
      temp = obsids[ord]
      FOR j=1,n_elements(temp)-1 DO BEGIN
         obsid = obsid+'_'+strcompress(temp[j],/remove_all)
         push, myobs, strcompress(temp[j],/remove_all)
      ENDFOR
      multi = 'yes'
   ENDELSE
   
   ;# tx profile
   ord = where(trfile.obsid EQ obsid)
   IF ord[0] EQ -1 THEN BEGIN
      print, "## ERROR: Missing Tx for",obsid
      err = 'T'
      offend = 'no_tx'
      txpr  = [-99.0]
      fepr  = [-99.0]
   ENDIF ELSE BEGIN
      z = zs[i]
      cosmology, z, result, /silent
      rin   = trfile.rin[where(trfile.obsid EQ obsid)]
      rout  = trfile.rout[where(trfile.obsid EQ obsid)]
      rtx   = ((rin+rout)/2.)*60.*result[4]
      rtxlo = rtx-(rin*60.)*result[4]
      rtxhi = ((rout*60.)*result[4])-rtx
      tx    = trfile.tx[where(trfile.obsid EQ obsid)]
      txhi  = trfile.thi[where(trfile.obsid EQ obsid)]
      txlo  = trfile.tlo[where(trfile.obsid EQ obsid)]
      tlo   = tx-txlo
      thi   = txhi-tx
      fe    = trfile.fe[where(trfile.obsid EQ obsid)]
      felo  = trfile.felo[where(trfile.obsid EQ obsid)]
      fehi  = trfile.fehi[where(trfile.obsid EQ obsid)]
      felo  = fe-felo
      fehi  = fehi-fe
      txpr  = [[rtx], [rtxlo], [rtxhi], [tx], [txlo], [txhi]]
      fepr  = [[rtx], [rtxlo], [rtxhi], [fe], [felo], [fehi]]
   ENDELSE

   ;# sbr prof
   IF multi EQ 'no' THEN $
      sbr = datadir+'/'+obsid+'/'+redir+'/'+obsid+'_sbprof_'+bin+'.fits' $
   ELSE $
      sbr = datadir+'/merged/'+name+'/'+obsid+'_sbprof_'+bin+'.fits'
   check = findfile(sbr,count=count)
   IF (count NE 1) THEN BEGIN
      print, "## ERROR: Missing ",sbr
      err = 'T'
      offend = 'no_sbr_'+bin
      sbpr = [-99.0]
   ENDIF ELSE BEGIN
      fits   = mrdfits(sbr,1,/silent)
      rsbr   = fits.rmid*0.492*result[4]
      rslo   = rsbr-(fits.rin*0.492*result[4])
      rshi   = (fits.rout*0.492*result[4])-rsbr
      exp    = fits.exposure
      surbri = fits.sur_bri/exp/(0.492^2.)
      sbrerr = fits.sur_bri_err/exp/(0.492^2.)
      sbpr   = [[rsbr], [rslo], [rshi], [surbri], [sbrerr]]
   ENDELSE
   
   ;# read data from files
   ;# entropy
   file1 = myhome+'/research/pf_clusters/pf_fits/tables/'+obsid+'_table.dat'
   check = findfile(file1,count=count1)
   IF (count1 NE 1) THEN BEGIN
      print, "## ERROR: Missing ",file1
      err = 'T'
      offend = 'no_ktab'
      dens    = [-99.0]
      prflat  = [-99.0]
      prext   = [-99.0]
      entflat = [-99.0]
      entext  = [-99.0]
      gmass   = [-99.0]
   ENDIF ELSE BEGIN
      enttab = read_ascii(file1, template = s_tabletemplate)
      rmean = ((enttab.rin_mpc + enttab.rout_mpc)/2.)*1000.
      rmlo  = rmean-(enttab.rin_mpc*1000.)
      rmhi  = (enttab.rout_mpc*1000.)-rmean
      nelec = enttab.n_elec
      nelecerr = enttab.sigma_ne
      kflat = enttab.k_flat
      kext  = enttab.k
      kerr = enttab.k_err
      pflat = 2.*enttab.p_flat*keVdyne
      pext  = 2.*enttab.p*keVdyne
      perr = enttab.p_err*keVdyne
      mgrav = enttab.mgas
      merr = enttab.merr

      ;# get rid of the 'NaN' entries and
      ;# negatives
      ord   = where((nelec EQ nelec) AND (nelec GT 0.))
      rne   = rmean[ord]
      rnelo = rmlo[ord]
      rnehi = rmhi[ord]
      nelec = nelec[ord]
      nelecerr = nelecerr[ord]
      ord   = where((pflat EQ pflat) AND (pflat GT 0.))
      rp    = rmean[ord]
      rplo  = rmlo[ord]
      rphi  = rmhi[ord]
      pflat = pflat[ord]
      pext  = pext[ord]
      perr  = perr[ord]
      ord   = where((mgrav EQ mgrav) AND (mgrav GT 0.))
      rmg   = rmean[ord]
      rmglo = rmlo[ord]
      rmghi = rmhi[ord]
      mgrav  = mgrav[ord]
      merr  = merr[ord]
      ord   = where((kflat EQ kflat) AND (kflat GT 0.))
      rk    = rmean[ord]
      rklo  = rmlo[ord]
      rkhi  = rmhi[ord]
      kflat = kflat[ord]
      kext  = kext[ord]
      kerr  = kerr[ord]
      dens    = [[rne],  [rnelo], [rnehi], [nelec],  [nelecerr]]
      prflat  = [[rp],   [rplo],  [rphi],  [pflat],  [perr]]
      prext   = [[rp],   [rplo],  [rphi],  [pext],   [perr]]
      entflat = [[rk],   [rklo],  [rkhi],  [kflat],  [kerr]]
      entext  = [[rk],   [rklo],  [rkhi],  [kext],   [kerr]]
      gmass   = [[rmg],  [rmglo], [rmghi], [mgrav],   [merr]]
   ENDELSE

   ;# cooling time
   file2 = myhome+'/research/pf_clusters/pf_fits/tables/'+obsid+'_tcool.dat'
   check = findfile(file2,count=count2)
   IF (count2 NE 1) THEN BEGIN
      print, "## ERROR: Missing ",file2
      err = 'T'
      offend = 'no_tcool'
      cool = [-99.0]
   ENDIF ELSE BEGIN
      cooltab  = read_ascii(file2, template = tcooltemplate)
      rtc  = ((cooltab.rin + cooltab.rout)/2.)*1000.
      tc   = cooltab.tc32
      tcerr= cooltab.tc32err

      ;# get rid of the 'NaN' entries and
      ;# negatives
      ord   = where((tc EQ tc) AND (tc GT 0.))
      rtc   = rtc[ord]
      rtclo = reverse(rmlo[ord])
      rtchi = reverse(rmhi[ord])
      tc    = tc[ord]
      tcerr = tcerr[ord]
      cool  = [[rtc], [rtclo], [rtchi], [tc], [tcerr]]
   ENDELSE

   ;# build an array of these values
   arr = {cluster:name, $
          tx:txpr, $
          fe:fepr, $
          sbr:sbpr, $
          dens:dens, $
          pflat:prflat, $
          pextr:prext, $
          kflat:entflat, $
          kextr:entext, $
          tcool:cool, $
          mgrav:gmass}          
   
   ;# push this array into a master array
   MWRFITS, arr, output, hdr
   
ERR_EXIT:
   IF err EQ 'T' THEN BEGIN
      openw, /get_lun, ERRLOG, err_log, /append
      printf, ERRLOG, format='(A-25,A20,A20)',name,obsid,offend
      close, ERRLOG
      free_lun, ERRLOG
   ENDIF
NEXT:
   prevname = name
   tcount--
ENDFOR
print, 'All done!'
END
