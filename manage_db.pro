PRO manage_db

; NAME:
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
; MODIFICATION HISTORY:
;
;#####################
;#####################
; OPTIONS
;#####################
;#####################

creator = 'Kenneth W. Cavagnolo'
ciaover = '3.4'
caldbver = '3.4.1'
xspecver = '11.3.2ag'
cosmo = 'H0=70 : Omega_m=0.3 : Omega_lambda=0.7'

;#####################
;#####################
; Main Program
;#####################
;#####################

; return to caller on error
ON_ERROR, 2

; check for correct number of parameters
IF n_params() LE 0. THEN BEGIN
   print, 'Syntax - MANAGE_DB'
   return
ENDIF

;# name error log file
myhome = GETENV('HOME')
err_log = 'managedb_err.log'
file_delete, err_log, /allow_nonexistent, /quiet

END
