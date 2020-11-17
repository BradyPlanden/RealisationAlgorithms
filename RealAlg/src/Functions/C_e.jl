function C_e(CellData::Cell)
""" 
Electrolyte Concentration Transfer Function
# Add License
# Add Ins and Outs
    # Locations to be computed
    # Sampling Frequency
"""
Lpos = CellData.Geo.Lpos
Lneg = CellData.Geo.Lneg
Lsep = CellData.Geo.Lsep
Ltot = CellData.Geo.Ltot


F = CellData.Const.F      # Faraday Constant
R = CellData.Const.R       # Universal Gas Constant
T = CellData.Const.T      # Temperature
t_plus = CellData.Const.t_plus  # Transference Number
ζ = (1-t_plus)/F    #Simplifying Variable


Rs_Neg = CellData.Neg.Rs       # Particle radius [m]
Rs_Pos = CellData.Pos.Rs       # Particle radius [m]
Ds_Neg = CellData.Neg.Ds       # Solid diffusivity [m^2/s]
Ds_Pos = CellData.Pos.Ds       # Solid diffusivity [m^2/s]
CC_A = CellData.Geo.CC_A   # Current-collector area [m^2]
as_neg = 3*CellData.Neg.ϵ_s/Rs_Neg # Specific interfacial surf. area
as_pos = 3*CellData.Pos.ϵ_s/Rs_Pos # Specific interfacial surf. area
ϵ1 = CellData.Neg.ϵ_e      # Porosity of negative electrode
ϵ2 = CellData.Sep.ϵ_e      # Porosity of separator
ϵ3 = CellData.Pos.ϵ_e      # Porosity of positive electrode
D1 = CellData.Const.De * ϵ1^CellData.Neg.De_brug # Effective ...
D2 = CellData.Const.De * ϵ2^CellData.Sep.De_brug # diffusivities ...
D3 = CellData.Const.De * ϵ3^CellData.Pos.De_brug # of cell regions


κ_eff_Neg = CellData.Const.κ*ϵ1^CellData.Neg.κ_brug
κ_eff_Pos = CellData.Const.κ*ϵ3^CellData.Pos.κ_brug

σ_eff_Neg = CellData.Neg.σ*ϵ1^CellData.Neg.σ_brug #Effective Conductivity Neg
σ_eff_Pos = CellData.Pos.σ*ϵ3^CellData.Pos.σ_brug #Effective Conductivity Pos


#Defining SOC
θ_neg = 1 - (cs_max_neg-cs)/cs_max_neg

#Beta's 
βn = Rs_Neg*(s*Ds_Neg)^(1/2)
βp = Rs_Pos*(s*Ds_Pos)^(1/2)



#Concentrations


#Current Flux Density
j0_neg = κ_Neg*(ce0*cs_max_neg*cs0_neg)^(1-α)*cs0_neg^α
j0_pos = κ_pos*(ce0*cs_max_pos*cs0_pos)^(1-α)*cs0_pos^α

#Resistances
Rct_neg = R*T/(j0_neg*F)^2
Rtot_neg = Rct_neg + Rfilm_neg

Rct_pos = R*T/(j0_pos*F)^2
Rtot_pos = Rct_pos + Rfilm_pos

#Condensing Variable
ν_n = Lneg*(as_neg/σ_eff_Neg+as_neg/κ_eff_Neg)^(1/2)/(Rtot_neg+∂Uocp_Cse*(Rs_Neg/(F*Ds_Neg))*(tanh(βn)/(tanh(βn)-βn)))
ν_p = Lpos*(as_pos/σ_eff_Pos+as_pos/κ_eff_Pos)^(1/2)/(Rtot_pos+∂Uocp_Cse*(Rs_Pos/(F*Ds_Pos))*(tanh(βp)/(tanh(βp)-βp)))


Lneg⋆ = Lneg * (ϵ1 * λ_k / Ds_Neg)^1/2
Lpos⋆ = Lpos * (ϵ3 * λ_k / Ds_Pos)^1/2
L⋆ = Ltot * (ϵ3 * λ_k / Ds_Pos)^1/2
Lnm⋆ = (Lneg+Lsep) * (ϵ3 * λ_k / Ds_Pos)^1/2



j_Neg = κ1*ζ*Lneg⋆*sin(Lneg⋆)*(κ_eff_Neg+σ_eff_Neg*cosh(ν_n)*ν_s)/(CC_A*(κ_eff_Neg+σ_eff_Neg)*(Lneg⋆^2+ν_n^2*sinh(ν_n)))

Hlp1 = σ_eff_Pos+κ_eff_Pos
Hlp2 = (Hlp1*cosh(ν_p)*ν_p)
Hlp3 = (Lpos⋆^2 + ν_p^2)*sinh(ν_p)


j_Pos1 = (κ6*ζ*Lpos⋆*cos(L⋆)*Hlp2)/(CC_A*Hlp1*Hlp3)
j_Pos2 = (κ5*ζ*Lpos⋆*sin(Lpos⋆)*Hlp2)/(CC_A*Hlp1*Hlp3)
j_Pos3 = (κ6*ζ*Lpos⋆*cos(Lnm⋆)*Hlp2)/(CC_A*Hlp1*Hlp3)
j_Pos4 = (κ5*ζ*Lpos⋆*sin(L⋆)*Hlp2)/(CC_A*Hlp1*Hlp3)
j_Pos5 = (κ5*ζ*σ_eff_Pos*cos(Lnm⋆)*κ_eff_Pos*cos(L⋆)*ν_p^2)/(CC_A*Hlp1*(Lpos⋆^2 + ν_p^2))
j_Pos6 = (κ6*ζ*σ_eff_Pos*sin(Lnm⋆)*κ_eff_Pos*sin(L⋆)*ν_p^2)/(CC_A*Hlp1*(Lpos⋆^2 + ν_p^2))


j_Pos = j_Pos1 - j_Pos2 + j_Pos3 - j_Pos4 - j_Pos5 - j_Pos6



C_e = (1/(s+λ_k))* (j_Neg + j_Pos)

return Ltot

end