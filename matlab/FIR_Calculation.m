%================================================================================
% This function calculates an FIR filter based on the given parameters. 
% The function outputs a filter object.
%================================================================================
function Hd = FIR_Calculation(F_s, Fpass, Fstop, filterType, Apass, Astop)
    if (any(Apass >= Astop))
        error('[ERROR] Astop must be greater then Apass.');
    end

    Dpass = (10.^(Apass / 20) - 1) ./ (10.^(Apass / 20) + 1); % Passband ripple
    Dstop = 10.^(-Astop / 20); % Stopband ripple
    
    %================================================================================
    %% Selecting a filter type
    %================================================================================
    switch lower(filterType)
        case 'lowpass'
            if (Fpass < Fstop)
                f_edges = [Fpass Fstop];
                a_levels = [1 0];
                devs = [Dpass Dstop];
            else
                error('[ERROR] For lowpass Fstop must be greater then Fpass');
            end
        case 'highpass'
            if (Fpass > Fstop)
                f_edges = [Fpass Fstop];
                a_levels = [0 1];
                devs = [Dstop Dpass];
            else
                error('[ERROR] For highpass Fpass must be greater then Fstop');
            end
        case 'bandpass'
            f_edges = [Fstop(1) Fpass(1) Fpass(2) Fstop(2)];
            a_levels = [0 1 0];
            devs = [Dstop(1) Dpass Dstop(2)];
            if (~issorted(f_edges(:), 'strictascend'))
                error('[ERROR] For a bandpass filter, frequencies are in ascending order as follows: Fstop1 Fpass1 Fpass2 Fstop2');
            end
        case 'bandstop'
            f_edges = [Fpass(1), Fstop(1), Fstop(2), Fpass(2)];
            a_levels = [1 0 1];
            devs = [Dpass(1) Dstop Dpass(2)];
            if (~issorted(f_edges(:), 'strictascend'))
                error('[ERROR] For a bandstop filter, frequencies are in ascending order as follows: Fpass1 Fstop1 Fstop2 Fpass2');
            end
        otherwise
            error('[ERROR] The filter type is set incorrectly. Use "lowpass", "highpass", "bandpass" or "bandstop"');
    end
    
    %================================================================================
    %% Filter calculation
    %================================================================================
    [N, Fo, Ao, W] = firpmord(f_edges/(F_s/2), a_levels, devs); % Parks-McClellan optimal FIR filter order estimation
    b  = firpm(N, Fo, Ao, W); % Parks-McClellan optimal FIR filter design
    Hd = dfilt.dffir(b); % Filter object
end