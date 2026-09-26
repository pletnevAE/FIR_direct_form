%================================================================================
% This script compares the output of an RTL FIR filter with a filter that has 
% double coefficients.
%================================================================================

clear; clc; close all;

F_clk = 100e6; % Clock frequency
F_s = 100e6; % Sampling frequency
filterType = 'lowpass'; % Filter Type
Fpass = 10e6; % Passband edge
Fstop = 15e6; % Stopband edge
Fpass1 = 10e6; % First Passband edge
Fpass2 = 15e6; % Second Passband edge
Fstop1 = 7e6; % First Stopband edge
Fstop2 = 18e6; % Stopband edge
Apass = 0.1; % Passband ripple in dB
Astop = 60; % Stopband ripple in dB
Apass1 = 0.1; % First Passband ripple in dB
Apass2 = 0.1; % Second Passband ripple in dB
Astop1 = 60; % First Stopband ripple in dB
Astop2 = 60; % Second Stopband ripple in dB
in_WL = 16; % Word lengths for input signal
in_FL = 15; % Fraction lengths for input signal 
out_FL = 32; % Fraction lengths for output signal
out_WL = 34; % Word lengths for output signal
coeff_WL = 16; % Word lengths for coefficients
coeff_FL = 17; % Fraction lengths for coefficients
output_rtl_path = "output_fir.txt"; % RTL output file path
stimul_path = "stimulus.txt"; % Stimulus file path

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
rtl_out_fi = fi([], true, out_WL, out_FL);
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
fprintf('Output Word Length           : %d\n', out_WL);
fprintf('Output Frac. Length          : %d\n', out_FL);
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
