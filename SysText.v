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
	input [63:0] i_debug,

	output reg o_ce_pixel,

	output reg [1:0] o_r,
	output reg [1:0] o_g,
	output reg [1:0] o_b
);

reg [2:0] col;
reg [3:0] row;
reg [7:0] ascii;
reg [63:0] number;
reg [11:0] h_count;
reg line;

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

	h_count <= 200 - i_v;
	col <= (h_count[2:0]) + 1;
	row <= i_h[3:0];
	number <= (i_debug >> (((h_count - 8) >> 3) << 2));
	ascii <= number[3:0] == 4'hA ? 8'h41 :
				number[3:0] == 4'hB ? 8'h42 :
				number[3:0] == 4'hC ? 8'h43 :
				number[3:0] == 4'hD ? 8'h44 :
				number[3:0] == 4'hE ? 8'h45 :
				number[3:0] == 4'hF ? 8'h46 :
				8'h30 + {4'h0, number[3:0]};
	line <= (h_count[7:0] == 8'h08) | (h_count[7:0] == 8'h48) | (h_count[7:0] == 8'h88) | (h_count[7:0] == 8'hC8)? 1 : 0;

	{o_r,o_g,o_b} <= pix ? pixcolor : line ? 6'b111111 : 6'b000001;
	o_ce_pixel <= pix;

end

endmodule
