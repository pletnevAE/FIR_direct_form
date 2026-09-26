//=====================================================================================
// 		FIR Testbench Module
//
//			The module is used to feed the stimulus signal to the FIR SystemVerilog
//			module being verified. The module output signal are written to
//			separate file using the enable signal.
//
//=====================================================================================
`timescale 1 ns / 1 ps
`include "fir_params.vh"

module testbench;

//=====================================================================================
// Testbench parameters
//=====================================================================================
parameter N_COEFFS = N_TAPS; // Number of coefficients
parameter IN_WIDTH = INPUT_WL; // Input word length
parameter COEFF_WIDTH = COEFF_WL; // Coefficients word length
parameter MULT_WIDTH = MULT_WL; // Product word length
parameter MULT_FRACTION = MULT_FL; // Product fraction length
parameter ACC_WIDTH = ACC_WL; // Accumulator word length
parameter OUT_WIDTH = OUT_WL; // Output word length
parameter OUT_FRACTION = OUT_FL; // Output fraction length
parameter CLK_PERIOD = 1_000_000_000 / F_CLK; // Clock period
parameter CLK_ENABLE_DIV = CLK_EN_DIV; // Division factor for the clock enable
parameter RESET_CYCLES = 10; // Reset cycles
parameter NUM_SAMPLES = SIN_NUM_SAMPLES; // Number of stimulus samples

//=====================================================================================
// Testbench signals
//=====================================================================================	
logic clk; // Clock
logic rst_n; // Reset
logic valid_in; // Input data valid
logic signed [IN_WIDTH - 1:0] data_in; // Input data
logic valid_out; // Output data valid
logic signed [OUT_WIDTH - 1:0] data_out; // Output data

integer clk_cnt = 0; // Clock counter
integer stim_file; // Stimulus file descriptor
integer scanf_ret;
integer value; // Read sample
integer stim_values [$]; // Storage for Stimulus
integer out_file_fir; // Output file descriptor
integer sample_idx; // Storage index
integer sample_wr_cnt = 0; // Output write counter

//=====================================================================================
// FIR Instantiation
//=====================================================================================
FIR 
#(
	.N_COEFFS(N_COEFFS), 
	.IN_WIDTH(IN_WIDTH), 
	.COEFF_WIDTH(COEFF_WIDTH), 
	.MULT_WIDTH(MULT_WIDTH), 
	.MULT_FRACTION(MULT_FRACTION), 
	.ACC_WIDTH(ACC_WIDTH), 
	.OUT_WIDTH(OUT_WIDTH), 
	.OUT_FRACTION(OUT_FRACTION)) dut
(
	.clk(clk),
	.rst_n(rst_n),
	.valid_in(valid_in),
	.data_in(data_in),
	.valid_out(valid_out),
	.data_out(data_out)
);

//=====================================================================================
// Clock signal generation
//=====================================================================================
initial begin
	clk = 0;
	forever clk = #(CLK_PERIOD/2) ~clk;
end

//=====================================================================================
// Clock Enable signal generation
//=====================================================================================
initial begin
	clk_cnt = 0;
	forever begin
		@(posedge clk);
		if (CLK_ENABLE_DIV > 1) begin
			clk_cnt  = (clk_cnt >= CLK_ENABLE_DIV - 1) ? '0 : clk_cnt + 1'b1;
		end
		else begin
			clk_cnt = 0;
		end
	end
end

assign valid_in = (CLK_ENABLE_DIV == 1) ? 1'b1 : (CLK_ENABLE_DIV  > 1 && clk_cnt == 0);

initial begin
//=====================================================================================
// Reading from a file
//=====================================================================================
	stim_file = $fopen("stimulus.txt", "r");
	if (stim_file == 0) begin
		$display("ERROR");
		$stop;
	end
	
	while (!$feof(stim_file)) begin
		scanf_ret = $fscanf(stim_file, "%d\n", value);
		if (scanf_ret == 1) begin
			stim_values.push_back(value);
		end
	end
	$fclose(stim_file);
	
	$display("Loaded %0d samples from stimulus.txt", stim_values.size());
	
//=====================================================================================
// Opening output file
//=====================================================================================
	out_file_fir = $fopen("output_fir.txt", "w");
	if (out_file_fir == 0) begin
		$display("ERROR");
		$stop;
	end
	
//=====================================================================================
// Starting value of signals	
//=====================================================================================
	rst_n = 1'b0;
	data_in = {IN_WIDTH{1'b0}};
	sample_idx = 0;

//=====================================================================================
// Removing the reset	
//=====================================================================================
	repeat (RESET_CYCLES) @(posedge clk);
	#1;
	rst_n = 1'b1;
	
	while (sample_idx < stim_values.size()) begin
		if (valid_in) begin
			data_in = stim_values[sample_idx];
			sample_idx++;
		end
		@(posedge clk);
	end
	
	wait (sample_wr_cnt == stim_values.size());
	
	$display("Simulation finished.");
	$fclose(out_file_fir);
	$stop;
end

//=====================================================================================	
// Writing samples to a file
//=====================================================================================	
always @ (posedge clk) begin
	if (valid_out) begin
		$fwrite(out_file_fir, "%0d\n", data_out);
		sample_wr_cnt++;
	end
end

endmodule