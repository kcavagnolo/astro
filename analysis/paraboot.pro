; NAME:
;     paraboot
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

PRO paraboot, in0, in1, in2
; paraboot, '../info/reference.list','../fits/dat/adj_r2500-50_nhfro_fefree_7-7.dat','../fits/dat/adj_r2500-50_nhfree_fefree_7-7.dat'

ON_ERROR, 2
IF n_params() NE 3 THEN BEGIN
    print, 'Syntax - PARABOOT, <ref>, <in1>, <in2>'
    print, '<in1> must have more dof than <in2>!'
    return
ENDIF

; get the data
restore, "../scripts/full_sample.sav"
ref = read_ascii(in0, template = full_sample)
restore,"../scripts/xspectemp_rin_normerr_src.sav"
dat1 = read_ascii(in1, template = xspectemp_rin_normerr_src)
dat2 = read_ascii(in2, template = xspectemp_rin_normerr_src)

FOR r=0,n_elements(ref.obsid)-1 DO BEGIN
    obsid = ref.obsid[r]
    ; get fiducial data
    dof1 = dat1.dof[where(dat1.obsid EQ obsid)]
    dof2 = dat2.dof[where(dat2.obsid EQ obsid)]
    chi1 = dat1.chisq[where(dat1.obsid EQ obsid)]
    chi2 = dat2.chisq[where(dat2.obsid EQ obsid)]
    chi1 = chi1*dof1
    chi2 = chi2*dof2
stop
    f = ((chi1-chi2)/(dof1-dof2))/(chi2/dof2)
    push, outc, ref.name[r]
    push, outo, obsid
    push, outc1, chi1
    push, outc2, chi2
    push, outd1, dof1
    push, outd2, dof2
    push, outf, f
ENDFOR

close,1
openw,1,'ftest.dat'
o1 = transpose(outc)
o2 = transpose(outo)
o3 = transpose(outc1)
o4 = transpose(outc2)
o5 = transpose(outd1)
o6 = transpose(outd2)
o7 = transpose(outf)
FOR nn=0,n_elements(o1)-1 DO BEGIN
    printf,1,format='(A-,A20,2F12.3,2I12,F12.3)',o1[nn],o2[nn],o3[nn],o4[nn],o5[nn],o6[nn],o7[nn]
ENDFOR
close,1

END
