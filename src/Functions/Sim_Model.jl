function Sim_Model(CellData,Dtt,Iapp,Tk,A,B,C,D)
    """ 
    Simulation of generated reduced-order models
    # Add License
    # Add Ins and Outs
        # Locations to be computed
        # Sampling Frequency
    """
    #Slice SS Matrices
    A = A[1]
    B = B[1]
    C = C[1]
    D = D[1]

    #Capturing Indices
    tfstr = Array{String}(undef,0,1)
    for i in 1:size(CellData.Transfer.tfs[:,1],1)
        t1 = t2 = Array{String}(undef,0,1)
        for j in 1:size(CellData.Transfer.tfs[i,3],1)
            t1 ="$(CellData.Transfer.tfs[i,1])_$(CellData.Transfer.tfs[i,2])"
            t2 = [t2; t1]
        end
        tfstr = [tfstr; t2]
    end

    CeInd = findall(isequal("C_e_Na"), tfstr)
    ϕ_ẽInd = findall(isequal("Phi_e_Na"), tfstr)
    CsePosInd = findall(isequal("C_se_Pos"), tfstr)
    CseNegInd = findall(isequal("C_se_Neg"), tfstr)
    ϕ_sNegInd = findall(isequal("Phi_s_Neg"), tfstr)
    ϕ_sPosInd = findall(isequal("Phi_s_Pos"), tfstr)
    ϕ_sePosInd = findall(isequal("Phi_se_Pos"), tfstr)
    ϕ_seNegInd = findall(isequal("Phi_se_Neg"), tfstr)
    FluxNegInd = findall(isequal("Flux_Neg"), tfstr)
    FluxPosInd = findall(isequal("Flux_Pos"), tfstr)

    csegain_neg = C[CseNegInd[1],1]
    csegain_pos = C[CsePosInd[1],1]

    #Determine time span and allocate arrays
    tlength = size(Iapp,1)

    #Memory Allocation
    θ_neg = Array{Float64}(undef,tlength,1) .= 0.
    θ_pos = Array{Float64}(undef,tlength,1) .= 0.
    x = Array{Float64}(undef,tlength,size(A,1)) .= 0.
    y = Array{Float64}(undef,tlength,size(C,1)) .= 0.
    Cse_Neg = Array{Float64}(undef,tlength,size(CseNegInd,1)) .= 0.
    Cse_Pos = Array{Float64}(undef,tlength,size(CsePosInd,1)) .= 0.
    Ce = Array{Float64}(undef,tlength,size(CeInd,1)) .= 0.
    η0 = Array{Float64}(undef,tlength,1) .= 0.
    η_neg = Array{Float64}(undef,tlength,size(FluxNegInd,1)) .= 0.
    ηL = Array{Float64}(undef,tlength,1) .= 0.
    η_pos = Array{Float64}(undef,tlength,size(FluxPosInd,1)) .= 0.
    ϕ_ẽ1 = Array{Float64}(undef,tlength,size(ϕ_ẽInd,1)) .= 0.
    ϕ_ẽ2 = Array{Float64}(undef,tlength,size(ϕ_ẽInd,1)) .= 0.
    ϕ_se_neg_0 = Array{Float64}(undef,tlength,1) .= 0. #Replace with length of ϕ_seNegInd @ zero
    jNeg = Array{Float64}(undef,tlength,2) .= 0. 
    j0 = Array{Float64}(undef,tlength,1) .= 0. 
    jPos = Array{Float64}(undef,tlength,2) .= 0.
    jL = Array{Float64}(undef,tlength,1) .= 0.  
    Cell_V = Array{Float64}(undef,tlength,1) .= 0.

    #Defining SOC
    θ_neg[1] = CellData.Const.SOC * (CellData.Neg.θ_100-CellData.Neg.θ_0) + CellData.Neg.θ_0
    θ_pos[1] = CellData.Const.SOC * (CellData.Pos.θ_100-CellData.Pos.θ_0) + CellData.Pos.θ_0

    #Loop through time
        #Compute dependent variables (voltage, flux, etc.)
    for i in 1:tlength-1
        cs_neg_avg = x[i,end]*csegain_neg+θ_neg[i]*CellData.Neg.cs_max < 0. ? 0. : x[i,end]*csegain_neg+θ_neg[i]*CellData.Neg.cs_max #Zero if < 0
        cs_pos_avg = x[i,end]*csegain_pos+θ_pos[i]*CellData.Pos.cs_max < 0. ? 0. : x[i,end]*csegain_pos+θ_pos[i]*CellData.Pos.cs_max #Zero if < 0

        # println("cs_neg_avg:", cs_neg_avg)

        θ_neg[i+1] = cs_neg_avg/CellData.Neg.cs_max
        θ_pos[i+1] = cs_pos_avg/CellData.Pos.cs_max
        Cell_SOC = (θ_neg[i]-CellData.Neg.θ_0)/(CellData.Neg.θ_100-CellData.Neg.θ_0)
        # println("θ_neg:",θ_neg)
        # println("θ_pos:",θ_pos)
        # println("Cell_SOC:",Cell_SOC)


        jeq_neg = CellData.Neg.k_norm*sqrt(cs_neg_avg*(CellData.Const.ce0*(CellData.Neg.cs_max-cs_neg_avg)))
        jeq_pos = CellData.Pos.k_norm*sqrt(cs_pos_avg*(CellData.Const.ce0*(CellData.Pos.cs_max-cs_pos_avg)))
        javg_neg = Iapp[i]/(CellData.Neg.ϵ_s*(3*F*CellData.Neg.L*CellData.Const.CC_A)/CellData.Neg.Rs)
        javg_pos = Iapp[i]/(CellData.Pos.ϵ_s*(3*F*CellData.Pos.L*CellData.Const.CC_A)/CellData.Pos.Rs)


        Arr_Factor = ((1/CellData.Const.T_ref)-(1/Tk[i]))/R
        κ = CellData.Const.κf(CellData.Const.ce0)*exp(CellData.Const.Ea_κ*Arr_Factor)
        σ_neg = CellData.Neg.σ*exp(CellData.Const.Ea_κ*Arr_Factor)
        σ_pos = CellData.Pos.σ*exp(CellData.Const.Ea_κ*Arr_Factor)
        κ_eff_Neg = κ*(CellData.Neg.ϵ_e^(CellData.Neg.κ_brug))
        κ_eff_Sep = κ*(CellData.Sep.ϵ_e^(CellData.Sep.κ_brug))
        κ_eff_Pos = κ*(CellData.Pos.ϵ_e^(CellData.Pos.κ_brug))


        σ_eff_Neg = σ_neg*CellData.Neg.ϵ_s^CellData.Neg.σ_brug #Effective Conductivity Neg
        σ_eff_Pos = σ_pos*CellData.Pos.ϵ_s^CellData.Pos.σ_brug #Effective Conductivity Pos
        
        #Reaction Rates
        k_neg = CellData.Neg.k_norm*CellData.Neg.cs_max/CellData.Const.ce0^(1-CellData.Neg.α)
        k_pos = CellData.Pos.k_norm*CellData.Pos.cs_max/CellData.Const.ce0^(1-CellData.Pos.α)

        #Resistances
        Rtot_neg = (Tk[i]*R)/(F^2*sqrt(jeq_neg^2+(javg_neg^2/4)))+CellData.Neg.RFilm
        Rtot_pos = (Tk[i]*R)/(F^2*sqrt(jeq_pos^2+(javg_pos^2/4)))+CellData.Pos.RFilm

        #Condensing Variable
        ν_neg = CellData.Neg.L*sqrt((3*(CellData.Neg.ϵ_s/CellData.Neg.Rs)*(1/κ_eff_Neg+1/σ_eff_Neg))/Rtot_neg)
        ν_pos = CellData.Pos.L*sqrt((3*(CellData.Pos.ϵ_s/CellData.Pos.Rs)*(1/κ_eff_Pos+1/σ_eff_Pos))/Rtot_pos)

        #Relinearise dependent on ν, σ, κ
        #Call from CellData? List of functions composed from ROM creation?
        #D = D_fun(CellData, ν_neg, ν_pos, σ_eff_Neg, σ_eff_Pos, κ_eff_Neg, κ_eff_Sep, κ_eff_Pos) #Calling D linearisation functions
        #D = D_Linear(Dtt,ν_neg,ν_pos)

        #SS Output
        y[i,:] = C*x[i,:] + D*Iapp[i]
        # display("text/plain", x[i,:])
        # println("\n")
        # display("text/plain", y[i,:])
        # println("\n")
        #Concentrations
        Cse_Neg[i,:] = @. θ_neg[i]*CellData.Neg.cs_max + y[i,CseNegInd]  
        Cse_Pos[i,:] = @. θ_pos[i]*CellData.Pos.cs_max + y[i,CsePosInd] 
        Ce[i,:] = @. CellData.Const.ce0 + y[i,CeInd]
        # println("Cse_Neg:",Cse_Neg)
        # println("Cse_Pos:",Cse_Pos)
        
        #Potentials
        Uocp_Neg = CellData.Const.Uocp("Neg",θ_neg[i])
        Uocp_Pos = CellData.Const.Uocp("Pos",θ_pos[i])
        # println("ϕ_seNegInd[1]:",ϕ_seNegInd[1])
        # println("Uocp_Neg:",Uocp_Neg)
        # println("y[i, ϕ_seNegInd[1]]:",y[i, ϕ_seNegInd[1]])
        ϕ_se_neg_0[i] = y[i, ϕ_seNegInd[1]] + Uocp_Neg #Location 0
        ϕ_ẽ1[i,:] = y[i,ϕ_ẽInd]
        ϕ_ẽ2 = @. ((Tk[i]*2*R*(1-CellData.Const.t_plus))/F)*(log(Ce[i,:]/Ce[1]))
        ϕ_e = @. [0; ϕ_ẽ1[i,:]]+ϕ_ẽ2-ϕ_se_neg_0[i]

        #Flux
        jNeg[i,:] = y[i,FluxNegInd]
        j0[i] = y[i,FluxNegInd[1]]
        jPos[i,:] = y[i,FluxPosInd]
        jL[i] = y[i,FluxPosInd[1]]
        # println("FluxNegInd[1]",FluxNegInd[1])
        j0_CC_neg = findmax([eps(); ((CellData.Neg.cs_max-Cse_Neg[i,1])^(1-CellData.Neg.α))*((Cse_Neg[i,1]^CellData.Neg.α)*(Ce[i,1]^(1-CellData.Neg.α)))*k_neg])[1]
        j0_neg = @. findmax([eps(); ((Cse_Neg[i,:]^CellData.Neg.α)*(Ce[i,1]^(1-CellData.Neg.α)))*(CellData.Neg.cs_max-Cse_Neg[i,:])^(1-CellData.Neg.α)*k_neg])[1]
        η0[i] = asinh((y[i,FluxNegInd[1]]/(2*j0_CC_neg)))*(Tk[i]*2*R/F)
        η_neg[i,:] = @. (Tk[i]*2*R/F)/asinh(jNeg[i,:]/(2*j0_neg))

        j0_CC_pos = findmax([eps(); ((CellData.Pos.cs_max+Cse_Pos[i,1])^(1-CellData.Pos.α))*((Cse_Pos[i,1]^CellData.Pos.α)*(Ce[1]^(1-CellData.Pos.α)))*k_pos])[1] 
        j0_pos = @. findmax([eps(); ((Cse_Pos[i,:]^CellData.Pos.α)*(Ce[i,1]^(1-CellData.Pos.α)))*(CellData.Pos.cs_max-Cse_Pos[i,:])^(1-CellData.Pos.α)*k_pos])[1]
        ηL[i] = asinh(y[i,FluxPosInd[1]])/(2*j0_CC_pos)*(Tk[i]*2*R/F)
        η_pos[i,:] = @. (Tk[i]*2*R/F)/asinh((jPos[i,:]/(2*j0_pos)))

        #Cell Voltage
        Cell_V[i] = @. (Uocp_Pos-Uocp_Neg) + (ηL[i]-η0[i]) + (ϕ_ẽ1[i,end]+ϕ_ẽ2[end]) + (CellData.Pos.RFilm*jL[i]-CellData.Neg.RFilm*j0[i])*F
        # println("Cell_V:",Cell_V[i])
        # println("Uocp_Pos:",Uocp_Pos)
        # println("Uocp_Neg:",Uocp_Neg)
        # println("ηL[i]:",ηL[i])
        # println("η0[i]:",η0[i])
        # println("ϕ_ẽ1[i,end]:",ϕ_ẽ1[i,end])
        # println("ϕ_ẽ2[end]:",ϕ_ẽ2[end])
        # println("CellData.Pos.RFilm*j0[i]:",CellData.Pos.RFilm*j0[i])
        # println("CellData.Neg.RFilm*j0[i]):",CellData.Neg.RFilm*j0[i])
        # println("")
        #ϕ_s
        ϕ_s_neg = y[i,ϕ_sNegInd]
        ϕ_s_pos = @. y[i,ϕ_sPosInd] + Cell_V[i]


        #Update States
        x[i+1,:] = A*x[i,:] + B*Iapp[i]


    end
    return Cell_V, jNeg, jPos, y, x, η0, ηL, ϕ_ẽ1, ϕ_ẽ2
end

function D_Linear(Dtt,ν_neg, ν_pos)
    Dtemp = Array{Float64}(undef,0,1)
    D = Array{Float64}(undef,0,1)
    global ν_neg
    for j in 1:length(Dtt)
        Dtemp = eval(Meta.parse(Dtt[j]))
        D = [D; Dtemp]
    end
    return D
end

# println("j0_CC_neg:",length(j0_CC_neg))
# display("text/plain", j0_CC_neg)