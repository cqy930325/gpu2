//MATRIX MULTIPLICATION USING 1 FP MULTIPLY and 1 FP ADD UNIT (GENERATED BY XILINX COREGEN)
//Written by Ana Klimovic
//March 11, 2013

//counts up to parameter and then resets
module counter(
		input clk,
		input reset,
		input in_ready,			//assert this for one cycle when providing module with fresh input
		output done,			//this is asserted when counter reaches N (ie: added all the products for this element of matrix)
		output reg [2:0] count
		);

	parameter N = 4; 	//number of rows in matrix (number of additions required to generate one element of matrix result)
	//parameter log2N = 2;

	assign done = (count == N) ? 1'b1 : 1'b0;

	always @ (posedge clk)
	begin
		if (reset || done) //done???????????????????????????????????????? --> only want done on for 1 cycle!!!
			begin
				count <= 'b0;
			end
		else if (in_ready && !done) //don't keep adding if done
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
			done_matrix <= 1'b0;
			count <= 3'b0;
			end
		else if (new_element && count == 0)	
			begin
			element0 <= element_in;
			count <= count + 1'b1;
			done_matrix <= 1'b0;
			end
		else if (new_element && count == 1)	
			begin
			element1 <= element_in;
			count <= count + 1'b1;
			done_matrix <= 1'b0;
			end
		else if (new_element && count == 2)	
			begin
			element2 <= element_in;
			count <= count + 1'b1;
			done_matrix <= 1'b0;
			end
		else if (new_element && count == 3)	
			begin
			element3 <= element_in;
			count <= count + 1'b1;
			done_matrix <= 1'b1;
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
	wire [2:0] product_tuser;
	wire element_ready;

	wire add_b_tready, add_operation_tready, sum_tready, sum1_tvalid, sum2_tvalid, sum3_tvalid; 
	wire [2:0] count;
	wire [31:0] sum1_tdata, sum2_tdata, sum3_tdata;
	reg [31:0] prev_product;
	reg prev2_product_tvalid;
	//wire [31:0] sum1, sum2, sum3;
	reg prev_product_tvalid;

	assign product_tready = 1'b1;
	assign sum_tready = 1'b1;
	
	always @ (posedge clk) begin
		if (reset) 
			prev_product_tvalid <= 1'b0;
		else
			begin
			prev_product <= product_tdata;
			prev_product_tvalid <= product_tvalid;
			prev2_product_tvalid <= prev_product_tvalid;
		end
	end
	
	
	floating_point_v6_1 fmul (
	  .aclk(clk), // input aclk
	  .s_axis_a_tvalid(a_tvalid), // input s_axis_a_tvalid
	  .s_axis_a_tready(a_tready), // output s_axis_a_tready
	  .s_axis_a_tdata(a), // input [31 : 0] s_axis_a_tdata
	  .s_axis_b_tvalid(b_tvalid), // input s_axis_b_tvalid
	  .s_axis_b_tready(b_tready), // output s_axis_b_tready
	  .s_axis_b_tdata(b), // input [31 : 0] s_axis_b_tdata
	  .m_axis_result_tvalid(product_tvalid), // output m_axis_result_tvalid
	  .m_axis_result_tready(product_tready), // input m_axis_result_tready
	  .m_axis_result_tdata(product_tdata), // output [31 : 0] m_axis_result_tdata
	  .m_axis_result_tuser(product_tuser) // output [2 : 0] m_axis_result_tuser
	);

	

	floating_point_add_sub_v6_1 fadd1 (
	  .aclk(clk), // input aclk
	  .s_axis_a_tvalid(product_tvalid), // input s_axis_a_tvalid
	  .s_axis_a_tready(add_product_tready), // output s_axis_a_tready
	  .s_axis_a_tdata(product_tdata), // input [31 : 0] s_axis_a_tdata
	  .s_axis_b_tvalid(prev2_product_tvalid), // input s_axis_b_tvalid
	  .s_axis_b_tready(add_b_tready), // output s_axis_b_tready
	  .s_axis_b_tdata(prev_product), // input [31 : 0] s_axis_b_tdata
	  .s_axis_operation_tvalid(1'b1), // input s_axis_operation_tvalid
	  .s_axis_operation_tready(add_operation_tready), // output s_axis_operation_tready
	  .s_axis_operation_tdata(8'b0 /*ADD*/), // input [7 : 0] s_axis_operation_tdata
	  .m_axis_result_tvalid(sum1_tvalid), // output m_axis_result_tvalid
	  .m_axis_result_tready(sum_tready), // input m_axis_result_tready
	  .m_axis_result_tdata(sum1_tdata), // output [31 : 0] m_axis_result_tdata
	  .m_axis_result_tuser() // output [2 : 0] m_axis_result_tuser
	);
	

	floating_point_add_sub_v6_1 fadd2 (
	  .aclk(clk), // input aclk
	  .s_axis_a_tvalid(product_tvalid), // input s_axis_a_tvalid
	  .s_axis_a_tready(), // output s_axis_a_tready
	  .s_axis_a_tdata(product_tdata), // input [31 : 0] s_axis_a_tdata
	  .s_axis_b_tvalid(sum1_tvalid), // input s_axis_b_tvalid
	  .s_axis_b_tready(), // output s_axis_b_tready
	  .s_axis_b_tdata(sum1_tdata), // input [31 : 0] s_axis_b_tdata
	  .s_axis_operation_tvalid(1'b1), // input s_axis_operation_tvalid
	  .s_axis_operation_tready(add_operation_tready), // output s_axis_operation_tready
	  .s_axis_operation_tdata(8'b0 /*ADD*/), // input [7 : 0] s_axis_operation_tdata
	  .m_axis_result_tvalid(sum2_tvalid), // output m_axis_result_tvalid
	  .m_axis_result_tready(1'b1), // input m_axis_result_tready
	  .m_axis_result_tdata(sum2_tdata), // output [31 : 0] m_axis_result_tdata
	  .m_axis_result_tuser() // output [2 : 0] m_axis_result_tuser
	);

	floating_point_add_sub_v6_1 fadd3 (
	  .aclk(clk), // input aclk
	  .s_axis_a_tvalid(product_tvalid), // input s_axis_a_tvalid
	  .s_axis_a_tready(), // output s_axis_a_tready
	  .s_axis_a_tdata(product_tdata), // input [31 : 0] s_axis_a_tdata
	  .s_axis_b_tvalid(sum2_tvalid), // input s_axis_b_tvalid
	  .s_axis_b_tready(), // output s_axis_b_tready
	  .s_axis_b_tdata(sum2_tdata), // input [31 : 0] s_axis_b_tdata
	  .s_axis_operation_tvalid(1'b1), // input s_axis_operation_tvalid
	  .s_axis_operation_tready(add_operation_tready), // output s_axis_operation_tready
	  .s_axis_operation_tdata(8'b0 /*ADD*/), // input [7 : 0] s_axis_operation_tdata
	  .m_axis_result_tvalid(sum3_tvalid), // output m_axis_result_tvalid
	  .m_axis_result_tready(1'b1), // input m_axis_result_tready
	  .m_axis_result_tdata(sum3_tdata), // output [31 : 0] m_axis_result_tdata
	  .m_axis_result_tuser() // output [2 : 0] m_axis_result_tuser
	);


	//note: there might be an issue with one cycle delay of count to get to input mux of
	//fadd!!!!!!!!!!!!!---> check this in simulation!!!!!!!!!!!!!!!!!!!!!!	
	counter count_dot_product_elements(
		.clk(clk),
		.reset(reset),
		.in_ready(sum3_tvalid),//assert this for one cycle when providing module with fresh input
		.done(element_ready),
		.count(count)
		);

 	latch_matrixmult latch(
		.clk(clk),
		.reset(reset),
		.element_in(sum3_tdata),
		.new_element(element_ready),	//need to pulse for one cycle only
		.element0(result0),
		.element1(result1),
		.element2(result2),
		.element3(result3),
		.done_matrix(done_matrixmult)
		);

endmodule
