//=====================================================================================
// 		Direct Form FIR
//
//			Parameters:
//				N_COEFFS - number of coefficients
//				IN_WIDTH - input word length
//				COEFF_WIDTH - coefficients word length
//				MULT_WIDTH - product word length
//				MULT_FRACTION - product fraction length
//				ACC_WIDTH - accumulator word length
//				OUT_WIDTH - output word length
//				OUT_FRACTION - output fraction length
//
//			Control Signals:
//				clk - clock signal
//				rst_n – reset (Active-Low)
//				valid_in - input data valid
//				valid_out - output data valid
//
//			Data:
//				data_in - input data
//				data_out - output data
//=====================================================================================
`include "fir_params.vh"

module FIR
#(
	parameter N_COEFFS = N_TAPS, // Number of coefficients
	parameter IN_WIDTH = INPUT_WL, // Input word length
	parameter COEFF_WIDTH = COEFF_WL, // Coefficients word length
	parameter MULT_WIDTH = MULT_WL, // Product word length
	parameter MULT_FRACTION = MULT_FL, // Product fraction length
	parameter ACC_WIDTH = ACC_WL, // Accumulator word length
	parameter OUT_WIDTH = OUT_WL, // Output word length
	parameter OUT_FRACTION = OUT_FL // Output fraction length
)
(
	input clk, // Clock
	input rst_n, // Reset
	input valid_in, // Input data valid
	input signed [IN_WIDTH - 1:0] data_in, // Input data
	output logic valid_out, // Output data valid
	output logic signed [OUT_WIDTH - 1:0] data_out // Output data
);

localparam PREADD_WIDTH = IN_WIDTH + 1; // Preadder word length
localparam bit IS_ODD = (N_COEFFS % 2 != 0); // Odd taps or even taps
localparam NUM_UNIQUE_COEFFS = (N_COEFFS + 1) / 2; // Number of unique coefficients
localparam DROP_BITS = MULT_FRACTION - OUT_FRACTION; // Truncation of the fractional part
localparam STAGES = $clog2(NUM_UNIQUE_COEFFS); // Number of stages of a adder tree
localparam TOTAL_LATENCY = 4 + STAGES; // Total pipeline delay

logic signed [COEFF_WIDTH - 1:0] h [0:NUM_UNIQUE_COEFFS - 1]; // Coefficients
logic [TOTAL_LATENCY - 1:0] valid_pipe; // Pipeline for valid signal
logic signed [PREADD_WIDTH - 1:0] preadd_reg [0:NUM_UNIQUE_COEFFS - 1]; // Preadders registers
logic signed [IN_WIDTH - 1:0] shift_reg [0:N_COEFFS - 1]; // Tap delay line
(* multstyle = "dsp" *) logic signed [MULT_WIDTH - 1:0] mult_reg [0:NUM_UNIQUE_COEFFS - 1]; // Multipliers registers
logic signed [ACC_WIDTH - 1:0] mult_ext [0:NUM_UNIQUE_COEFFS - 1]; // Results of multiplication with sign extension
logic signed [ACC_WIDTH - 1:0] acc_sum; // Output of the adder tree

genvar i;

//=====================================================================================
// Pipelined Reduction Adder Tree
//=====================================================================================
reduction_adder_tree #(.TAPS(NUM_UNIQUE_COEFFS), .DATA_WIDTH(ACC_WIDTH)) u_adder_tree
(
	.clk(clk),
	.rst_n(rst_n),
	.clk_enable(valid_in),
	.data_in(mult_ext),
	.data_out(acc_sum)
);

//=====================================================================================
// Initialization of Coefficients
//=====================================================================================
initial begin
	$readmemh("fir_coeffs.txt", h);
end

//=====================================================================================
// Tap Delay Line
//=====================================================================================
always_ff @ (posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		for (int i = 0; i < N_COEFFS; i++) begin
			shift_reg[i] <= {IN_WIDTH{1'b0}};
		end
	end
	else begin
		if (valid_in) begin
			shift_reg[0] <= data_in;
			for (int i = 1; i < N_COEFFS; i++) begin
				shift_reg[i] <= shift_reg[i - 1];
			end
		end
	end
end


//=====================================================================================
// Preadder
//=====================================================================================
generate
	for (i = 0; i < NUM_UNIQUE_COEFFS; i++) begin : g_preadd
//-------------------------------------------------------------------------------------
// The central coefficient for an odd number does not add up
		if (IS_ODD && (i == NUM_UNIQUE_COEFFS - 1)) begin	: g_middle_tap
			always_ff @ (posedge clk, negedge rst_n) begin
				if (!rst_n) begin
					preadd_reg[i] <= {PREADD_WIDTH{1'b0}};
				end
				else begin
					if (valid_in) begin
						preadd_reg[i] <= $signed({shift_reg[i][IN_WIDTH - 1], shift_reg[i]});
					end
				end
			end
		end
//-------------------------------------------------------------------------------------
// Symmetrical elements add up
		else begin : g_symmetric_taps
			always_ff @ (posedge clk, negedge rst_n) begin
				if (!rst_n) begin
					preadd_reg[i] <= {PREADD_WIDTH{1'b0}};
				end
				else begin
					if (valid_in) begin
						preadd_reg[i] <= $signed(shift_reg[i]) + $signed(shift_reg[N_COEFFS - 1 - i]);
					end
				end
			end
		end
	end
endgenerate

//=====================================================================================
// Multipliers with output registers
//=====================================================================================
always_ff @ (posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		for (int i = 0; i < NUM_UNIQUE_COEFFS; i++) begin
			mult_reg[i] <= {MULT_WIDTH{1'b0}};
		end 
	end
	else begin
		if (valid_in) begin
			for (int i = 0; i < NUM_UNIQUE_COEFFS; i++) begin
				mult_reg[i] <= preadd_reg[i] * h[i];
			end
		end
	end
end

//=====================================================================================
// Sign extension before feeding into the adder tree
//=====================================================================================
always_comb begin
	for (int i = 0; i < NUM_UNIQUE_COEFFS; i++) begin
		mult_ext[i] = $signed(mult_reg[i]);
	end
end

//=====================================================================================
// Output register with MSB cutoff
//=====================================================================================
always_ff @ (posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		data_out <= {OUT_WIDTH{1'b0}};
	end
	else begin
		if (valid_pipe[TOTAL_LATENCY - 2]) begin
			data_out <= acc_sum[DROP_BITS + OUT_WIDTH - 1:DROP_BITS];
		end
	end
end

//=====================================================================================
// Output valid delay and syncronization with valid_in
//=====================================================================================
always_ff @ (posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		valid_pipe <= {TOTAL_LATENCY{1'b0}};
	end
	else begin
		if (valid_in) begin
			valid_pipe <= {valid_pipe[TOTAL_LATENCY - 2:0], 1'b1};
		end
	end
end

assign valid_out = valid_in & valid_pipe[TOTAL_LATENCY - 1];

endmodule