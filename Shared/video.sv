//------------------------------------------------------------------------------
//--
//--  FAMI - FPGA Arcade Machine Instauration
//--  
//--  Copyright (C) 2018 Denis Reischl
//-- 
//--  Project MiSTer and related files (C) 2017,2018 Sorgelig 
//--
//--  EisernSchild/FAMI is licensed under the
//--  GNU General Public License v3.0
//--
//------------------------------------------------------------------------------
//
// --------------------------------------------------------------------
// File <video.sv> is based upon file <vga_generator.v> from "HDMI_TX"
// DE10 nano example code
// Copyright (c) 2007 by Terasic Technologies Inc. 
// --------------------------------------------------------------------
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// --------------------------------------------------------------------
//           
//                     Terasic Technologies Inc
//                     356 Fu-Shin E. Rd Sec. 1. JhuBei City,
//                     HsinChu County, Taiwan
//                     302
//
//                     web: http://www.terasic.com/
//                     email: support@terasic.com
//
// --------------------------------------------------------------------

// define to use MiSTer video mixer (and debug output)
`define VIDEO_MIXER
`ifdef VIDEO_MIXER
reg  HBlank, VBlank, HSync, VSync;
`endif

module video
(                                    
  input						clk,                
  input						reset_n,
  
  input 			[3:0]		VGA_R4,
  input			[3:0]		VGA_G4,
  input			[3:0]		VGA_B4,
  
`ifdef LITE
  input			[63:0]   DEBUG_OUT0,
  input			[63:0]   DEBUG_OUT1,
  input			[63:0]   DEBUG_OUT2,
  input			[63:0]   DEBUG_OUT3,
  input			[63:0]   DEBUG_OUT4,
  input			[63:0]   DEBUG_OUT5,
  input			[63:0]   DEBUG_OUT6,
  input			[63:0]   DEBUG_OUT7,
`endif
  
  output reg            CE_PIXEL, 
  output	reg				VGA_HS,             
  output	reg				VGA_VS,           
  output	reg				VGA_DE,
  output	reg	[7:0]		VGA_R,
  output	reg	[7:0]		VGA_G,
  output	reg	[7:0]		VGA_B                                                 
);

//=======================================================
//   Mode selection
//=======================================================
wire [11:0] h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp; 

//-- video mode (256x256)
//--
//-- Horizontal : 
//-- Total time for each line       31.778	µs = 320
//-- Front porch               (A)   0.636	µs =   8
//-- Sync pulse length         (B)   3.813	µs =  40
//-- Back porch                (C)   1.907	µs =  16
//-- Active video              (D)	 25.422	µs = 256
//
//-- Vertical :
//-- Total time for each frame      16.683	ms = 288
//-- Front porch               (A)   0.318	ms =   8
//-- Sync pulse length         (B)   0.064	ms =   8 
//-- Back porch                (C)   1.048	ms =  16
//-- Active video              (D)  15.253	ms = 256

assign {h_display, h_fp, h_pulse, h_bp, v_display, v_fp, v_pulse, v_bp} = {12'd256,	12'd8, 12'd40, 12'd16, 12'd256, 12'd8, 12'd8, 12'd16}; 
	
//=======================================================
//   Assign timing constant  
//
//   h_total : total - 1
//   h_sync : sync - 1
//   h_start : sync + back porch - 1 - 2(delay)
//   h_end : h_start + active
//   v_total : total - 1
//   v_sync : sync - 1
//   v_start : sync + back porch - 1
//   v_end : v_start + active
//   v_active_14 : v_start + 1/4 active
//   v_active_24 : v_start + 2/4 active
//   v_active_34 : v_start + 3/4 active
//=======================================================
wire [11:0] h_total, h_sync, h_start, h_end; 
wire [11:0] v_total, v_sync, v_start, v_end; 
wire [11:0] v_active_14, v_active_24, v_active_34, v_active4;
assign h_total = h_display + h_fp + h_pulse + h_bp - 1;
assign h_sync = h_pulse - 1;
assign h_start = h_pulse + h_bp - 1 - 2;
assign h_end = h_display + h_pulse + h_bp - 1 - 2; 
assign v_total = v_display + v_fp + v_pulse + v_bp - 1;
assign v_sync = v_pulse - 1;
assign v_start = v_pulse + v_bp - 1;
assign v_end = v_display + v_pulse + v_bp - 1;
assign v_active_14 = v_pulse + v_bp - 1 + (v_display >> 2);
assign v_active_24 = v_pulse + v_bp - 1 + (v_display >> 1);
assign v_active_34 = v_pulse + v_bp - 1 + (v_display >> 2) + (v_display >> 1);

//=======================================================
//  Signal declarations
//=======================================================
reg	[11:0]	h_count;
reg	[7:0]		pixel_x;
reg	[11:0]	v_count;
wire  [11:0]   X, Y;
reg				h_act; 
reg				h_act_d;
reg				v_act; 
reg				v_act_d; 
reg				pre_vga_de;
wire				h_max, hs_end, hr_start, hr_end;
wire				v_max, vs_end, vr_start, vr_end;
wire				v_act_14, v_act_24, v_act_34;
reg				boarder;
reg	[3:0]		color_mode;
assign X = h_end - h_count;
assign Y = v_count - v_start;

//=======================================================
//  Structural coding
//=======================================================
assign h_max = h_count == h_total;
assign hs_end = h_count >= h_sync;
assign hr_start = h_count == h_start; 
assign hr_end = h_count == h_end;
assign v_max = v_count == v_total;
assign vs_end = v_count >= v_sync;
assign vr_start = v_count == v_start; 
assign vr_end = v_count == v_end;
assign v_act_14 = v_count == v_active_14; 
assign v_act_24 = v_count == v_active_24; 
assign v_act_34 = v_count == v_active_34;

//============= horizontal control signals
always @ (posedge clk or negedge reset_n)
	if (!reset_n)
	begin
		h_act_d	<=	1'b0;
		h_count	<=	12'b0;
		pixel_x	<=	8'b0;
`ifdef VIDEO_MIXER
`else
		VGA_HS	<=	1'b1;
`endif
		h_act		<=	1'b0;
	end
	else
	begin
		h_act_d	<=	h_act;

		if (h_max)
			h_count	<=	12'b0;
		else
			h_count	<=	h_count + 12'b1;

		if (h_act_d)
			pixel_x	<=	pixel_x + 8'b1;
		else
			pixel_x	<=	8'b0;

`ifdef VIDEO_MIXER
		if (hs_end && !h_max)
			HSync <=	1'b1;
		else
			HSync	<=	1'b0;
`else
		if (hs_end && !h_max)
			VGA_HS	<=	1'b1;
		else
			VGA_HS	<=	1'b0;
`endif

		if (hr_start)
			h_act		<=	1'b1;
		else if (hr_end)
			h_act		<=	1'b0;
	end

//============= vertical control signals
always@(posedge clk or negedge reset_n)
	if(!reset_n)
	begin
		v_act_d		<=	1'b0;
		v_count		<=	12'b0;
`ifdef VIDEO_MIXER
`else
		VGA_VS		<=	1'b1;
`endif
		v_act			<=	1'b0;
		color_mode	<=	4'b0;
	end
	else 
	begin		
		if (h_max)
		begin		  
			v_act_d	  <=	v_act;
		  
			if (v_max)
				v_count	<=	12'b0;
			else
				v_count	<=	v_count + 12'b000000000001;

`ifdef VIDEO_MIXER
			if (vs_end && !v_max)
				VSync	<=	1'b1;
			else
				VSync	<=	1'b0;
`else
			if (vs_end && !v_max)
				VGA_VS	<=	1'b1;
			else
				VGA_VS	<=	1'b0;
`endif

			if (vr_start)
				v_act <=	1'b1;
			else if (vr_end)
				v_act <=	1'b0;

			if (vr_start)
				color_mode[0] <=	1'b1;
			else if (v_act_14)
				color_mode[0] <=	1'b0;

			if (v_act_14)
				color_mode[1] <=	1'b1;
			else if (v_act_24)
				color_mode[1] <=	1'b0;
		    
			if (v_act_24)
				color_mode[2] <=	1'b1;
			else if (v_act_34)
				color_mode[2] <=	1'b0;
		    
			if (v_act_34)
				color_mode[3] <=	1'b1;
			else if (vr_end)
				color_mode[3] <=	1'b0;
		end
	end


//============= pixel mux
always @(posedge clk or negedge reset_n)
begin
	if (!reset_n)
	begin
`ifdef VIDEO_MIXER
`else
		VGA_DE		<=	1'b0;
		pre_vga_de	<=	1'b0;
		boarder		<=	1'b0;		
`endif	
	end
	else
	begin		
`ifdef VIDEO_MIXER
`else
		VGA_DE		<=	pre_vga_de;
		pre_vga_de	<=	v_act && h_act;
		
		if ((!h_act_d&&h_act) || hr_end || (!v_act_d&&v_act) || vr_end)
			boarder	<=	1'b1;
		else
			boarder	<=	1'b0;  

		if (boarder)
			{VGA_R, VGA_G, VGA_B} <= {8'hFF,8'hFF,8'hFF};
		else
		begin
			VGA_R <= {VGA_R4, VGA_R4};
			VGA_G <= {VGA_G4, VGA_G4};
			VGA_B <= {VGA_B4, VGA_B4};
		end			
`endif
	end
end

`ifdef LITE
reg	[1:0]	FR, FG, FB;
Analyzer Analyzer
(
	.clk(clk),
	.i_h(v_count),
	.i_v(h_count),
	
	.i_debug0(DEBUG_OUT0),
	.i_debug1(DEBUG_OUT1),
	.i_debug2(DEBUG_OUT2),
	.i_debug3(DEBUG_OUT3),
	.i_debug4(DEBUG_OUT4),
	.i_debug5(DEBUG_OUT5),
	.i_debug6(DEBUG_OUT6),
	.i_debug7(DEBUG_OUT7),

	.o_r(FR),
	.o_g(FG),
	.o_b(FB)
);

reg	[7:0]	DR, DG, DB;
assign DR = {FR,VGA_R4,FR};
assign DG = {FG,VGA_G4,FG};
assign DB = {FB,VGA_B4,FB};


`ifdef VIDEO_MIXER
assign HBlank = !h_act;
assign VBlank = !v_act;
video_mixer #(.LINE_LENGTH(320), .HALF_DEPTH(0)) video_mixer
(
	.*,
	.clk_sys(clk),
	.ce_pix(1),
	.ce_pix_out(CE_PIXEL),

	.scanlines(2'h00),
	.hq2x(0),
	.scandoubler(0),
	.mono(0),

	.R(DR),
	.G(DG),
	.B(DB)
);
`endif
`else
`ifdef VIDEO_MIXER
assign HBlank = !h_act;
assign VBlank = !v_act;
video_mixer #(.LINE_LENGTH(320), .HALF_DEPTH(0)) video_mixer
(
	.*,
	.clk_sys(clk),
	.ce_pix(1),
	.ce_pix_out(CE_PIXEL),

	.scanlines(2'h00),
	.hq2x(0),
	.scandoubler(0),
	.mono(0),

	.R({VGA_R4, VGA_R4}),
	.G({VGA_G4, VGA_G4}),
	.B({VGA_B4, VGA_B4})
);
`endif
`endif

endmodule