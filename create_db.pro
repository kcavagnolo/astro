PRO create_db, dat1, output

;# name error log file
myhome = GETENV('HOME')
rootdir = '/mnt/DROBO'
datadir = 'reprocessed'
err_log = 'createdb_err.log'
file_delete, err_log, /allow_nonexistent, /quiet

;# default files to use
dat2 = myhome+'/research/pf_clusters/pf_fits/master.table'
dat3 = myhome+'/research/me_temp_proj/me_info/ccncc_r2500-core.log'
dat4 = myhome+'/research/me_temp_proj/me_info/ccncc_r5000-core.log'
dat5 = myhome+'/research/me_temp_proj/me_info/ccncc_r2500.log'
dat6 = myhome+'/research/me_temp_proj/me_info/ccncc_r5000.log'
dat7 = myhome+'/research/me_temp_proj/me_fits/dat/culled_r2500-50_7-7.dat'
dat8 = myhome+'/research/me_temp_proj/me_fits/dat/culled_r2500-50_2-7.dat'
dat9 = myhome+'/research/me_temp_proj/me_fits/dat/culled_r5000-50_7-7.dat'
dat10 = myhome+'/research/me_temp_proj/me_fits/dat/culled_r5000-50_2-7.dat'
dat11 = myhome+'/research/pf_clusters/pf_fits/dat/ir.dat'

;# these params should not change very often
get_date, date, /timetag
creator = 'Kenneth W. Cavagnolo'
ciaover = '3.4'
caldbver = '3.4.1'
xspecver = '11.3.2ag'
model = 'mekal+mekal/b'
cosmo = '70, 0.3, 0.7'

;# read the input reference file
readcol, dat1, FORMAT='A,A,F,F,F,F,F,F,F,F,F,A,F,A,F,A', comment='#', /silent, $
         clusters, obsids, xs, ys, rmaxs, minctss, zs, nhs, txs, fes, lbols, chips, eobss, diffs, robs, locs

;# read the existing data files
readcol, dat2, FORMAT='A,A,A,F,F,F,F,F,F,F,F,D,D,A,D,A', comment='#', /silent, $
         mclusters, mra, mdec, mz, mtx, mk0, mk0err, mk100, mk100err, malpha, malphaerr, mlx, mlha, mhatype, mlrad, mradtype

;# read cc/ncc thbr data files
readcol, dat3, FORMAT='A,A,F,F,F,F,F,F', comment='#', /silent, $
         r25c_clusters, r25c_ctype, r25c_thbr, r25c_thbrhi, r25c_thbrlo, r25c_dec, r25c_dechi, r25c_declo
readcol, dat4, FORMAT='A,A,F,F,F,F,F,F', comment='#', /silent, $
         r50c_clusters, r50c_ctype, r50c_thbr, r50c_thbrhi, r50c_thbrlo, r50c_dec, r50c_dechi, r50c_declo
readcol, dat5, FORMAT='A,A,F,F,F,F,F,F', comment='#', /silent, $
         r25_clusters, r25_ctype, r25_thbr, r25_thbrhi, r25_thbrlo, r25_dec, r25_dechi, r25_declo
readcol, dat6, FORMAT='A,A,F,F,F,F,F,F', comment='#', /silent, $
         r50_clusters, r50_ctype, r50_thbr, r50_thbrhi, r50_thbrlo, r50_dec, r50_dechi, r50_declo

;# read thbr spec files
readcol, dat7, FORMAT='A,X,X,X,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F', comment='#', /silent, $
         r25csf_clusters, r25csf_nh, r25csf_nhlo, r25csf_nhhi, $
         r25csf_t, r25csf_tlo, r25csf_thi, r25csf_fe, r25csf_felo, r25csf_fehi, $
         r25csf_norm, r25csf_normlo, r25csf_normhi, r25csf_t2, r25csf_t2lo, r25csf_t2hi, $
         r25csf_norm2, r25csf_norm2lo, r25csf_norm2hi, r25csf_z, r25csf_cr, r25csf_src, r25csf_chisq, r25csf_dof
readcol, dat8, FORMAT='A,X,X,X,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F', comment='#', /silent, $
         r25csh_clusters, r25csh_nh, r25csh_nhlo, r25csh_nhhi, $
         r25csh_t, r25csh_tlo, r25csh_thi, r25csh_fe, r25csh_felo, r25csh_fehi, $
         r25csh_norm, r25csh_normlo, r25csh_normhi, r25csh_t2, r25csh_t2lo, r25csh_t2hi, $
         r25csh_norm2, r25csh_norm2lo, r25csh_norm2hi, r25csh_z, r25csh_cr, r25csh_src, r25csh_chisq, r25csh_dof
readcol, dat9, FORMAT='A,X,X,X,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F', comment='#', /silent, $
         r50csf_clusters, r50csf_nh, r50csf_nhlo, r50csf_nhhi, $
         r50csf_t, r50csf_tlo, r50csf_thi, r50csf_fe, r50csf_felo, r50csf_fehi, $
         r50csf_norm, r50csf_normlo, r50csf_normhi, r50csf_t2, r50csf_t2lo, r50csf_t2hi, $
         r50csf_norm2, r50csf_norm2lo, r50csf_norm2hi, r50csf_z, r50csf_cr, r50csf_src, r50csf_chisq, r50csf_dof
readcol, dat10, FORMAT='A,X,X,X,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F,F', comment='#', /silent, $
         r50csh_clusters, r50csh_nh, r50csh_nhlo, r50csh_nhhi, $
         r50csh_t, r50csh_tlo, r50csh_thi, r50csh_fe, r50csh_felo, r50csh_fehi, $
         r50csh_norm, r50csh_normlo, r50csh_normhi, r50csh_t2, r50csh_t2lo, r50csh_t2hi, $
         r50csh_norm2, r50csh_norm2lo, r50csh_norm2hi, r50csh_z, r50csh_cr, r50csh_src, r50csh_chisq, r50csh_dof

;# read ir data file
readcol, dat11, FORMAT='A,F,A', comment='#', /silent, $
         ir_clusters, lirs, irlines
lirs = lirs*1d44

;# write the generic header for extension-1 in general
SXADDPAR, hdr, 'COMMENT', 'Core region was defined as 0.15*R500'
SXADDPAR, hdr, 'EXTNAME', 'CLUSTERDB', 'Cluster database'
SXADDPAR, hdr, 'CREATOR', creator, 'Creator of this file'
SXADDPAR, hdr, 'CREATED', date, 'File creation date'
SXADDPAR, hdr, 'CIAO', ciaover, 'Version of CIAO used'
SXADDPAR, hdr, 'CALDB', caldbver, 'Version of CALDB used'
SXADDPAR, hdr, 'XSPEC', xspecver, 'Version of Xspec used'
SXADDPAR, hdr, 'MODEL', model, 'Spectral model used in fitting'
SXADDPAR, hdr, 'COMSO', cosmo, 'Assumed cosmology: H0, Omega_Matter, Omega_Lambda'
SXADDPAR, hdr, 'CLUSTER', 'CDA name of cluster', format='A'
SXADDPAR, hdr, 'OBS', 'CDA ObsIDs associated with analysis', format='A'
SXADDPAR, hdr, 'RA', 'Right Ascension of X-ray centroid (J2000)', format='A'
SXADDPAR, hdr, 'DEC', 'Declination of X-ray centroid (J2000)', format='A'
SXADDPAR, hdr, 'RAD', 'Decimal Right Ascension of X-ray centroid (J2000)', format='A'
SXADDPAR, hdr, 'DECD', 'Decimal Declination of X-ray centroid (J2000)', format='A'
SXADDPAR, hdr, 'l', 'Galactic longitude', format='A'
SXADDPAR, hdr, 'b', 'Galactic latitude', format='A'
SXADDPAR, hdr, 'NH', 'Absorbing Hydr column density', format='F'
SXADDPAR, hdr, 'UNIT', '10**20 cm**-2'
SXADDPAR, hdr, 'Z', 'NED database mean redshift of cluster', format='F'
SXADDPAR, hdr, 'TXREF', 'T_X taken from literature', format='F'
SXADDPAR, hdr, 'UNIT', 'keV'
SXADDPAR, hdr, 'LB200', 'Bolo (0.001-100.0 keV) lum from Xspec for R200', format='F'
SXADDPAR, hdr, 'UNIT', 'ergs/sec'
SXADDPAR, hdr, 'LB500', 'Bolo (0.001-100.0 keV) lum from Xspec for R500', format='F'
SXADDPAR, hdr, 'UNIT', 'ergs/sec'
SXADDPAR, hdr, 'LB1000', 'Bolo (0.001-100.0 keV) lum from Xspec for R1000', format='F'
SXADDPAR, hdr, 'UNIT', 'ergs/sec'
SXADDPAR, hdr, 'LB2500', 'Bolo (0.001-100.0 keV) lum from Xspec for R2500', format='F'
SXADDPAR, hdr, 'UNIT', 'ergs/sec'
SXADDPAR, hdr, 'LB5000', 'Bolo (0.001-100.0 keV) lum from Xspec for R5000', format='F'
SXADDPAR, hdr, 'UNIT', 'ergs/sec'
SXADDPAR, hdr, 'LB7500', 'Bolo (0.001-100.0 keV) lum from Xspec for R7500', format='F'
SXADDPAR, hdr, 'UNIT', 'ergs/sec'
SXADDPAR, hdr, 'LBC200', 'Bolo (0.001-100.0 keV) lum from Xspec for R200-core', format='F'
SXADDPAR, hdr, 'UNIT', 'ergs/sec'
SXADDPAR, hdr, 'LBC500', 'Bolo (0.001-100.0 keV) lum from Xspec for R500-core', format='F'
SXADDPAR, hdr, 'UNIT', 'ergs/sec'
SXADDPAR, hdr, 'LBC1000', 'Bolo (0.001-100.0 keV) lum from Xspec for R1000-core', format='F'
SXADDPAR, hdr, 'UNIT', 'ergs/sec'
SXADDPAR, hdr, 'LBC2500', 'Bolo (0.001-100.0 keV) lum from Xspec for R2500-core', format='F'
SXADDPAR, hdr, 'UNIT', 'ergs/sec'
SXADDPAR, hdr, 'LBC5000', 'Bolo (0.001-100.0 keV) lum from Xspec for R5000-core', format='F'
SXADDPAR, hdr, 'UNIT', 'ergs/sec'
SXADDPAR, hdr, 'LBC7500', 'Bolo (0.001-100.0 keV) lum from Xspec for R7500-core', format='F'
SXADDPAR, hdr, 'UNIT', 'ergs/sec'
SXADDPAR, hdr, 'LOSD', 'Line of sight distance', format='F'
SXADDPAR, hdr, 'UNIT', 'Mpc'
SXADDPAR, hdr, 'DL', 'Luminosity distance', format='F'
SXADDPAR, hdr, 'UNIT', 'Mpc'
SXADDPAR, hdr, 'DA', 'Angular diameter distance', format='F'
SXADDPAR, hdr, 'UNIT', 'Mpc'
SXADDPAR, hdr, 'KPC_ASEC', 'Angular diameter size', format='F'
SXADDPAR, hdr, 'UNIT', 'kpc/arcsec'
SXADDPAR, hdr, 'VC', 'Comoving volume', format='F'
SXADDPAR, hdr, 'UNIT', 'Gpc**3'
SXADDPAR, hdr, 'LOOKT', 'Lookback time', format='F'
SXADDPAR, hdr, 'UNIT', 'Gyrs'
SXADDPAR, hdr, 'R200_MPC', 'Radius w/ mean overdensity 200 times critical dens for closed uni', format='F'
SXADDPAR, hdr, 'UNIT', 'Mpc'
SXADDPAR, hdr, 'R200_ASEC', 'Radius w/ mean overdensity 200 times critical dens for closed uni', format='F'
SXADDPAR, hdr, 'UNIT', 'arcsec'
SXADDPAR, hdr, 'R500_MPC', 'Radius w/ mean overdensity 500 times critical dens for closed uni', format='F'
SXADDPAR, hdr, 'UNIT', 'Mpc'
SXADDPAR, hdr, 'R500_ASEC', 'Radius w/ mean overdensity 500 times critical dens for closed uni', format='F'
SXADDPAR, hdr, 'UNIT', 'arcsec'
SXADDPAR, hdr, 'R1000_MPC', 'Radius w/ mean overdensity 1000 times critical dens for closed uni', format='F'
SXADDPAR, hdr, 'UNIT', 'Mpc'
SXADDPAR, hdr, 'R1000_ASEC', 'Radius w/ mean overdensity 1000 times critical dens for closed uni', format='F'
SXADDPAR, hdr, 'UNIT', 'arcsec'
SXADDPAR, hdr, 'R2500_MPC', 'Radius w/ mean overdensity 2500 times critical dens for closed uni', format='F'
SXADDPAR, hdr, 'UNIT', 'Mpc'
SXADDPAR, hdr, 'R2500_ASEC', 'Radius w/ mean overdensity 2500 times critical dens for closed uni', format='F'
SXADDPAR, hdr, 'UNIT', 'arcsec'
SXADDPAR, hdr, 'R5000_MPC', 'Radius w/ mean overdensity 5000 times critical dens for closed uni', format='F'
SXADDPAR, hdr, 'UNIT', 'Mpc'
SXADDPAR, hdr, 'R5000_ASEC', 'Radius w/ mean overdensity 5000 times critical dens for closed uni', format='F'
SXADDPAR, hdr, 'UNIT', 'arcsec'
SXADDPAR, hdr, 'R7500_MPC', 'Radius w/ mean overdensity 7500 times critical dens for closed uni', format='F'
SXADDPAR, hdr, 'UNIT', 'Mpc'
SXADDPAR, hdr, 'R7500_ASEC', 'Radius w/ mean overdensity 7500 times critical dens for closed uni', format='F'
SXADDPAR, hdr, 'UNIT', 'arcsec'
SXADDPAR, hdr, 'R25CTYPE', 'Core classification for r2500-core aperture', format='A'
SXADDPAR, hdr, 'UNIT', 'none'
SXADDPAR, hdr, 'R25T77', 'r2500-core TX for 0.7-7.0 keV band', format='F'
SXADDPAR, hdr, 'UNIT', 'keV'
SXADDPAR, hdr, 'R25T77HI', 'r2500-core TX 90% upper bound for 0.7-7.0 keV band', format='F'
SXADDPAR, hdr, 'UNIT', 'keV'
SXADDPAR, hdr, 'R25T77LO', 'r2500-core TX 90% lower bound for 0.7-7.0 keV band', format='F'
SXADDPAR, hdr, 'UNIT', 'keV'
SXADDPAR, hdr, 'R25T27', 'r2500-core TX for 2.0_rest-7.0 keV band', format='F'
SXADDPAR, hdr, 'UNIT', 'keV'
SXADDPAR, hdr, 'R25T27HI', 'r2500-core TX 90% upper bound for 2.0_rest-7.0 keV band', format='F'
SXADDPAR, hdr, 'UNIT', 'keV'
SXADDPAR, hdr, 'R25T27LO', 'r2500-core TX 90% lower bound for 2.0_rest-7.0 keV band', format='F'
SXADDPAR, hdr, 'UNIT', 'keV'
SXADDPAR, hdr, 'R25THBR', 'r2500-core T27/T77 ratio', format='F'
SXADDPAR, hdr, 'UNIT', 'none'
SXADDPAR, hdr, 'R25THBRHI', 'r2500-core 1sigma upper bound for THBR', format='F'
SXADDPAR, hdr, 'UNIT', 'none'
SXADDPAR, hdr, 'R25THBRLO', 'r2500-core 1sigma lower bound for THBR', format='F'
SXADDPAR, hdr, 'UNIT', 'none'
SXADDPAR, hdr, 'R25FE', 'r2500-core metallicity for 0.7-7.0 keV band', format='F'
SXADDPAR, hdr, 'UNIT', 'solar'
SXADDPAR, hdr, 'R25FEHI', 'r2500-core 90% upper bound for metallicity', format='F'
SXADDPAR, hdr, 'UNIT', 'solar'
SXADDPAR, hdr, 'R25FELO', 'r2500-core 90% lower bound for metallicity', format='F'
SXADDPAR, hdr, 'UNIT', 'solar'
SXADDPAR, hdr, 'R50CTYPE', 'Core classification for r5000-core aperture', format='A'
SXADDPAR, hdr, 'UNIT', 'none'
SXADDPAR, hdr, 'R50T77', 'r5000-core TX for 0.7-7.0 keV band', format='F'
SXADDPAR, hdr, 'UNIT', 'keV'
SXADDPAR, hdr, 'R50T77HI', 'r5000-core TX 90% upper bound for 0.7-7.0 keV band', format='F'
SXADDPAR, hdr, 'UNIT', 'keV'
SXADDPAR, hdr, 'R50T77LO', 'r5000-core TX 90% lower bound for 0.7-7.0 keV band', format='F'
SXADDPAR, hdr, 'UNIT', 'keV'
SXADDPAR, hdr, 'R50T27', 'r5000-core TX for 2.0_rest-7.0 keV band', format='F'
SXADDPAR, hdr, 'UNIT', 'keV'
SXADDPAR, hdr, 'R50T27HI', 'r5000-core TX 90% upper bound for 2.0_rest-7.0 keV band', format='F'
SXADDPAR, hdr, 'UNIT', 'keV'
SXADDPAR, hdr, 'R50T27LO', 'r5000-core TX 90% lower bound for 2.0_rest-7.0 keV band', format='F'
SXADDPAR, hdr, 'UNIT', 'keV'
SXADDPAR, hdr, 'R50THBR', 'r5000-core T27/T77 ratio', format='F'
SXADDPAR, hdr, 'UNIT', 'none'
SXADDPAR, hdr, 'R50THBRHI', 'r5000-core 1sigma upper bound for THBR', format='F'
SXADDPAR, hdr, 'UNIT', 'none'
SXADDPAR, hdr, 'R50THBRLO', 'r5000-core 1sigma lower bound for THBR', format='F'
SXADDPAR, hdr, 'UNIT', 'none'
SXADDPAR, hdr, 'R50FE', 'r5000-core metallicity for 0.7-7.0 keV band', format='F'
SXADDPAR, hdr, 'UNIT', 'solar'
SXADDPAR, hdr, 'R50FEHI', 'r5000-core 90% upper bound for metallicity', format='F'
SXADDPAR, hdr, 'UNIT', 'solar'
SXADDPAR, hdr, 'R50FELO', 'r5000-core 90% lower bound for metallicity', format='F'
SXADDPAR, hdr, 'UNIT', 'solar'
SXADDPAR, hdr, 'K0', 'Best-fit K0 for K(r); flat central temp interpolation scheme', format='F'
SXADDPAR, hdr, 'UNIT', 'keV cm**2'
SXADDPAR, hdr, 'K0ERR', '1sigma uncertainty for K0', format='F'
SXADDPAR, hdr, 'UNIT', 'keV cm**2'
SXADDPAR, hdr, 'K100', 'Best-fit normalizaton at 100 kpc for K(r)', format='F'
SXADDPAR, hdr, 'UNIT', 'keV cm**2'
SXADDPAR, hdr, 'K100ERR', '1sigma uncertainty for K100', format='F'
SXADDPAR, hdr, 'UNIT', 'keV cm**2'
SXADDPAR, hdr, 'ALPHA', 'Best-fit power law index for K(r)', format='F'
SXADDPAR, hdr, 'UNIT', 'none'
SXADDPAR, hdr, 'ALPHAERR', '1sigma uncertainty for alpha', format='F'
SXADDPAR, hdr, 'UNIT', 'none'
SXADDPAR, hdr, 'LHA', 'Literature Halpha luminosity', format='F'
SXADDPAR, hdr, 'UNIT', 'ergs/sec'
SXADDPAR, hdr, 'HATYPE', 'F=found, NF=not found (upper limit), UK=no observations', format='A'
SXADDPAR, hdr, 'UNIT', 'none'
SXADDPAR, hdr, 'LRAD', 'Radio luminosity from either SUMSS (~805MHz) or NVSS (~1.4GHZ)', format='F'
SXADDPAR, hdr, 'UNIT', 'ergs/sec'
SXADDPAR, hdr, 'RADTYPE', 'F=found, NF=not found (upper limit), UK=no observations', format='F'
SXADDPAR, hdr, 'UNIT', 'none'
SXADDPAR, hdr, 'LIR', 'Literature infrared luminosity', format='F'
SXADDPAR, hdr, 'UNIT', 'ergs/sec'
SXADDPAR, hdr, 'IRTYPE', 'Y=yes lines detected, N=no lines detected', format='F'
SXADDPAR, hdr, 'UNIT', 'none'

;# add an entry in the db for each cluster
prevname = 'dsf@#!$!@#$sdf'
tcount = n_elements(clusters)
FOR i = 0, n_elements(clusters)-1 DO BEGIN

   ;# to keep the user busy
   print, FORMAT='(I10,A-20)', tcount, ' clusters left...'

   ;# get info from ref file
   err = 'F'
   name = strcompress(clusters[i],/remove_all)
   IF name EQ prevname THEN GOTO, NEXT
   z = zs[i]
   nh = nhs[i]
   txref = txs[i]
   feref = fes[i]

   ;# get info from master.table
   mord = where(mclusters EQ name, num)
   mord = mord[0]
   IF num LE 0 THEN BEGIN
      ra       = '-1:-1:-1'
      dec      = '-1:-1:-1'
      ra_dec   = -999.0
      dec_dec  = -999.0
      gall     = -999d
      galb     = -999d
      k0       = -999.0
      k0err    = -999.0
      k100     = -999.0
      k100err  = -999.0
      alpha    = -999.0
      alphaerr = -999.0
      lha      = -999.0d44
      hatype   = 'X'
      lrad     = -999.0d44
      radtype  = 'X'
   ENDIF ELSE BEGIN
      ra       = mra[mord]
      dec      = mdec[mord]
      k0       = mk0[mord]
      k0err    = mk0err[mord]
      k100     = mk100[mord]
      k100err  = mk100err[mord]
      alpha    = malpha[mord]
      alphaerr = malphaerr[mord]
      lha      = mlha[mord]
      hatype   = mhatype[mord]
      lrad     = mlrad[mord]
      radtype  = mradtype[mord]

      ;# calculate l and b from ra and dec
      ra_dec = str2arr(ra,':')
      dec_dec = str2arr(dec,':')
      ra_dec = (ra_dec[0]+(ra_dec[1]/60.)+(ra_dec[2]/3600.))*(360./24.)
      IF dec_dec[0] LT 0. THEN term = -1. ELSE term = 1.
      dec_dec = term*(abs(dec_dec[0])+(dec_dec[1]/60.)+(dec_dec[2]/3600.))
      euler, ra_dec, dec_dec, gall, galb, select=1
   ENDELSE

   ;# get r2500-core info
   mord = where(r25c_clusters EQ name, num)
   mord = mord[0]
   IF num LE 0 THEN BEGIN
      r25ctype = 'XX'
      r25thbr    = -99.0
      r25thbrhi  = -99.0
      r25thbrlo  = -99.0
   ENDIF ELSE BEGIN
      r25ctype = r25c_ctype[mord]
      r25thbr    = r25c_thbr[mord]
      r25thbrhi  = r25c_thbrhi[mord]
      r25thbrlo  = r25c_thbrlo[mord]
   ENDELSE
   mord = where(r25csf_clusters EQ name, num)
   mord = mord[0]
   IF num LE 0 THEN BEGIN
      r25t77 = -99.0
      r25t77hi = -99.0
      r25t77lo = -99.0
      r25fe = -99.0
      r25fehi = -99.0
      r25felo = -99.0
   ENDIF ELSE BEGIN
      r25t77 = r25csf_t[mord]
      r25t77hi = r25csf_thi[mord]
      r25t77lo = r25csf_tlo[mord]
      r25fe = r25csf_fe[mord]
      r25fehi = r25csf_fehi[mord]
      r25felo = r25csf_felo[mord]
   ENDELSE
   mord = where(r25csh_clusters EQ name, num)
   mord = mord[0]
   IF num LE 0 THEN BEGIN
      r25t27 = -99.0
      r25t27hi = -99.0
      r25t27lo = -99.0
   ENDIF ELSE BEGIN
      r25t27 = r25csh_t[mord]
      r25t27hi = r25csh_thi[mord]
      r25t27lo = r25csh_tlo[mord]
   ENDELSE
   
   ;# get r5000-core info
   mord = where(r50c_clusters EQ name, num)
   mord = mord[0]
   IF num LE 0 THEN BEGIN
      r50ctype = 'XX'
      r50thbr    = -99.0
      r50thbrhi  = -99.0
      r50thbrlo  = -99.0
   ENDIF ELSE BEGIN
      r50ctype = r50c_ctype[mord]
      r50thbr    = r50c_thbr[mord]
      r50thbrhi  = r50c_thbrhi[mord]
      r50thbrlo  = r50c_thbrlo[mord]
   ENDELSE
   mord = where(r50csf_clusters EQ name, num)
   mord = mord[0]
   IF num LE 0 THEN BEGIN
      r50t77 = -99.0
      r50t77hi = -99.0
      r50t77lo = -99.0
      r50fe = -99.0
      r50fehi = -99.0
      r50felo = -99.0
   ENDIF ELSE BEGIN
      r50t77 = r50csf_t[mord]
      r50t77hi = r50csf_thi[mord]
      r50t77lo = r50csf_tlo[mord]
      r50fe = r50csf_fe[mord]
      r50fehi = r50csf_fehi[mord]
      r50felo = r50csf_felo[mord]
   ENDELSE
   mord = where(r50csh_clusters EQ name, num)
   mord = mord[0]
   IF num LE 0 THEN BEGIN
      r50t27 = -99.0
      r50t27hi = -99.0
      r50t27lo = -99.0
   ENDIF ELSE BEGIN
      r50t27 = r50csh_t[mord]
      r50t27hi = r50csh_thi[mord]
      r50t27lo = r50csh_tlo[mord]
   ENDELSE

   ;# get IR info
   mord = where(ir_clusters EQ name, num)
   mord = mord[0]
   IF num LE 0 THEN BEGIN
      lir = -99.0d44
      irl = 'X'
   ENDIF ELSE BEGIN
      lir = lirs[mord]
      irl = irlines[mord]
   ENDELSE

   ;# get info about each obsid
   mord = where(clusters EQ name)
   obs = strcompress(obsids[mord],/remove_all)
   obs = strjoin(obs,';')
;   phys_x = xs[mord]
;   phys_y = ys[mord]
;   rmax = rmaxs[mord]
;   mincts = minctss[mord]
;   chip = chips[mord]

   ;# get info about lx
   tobs = strcompress(obsids[i],/remove_all)
   tpath = rootdir+'/'+tobs+'/'+datadir+'/'
   lxfiles = list_with_path('*lumin*.dat',tpath,/nocurrent)
   FOR j=0,n_elements(lxfiles)-1 DO BEGIN
      IF lxfiles[j] EQ '' THEN GOTO, LXSKIP
      OPENR, lun, lxfiles[j], /GET_LUN
      WHILE ~ EOF(lun) DO BEGIN
         a = ''
         b = ''
         READF, lun, a
         b = strsplit(a,/extract)
         IF b[0] EQ 'Runname:' THEN aper = b[1]
         IF b[0] EQ 'Lbol' THEN BEGIN
            IF aper EQ 'r200'  THEN lb200  = [float(b[1]), float(b[2]), float(b[3])]
            IF aper EQ 'r500'  THEN lb500  = [float(b[1]), float(b[2]), float(b[3])]
            IF aper EQ 'r1000' THEN lb1000 = [float(b[1]), float(b[2]), float(b[3])]
            IF aper EQ 'r2500' THEN lb2500 = [float(b[1]), float(b[2]), float(b[3])]
            IF aper EQ 'r5000' THEN lb5000 = [float(b[1]), float(b[2]), float(b[3])]
            IF aper EQ 'r7500' THEN lb7500 = [float(b[1]), float(b[2]), float(b[3])]
            IF aper EQ 'r200-core'  THEN lbc200  = [float(b[1]), float(b[2]), float(b[3])]
            IF aper EQ 'r500-core'  THEN lbc500  = [float(b[1]), float(b[2]), float(b[3])]
            IF aper EQ 'r1000-core' THEN lbc1000 = [float(b[1]), float(b[2]), float(b[3])]
            IF aper EQ 'r2500-core' THEN lbc2500 = [float(b[1]), float(b[2]), float(b[3])]
            IF aper EQ 'r5000-core' THEN lbc5000 = [float(b[1]), float(b[2]), float(b[3])]
            IF aper EQ 'r7500-core' THEN lbc7500 = [float(b[1]), float(b[2]), float(b[3])]
         ENDIF
      ENDWHILE
      CLOSE, lun
      FREE_LUN, lun
      LXSKIP:
   ENDFOR
   num = [-1.0,-1.0,-1.0]
   IF n_elements(lb200) LE 0 THEN lb200 = num
   IF n_elements(lb500) LE 0 THEN lb500 = num
   IF n_elements(lb1000) LE 0 THEN lb1000 = num
   IF n_elements(lb2500) LE 0 THEN lb2500 = num
   IF n_elements(lb5000) LE 0 THEN lb5000 = num
   IF n_elements(lb7500) LE 0 THEN lb7500 = num
   IF n_elements(lbc200) LE 0 THEN lbc200 = num
   IF n_elements(lbc500) LE 0 THEN lbc500 = num
   IF n_elements(lbc1000) LE 0 THEN lbc1000 = num
   IF n_elements(lbc2500) LE 0 THEN lbc2500 = num
   IF n_elements(lbc5000) LE 0 THEN lbc5000 = num
   IF n_elements(lbc7500) LE 0 THEN lbc7500 = num

   ;# get cosmological info
   cosmology, z, result, /silent
   loscd     = result[0]
   dl        = result[2]
   da        = result[3]
   kpc_asec  = result[4]
   vc        = result[5]
   lookt     = result[6]
   r200_mpc  = rdelta(200, z, txref, /silent)
   r500_mpc  = rdelta(500, z, txref, /silent)
   r1000_mpc = rdelta(1000, z, txref, /silent)
   r2500_mpc = rdelta(2500, z, txref, /silent)
   r5000_mpc = rdelta(5000, z, txref, /silent)
   r7500_mpc = rdelta(7500, z, txref, /silent)
   r200_asec = (r200_mpc*1000.)/kpc_asec
   r500_asec = (r500_mpc*1000.)/kpc_asec
   r1000_asec = (r1000_mpc*1000.)/kpc_asec
   r2500_asec = (r2500_mpc*1000.)/kpc_asec
   r5000_asec = (r5000_mpc*1000.)/kpc_asec
   r7500_asec = (r7500_mpc*1000.)/kpc_asec

   ;# build an array of these values
   arr = {cluster:name, $
          obs:obs, $
          ra:ra, $
          dec:dec, $
          rad:ra_dec, $
          decd:dec_dec, $
          l:gall, $
          b:galb, $
          nh:nh, $
          z:z, $
          txref:txref, $
          loscd:loscd, $
          dl:dl, $
          da:da, $
          kpc_asec:kpc_asec, $
          vc:vc, $
          lookt:lookt, $
          r200_mpc:r200_mpc, $
          r200_asec:r200_asec, $
          r500_mpc:r500_mpc, $
          r500_asec:r500_asec, $
          r1000_mpc:r1000_mpc, $
          r1000_asec:r1000_asec, $
          r2500_mpc:r2500_mpc, $
          r2500_asec:r2500_asec, $
          r5000_mpc:r5000_mpc, $
          r5000_asec:r5000_asec, $
          r7500_mpc:r7500_mpc, $
          r7500_asec:r7500_asec, $
          lb200:lb200[0], lb200lo:lb200[1], lb200hi:lb200[2], $
          lb500:lb500[0], lb500lo:lb500[1], lb500hi:lb500[2], $
          lb1000:lb1000[0], lb1000lo:lb1000[1], lb1000hi:lb1000[2], $
          lb2500:lb2500[0], lb2500lo:lb2500[1], lb2500hi:lb2500[2], $
          lb5000:lb5000[0], lb5000lo:lb5000[1], lb5000hi:lb5000[2], $
          lb7500:lb7500[0], lb7500lo:lb7500[1], lb7500hi:lb7500[2], $
          lbc200:lbc200[0], lbc200lo:lbc200[1], lbc200hi:lbc200[2], $
          lbc500:lbc500[0], lbc500lo:lbc500[1], lbc500hi:lbc500[2], $
          lbc1000:lbc1000[0], lbc1000lo:lbc1000[1], lbc1000hi:lbc1000[2], $
          lbc2500:lbc2500[0], lbc2500lo:lbc2500[1], lbc2500hi:lbc2500[2], $
          lbc5000:lbc5000[0], lbc5000lo:lbc5000[1], lbc5000hi:lbc5000[2], $
          lbc7500:lbc7500[0], lbc7500lo:lbc7500[1], lbc7500hi:lbc7500[2], $
          r25ctype:r25ctype, $
          r25t77:r25t77, $
          r25t77hi:r25t77hi, $
          r25t77lo:r25t77lo, $
          r25t27:r25t27, $
          r25t27hi:r25t27hi, $
          r25t27lo:r25t27lo, $
          r25thbr:r25thbr, $
          r25thbrhi:r25thbrhi, $
          r25thbrlo:r25thbrlo, $
          r25fe:r25fe, $
          r25fehi:r25fehi, $
          r25felo:r25felo, $
          r50ctype:r50ctype, $
          r50t77:r50t77, $
          r50t77hi:r50t77hi, $
          r50t77lo:r50t77lo, $
          r50t27:r50t27, $
          r50t27hi:r50t27hi, $
          r50t27lo:r50t27lo, $
          r50thbr:r50thbr, $
          r50thbrhi:r50thbrhi, $
          r50thbrlo:r50thbrlo, $
          k0:k0, $
          k0err:k0err, $
          k100:k100, $
          k100err:k100err, $
          alpha:alpha, $
          alphaerr:alphaerr, $
          lha:lha, $
          hatype:hatype, $
          lrad:lrad, $
          radtype:radtype, $
          lir:lir, $
          irtype:irl}

   ;# push this array into a master array
   push, ext1arr, arr
   
ERR_EXIT:
   IF err EQ 'T' THEN BEGIN
      openw, /get_lun, ERRLOG, err_log, /append
      printf, ERRLOG, format='(A-25,A15)',name,obsid
      close, ERRLOG
      free_lun, ERRLOG
   ENDIF
NEXT:
   prevname = name
   tcount--
ENDFOR
print, 'All done!'

;# add to the FITS file
MWRFITS, ext1arr, output, hdr

END
