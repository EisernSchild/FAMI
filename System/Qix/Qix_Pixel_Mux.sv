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

module pixel_mux
(
	input            clk_vid,
	input      [7:0] i_Pixel,

	output reg [3:0] o_R,
	output reg [3:0] o_G,
	output reg [3:0] o_B
);


always @(posedge clk_vid) begin

	{o_R, o_G, o_B} <= {i_Pixel[7:4],i_Pixel[7:4],i_Pixel[3:0]};

//		case(mix)
//			0,
//			1: {R_out, G_out, B_out} <= {R_in,     G_in,     B_in      }; // color
//			2: {       G_out       } <= {          px[15:8]            }; // green
//			3: {R_out, G_out       } <= {px[15:8], px[15:8] - px[15:10]}; // amber
//			4: {       G_out, B_out} <= {          px[15:8], px[15:8]  }; // cyan
//			5: {R_out, G_out, B_out} <= {px[15:8], px[15:8], px[15:8]  }; // gray
//		endcase
//
//		HSync_out  <= HSync_in;
//		VSync_out  <= VSync_in;
//		HBlank_out <= HBlank_in;
//		VBlank_out <= VBlank_in;

end

endmodule