//MATRIX MULTIPLICATION USING 1 FP MULTIPLY and 2 FP ADD UNIT (GENERATED BY XILINX COREGEN)
//Note: This does a 4-element dot product, which is what matrix multiplication requires when the common matrix dimension is 4.
//Written by Ana Klimovic
//March 11, 2013

//toggle flip-flop
module tff(
		input clk,
		input reset,
		input t,
		output q
		);
	reg tff;

	always @ (posedge clk)
		if (reset)
			tff <= 1'b0;
		else if (t)
			tff <= ~tff;
		else
			tff <= tff;

	assign q = tff;
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
			count <= count;
			done_matrix <= 1'b0;
			end
	end


endmodule

//provide 2 inputs at a time and assert inputs_ready to start, then keep going
//computes a[i]*b[i]=c[i] when inputs are given, then then computes result = (c[0] + c[1]) + (c[2] + c[3])
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
	wire product_tvalid; 
	wire t_inner, t_outer;

	wire sum_inner_tvalid, sum_outer_tvalid;

	wire [31:0] sum_inner_tdata;
	wire [31:0] sum_outer_tdata;

	floating_point_v6_1 fmul (
	  .aclk(clk), // input aclk
	  .s_axis_a_tvalid(a_tvalid), // input s_axis_a_tvalid
	  .s_axis_a_tready(), // output s_axis_a_tready
	  .s_axis_a_tdata(a), // input [31 : 0] s_axis_a_tdata
	  .s_axis_b_tvalid(b_tvalid), // input s_axis_b_tvalid
	  .s_axis_b_tready(), // output s_axis_b_tready
	  .s_axis_b_tdata(b), // input [31 : 0] s_axis_b_tdata
	  .m_axis_result_tvalid(product_tvalid), // output m_axis_result_tvalid
	  .m_axis_result_tready(1'b1), // input m_axis_result_tready
	  .m_axis_result_tdata(product_tdata), // output [31 : 0] m_axis_result_tdata
	  .m_axis_result_tuser() // output [2 : 0] m_axis_result_tuser
	);

	floating_point_add_sub_v6_1 fadd_inner (
	  .aclk(clk), // input aclk
	  .s_axis_a_tvalid(product_tvalid & t_inner), // input s_axis_a_tvalid
	  .s_axis_a_tready(), // output s_axis_a_tready
	  .s_axis_a_tdata(product_tdata), // input [31 : 0] s_axis_a_tdata
	  .s_axis_b_tvalid(product_tvalid & ~t_inner), // input s_axis_b_tvalid
	  .s_axis_b_tready(), // output s_axis_b_tready
	  .s_axis_b_tdata(product_tdata), // input [31 : 0] s_axis_b_tdata
	  .s_axis_operation_tvalid(product_tvalid & t_inner), // input s_axis_operation_tvalid
	  .s_axis_operation_tready(), // output s_axis_operation_tready
	  .s_axis_operation_tdata(8'b0), // input [7 : 0] s_axis_operation_tdata
	  .m_axis_result_tvalid(sum_inner_tvalid), // output m_axis_result_tvalid
	  .m_axis_result_tready(1'b1), // input m_axis_result_tready
	  .m_axis_result_tdata(sum_inner_tdata), // output [31 : 0] m_axis_result_tdata
	  .m_axis_result_tuser() // output [2 : 0] m_axis_result_tuser
	);

	floating_point_add_sub_v6_1 fadd_outer (
	  .aclk(clk), // input aclk
	  .s_axis_a_tvalid(sum_inner_tvalid & t_outer), // input s_axis_a_tvalid
	  .s_axis_a_tready(), // output s_axis_a_tready
	  .s_axis_a_tdata(sum_inner_tdata), // input [31 : 0] s_axis_a_tdata
	  .s_axis_b_tvalid(sum_inner_tvalid & ~t_outer), // input s_axis_b_tvalid
	  .s_axis_b_tready(), // output s_axis_b_tready
	  .s_axis_b_tdata(sum_inner_tdata), // input [31 : 0] s_axis_b_tdata
	  .s_axis_operation_tvalid(sum_inner_tvalid & t_outer), // input s_axis_operation_tvalid
	  .s_axis_operation_tready(), // output s_axis_operation_tready
	  .s_axis_operation_tdata(8'b0), // input [7 : 0] s_axis_operation_tdata
	  .m_axis_result_tvalid(sum_outer_tvalid), // output m_axis_result_tvalid
	  .m_axis_result_tready(1'b1), // input m_axis_result_tready
	  .m_axis_result_tdata(sum_outer_tdata), // output [31 : 0] m_axis_result_tdata
	  .m_axis_result_tuser() // output [2 : 0] m_axis_result_tuser
	);

	tff tff_inner(
		.clk(clk),
		.reset(reset),
		.t(product_tvalid),
		.q(t_inner)
	);

	tff tff_outer(
		.clk(clk),
		.reset(reset),
		.t(sum_inner_tvalid),
		.q(t_outer)
	);

	latch_matrixmult latch(
		.clk(clk),
		.reset(reset),
		.element_in(sum_outer_tdata),
		.new_element(sum_outer_tvalid),	//need to pulse for one cycle only
		.element0(result0),
		.element1(result1),
		.element2(result2),
		.element3(result3),
		.done_matrix(done_matrixmult)
		);

endmodule
