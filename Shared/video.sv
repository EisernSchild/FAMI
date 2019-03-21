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

  input                 HBlank,
  input                 VBlank,
  input                 HSync,
  input                 VSync,
  
  output reg            CE_PIXEL, 
  output	reg				VGA_HS,             
  output	reg				VGA_VS,           
  output	reg				VGA_DE,
  output	reg	[7:0]		VGA_R,
  output	reg	[7:0]		VGA_G,
  output	reg	[7:0]		VGA_B                                                 
);

video_mixer #(.LINE_LENGTH(320), .HALF_DEPTH(0)) video_mixer
(
	.*,
	.clk_sys(clk),
	.ce_pix(1),
	.ce_pix_out(CE_PIXEL),

	.scanlines(2'h01),
	.hq2x(0),
	.scandoubler(0),
	.mono(0),

	.R({VGA_R4, VGA_R4}),
	.G({VGA_G4, VGA_G4}),
	.B({VGA_B4, VGA_B4})
);

endmodule