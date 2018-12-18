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
		cpu_state_o  : out std_logic_vector(5 downto 0);  -- cpu sequencer state (defined in defs.v)
		cpu_we_o     : out std_logic;                     -- write enabled
		cpu_oe_o     : out std_logic;                     -- read enabled
		cpu_addr_o   : out std_logic_vector(15 downto 0); -- cpu address 16 bit
		cpu_data_i   : in std_logic_vector(7 downto 0);   -- cpu data input 8 bit
		cpu_data_o   : in std_logic_vector(7 downto 0);   -- cpu data output 8 bit
		
		debug_clk    : in std_logic;                      -- debug clock
		debug_data_o : out std_logic                      -- serial debug info, 64 bit shift register
	);
	end component MC6809_cpu;
	
	
-- The M6845 has 48 external signals; 16 inputs and 32 outputs.
	component MC6845 is
	port(

	-- CPU INTERFACE SIGNALS
		DI     : in std_logic_vector(7 downto 0);  -- Input Data bus input (8-bits)
		RNW    : in std_logic;                     -- Read not write, data transfer direction (1=read, 0=write)
		NCS    : in std_logic;                     -- Not chip select, enables CPU data transfer, active low
		RS     : in std_logic;                     -- Register select, when low the address register is selected, when high one of the 18 control registers is selected
		E      : in std_logic;                     -- Enable, used as a strobe signal in CPU read or write operations
		DR     : out std_logic_vector(7 downto 0); -- Data bus output (8-bits)
		NVDL   : out std_logic;                    -- Not valid data, can be used, in combination with DI0-7 & DR0-7, to generate a bidirectional data bus, active low

	-- CRT INTERFACE SIGNALS
		CLK    : in std_logic;                      -- Clock input, defines character timing
		HSYNC  : out std_logic;                     -- Horizontal synchronization, active high
		VSYNC  : out std_logic;                     -- Vertical synchronization, active high
		EDISP  : out std_logic;                     -- Enable display (DE) , defines the display period in horizontal and vertical raster scanning, active high
		MA     : out std_logic_vector(13 downto 0); -- Refresh memory address lines (16K max.)
		RA     : out std_logic_vector(4 downto 0);  -- Raster address lines
		ECURS  : out std_logic;                     -- Enable cursor, used to display the cursor, active high
		LPSTB  : in std_logic;                      -- Light pen strobe, on a low to high transition the refresh memory address is stored in the light pen register. Must be high for at least 1 period of CLK

	-- OTHER INTERFACE SIGNALS
		NRESET : in std_logic; -- Reset, when low the M6845 is reset after 3 clocks
		NTST   : in std_logic  -- Used during testing for fault cover improvement
		
	);
	end component MC6845;
	
	-- 
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
	
	-- Data Processor 
	signal dpu_addr   : std_logic_vector(15 downto 0);
	signal dpu_di     : std_logic_vector( 7 downto 0);
	signal dpu_do     : std_logic_vector( 7 downto 0);
	signal dpu_rw     : std_logic;
	signal dpu_irq    : std_logic;
	signal dpu_firq   : std_logic;
	signal dpu_we, dpu_oe : std_logic;
	signal dpu_state      : std_logic_vector(5 downto 0);
	
	-- Video Processor 
	signal vpu_addr   : std_logic_vector(15 downto 0);
	signal vpu_di     : std_logic_vector( 7 downto 0);
	signal vpu_do     : std_logic_vector( 7 downto 0);
	signal vpu_rw     : std_logic;
	signal vpu_irq    : std_logic;
	signal vpu_firq   : std_logic;
	signal vpu_we, vpu_oe : std_logic;
	signal vpu_state      : std_logic_vector(5 downto 0);
	
	
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
	
	-- TODO !!
	-- Bi-directional FIRQ capability
	-- To provide for immediate inter-system communication on demand 
	-- Bi-directional FIRQ Capability has been provided. Any access of 
	-- address $8C00 by the Video Processor will gewnerate a FIRQ to the 
	-- Data Processor. Any access of $8C01 by the Video Processor will 
	-- remove a FIRQ generated by the Data Processor to the Video 
	-- Processor. This is accomplished by U7, U8 and U9.
	
	-- Data Processor : MC6809 1.25MHz
	Data_Processor : MC6809_cpu
	port map(
		cpu_clk      => Clk_1250K, -- clock
		cpu_reset    => i_Reset,   -- reset
		cpu_nmi_n    => '0',       -- non-maskable interrupt
		cpu_irq_n    => dpu_irq,   -- interrupt request
		cpu_firq_n   => dpu_firq,  -- fast interrupt request
		cpu_state_o  => dpu_state, -- cpu sequencer state (defined in defs.v)
		cpu_we_o     => dpu_we,    -- write enabled
		cpu_oe_o     => dpu_oe,    -- read enabled
		cpu_addr_o   => dpu_addr,  -- cpu address 16 bit
		cpu_data_i   => dpu_di,    -- cpu data input 8 bit
		cpu_data_o   => dpu_do,    -- cpu data output 8 bit
		
		debug_clk    => '0',       -- debug clock
		debug_data_o => open       -- serial debug info, 64 bit shift register
	);
	
	-- Video Processor : MC6809 1.25MHz
	Video_Processor : MC6809_cpu
	port map(
		cpu_clk      => Clk_1250K, -- clock TODO !! VPU CLOCK 1/4 AFTER DPU
		cpu_reset    => i_Reset,   -- reset
		cpu_nmi_n    => '0',       -- non-maskable interrupt
		cpu_irq_n    => vpu_irq,   -- interrupt request
		cpu_firq_n   => vpu_firq,  -- fast interrupt request
		cpu_state_o  => vpu_state, -- cpu sequencer state (defined in defs.v)
		cpu_we_o     => vpu_we,    -- write enabled
		cpu_oe_o     => vpu_oe,    -- read enabled
		cpu_addr_o   => vpu_addr,  -- cpu address 16 bit
		cpu_data_i   => vpu_di,    -- cpu data input 8 bit
		cpu_data_o   => vpu_do,    -- cpu data output 8 bit
		
		debug_clk    => '0',       -- debug clock
		debug_data_o => open       -- serial debug info, 64 bit shift register
	);



end System;