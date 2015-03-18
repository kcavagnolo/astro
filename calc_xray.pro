function calc_xray, x, params

; x is the independent variable, the projected radius in Mpc
;
; params is an array of parameter values for a beta model for the
; gas density and the universal temperature profile
; 
;  param[0] = r_c the core radius in Mpc
;  param[1] = the beta exponent
;  param[2] = the core size for the temperature profile (alpha)
;  param[3] = the overdensity radius for delta = 500 in Mpc
;  param[4] = exponent for the temperature profile (delta)

; ymodel=the I value
; calling syntax: result = calc_xray(x, params)

hypgeo_lib = './hypergeometric.so'


num_points = n_elements(x)
num_params = n_elements(params)

ymodel = dblarr(num_points)

this_rc    = params[0]
this_beta  = params[1]
this_alpha = params[2]
this_r500  = params[3]
this_delta = params[4]

this_rc = this_rc/this_r500
this_r500 = this_r500/this_r500

gam1 = gamma(3.0d0 * this_beta + this_delta / 2.0d0 - 0.5d0)
gam2 = gamma(3.0d0 * this_beta + this_delta / 2.0d0)


if ( this_rc GT this_alpha * this_r500 ) then begin

   for I = 0, num_points-1 do begin

      a = float(3.0 * this_beta)
      b = 0.5
      c = float(3.0 * this_beta + this_delta/2.0)
      z = float(1.0 - (this_alpha * this_alpha * this_r500 * this_r500 + x[I] * x[I]) / $
                (this_rc * this_rc + x[I] * x[I]))
      f21 = call_external(hypgeo_lib, 'hypgeo_idl', a, 0.0, b, 0.0, c, 0.0, z, 0.0, $
                         /ALL_VALUE, /F_VALUE, RETURN_TYPE=4) 

      ymodel[I] = this_alpha*this_r500/2.0*( 1.0d0 + (x[i] / this_alpha / this_r500)^2 )^(0.5) * sqrt(!PI) * gam1 / gam2 * f21

   endfor

endif else begin

   for I = 0, num_points-1 do begin
   
      a = float(this_delta/2.0)
      b = 0.5
      c = float(3.0 * this_beta + this_delta/2.0)
      z = float(1.0 - ( this_rc * this_rc + x[I] * x[I]) / $
                ( this_alpha * this_alpha * this_r500 * this_r500 + x[I] * x[I]))
      f21 = call_external(hypgeo_lib, 'hypgeo_idl', a, 0.0, b, 0.0, c, 0.0, z, 0.0, $
                         /ALL_VALUE, /F_VALUE, RETURN_TYPE=4)


      ymodel[I] = this_rc/2.0 * ( 1.0d0 + (x[I] / this_rc)^2 )^(0.5) * $
                   sqrt(!PI) * gam1 / gam2  * f21
   endfor

endelse



return, ymodel
end
