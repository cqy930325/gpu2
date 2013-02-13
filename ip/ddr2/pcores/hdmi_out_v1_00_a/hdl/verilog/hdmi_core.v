/*
----------------------------------------------------------------------------
--	hdmi_core.v -- Hdmi Output Core
----------------------------------------------------------------------------
-- Author:  Bryce Long 
--          Translated from hdmi_out.vhd
----------------------------------------------------------------------------
--
----------------------------------------------------------------------------
--
--Sync Signal Register Definitions:
--
--    0     hsr           hbpr                hfpr         htr
--    | Sync |--------------|-------------------|------------
--    |------|  Back Porch  |   active video    | Front Porch
--	 														
----------------------------------------------------------------------------
*/
module hdmi_core (
    input clock,
    input start,
    input reset,
    input [10:0] hres,
    input [9:0] vres,
    input [31:0] color,
    output [7:0] red,
    output [7:0] green,
    output [7:0] blue,
    output hsync,
    output vsync,
    output ve,
    output read_go,
    output read_next_line,
    output read_next_chunk,
    output read_done
    );

reg [15:0] htr, hsr, hfpr, hbpr, vtr, vsr, vfpr, vbpr;
reg polarity;
reg [15:0] hcnt, vcnt;
wire hblank_i, vblank_i, active_video_i, hsync_i, vsync_i;
reg active_video_d2, active_video_d1, hsync_d2, hsync_d1, vsync_d2, vsync_d1;
reg [31:0] video_data_d1 ;

assign hsync_i = (hcnt < hsr) ? polarity : ~polarity;
assign vsync_i = (vcnt < vsr) ? polarity : ~polarity;
assign hblank_i = ((hcnt >= hbpr) && (hcnt < hfpr)) ? 1 : 0;
assign vblank_i = ((vcnt >= vbpr) && (vcnt < vfpr)) ? 1 : 0;
assign active_video_i = hblank_i && vblank_i;
assign red = video_data_d1[31:24];
assign green = video_data_d1[23:16];
assign blue = video_data_d1[15:8];
assign ve = active_video_d2;
assign hsync = hsync_d2;
assign vsync = vsync_d2;

wire pre_video_hsync;
wire video_hsync;
wire post_video_hsync;

assign pre_video_hsync = (hsync_i ^ ~polarity) && (vcnt == vbpr);
assign video_hsync = (hsync_i ^ ~polarity) && (vcnt > vbpr) & (vcnt < vfpr);
assign post_video_hsync = (hsync_i ^ ~polarity) && (vcnt == vfpr);
assign read_next_chunk = ((((hcnt - hbpr - 2) & 32'h3f) == 0)& ve);

pulse_gen #(3) pulse_gen_inst(
  .clk(clock),
  .sig_I({pre_video_hsync, video_hsync, post_video_hsync}),
  .toggle_O(),
  .posedge_O(),
  .negedge_O({read_go, read_next_line, read_done})
);

always @ (*)
begin
    case (hres)
        800:
        begin
            htr <= 1056;
            hsr <= 128;
            hfpr <= 1016;
            hbpr <= 216;
            vtr <= 628;
            vsr <= 4;
            vfpr <= 627;
            vbpr <= 27;
            polarity <= 0;
        end
        1280:
        begin
            htr <= 1650;
            hsr <= 40;
            hfpr <= 1540;
            hbpr <= 260;
            vtr <= 750;
            vsr <= 5;
            vfpr <= 745;
            vbpr <= 25;
            polarity <= 1;
        end
        default:
        begin
            htr <= 800;
            hsr <= 96;
            hfpr <= 792;
            hbpr <= 152;
            vtr <= 525;
            vsr <= 2;
            vfpr <= 523;
            vbpr <= 43;
            polarity <= 0;
        end
    endcase
end

always @ (posedge clock)
begin
    if (reset || !start)
    begin
        hsync_d2 <= 0;
        vsync_d2 <= 0;
        hsync_d1 <= 0;
        vsync_d1 <= 0;
        active_video_d2 <= 0;
        active_video_d1 <= 0;
        video_data_d1 <= 0;
        hcnt <= 0;
        vcnt <= 0;
    end
    else
    begin
        hsync_d2 <= hsync_d1;
        hsync_d1 <= hsync_i;
        vsync_d2 <= vsync_d1;
        vsync_d1 <= vsync_i;
        active_video_d2 <= active_video_d1;
        active_video_d1 <= active_video_i;
        video_data_d1 <= color;
        if (hcnt < htr)
            hcnt <= hcnt + 1;
        else
            begin
            hcnt <= 0;
            if (vcnt < vtr)
                vcnt <= vcnt + 1;
            else
                vcnt <= 0;
            end
    end
end

endmodule

