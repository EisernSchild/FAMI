//------------------------------------------------------------------------------
//--
//--  Arcade: Taito - Taito Arcade Systems FPGA Configuration for Project MiSTer
//--  
//--  Copyright (C) 2018 Denis Reischl
//-- 
//--  Project MiSTer and related files (C) 2017,2018 Sorgelig 
//--
//--  EisernSchild/Arcade-Taito is licensed under the
//--  GNU General Public License v3.0
//--
//------------------------------------------------------------------------------

// Prefixes:
//	i_   Input signal 
//	o_   Output signal 
//	r_   Register signal (has registered logic) 
//	w_   Wire signal (has no registered logic) 
//	c_   Constant 
//	g_   Generic (VHDL only)
//	t_   User-Defined Type  
//	

module Analyzer
(
	input clk,
	input [11:0] i_h,
	input [11:0] i_v,

	output reg o_ce_pixel,

	output reg [1:0] o_r,
	output reg [1:0] o_g,
	output reg [1:0] o_b
);

reg [2:0] col;
reg [3:0] row;
reg [7:0] ascii;

wire pix;
wire [5:0] pixcolor = 6'b111100;

AnalyzerFont font
(
	.clk(clk),
	.col(col),
	.row(row),
	.ascii(ascii),
	
	.pixel(pix)
);


always @(posedge clk) begin

	col <= i_v[2:0];
	row <= i_h[3:0];
	ascii <= 8'h41;

	{o_r,o_g,o_b} <= pix ? pixcolor : 6'b000001;
	o_ce_pixel <= pix;

end

endmodule
