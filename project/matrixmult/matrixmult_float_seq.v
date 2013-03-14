//MATRIX MULTIPLICATION USING 1 FP MULTIPLY and 1 FP ADD UNIT (GENERATED BY XILINX COREGEN)
//Written by Ana Klimovic
//March 11, 2013

//counts up to parameter and then resets
module counter(
		input clk,
		input reset,
		input in_ready,			//assert this for one cycle when providing module with fresh input
		output done,			//this is asserted when counter reaches N (ie: added all the products for this element of matrix)
		output reg [3:0] count
		);

	parameter N = 4; 	//number of rows in matrix (number of additions required to generate one element of matrix result)
	//parameter log2N = 2;

	assign done = (count == N-1 && in_ready);

	always @ (posedge clk)
	begin
		if (reset || done) //done???????????????????????????????????????? --> only want done on for 1 cycle!!!
			begin
				count <= 'b0;
			end
		else if (in_ready)
			begin
				count <= count + 1'b1;
			end
	end
endmodule

//latch matrix result elements and count up to 4 (then you have all elements of result matrix ready)
module latch_matrixmult(
		input clk,
		input reset,
		input [31:0] element_in,
		input new_element,	//need to pulse for one cycle only
		output reg [31:0] element0,
		output reg [31:0] element1,
		output reg [31:0] element2,
		output reg [31:0] element3,
		output reg done_matrix

	);

	reg [2:0] count;

	always @ (posedge clk)
	begin
		if (reset)
			begin 
			element0 <= 32'b0;
			element1 <= 32'b0;
			element2 <= 32'b0;
			element3 <= 32'b0;
			count <= 3'b0;
			done_matrix <= 1'b0;
			end
		else if (new_element && count == 0)	
			begin
			element0 <= element_in;
			element1 <= element1;
			element2 <= element2;
			element3 <= element3;
			count <= count + 1'b1;
			done_matrix <= 1'b0;
			end
		else if (new_element && count == 1)	
			begin
			element0 <= element0;
			element1 <= element_in;
			element2 <= element2;
			element3 <= element3;
			count <= count + 1'b1;
			done_matrix <= 1'b0;
			end
		else if (new_element && count == 2)	
			begin
			element0 <= element0;
			element1 <= element1;
			element2 <= element_in;
			element3 <= element3;
			count <= count + 1'b1;
			done_matrix <= 1'b0;
			end
		else if (new_element && count == 3)	
			begin
			element0 <= element0;
			element1 <= element1;
			element2 <= element2;
			element3 <= element_in;
			count <= 3'b0;
			done_matrix <= 1'b1;
			end
		else
			begin
			element0 <= element0;
			element1 <= element1;
			element2 <= element2;
			element3 <= element3;
			count <= 3'b0;
			done_matrix <= 1'b0;
			end
	end


endmodule

//provide 2 inputs at a time and assert inputs_ready to start, then keep going
module matrixmultiplier (
		input clk,
		input reset,
		input a_tvalid,
		input b_tvalid,
		input [31:0] a,
		input [31:0] b,
		output [31:0] result0,
		output [31:0] result1,
		output [31:0] result2,
		output [31:0] result3,
		output done_matrixmult
		);


	wire [31:0] product_tdata;
	wire product_tready;
	wire product_tvalid; 
	wire [2:0] product_tuser, sum_tuser;
	wire element_ready;

	wire add1_operation_tready, sum_tready, sum_tvalid;
	wire a_tready, b_tready, a1_tready,b1_tready;
	wire [3:0] element_count, run_count;
	wire runcount_tvalid;

	wire [31:0] sum_tdata;
	reg [31:0] prev_product;


		
	floating_point_v6_1 fmul (
	  .aclk(clk), // input aclk
	  .s_axis_a_tvalid(a_tvalid), // input s_axis_a_tvalid
	  .s_axis_a_tready(a_tready), // output s_axis_a_tready
	  .s_axis_a_tdata(a), // input [31 : 0] s_axis_a_tdata
	  .s_axis_b_tvalid(b_tvalid), // input s_axis_b_tvalid
	  .s_axis_b_tready(b_tready), // output s_axis_b_tready
	  .s_axis_b_tdata(b), // input [31 : 0] s_axis_b_tdata
	  .m_axis_result_tvalid(product_tvalid), // output m_axis_result_tvalid
	  .m_axis_result_tready(a1_tready && b1_tready), // input m_axis_result_tready
	  .m_axis_result_tdata(product_tdata), // output [31 : 0] m_axis_result_tdata
	  .m_axis_result_tuser(product_tuser) // output [2 : 0] m_axis_result_tuser
	);

	floating_point_add_sub_v6_1 fadd1 (
	  .aclk(clk), // input aclk
	  .s_axis_a_tvalid(product_tvalid), // input s_axis_a_tvalid
	  .s_axis_a_tready(a1_tready), // output s_axis_a_tready
	  .s_axis_a_tdata(product_tdata), // input [31 : 0] s_axis_a_tdata
	  .s_axis_b_tvalid(product_tvalid), // input s_axis_b_tvalid
	  .s_axis_b_tready(b1_tready), // output s_axis_b_tready
	  .s_axis_b_tdata((element_count == 0) ? 32'b0 : sum_tdata ), // input [31 : 0] s_axis_b_tdata
	  .s_axis_operation_tvalid(product_tvalid), // input s_axis_operation_tvalid
	  .s_axis_operation_tready(add1_operation_tready), // output s_axis_operation_tready
	  .s_axis_operation_tdata(8'b0), // input [7 : 0] s_axis_operation_tdata
	  .m_axis_result_tvalid(sum_tvalid), // output m_axis_result_tvalid
	  .m_axis_result_tready(1'b1), // input m_axis_result_tready
	  .m_axis_result_tdata(sum_tdata), // output [31 : 0] m_axis_result_tdata
	  .m_axis_result_tuser(sum_tuser) // output [2 : 0] m_axis_result_tuser
	);

	counter #(.N(4)) element_counter(
		.clk(clk),
		.reset(reset),
		.in_ready(sum_tvalid),
		.done(element_ready),
		.count(element_count)
	);


	latch_matrixmult latch(
		.clk(clk),
		.reset(reset),
		.element_in(sum_tdata),
		.new_element(element_ready),	//need to pulse for one cycle only
		.element0(result0),
		.element1(result1),
		.element2(result2),
		.element3(result3),
		.done_matrix(done_matrixmult)
		);

endmodule
