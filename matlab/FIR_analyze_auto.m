%================================================================================
% This function compares the output of an RTL FIR filter with a filter that has 
% double coefficients.
%================================================================================

function FIR_analyze_auto(build_path)

    output_rtl_path = build_path + "/output_fir.txt"; % RTL output file path
    stimul_path = build_path + "/stimulus.txt"; % Stimulus file path
    params_path = "../matlab/params.mat"; % Parameters file path
    
    %================================================================================
    %% Reading parameters
    %================================================================================
    if (exist(params_path, 'file') == 2)
        params = load(params_path);
        delete(params_path);
    else
        error('File ''params.mat'' not found.');
    end

    F_s = params.F_s; % Sampling frequency
    Fpass = params.Fpass; % Passband edge
    Fstop = params.Fstop; % Stopband edge
    filterType = params.filterType; % Filter Type
    Apass = params.Apass; % Passband ripple in dB
    Astop = params.Astop; % Stopband ripple in dB
    in_WL = params.in_WL; % Word lengths for input signal
    in_FL = params.in_FL; % Fraction lengths for input signal
    out_sym_WL = params.out_sym_WL; % Word lengths for output signal (symmetry)
    out_sym_FL = params.out_sym_FL; % Fraction lengths for output signal (symmetry)
    coeff_WL = params.coeff_WL; % Word lengths for coefficients
    coeff_FL = params.coeff_FL; % Fraction lengths for coefficients
    mult_WL = params.mult_WL; % Word lengths for multipliers 
    mult_FL = params.mult_FL; % Fraction lengths for multipliers 
    acc_WL = params.acc_WL; % Word lengths for accumulators
    acc_FL = params.acc_FL; % Fraction lengths for accumulators
    
    %================================================================================
    %% Reading stimulus signal
    %================================================================================
    if (exist(stimul_path, 'file') == 2)
        stimulus = readmatrix(stimul_path);
    else
        error('File ''stimul_path.txt'' not found.');
    end
    
    %================================================================================
    %% Reading RTL output signal
    %================================================================================
    if (exist(output_rtl_path, 'file') == 2)
        rtl_out = readmatrix(output_rtl_path);
    else
        error('File ''output_fir.txt'' not found.');
    end
    
    Hd = FIR_Calculation(F_s, Fpass, Fstop, filterType, Apass, Astop); % FIR Calculation
    
    %================================================================================
    %% Converting the stimulus
    %================================================================================
    stimulus_fi = fi([], true, in_WL, in_FL);
    stimulus_fi.int = stimulus;
    stimulus_double = double(stimulus_fi);
    
    %================================================================================
    %% Filtering the stimulus signal with double coefficients
    %================================================================================
    out_double = filter(Hd.Numerator, 1, stimulus_double); % Filtering
    
    %================================================================================
    %% Converting the RTL output signal
    %================================================================================
    rtl_out_fi = fi([], true, out_sym_WL, out_sym_FL);
    rtl_out_fi.int = rtl_out;
    rtl_out_double = double(rtl_out_fi);
    
    num_samples = length(rtl_out_double);
    n = 0 : num_samples - 1;
    
    %================================================================================
    %% Calculation of Absolute Error
    %================================================================================
    err = rtl_out_double - out_double;
    abs_err = abs(err);
    max_err = max(abs_err);
    rms_err = sqrt(mean(err.^2));
    sqnr = 10 * log10(sum((out_double).^2) / sum(err.^2));
    
    sqnr_theory = 6.02 * coeff_FL + 1.76 - 10 * log10(length(Hd.Numerator) - 1);
    max_err_theory = 3 * sqrt(length(Hd.Numerator) - 1) * 2^(-coeff_FL) / sqrt(12);
    
    %================================================================================
    %% Report
    %================================================================================
    fprintf('\n==================== FIR REPORT ====================\n')
    fprintf('Filter Type                  : %s\n', filterType);
    fprintf('Filter Order                 : %d\n', length(Hd.Numerator) - 1);
    fprintf('Numerator Word Length        : %d\n', coeff_WL);
    fprintf('Numerator Frac. Length       : %d\n', coeff_FL);
    fprintf('Input Word Length            : %d\n', in_WL);
    fprintf('Input Frac. Length           : %d\n', in_FL);
    fprintf('Output Word Length           : %d\n', out_sym_WL);
    fprintf('Output Frac. Length          : %d\n', out_sym_FL);
    fprintf('Product Word Length          : %d\n', mult_WL);
    fprintf('Product Frac. Length         : %d\n', mult_FL);
    fprintf('Accum. Word Length           : %d\n', acc_WL);
    fprintf('Accum. Frac. Length          : %d\n', acc_FL);
    fprintf('Theoretical Error            : %e\n', max_err_theory);
    fprintf('Theoretical SQNR             : %.2f dB', sqnr_theory);
    fprintf('\n----------------------------------------------------\n')
    fprintf('Maximum Absolute Error      : %e\n', max_err);
    fprintf('RMS Error                   : %e\n', rms_err);
    fprintf('Actual Measured SQNR        : %.2f dB\n', sqnr);
    fprintf('\n====================================================\n')
    
    %================================================================================
    %% Signals and Error Graphs
    %================================================================================
    figure;
    subplot(2, 1, 1);
    plot(n, rtl_out_double, 'b-', 'LineWidth', 1.5);
    hold on;
    plot(n, out_double, 'r--', 'LineWidth', 1);
    grid on;
    xlim([0 num_samples - 1]);
    title('FIR Output');
    xlabel('Sample');
    ylabel('Amplitude');
    legend('RTL, Fixed-Point FIR', 'MATLAB, Double FIR');
    
    subplot(2, 1, 2);
    plot(n, abs_err, 'r-');
    grid on;
    xlim([0 num_samples - 1]);
    title('Error');
    xlabel('Sample');
    ylabel('Absolute Error (LBSs)');
    
	fprintf('[INFO] Close all charts to finish...\n');
    %================================================================================
    %% Waiting for charts to close
    %================================================================================
	figs = findall(0, 'Type', 'figure');
	while ~isempty(findall(0, 'Type', 'figure'))
		figs = findall(0, 'Type', 'figure');
		uiwait(figs(1))
    end
end