PRO fix_nvas, infile
  nrows = 10
  outfile = 'fixed_'+infile
  a=mrdfits(infile, 0, hdr)
  maxrows = n_elements(a[0,*])-1
  FOR i=(maxrows-nrows),maxrows DO BEGIN
     a[*,i]=0
  ENDFOR
  FOR i=0L,n_elements(a[*,1])-1 DO BEGIN
     ord = where((Finite(a[i,*]) EQ 0),num)
     IF num GT 0 THEN $
        a[i,ord] = 0.0
  ENDFOR
  file_delete, outfile, /quiet
  mwrfits, a, outfile, hdr
END
