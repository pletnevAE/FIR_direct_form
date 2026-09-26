%================================================================================
% This script calculates the FIR filter coefficients, the bit depth of this 
% filter, and calculates the stimulus signal.
%================================================================================
clear; clc; close all;

F_clk = 100e6; % Clock
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
coeff_WL = 16; % Word lengths for coefficients
in_WL = 16; % Word lengths for input signal
in_FL = 15; % Fraction lengths for input signal  
out_file_coeff = 'fir_coeffs.txt'; % File with coefficients
out_file_stimul = 'stimulus.txt'; % Path to the stimulus file
num_format = 'hex'; % Coefficients representation format ('dec', 'hex', 'bin')

if (F_s > F_clk)
    error('[ERROR] F_clk must be greater than or equal to F_s');
elseif (mod(F_clk, F_s) ~= 0)
    error('[ERROR] F_clk must be divisible by F_s');
end

%================================================================================
%% Selecting a filter type
%================================================================================
switch filterType
    case 'lowpass'
        Fpass = Fpass;
        Fstop = Fstop;
        Apass = Apass;
        Astop = Astop;
    case 'highpass'
        Fpass = Fpass;
        Fstop = Fstop;
        Apass = Apass;
        Astop = Astop;
    case 'bandpass'
        Fpass = [Fpass1 Fpass2];
        Fstop = [Fstop1 Fstop2];
        Apass = Apass;
        Astop = [Astop1 Astop2];
    case 'bandstop'
        Fpass = [Fpass1 Fpass2];
        Fstop = [Fstop1 Fstop2];
        Apass = [Apass1, Apass2];
        Astop = Astop;
end

%================================================================================
%% Calculation of filter coefficients and order
%================================================================================
Hd = FIR_Calculation(F_s, Fpass, Fstop, filterType, Apass, Astop); % FIR Calculation
b_fix = fi(Hd.Numerator, true, coeff_WL); % Converting coefficients to Fixed-Point
N = length(Hd.Numerator) - 1; % Filter Order

[h_dbl, f] = freqz(Hd.Numerator, 1, 4096, F_s); % Frequency response of digital filter (Double coefficients)

%================================================================================
%% Calculation of bit depth
%================================================================================
coeff_FL = b_fix.FractionLength; % Determining the optimal length of the fractional part.
coeff_IL = coeff_WL - coeff_FL; % Integer bit depth in bits, including the sign bit for coefficients

in_IL = in_WL - in_FL; % Integer bit depth in bits, including the sign bit for input

mult_max_val = (2^(in_IL - 1) - 2^(-in_FL)) * max(abs(b_fix)); % Max value in multipliers output
mult_FL = in_FL + coeff_FL; % Optimal fraction lengths for multipliers
mult_IL = floor(log2(double(mult_max_val))) + 2; % Integer bit depth in bits, including the sign bit for multipliers
mult_WL = mult_FL + mult_IL; % Optimal word lengths for multipliers

worst_case_gain = sum(abs(double(b_fix))); % Absolute worst-case gain
bit_growth = ceil(log2(worst_case_gain)) + 2; % Real growth of the integer part
acc_FL = mult_FL; % Optimal fraction lengths for accumulators
acc_IL = mult_IL + bit_growth; % Integer bit depth in bits, including the sign bit for accumulators
acc_WL = acc_IL + acc_FL; % Optimal word lengths for accumulators

preadd_WL = in_WL + 1; % Word length for preadder
preadd_FL = in_FL; % Fraction length for preader
preadd_IL = preadd_WL - preadd_FL; % Integer bit depth for preadder

mult_sym_max_val = (2^(preadd_IL - 1) - 2^(-preadd_FL)) * max(abs(b_fix)); % Max value in multipliers output
mult_sym_IL = floor(log2(double(mult_sym_max_val))) + 2; % Integer bit depth in bits, including the sign bit for multipliers
mult_sym_FL = preadd_FL + coeff_FL; % Fraction lengths for multipliers
mult_sym_WL = mult_sym_FL + mult_sym_IL; % Word lengths for multipliers

worst_case_gain_sym = sum(abs(double(b_fix(1:length(b_fix) / 2)))); % Absolute worst-case gain
bit_growth_sym = ceil(log2(worst_case_gain_sym)) + 2; % Real growth of the integer part
acc_sym_FL = mult_sym_FL; % Fraction lengths for accumulators
acc_sym_IL = mult_sym_IL + bit_growth_sym; % Integer bit depth in bits, including the sign bit for accumulators
acc_sym_WL = acc_sym_IL + acc_sym_FL; % Word lengths for accumulators

out_FL = acc_FL; % Fraction lengths for output signal
out_WL = acc_WL; % Word lengths for output signal
out_IL = acc_IL; % Integer bit depth in bits, including the sign bit for output signal
out_sym_FL = acc_sym_FL; % Fraction lengths for output signal
out_sym_WL = acc_sym_WL; % Word lengths for output signal
out_sym_IL = acc_sym_IL; % Integer bit depth in bits, including the sign bit for output signal

%================================================================================
%% Output coefficients
%================================================================================
% Set the arithmetic property for FIR.
set(Hd, 'Arithmetic', 'fixed', ...
    'CoeffWordLength', coeff_WL, ...
    'CoeffAutoScale', false, ...
    'NumFracLength', coeff_FL, ...
    'Signed',         true, ...
    'InputWordLength', in_WL, ...
    'inputFracLength', in_FL, ...
    'FilterInternals',  'SpecifyPrecision', ...
    'OutputWordLength',  out_WL, ...
    'OutputFracLength',  out_FL, ...
    'ProductWordLength', mult_WL, ...
    'ProductFracLength', mult_FL, ...
    'AccumWordLength',   acc_WL, ...
    'AccumFracLength',   acc_FL, ...
    'RoundMode',         'convergent', ...
    'OverflowMode',      'Wrap');
denormalize(Hd);

b_out = Hd.Numerator(1:ceil(length(Hd.Numerator) / 2)); % Output coefficients
if ~isfi(b_out)
    b_out = fi(b_out, true, coeff_WL, coeff_FL);
end

[h_fix, ~] = freqz(double(Hd.Numerator), 1, 4096, F_s); % Frequency response of digital filter (Fixed-Point coefficients)

%================================================================================
%% Plotting magnitude response graphs
%================================================================================
figure;
plot(f/1e6, 20 * log10(abs(h_dbl)), 'b', 'LineWidth', 1.5);
hold on;
plot(f/1e6, 20 * log10(abs(h_fix)), 'r--', 'LineWidth', 1.2);
grid on;
set(gcf, 'WindowState', 'maximized');

title(sprintf('Magnitude Response (%s) | Order N = %d', filterType, N), 'FontSize', 12);
xlabel('Frequency (MHz)');
ylabel('Magnitude (dB)');
legend({'Double Precision', 'Fixed-Point'}, 'Location', 'northeast');
ylim([-100 5]);

%================================================================================
%% Stimulus signal generation
%================================================================================
f_sig = [Fpass/10 Fpass/2 Fpass Fpass * 2 Fpass * 2.5]; % Sin frequencies
N_sine = 500; % Number of Sine Samples
A = 0.9; % Amplitude
noise_std = 0.03; % Standart Deviation of Noise

noise = noise_std * randn(1, N_sine); % Noise signal

%================================================================================
%% Samples of different segments of sinusoids with noise
%================================================================================
t = (0:N_sine - 1) / F_s;
for i = 1:5
    sine_wave(i,:) = A * sin(2 * pi * f_sig(i) * t) + noise;
end

%================================================================================
%% Stimulus signal and writing its samples to a file
%================================================================================
sine_stimul = fi([sine_wave(1,:) sine_wave(2,:) sine_wave(3,:) sine_wave(4,:) sine_wave(5,:)], true, in_WL, in_FL);
write_file(out_file_stimul, sine_stimul, 'dec');

%================================================================================
%% Writing parameters for RTL
%================================================================================
fid = fopen('fir_params.vh', 'w');
fprintf(fid, 'localparam N_TAPS = %d;\n', N + 1); % Number of coefficients
fprintf(fid, 'localparam INPUT_WL = %d;\n', in_WL); % Input word length
fprintf(fid, 'localparam INPUT_FL = %d;\n', in_FL); % Input fraction length
fprintf(fid, 'localparam COEFF_WL = %d;\n', coeff_WL); % Coeffs word length
fprintf(fid, 'localparam COEFF_FL = %d;\n', coeff_FL); % Coeffs fraction length
fprintf(fid, 'localparam MULT_WL = %d;\n', mult_sym_WL); % Mults word length
fprintf(fid, 'localparam MULT_FL = %d;\n', mult_sym_FL); % Mults fraction length
fprintf(fid, 'localparam ACC_WL = %d;\n', acc_sym_WL); % Accumulators word length
fprintf(fid, 'localparam ACC_FL = %d;\n', acc_sym_FL); % Accumulators fraction length
fprintf(fid, 'localparam OUT_WL = %d;\n', out_sym_WL); % Output word length
fprintf(fid, 'localparam OUT_FL = %d;\n', out_sym_FL); % Output fraction length
fprintf(fid, 'localparam F_CLK = %d;\n', F_clk); % Clock frequency
fprintf(fid, 'localparam CLK_EN_DIV = %d;\n', F_clk/F_s); % Clock division factor for determining the clock enable frequency
fprintf(fid, 'localparam SIN_NUM_SAMPLES = %d;', length(sine_stimul)); % Number of stimulus signal samples
fclose(fid);
write_file(out_file_coeff, b_out', num_format);