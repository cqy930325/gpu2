module dvi_stimulate (
	input clock,
	input reset,
	input start,
	output reg [7:0] red,
	output reg [7:0] blue,
	output reg [7:0] green,
	output reg hsync,
	output reg vsync
);

/*
* States:
	* hsync. if vcounter == video height, output vsync too. reset.
	* send video data until hcounter = video width
	*/

localparam RESET = 2'b00, HSYNC = 2'b01, ACTIVE = 2'b10, DONE = 2'b11; 
localparam WIDTH = 1280, HEIGHT = 720;

reg [1:0] state, nextstate;
reg [10:0] hcounter, nexthcounter;
reg [9:0] vcounter, nextvcounter;
reg nexthsync, nextvsync;
reg [7:0] nextred, nextgreen, nextblue;

always @ (posedge clock)
begin
	if (reset)
	begin
		state <= RESET;
		hsync <= 0;
		vsync <= 0;
		red <= 0;
		green <= 0;
		blue <= 0;
		hcounter <= 0;
		vcounter <= 0;
	end
        else
	begin
		state <= nextstate;
		hsync <= nexthsync;
		vsync <= nextvsync;
		red <= nexctred;
		green <= nextgreen;
		blue <= nextblue;
		hcounter <= nexthcounter;
		vcounter <= nextvcounter;
	end
end

always @ (*)
begin
	nextstate = state;
	nexthsync = hsync;
	nextvsync = vsync;
	nextred = red;
	nextblue = blue;
	nextgreen = green;
		case (state)
			RESET:
			begin
				if (start)
				begin
					nextstate = HSYNC;
					nexthsync = 1'b1;
				end
			end
			HSYNC:
			begin
				if (vcounter == HEIGHT)
				begin
					nextstate = DONE;
					nextvsync = 1;
				end
				else
				begin
					nextred = 8'b00000000;
					nextblue = 8'b11111111;
					nexthcounter = counter + 1;
					nextstate = ACTIVE;
				end
			end
			ACTIVE:
			begin
				nextred = 8'b11111111;
				if (hcounter == WIDTH)
				begin
					nexthcounter = 0;
					nexthsync = 1;
					nextvcounter = vcounter + 1;
					nextstate = HSYNC;
				end
			end
			DONE:
			begin
				//do nothing until reset
			end
		endcase
end

endmodule
