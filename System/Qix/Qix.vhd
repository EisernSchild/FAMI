------------------------------------------------------------------------------
--
--  Arcade: Taito - Taito Arcade Systems FPGA Configuration for Project MiSTer
--  
--  Copyright (C) 2018 Denis Reischl
-- 
--  Project MiSTer and related files (C) 2017,2018 Sorgelig
--
--  Taito Qix Arcade System Configuration
--  File <Qix.vhd> (c) 2018 by Denis Reischl
--
--  EisernSchild/Arcade-Taito is licensed under the
--  GNU General Public License v3.0
--
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.ALL;

entity Qix is port
(
	i_Clk_20M : in std_logic; -- input clock 20 mhz
	i_Reset : in std_logic -- reset when 1
      
);
end Qix;

architecture System of Qix is

-- "M6809/rtl/verilog/MC6809_cpu.v" module definition in VHDL
	component MC6809_cpu is
	port (
		cpu_clk      : in std_logic;                      -- clock
		cpu_reset    : in std_logic;                      -- reset
		cpu_nmi_n    : in std_logic;                      -- non-maskable interrupt
		cpu_irq_n    : in std_logic;                      -- interrupt request
		cpu_firq_n   : in std_logic;                      -- fast interrupt request
		cpu_state_o  : out std_logic_vector(5 downto 0);  -- cpu state flags ?
		cpu_we_o     : out std_logic;                     --
		cpu_oe_o     : out std_logic;                     --
		cpu_addr_o   : out std_logic_vector(15 downto 0); -- cpu address 16 bit
		cpu_data_i   : in std_logic_vector(7 downto 0);   -- cpu data input 8 bit
		cpu_data_o   : in std_logic_vector(7 downto 0);   -- cpu data output 8 bit
		
		debug_clk    : in std_logic;                      -- debug clock
		debug_data_o : out std_logic                      -- serial debug info, 64 bit shift register

	);
	end component MC6809_cpu;
		
	--     Qix clocks : 
	--           _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   
	--      10M / \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \__
	--           ___     ___     ___     ___     ___     ___     ___     ___   __
	--       5M /   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \_/ 
	--               _______         _______         _______         _______ 
	--     2.5M ____/       \_______/       \_______/       \_______/       \____
	--          ____________                 _______________                 ____
	--    1.25M             \_______________/               \_______________/    
	--          ____________ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _
	--     cclk _ _ _ _ _ _ \_____________________________
	--           _______________                 _______________                  
	--    (DE)Q /               \_______________/               \_______________/
	--               _______________                 _______________                  
	--       QX ____/               \_______________/               \____________
	--                   _______________                 _______________        
	--        E ________/               \_______________/               \________
	--                           _______________                 _______________                  
	--    Q_INV \_______________/               \_______________/               \
	--          ________                 _______________                 ________     
	--(DQ)E_INV         \_______________/               \_______________/        
	--               ___________________             ___________________
	--      VEQ ____/                   \___________/                   \________
	--           _______         _______         _______         _______ 
	--  RSZ_INV /       \_______/       \_______/       \_______/       \_______/
	--             _______         _______         _______         _______ 
	--  MUX_INV __/       \_______/       \_______/       \_______/       \______
	--          __         _______         _______         _______         ______
	--      MUX   \_______/       \_______/       \_______/       \_______/
	--             ________        ________        ________        ________ 
	--  RAS_INV __/        \______/        \______/        \______/        \_____
	--                   ___             ___             ___             ___
	--  CAS_INV ________/   \___________/   \___________/   \___________/   \____
	
	constant Khz_5000 : std_logic_vector(15 downto 0):= "0101010101010101";
	constant Khz_2500 : std_logic_vector(15 downto 0):= "0110011001100110";
	constant Khz_1250 : std_logic_vector(15 downto 0):= "0111100001111000";
	constant FRQ_Q    : std_logic_vector(15 downto 0):= "0000111100001111";
	constant FRQ_QX   : std_logic_vector(15 downto 0):= "0001111000011110";
	constant FRQ_E    : std_logic_vector(15 downto 0):= "0011110000111100";
	constant FRQ_MUX  : std_logic_vector(15 downto 0):= "0011001100110011";
	constant FRQ_RSZ  : std_logic_vector(15 downto 0):= "0011001100110011";
	
	signal Clk_10M : std_logic := '0'; -- 10Mhz
	signal Clk_5M : std_logic; -- 5Mhz
	signal Clk_2500K : std_logic; -- 2.5Mhz
	signal Clk_1250K : std_logic; -- 2 x M6809 @ 1.25Mhz (& All but Qix/Qix2 have a M68705 @ 1Mhz as well) 
	signal Clk_9216K : std_logic; -- Sound CPU : M6802 @ 921.6 Khz
	signal Clk_C : std_logic; -- composite clock
	signal Clk_DE, Clk_Qx, Clk_E, Clk_Q_Inv, Clk_DQ : std_logic;
	signal VEQ, RSZ, RSZ_INV, MUX, MUX_INV, RAS_INV, CAS_INV : std_logic;
	
	signal Ctr_FRQ : integer range 0 to 15 := 0; -- frequency counter
	
	
begin
	
	-- generate 10Mhz clock
	generate_Clk10 : process(i_Clk_20M, i_Reset)
	begin
		if i_Reset = '1' then
			Clk_10M  <= '0';
		elsif rising_edge(i_Clk_20M) then
			Clk_10M <= not Clk_10M;
		end if;
	end process generate_Clk10;
	
	-- generate base clocks
	generate_Clks : process(Clk_10M, i_Reset)
	begin
		if i_Reset = '1' then
			Ctr_FRQ  <= 0;
		elsif rising_edge(Clk_10M) then
			Ctr_FRQ <= Ctr_FRQ + 1;
			
			Clk_5M <= Khz_5000(Ctr_FRQ);
			Clk_2500K <= Khz_2500(Ctr_FRQ); 
			Clk_1250K <= Khz_1250(Ctr_FRQ);
		
			Clk_DE <= FRQ_Q(Ctr_FRQ);
			Clk_QX <= FRQ_QX(Ctr_FRQ);
			Clk_E <= FRQ_E(Ctr_FRQ);
			RSZ <= FRQ_RSZ(Ctr_FRQ);
			
		else
		
			MUX <= FRQ_RSZ(Ctr_FRQ);
		
		end if;
	end process generate_Clks;
	
	-- assign inverse clocks
	Clk_Q_INV <= not Clk_DE;
	Clk_DQ <= not Clk_E;
	RSZ_INV <= not RSZ;
	MUX_INV <= not MUX;	



end System;