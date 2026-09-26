//=====================================================================================
// 		Reduction Adder Tree
//			
//			Parameters:
//				TAPS - number of terms
//				DATA_WIDTH - data width
//
//			Control Signals:
//				clk - clock signal
//				rst_n – reset (Active-Low)
//				clk_enable - clock enable signal
//
//			Data:
//				data_in - input data
//				data_out - output data
//				
//=====================================================================================
module reduction_adder_tree
#(
	parameter int TAPS = 16, // Number of terms
	parameter int DATA_WIDTH = 36 // Data width
)
(
	input clk, // Clock
	input rst_n, // Reset
	input clk_enable, // Clock Enable
	input logic signed [DATA_WIDTH - 1:0] data_in [0:TAPS - 1], // Input data
	output logic signed [DATA_WIDTH - 1:0] data_out // Output data
);

localparam int STAGES = $clog2(TAPS); // Number of stages of a adder tree

typedef logic signed [DATA_WIDTH - 1:0] stage_data_t [TAPS];
stage_data_t tree [0:STAGES]; // 2D array for storing intermediate values of the tree
genvar j, s, i;

//=====================================================================================
// Function for calculating nodes at each stage
//=====================================================================================
function automatic int get_stage_nodes(int stage);
	int nodes = TAPS;
	for (int s = 0; s < stage; s++) begin
		nodes = (nodes + 1) / 2;
	end
	return nodes;
endfunction

//=====================================================================================
// Assignment of zero-stage inputs
//=====================================================================================
generate
	for (j = 0; j < TAPS; j++) begin : g_input_map
		always_comb begin
			tree[0][j] = data_in[j];
		end
	end
endgenerate

//=====================================================================================
// Tree stage generation
//=====================================================================================
generate
	for (s = 0; s < STAGES; s++) begin : g_stages
		localparam int CURR_NODES = get_stage_nodes(s);
		localparam int NEXT_NODES = get_stage_nodes(s + 1);
//-------------------------------------------------------------------------------------
// Matching of elements		
		for (i = 0; i < CURR_NODES / 2; i++) begin : g_adders
			always_ff @ (posedge clk, negedge rst_n) begin
				if (!rst_n) begin
					tree[s + 1][i] <= {DATA_WIDTH{1'b0}};
				end
				else begin
					if (clk_enable) begin
						tree[s + 1][i] <= tree[s][2 * i] + tree[s][2 * i + 1];
					end
				end
			end
		end
//-------------------------------------------------------------------------------------		
// The odd element is pushed to the next stage
		if (CURR_NODES % 2 != 0) begin : g_odd_pass
			always_ff @ (posedge clk, negedge rst_n) begin
				if (!rst_n) begin
					tree[s + 1][NEXT_NODES - 1] <= {DATA_WIDTH{1'b0}};
				end
				else begin
					if (clk_enable) begin
						tree[s + 1][NEXT_NODES - 1] <= tree[s][CURR_NODES - 1];
					end
				end
			end
		end
	end
endgenerate

assign data_out = tree[STAGES][0];

endmodule