function Phi_s(CellData,s,z,Def)
    """ 
    Solid Potential Transfer Function
    # Add License
    # Add Ins and Outs
        # Cell Data 
        # Frequency Vector 
        # Discretisation Locations
        # Electrode Definition
    """


 if Def == "Pos"   
    Electrode = CellData.Pos #Electrode Length
 else
    Electrode = CellData.Neg #Electrode Length
 end

as = 3*Electrode.ϵ_s/Electrode.Rs # Specific interfacial surf. area
κ_eff = CellData.Const.κ*Electrode.ϵ_e^Electrode.κ_brug #Effective Electrolyte Conductivity 
σ_eff = Electrode.σ*Electrode.ϵ_s^Electrode.σ_brug #Effective Electrode Conductivity 
comb_cond_eff = κ_eff+σ_eff #combining into single variable

#Defining SOC
θ = CellData.Const.SOC * (Electrode.θ_100-Electrode.θ_0) + Electrode.θ_0

#Beta's
β = @. Electrode.Rs*sqrt(s/Electrode.Ds)

#Prepare for j0
cs0 = Electrode.cs_max * θ

#Current Flux Density
κ = Electrode.k_norm/Electrode.cs_max/CellData.Const.ce0^(1-Electrode.α)
j0 = κ*(CellData.Const.ce0*(Electrode.cs_max-cs0))^(1-Electrode.α)*cs0^Electrode.α

#Resistance
Rtot = R*CellData.Const.T/(j0*F^2) + Electrode.RFilm

#∂Uocp_Def
∂Uocp_elc = CellData.Const.∂Uocp(Def,θ)/Electrode.cs_max

ν = @. Electrode.L*sqrt((as/σ_eff+as/κ_eff)/(Rtot+∂Uocp_elc*(Electrode.Rs/(F*Electrode.Ds))*(tanh(β)/(tanh(β)-β)))) #Condensing Variable - eq. 4.13
ν_∞ = @. Electrode.L*sqrt((as*(1/κ_eff)+(1/σ_eff))/(Rtot))

ϕ_tf = @. (-Electrode.L*(κ_eff*(cosh(ν)-cosh(z-1)*ν))-Electrode.L*(σ_eff*(1-cosh(z*ν)+z*ν*sinh(ν))))/(CellData.Const.CC_A*σ_eff*(comb_cond_eff)*ν*sinh(ν)) #Transfer Function - eq. 4.19
D = @. (-Electrode.L*(κ_eff*(cosh(ν_∞)-cosh(z-1)*ν_∞))-Electrode.L*(σ_eff*(1-cosh(z*ν_∞)+z*ν_∞*sinh(ν_∞))))/(CellData.Const.CC_A*σ_eff*(comb_cond_eff)*ν_∞*sinh(ν_∞)) # Contribution to D as G->∞
D_term = "@. -$(Electrode.L)*($κ_eff*(cosh($ν_∞)-cosh($z-1)*$ν_∞))/($(CellData.Const.CC_A)*$σ_eff*($comb_cond_eff)*$ν_∞*sinh($ν_∞))-$(Electrode.L)*($σ_eff*(1-cosh($z*$ν_∞)+$z*$ν_∞*sinh($ν_∞)))/($(CellData.Const.CC_A)*$σ_eff*($comb_cond_eff)*$ν_∞*sinh($ν_∞))"
zero_tf = @. Electrode.L*(z-2)*z/(2*CellData.Const.CC_A*σ_eff)
ϕ_tf[:,findall(s.==0)] .= zero_tf[:,findall(s.==0)]
res0 = zeros(length(z))

if Def == "Pos"
   ϕ_tf = -ϕ_tf
   D = -D
   D_term = "@. $(Electrode.L)*($κ_eff*(cosh($ν_∞)-cosh($z-1)*$ν_∞))/($(CellData.Const.CC_A)*$σ_eff*($comb_cond_eff)*$ν_∞*sinh($ν_∞))-$(Electrode.L)*($σ_eff*(1-cosh($z*$ν_∞)+$z*$ν_∞*sinh($ν_∞)))/($(CellData.Const.CC_A)*$σ_eff*($comb_cond_eff)*$ν_∞*sinh($ν_∞))"
   if Debug == 1
      println("D:Phi_s:Pos:",D)
      println("D_check:Phi_s:Pos:",D_check)
      #println("z:Phi_s:Pos:",z)
      println("ν_∞:Phi_s:Pos:",ν_∞)
      #println("ν:Phi_s:Pos:",ν)
      println("θ:Phi_s:Pos:",θ)
      println("κ:Phi_s:Pos:",κ)
      println("Rtot:Phi_s:Pos:",Rtot)
      println("j0:Phi_s:Pos:",j0)
      println("κ_eff:Phi_s:Pos:",κ_eff)
      println("σ_eff:Phi_s:Pos:",σ_eff)
   end
else
   if Debug == 1
      println("D:Phi_s:Neg:",D)
      println("D_check:Phi_s:Neg:",D_check)
      println("ν_∞:Phi_s:Neg:",ν_∞)
      println("θ:Phi_s:Neg:",θ)
      println("κ:Phi_s:Neg:",κ)
      println("Rtot:Phi_s:Neg:",Rtot)
      println("j0:Phi_s:Neg:",j0)
      println("κ_eff:Phi_s:Neg:",κ_eff)
      println("σ_eff:Phi_s:Neg:",σ_eff)
      println("zero_tf:Phi_s:Neg:",zero_tf)
      #println("z:Phi_s:Neg:",z)
      #println("ν:Phi_s:Neg:",ν)
   end
end
return ϕ_tf, D, res0, D_term

end
