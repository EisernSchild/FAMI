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

entity Qix is
generic 
(
	-- generic RAM integer constants
	constant nGenRamDataWidth      : integer := 8;     -- generic RAM 8 bit data width
	constant nGenRamAddrWidthDual  : integer := 10;    -- generic RAM dual address width
	constant nGenRamAddrWidthDPU	 : integer := 13;    -- generic RAM DPU address width
	constant nGenRamADDrWidthVPU	 : integer := 13;    -- generic RAM VPU address width
	constant nGenRamADDrWidthVideo : integer := 16;    -- generic RAM Video address width
	constant nGenRamADDrWidthSPU	 : integer := 7;     -- generic RAM SPU address width
	
	-- latch address constants
	constant nFirq             : std_logic_vector(15 downto 0) := X"8C00"; -- FIRQ true (both VPU and DPU)
	constant nFirqAck          : std_logic_vector(15 downto 0) := X"8C01"; -- FIRQ true (both VPU and DPU)
	constant nVideoAddrLatch   : std_logic_vector(15 downto 0) := X"9400"; -- video address latch
	constant nVideoAddrLatchHi : std_logic_vector(15 downto 0) := X"9402"; -- video address latch hi
	constant nVideoAddrLatchLo : std_logic_vector(15 downto 0) := X"9403"; -- video address latch lo
	constant nScanlineReadback : std_logic_vector(15 downto 0) := X"9800"; -- Scanline readback address
	constant nCrtcLatch0       : std_logic_vector(15 downto 0) := X"9C00"; -- CRTC latch 0
	constant nCrtcLatch1       : std_logic_vector(15 downto 0) := X"9C01"  -- CRTC latch 1
	
);
port
(
	i_Clk_20M   : in std_logic; -- input clock 20 Mhz
	i_Clk_0921K : in std_logic; -- input clock 0.9216 MHz -- Sound CPU : M6802 @ 921.6 Khz
	i_Reset     : in std_logic; -- reset when 1
	
	o_VGA_R4 : out std_logic_vector(3 downto 0); -- Red Color 4Bits
	o_VGA_G4 : out std_logic_vector(3 downto 0); -- Green Color 4Bits
	o_VGA_B4 : out std_logic_vector(3 downto 0)  -- Blue Color 4Bits
      
);
end Qix;

architecture System of Qix is

-- Motorola 6809 CPU
component mc6809 is
port 
(
	D        : in std_logic_vector(7 downto 0);   -- cpu data input 8 bit
	DOut     : out std_logic_vector(7 downto 0);  -- cpu data output 8 bit
	ADDR     : out std_logic_vector(15 downto 0); -- cpu address 16 bit
	RnW      : out std_logic;                     -- read enabled
	E        : out std_logic;                     -- output clock E
	Q        : out std_logic;                     -- output clock Q
	BS       : out	std_logic;                     -- bus status
	BA       : out std_logic;                     -- bus available
	nIRQ     : in std_logic;                      -- interrupt request
	nFIRQ    : in std_logic;                      -- fast interrupt request
	nNMI     : in std_logic;                      -- non-maskable interrupt
	EXTAL    : in std_logic;                      -- input oscillator
	XTAL     : in std_logic;                      -- input oscillator
	nHALT    : in std_logic; 							 -- not halt - causes the MPU to stop running
	nRESET   : in std_logic;                      -- not reset
	MRDY     : in std_logic;                      -- strech E and Q
	nDMABREQ : in std_logic;                      -- suspend execution
	RegData  : out std_logic_vector(111 downto 0) -- register data (debug)
);
end component mc6809;
	
-- The M6845 has 48 external signals; 16 inputs and 32 outputs.
	component crtc6845 is 
	port(
	-- CRT INTERFACE SIGNALS
		MA     : out STD_LOGIC_VECTOR (9 downto 0);    -- Refresh memory address lines (16K max.)
		RA     : out STD_LOGIC_VECTOR (2 downto 0);    -- Raster address lines
		HSYNC  : out STD_LOGIC;                        -- Horizontal synchronization, active high
		VSYNC  : out STD_LOGIC;                        -- Vertical synchronization, active high
		DE     : out STD_LOGIC;                        -- Enable display (DE) , defines the display period in horizontal and vertical raster scanning, active high
		CURSOR : out STD_LOGIC;                        -- Enable cursor, used to display the cursor, active high
		LPSTBn : in STD_LOGIC;                         -- Light pen strobe, on a low to high transition the refresh memory address is stored in the light pen register. Must be high for at least 1 period of CLK
		
	-- CPU INTERFACE SIGNALS
		E      : in STD_LOGIC;                         -- Enable, used as a strobe signal in CPU read or write operations
		RS     : in STD_LOGIC;                         -- Register select, when low the address register is selected, when high one of the 18 control registers is selected
		CSn    : in STD_LOGIC;                         -- Not chip select, enables CPU data transfer, active low
		RW     : in STD_LOGIC;                         -- Read not write, data transfer direction (1=read, 0=write)
		DI     : in STD_LOGIC_VECTOR (7 downto 0);     -- Data bus input (8-bits)
		DO     : out STD_LOGIC_VECTOR (7 downto 0);    -- Data bus output (8-bits)
		
	-- OTHER INTERFACE SIGNALS
		RESETn : in STD_LOGIC;                         -- Reset, when low the M6845 is reset after 3 clocks
		CLK    : in STD_LOGIC;                         -- Clock input, defines character timing
		
	-- ADDITIONAL SIGNALS
		REG_INIT: in STD_LOGIC;
		Hend: inout STD_LOGIC;
		HS: inout STD_LOGIC;
		CHROW_CLK: inout STD_LOGIC;
		Vend: inout STD_LOGIC;
		SLadj: inout STD_LOGIC;
		H: inout STD_LOGIC;
		V: inout STD_LOGIC;
		CURSOR_ACTIVE: inout STD_LOGIC;
		VERT_RST: inout STD_LOGIC
	 );
	end component crtc6845;
	
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
	
	signal Clk_10M : std_logic := '0'; -- 10Mhz
	signal Clk_5M : std_logic; -- 5Mhz
	signal Clk_2500K : std_logic; -- 2.5Mhz
	signal Clk_1250K : std_logic; -- 2 x M6809 @ 1.25Mhz (& All but Qix/Qix2 have a M68705 @ 1Mhz as well) 
	signal Clk_Q_vpu, Clk_E_vpu, Clk_Q_dpu, Clk_E_dpu : std_logic;
	
	signal Ctr_FRQ : integer range 0 to 15 := 0; -- frequency counter
	
	-- Data Processor 
	signal dpu_clock      : std_logic;
	signal dpu_addr       : std_logic_vector(15 downto 0);
	signal dpu_di         : std_logic_vector( 7 downto 0);
	signal dpu_do         : std_logic_vector( 7 downto 0);
	signal dpu_rw         : std_logic;
	signal dpu_irq        : std_logic;
	signal dpu_firq       : std_logic := '1';
	signal dpu_we, dpu_oe : std_logic;
	signal dpu_state      : std_logic_vector( 5 downto 0);
	signal dpu_bs, dpu_ba : std_logic;
	
	-- Video Processor
	signal vpu_clock      : std_logic;
	signal vpu_addr       : std_logic_vector(15 downto 0);
	signal vpu_di         : std_logic_vector( 7 downto 0);
	signal vpu_do         : std_logic_vector( 7 downto 0);
	signal vpu_rw         : std_logic;
	signal vpu_irq        : std_logic;
	signal vpu_firq       : std_logic := '1';
	signal vpu_we, vpu_oe : std_logic;
	signal vpu_state      : std_logic_vector( 5 downto 0);
	signal vpu_bs, vpu_ba : std_logic;
	
	-- Sound Processor
	signal spu_clock  : std_logic;
	signal spu_addr   : std_logic_vector(15 downto 0);
	signal spu_di     : std_logic_vector( 7 downto 0);
	signal spu_do     : std_logic_vector( 7 downto 0);
	signal spu_rw     : std_logic;
	signal spu_irq    : std_logic;
	
	-- Data Processor Memory Signals
	signal dpu_wram_addr  : std_logic_vector(12 downto 0);
	signal dpu_wram_we    : std_logic;
	signal dpu_wram_do    : std_logic_vector( 7 downto 0);
	signal dpu_rom_addr   : std_logic_vector(10 downto 0);
	
	-- Video Processor Memory Signals
	signal vpu_wram_addr        : std_logic_vector(12 downto 0);
	signal vpu_wram_we          : std_logic;
	signal vpu_wram_do          : std_logic_vector( 7 downto 0);
	signal vpu_wram_video_addr  : std_logic_vector(15 downto 0);
	signal vpu_wram_video_we    : std_logic;
	signal vpu_wram_video_do    : std_logic_vector( 7 downto 0);
	signal vpu_rom_addr         : std_logic_vector(10 downto 0);
		
	-- Sound Processor Memory Signals
	signal spu_wram_addr  : std_logic_vector(13 downto 0);
	signal spu_wram_we    : std_logic;
	signal spu_wram_do    : std_logic_vector( 7 downto 0);
	signal spu_rom_addr   : std_logic_vector(10 downto 0);
		
	-- dual RAM (Data+Video) Memory Signals
	signal dual_clock_w    : std_logic;
	signal dual_clock_r    : std_logic;
	signal dual_wram_di_a  : std_logic_vector( 7 downto 0);
	signal dual_wram_di_b  : std_logic_vector( 7 downto 0);
	signal dual_wram_addr_a: std_logic_vector( 9 downto 0);
	signal dual_wram_addr_b: std_logic_vector( 9 downto 0);
	signal dual_wram_we    : std_logic;
	signal dual_wram_do_a  : std_logic_vector( 7 downto 0);
	signal dual_wram_do_b  : std_logic_vector( 7 downto 0);
	signal dual_wren_a     : std_logic;
	signal dual_wren_b     : std_logic;
	
	-- Video control signals
	signal video_page           : std_logic;                     -- 0 : Page 0 | 1 : Page 1
	signal video_addr_latched   : std_logic_vector(15 downto 0); -- latched by $9C02 (hi) + $9C01 (lo)
	signal video_pixel		    : std_logic_vector( 7 downto 0);
	signal video_addr_crtc      : std_logic_vector(15 downto 0);
				
	-- CRTC    
	signal Clk_CRTC : std_logic;              
	signal DI : std_logic_vector(7 downto 0);  
	signal DO : std_logic_vector(7 downto 0);
	signal VSYNC : std_logic;
	signal HSYNC : std_logic;
	signal DE : std_logic;
	signal MA : std_logic_vector(9 downto 0);
	signal RA : std_logic_vector(2 downto 0);
	signal CURSOR :  STD_LOGIC;
	signal LPSTBn :  STD_LOGIC;
	signal E      :  STD_LOGIC;
	signal RS     :  STD_LOGIC;
	signal CSn    :  STD_LOGIC;
	signal RW     :  STD_LOGIC;
	signal REG_INIT: STD_LOGIC; -- used for initial crtc register setting
	
	-- PROM buses
	type   prom_buses_array is array (0 to 27) of std_logic_vector(7 downto 0);
	signal prom_buses : prom_buses_array;
	
	-- LED'S and Color RAM Page
	type leds_array is array (0 to 5) of std_logic;
	signal leds : leds_array;
	signal color_ram_page : std_logic_vector(1 downto 0);
	
	-- debug
	type debug_array is array (7 downto 0) of std_logic_vector(15 downto 0);
	type debug_array_1 is array (7 downto 0) of std_logic;
	signal debug_dpu : debug_array;
	signal debug_vpu : debug_array;
	signal debug_dpu_we : debug_array_1;
	signal debug_vpu_we : debug_array_1;
		
begin

	----------------------------------------------------------------------------------------------------------
	-- Clocks
	----------------------------------------------------------------------------------------------------------
	
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
		end if;
	end process generate_Clks;
	
	-- assign processor clocks
	dpu_clock <= Clk_E_dpu;
	vpu_clock <= Clk_E_vpu;
	spu_clock <= i_Clk_0921K;
	dual_clock_w <= vpu_clock when vpu_we = '1' else dpu_clock;
	dual_clock_r <= dpu_clock when vpu_we = '1' else vpu_clock;
	dual_wram_addr_a   <= vpu_addr(9 downto 0) when vpu_we = '1' else dpu_addr(9 downto 0);
	dual_wram_addr_b   <= dpu_addr(9 downto 0) when vpu_we = '1' else vpu_addr(9 downto 0);
	dual_wram_di_a     <= vpu_do               when vpu_we = '1' else dpu_do;
	dual_wram_di_b     <= dpu_do               when vpu_we = '1' else vpu_do;
	
	-- create clock Clk_CRTC :
	-- All timing  in  the  CRTC  is  derived from the  ClK  input.  In
	-- alphanumeric terminals, this signal  is  the character rate. The
	-- video rate or  "dot"  clock  is  externally divided by high-speed
	-- logic  (TTL)  to generate the  ClK  input.
	--
	-- Character clock : (MAME source code <qix.h>)
	-- #define MAIN_CLOCK_OSC          20000000    /* 20 MHz */
	-- #define QIX_CHARACTER_CLOCK     (20000000/2/16)
	--
	-- create clock using 10 MHz clock :
	process (Clk_10M)
		variable counter : std_logic_vector(3 downto 0) := "0000";
		variable E_counter : integer := 0; 
	begin
		if rising_edge(Clk_10M) then
		
			-- create clock
			counter := counter + 1;
			if (counter = "0001") then Clk_CRTC <= '1'; else Clk_CRTC <= '0'; end if;
			
			-- manually init CRTC using E and REG_INIT
			E_counter := E_counter +1;
			if ((E_counter > 10) and (E_counter < 30)) then E <= '1';
			elsif ((E_counter > 50) and (E_counter < 70)) then E <= '0';
			else E <= '1'; end if;
			
		end if;		 
	end process;
	REG_INIT <= '1';
	
	----------------------------------------------------------------------------------------------------------
	-- Components
	----------------------------------------------------------------------------------------------------------
	
	-- Bi-directional FIRQ capability
	-- To provide for immediate inter-system communication on demand 
	-- Bi-directional FIRQ Capability has been provided. Any access of 
	-- address $8C00 by the Video Processor will gewnerate a FIRQ to the 
	-- Data Processor. Any access of $8C01 by the Video Processor will 
	-- remove a FIRQ generated by the Data Processor to the Video 
	-- Processor. This is accomplished by U7, U8 and U9.
	dpu_firq <= '1' when vpu_addr = nFirq and vpu_we = '1' else
					'0' when dpu_addr = nFirqAck and dpu_we = '1';
	vpu_firq <= '1' when dpu_addr = nFirq and dpu_we = '1' else
					'0' when vpu_addr = nFirqAck and vpu_we = '1';
	dpu_irq  <= '1';
	vpu_irq  <= '1';
	
	-- Data Processor : MC6809 1.25MHz
	dpu_we <= not dpu_oe;
	Data_Processor : mc6809
	port map
	(
		D        => dpu_di,      -- cpu data input 8 bit
		DOut     => dpu_do,      -- cpu data output 8 bit
		ADDR     => dpu_addr,    -- cpu address 16 bit
		RnW      => dpu_oe,      -- write enabled
		E        => Clk_E_dpu,   -- output clock E
		Q        => Clk_Q_dpu,   -- output clock Q
		BS       => dpu_bs,      -- bus status
		BA       => dpu_ba,      -- bus available
		nIRQ     => dpu_irq,     -- interrupt request
		nFIRQ    => dpu_firq,    -- fast interrupt request
		nNMI     => '1',         -- non-maskable interrupt
		EXTAL    => Clk_5M,      -- input oscillator
		XTAL     => '0',         -- input oscillator
		nHALT    => '1',         -- not halt - causes the MPU to stop running
		nRESET   => not i_Reset, -- not reset
		MRDY     => '1',         -- strech E and Q
		nDMABREQ => '1',         -- suspend execution
		RegData  => open         -- register data (debug)
	);

	-- Video Processor : MC6809 1.25MHz
	vpu_we <= not vpu_oe;
	Video_Processor : mc6809
	port map
	(
		D        => vpu_di,      -- cpu data input 8 bit
		DOut     => vpu_do,      -- cpu data output 8 bit
		ADDR     => vpu_addr,    -- cpu address 16 bit
		RnW      => vpu_oe,      -- write enabled
		E        => Clk_E_vpu,   -- output clock E
		Q        => Clk_Q_vpu,   -- output clock Q
		BS       => vpu_bs,      -- bus status
		BA       => vpu_ba,      -- bus available
		nIRQ     => vpu_irq,     -- interrupt request
		nFIRQ    => vpu_firq,    -- fast interrupt request
		nNMI     => '1',         -- non-maskable interrupt
		EXTAL    => not Clk_5M,  -- input oscillator
		XTAL     => '0',         -- input oscillator
		nHALT    => '1',         -- not halt - causes the MPU to stop running
		nRESET   => not i_Reset, -- not reset
		MRDY     => '1',         -- strech E and Q
		nDMABREQ => '1',         -- suspend execution
		RegData  => open         -- register data (debug)
	);
	
	-- Sound Processor : MC6802
	Sound_Processor : entity work.cpu68
	port map(	
		clk      => spu_clock,-- E clock input (falling edge)
		rst      => i_Reset,  -- reset input (active high)
		rw       => spu_rw,   -- read not write output
		vma      => open,     -- valid memory address (active high)
		address  => spu_addr, -- address bus output
		data_in  => spu_di,   -- data bus input
		data_out => spu_do,   -- data bus output
		hold     => '0',      -- hold input (active high) extend bus cycle
		halt     => '0',      -- halt input (active high) grants DMA
		irq      => spu_irq,  -- interrupt request input (active high)
		nmi      => '0',      -- non maskable interrupt request input (active high)
		test_alu => open,
		test_cc  => open
	);
	
	-- CRTC : MC6845
	crtc6845i : crtc6845
	port map 
	(
		MA  => MA,
		RA  => RA,
		HSYNC  => HSYNC,
		VSYNC  => VSYNC,
		DE => DE,
		CURSOR => CURSOR,
		LPSTBn => LPSTBn,
		E => E,
		RS => RS,
		CSn => CSn,
		RW => RW,
		DI => DI,
		DO => DO,
		RESETn => not i_Reset,
		CLK => Clk_CRTC,
		
		-- not standard
		REG_INIT => REG_INIT,
		
		-- unused, additional signals
		Hend => open,
		HS => open,
		CHROW_CLK => open,
		Vend => open,
		SLadj => open,
		H => open,
		V => open,
		CURSOR_ACTIVE => open,
		VERT_RST => open
	);
	
	-- TODO !! PIAs !!
	
	----------------------------------------------------------------------------------------------------------
	-- Memory Mapping
	----------------------------------------------------------------------------------------------------------
	
	-- DATA/SOUND MEMORY MAP
	--
	-- Address                  Dir Data     Name        Description
	-- ------------------------ --- -------- ----------- -----------------------
	-- $8000 - 100000xxxxxxxxxx R/W xxxxxxxx DS0         dual port RAM (shared with video cpu)
	-- $8400 - 100001xxxxxxxxxx R/W xxxxxxxx             local RAM
	-- $8800 - 100010---------x R/W xxxxxxxx DS2         6850 ACIA [1]
	-- $8C00 - 100011---------0 R/W -------- DS3         assert FIRQ on video CPU
	-- $8C01 - 100011---------1 R/W -------- DS3         FIRQ acknowledge
	-- $9000 - 100100--------xx R/W xxxxxxxx DS4/U20     6821 PIA (sound control / data IRQ)
	-- $9400 - 100101--------xx R/W xxxxxxxx DS5/U11     6821 PIA (coin / player 1 inputs)
	-- $9900 - 100110-1------xx R/W xxxxxxxx DS6/U20     6821 PIA (spare / player 2 inputs)
	-- $9800 - 100110xxxxxxxx-- R/W ----xxxx DS6/U24     PAL 16R4 (purpose unclear)
	-- $9C00 - 100111--------xx R/W xxxxxxxx DS7/U30     6821 PIA (player 2 inputs / coin control)
	-- $A000 - 101xxxxxxxxxxxxx R   xxxxxxxx             program ROM
	-- $C000 - 11xxxxxxxxxxxxxx R   xxxxxxxx             program ROM : Qix : U12 - U19
	
	-- $8000 - $8400 : dual port RAM (shared with video cpu)
	Dual_RAM : work.dpram generic map (nGenRamADDrWidthDual, nGenRamDataWidth)
	port map
	(
		clock_a   => dual_clock_w, -- dpu_clock,
		wren_a    => dual_wren_a,
		address_a => dual_wram_addr_a,
		data_a    => dual_wram_di_a,
		q_a       => dual_wram_do_a,

		clock_b   => dual_clock_r, --vpu_clock,
		-- wren_b    => dual_wren_b,    -- = '0' !!!!
		address_b => dual_wram_addr_b,
		-- data_b    => dual_wram_di_b, -- no input here !!!!
		q_b       => dual_wram_do_b
	);
	
	-- $8000 - $9FFF : data control memory ($8000-$8400 = dual port RAM -> shared with video CPU)
	DPU_RAM : work.dpram generic map (nGenRamADDrWidthDPU, nGenRamDataWidth)
	port map
	(
		clock_a   => dpu_clock,
		wren_a    => dpu_wram_we,
		address_a => dpu_wram_addr,
		data_a    => dpu_do,
		q_a       => dpu_wram_do,
		
		clock_b   => '0',
		address_b => (others => '0'),
		enable_b  => '0',
		q_b       => open
	);
	
	-- VIDEO BOARD MEMORY MAP
	--
	-- Address                  Dir Data     Name        Description
	-- ------------------------ --- -------- ----------- -----------------------
	-- $0000 - 0xxxxxxxxxxxxxxx R/W xxxxxxxx             direct video RAM access
	-- $8000 - 100000xxxxxxxxxx R/W xxxxxxxx VS0         dual port RAM (shared with data CPU)
	-- $8400 - 100001xxxxxxxxxx R/W xxxxxxxx VS1         CMOS NVRAM
	-- $8800 - 100010----------   W xxxxxx-- VS2         self test LEDs      [1]
	-- $8800 - 100010----------   W ------xx VS2         palette bank select [1]
	-- $8C00 - 100011---------0 R/W -------- VS3         assert FIRQ on data CPU
	-- $8C01 - 100011---------1 R/W -------- VS3         FIRQ acknowledge
	-- $9000 - 100100xxxxxxxxxx R/W xxxxxxxx VS4         palette RAM (RRGGBBII)
	-- $9400 - 100101--------00 R/W xxxxxxxx VS5         video RAM access at latched address
	-- $9401 - 100101--------01 R/W xxxxxxxx             video RAM access mask [2]
	-- $9402 - 100101--------1x   W xxxxxxxx VS5         video RAM address latch
	-- $9800 - 100110---------- R   xxxxxxxx VS6         current scanline readback location
	-- $9C00 - 100111---------x R/W xxxxxxxx VS7         68A45 video controller
	-- $C000 - 11xxxxxxxxxxxxxx R   xxxxxxxx             program ROMs
	
	-- $0000 - $7FFF : direct video RAM access - Page 0 $0000-$7FFF / Page 1 $8000-$FFFF
	Video_RAM : work.dpram generic map (nGenRamADDrWidthVideo, nGenRamDataWidth)
	port map
	(
		clock_a   => vpu_clock,
		wren_a    => vpu_wram_video_we,
		address_a => vpu_wram_video_addr,
		data_a    => vpu_do,
		q_a       => vpu_wram_video_do,

		clock_b   => i_Clk_20M,
		address_b => video_addr_crtc,
		q_b       => video_pixel
	);
	
	-- $8000 - $9FFF : video control memory ($8000-$8400 = dual port RAM -> shared with data CPU)
	VPU_RAM : work.dpram generic map (nGenRamADDrWidthVPU, nGenRamDataWidth)
	port map
	(
		clock_a   => vpu_clock,
		wren_a    => vpu_wram_we,
		address_a => vpu_wram_addr,
		data_a    => vpu_do,
		q_a       => vpu_wram_do,
		
		clock_b   => '0',
		address_b => (others => '0'),
		enable_b  => '0',
		q_b       => open
	);

	-- Audio CPU:
	--
	-- Address          Dir Data     Name        Description
	-- ---------------- --- -------- ----------- -----------------------
	-- $0000 - 000000000xxxxxxx R/W xxxxxxxx             6802 internal RAM
	-- $0000 - 0-1-----------xx R/W xxxxxxxx U7          6821 PIA (TMS5200 control) - Not used by any game
	-- $0000 - 01------------xx R/W xxxxxxxx U8          6821 PIA (DAC, communication with data CPU)
	-- $0000 - 1100------------                          n.c.
	-- $0000 - 1101xxxxxxxxxxxx R   xxxxxxxx U25         program ROM
	-- $0000 - 1110xxxxxxxxxxxx R   xxxxxxxx U26         program ROM
	-- $0000 - 1111xxxxxxxxxxxx R   xxxxxxxx U27         program ROM - Qix
	
	-- $0000 - $007F : 6802 internal RAM
--	process(spu_clock)
--	begin
--		if rising_edge(spu_clock) then
--			if spu_wram_we = '1' then
--				RAM_spu(to_integer(unsigned(spu_wram_addr))) <= spu_do;
--			end if;
--			spu_wram_do <= RAM_spu(to_integer(unsigned(spu_wram_addr)));
--		end if;
--	end process;
	
	--	Data Processor ROM Region -> U12-U19 PROM
	PROM_U12 : entity work.prom_u12 port map (CLK => dpu_clock, ADDR => dpu_rom_addr, DATA => prom_buses(12));
	PROM_U13 : entity work.prom_u13 port map (CLK => dpu_clock, ADDR => dpu_rom_addr, DATA => prom_buses(13));
	PROM_U14 : entity work.prom_u14 port map (CLK => dpu_clock, ADDR => dpu_rom_addr, DATA => prom_buses(14));
	PROM_U15 : entity work.prom_u15 port map (CLK => dpu_clock, ADDR => dpu_rom_addr, DATA => prom_buses(15));
	PROM_U16 : entity work.prom_u16 port map (CLK => dpu_clock, ADDR => dpu_rom_addr, DATA => prom_buses(16));
	PROM_U17 : entity work.prom_u17 port map (CLK => dpu_clock, ADDR => dpu_rom_addr, DATA => prom_buses(17));
	PROM_U18 : entity work.prom_u18 port map (CLK => dpu_clock, ADDR => dpu_rom_addr, DATA => prom_buses(18));
	PROM_U19 : entity work.prom_u19 port map (CLK => dpu_clock, ADDR => dpu_rom_addr, DATA => prom_buses(19));
	
	--	Video Processor ROM Region -> U4-U10 PROM
	PROM_U4  : entity work.prom_u4  port map (CLK => vpu_clock, ADDR => vpu_rom_addr, DATA => prom_buses( 4));
	PROM_U5  : entity work.prom_u5  port map (CLK => vpu_clock, ADDR => vpu_rom_addr, DATA => prom_buses( 5));
	PROM_U6  : entity work.prom_u6  port map (CLK => vpu_clock, ADDR => vpu_rom_addr, DATA => prom_buses( 6));
	PROM_U7  : entity work.prom_u7  port map (CLK => vpu_clock, ADDR => vpu_rom_addr, DATA => prom_buses( 7));
	PROM_U8  : entity work.prom_u8  port map (CLK => vpu_clock, ADDR => vpu_rom_addr, DATA => prom_buses( 8));
	PROM_U9  : entity work.prom_u9  port map (CLK => vpu_clock, ADDR => vpu_rom_addr, DATA => prom_buses( 9));
	PROM_U10 : entity work.prom_u10 port map (CLK => vpu_clock, ADDR => vpu_rom_addr, DATA => prom_buses(10));
	
	--	Sound Processor ROM Region -> U27 PROM
	PROM_U27 : entity work.prom_u27 port map (CLK => spu_clock, ADDR => spu_rom_addr, DATA => prom_buses(27));
	
	----------------------------------------------------------------------------------------------------------
	-- Data Processor i/o control
	----------------------------------------------------------------------------------------------------------
	
	-- mux cpu in data between roms/io/wram
	dpu_di <= -- X"00" when dpu_oe = '0' else -- ?
		X"FF" when (dpu_addr = X"8C00" or dpu_addr = X"8C01") and dpu_we = '0' else
		prom_buses(19) when dpu_addr(15 downto 8) >= X"F8" else
		prom_buses(18) when dpu_addr(15 downto 8) >= X"F0" else
		prom_buses(17) when dpu_addr(15 downto 8) >= X"E8" else
		prom_buses(16) when dpu_addr(15 downto 8) >= X"E0" else
		prom_buses(15) when dpu_addr(15 downto 8) >= X"D8" else
		prom_buses(14) when dpu_addr(15 downto 8) >= X"D0" else
		prom_buses(13) when dpu_addr(15 downto 8) >= X"C8" else
		prom_buses(12) when dpu_addr(15 downto 8) >= X"C0" else		
		dpu_wram_do    when dpu_addr(15 downto 8) >= X"84" else
		dual_wram_do_a when dpu_addr(15 downto 10) = "100000" and vpu_we = '0' else
		dual_wram_do_b when dpu_addr(15 downto 10) = "100000"	else X"00";
		
	-- assign cpu in/out data addresses
	dpu_rom_addr  <= dpu_addr(10 downto 0) when dpu_addr(15 downto 12) >= X"A" else "000" & X"00";
	dpu_wram_addr <= dpu_addr(12 downto 0) when ((dpu_addr(15 downto 12) >= X"8") and (dpu_addr(15 downto 12) < X"A")) else '0' & X"000";
	dpu_wram_we   <= dpu_we                when ((dpu_addr(15 downto 12) >= X"8") and (dpu_addr(15 downto 12) < X"A")) else '0';
	dual_wren_a   <= vpu_we when vpu_we = '1' else 
						  dpu_we when (dpu_addr(15 downto 10) = "100000") else '0';
	
	----------------------------------------------------------------------------------------------------------
	-- Video Processor i/o control
	----------------------------------------------------------------------------------------------------------
	
	-- mux cpu in data between roms/io/wram
	vpu_di <= -- X"00" when vpu_oe = '0' else -- ?
		DO when (vpu_addr = nCrtcLatch0 or vpu_addr = nCrtcLatch1) else
		X"FF" when (vpu_addr = X"8C00" or vpu_addr = X"8C01") and vpu_we = '0' else
		MA(9 downto 5) & RA(2 downto 0) when vpu_addr = nScanlineReadback else
		prom_buses(10) when vpu_addr(15 downto 8) >= X"F8" else
		prom_buses( 9) when vpu_addr(15 downto 8) >= X"F0" else
		prom_buses( 8) when vpu_addr(15 downto 8) >= X"E8" else
		prom_buses( 7) when vpu_addr(15 downto 8) >= X"E0" else
		prom_buses( 6) when vpu_addr(15 downto 8) >= X"D8" else
		prom_buses( 5) when vpu_addr(15 downto 8) >= X"D0" else
		prom_buses( 4) when vpu_addr(15 downto 8) >= X"C8" else
		prom_buses( 3) when vpu_addr(15 downto 8) >= X"C0" else		
		vpu_wram_do    when vpu_addr(15 downto 8) >= X"84" else
		dual_wram_do_a when vpu_addr(15 downto 10) = "100000" and vpu_we = '1' else
		dual_wram_do_b when vpu_addr(15 downto 10) = "100000" else vpu_wram_video_do;
		
	-- assign cpu in/out data addresses and latch data
	vpu_rom_addr        <= 	vpu_addr(10 downto 0) when vpu_addr(15 downto 12) >= X"A" else "000" & X"00";
	video_page          <= 	vpu_do(7) when vpu_addr = nVideoAddrLatchHi;
	video_addr_latched(15 downto 8) <= vpu_do when vpu_addr = nVideoAddrLatchHi;
	video_addr_latched( 7 downto 0) <= vpu_do when vpu_addr = nVideoAddrLatchLo;
	vpu_wram_video_addr <= 	video_page & vpu_addr(14 downto 0) when vpu_addr(15) = '0' else
									video_addr_latched when vpu_addr = nVideoAddrLatch and vpu_we = '1' else X"0000";
	vpu_wram_video_we   <= 	vpu_we  when vpu_addr(15) = '0' else '0';
	vpu_wram_addr       <= 	vpu_addr(12 downto 0) when ((vpu_addr(15 downto 12) >= X"8") and (vpu_addr(15 downto 12) < X"A")) else '0' & X"000";
	vpu_wram_we         <= 	vpu_we                when ((vpu_addr(15 downto 12) >= X"8") and (vpu_addr(15 downto 12) < X"A")) else '0';
	dual_wren_b         <=  dpu_we when vpu_we = '1' else 
									vpu_we when (vpu_addr(15 downto 10) = "100000") else '0';
				
	----------------------------------------------------------------------------------------------------------
	-- Sound Processor i/o control
	----------------------------------------------------------------------------------------------------------
	
	----------------------------------------------------------------------------------------------------------
	-- CRTC i/o control
	----------------------------------------------------------------------------------------------------------
	
	-- CRTC latch ($9c00 - $9c01)
	CSn <= '0';
	RW <= not vpu_we;
	RS <= '1' when vpu_addr = nCrtcLatch1 else '0';
	DI <= vpu_do when (vpu_addr = nCrtcLatch0 or vpu_addr = nCrtcLatch1) and vpu_we = '1' else X"00";
	
	process(i_Clk_20M)
		variable video_h_counter : std_logic_vector(7 downto 0) := X"00";
		variable d_addr : std_logic_vector(15 downto 0) := X"0000";
		variable rgb : std_logic_vector(2 downto 0) := "000";
		variable rgb_dpu : std_logic_vector(2 downto 0) := "000";
		
	begin
		if rising_edge(i_Clk_20M) then
			-- get crtc video address
			-- if (HSYNC = '0') then 
			video_h_counter := video_h_counter + X"01"; 
			-- else video_h_counter := X"00"; end if;
			video_addr_crtc <= MA(4 downto 0) & RA(2 downto 0) & video_h_counter(7 downto 0);
			
			
			----- DEBUG OPTIONS :
			
--						d_addr := debug_vpu(to_integer(unsigned(video_h_counter)));	
--						
--						if (d_addr < X"8000") then rgb := "100"; end if;                         --- VIDEO : RED
--						if (d_addr >= X"8000") and (d_addr < X"9000") then rgb := "010"; end if; --- DUAL, CMOS, FIRQ : GREEN
--						if (d_addr >= X"9000") and (d_addr < X"9C00") then rgb := "001"; end if; --- PALETTE : BLUE
--						if (d_addr >= X"9C00") and (d_addr < X"C000") then rgb := "101"; end if; --- CRTC : PINK
--						if (d_addr >= X"C000") then rgb := "111"; end if;                        --- ROMS : GREY
--						
--						d_addr := debug_dpu(to_integer(unsigned(video_h_counter)));	
--						
--						if (d_addr < X"8400") then rgb_dpu := "100"; end if;                         --- DUAL : RED
--						if (d_addr >= X"8400") and (d_addr < X"9000") then rgb_dpu := "010"; end if; --- LOCAL, ACIA, FIRQ : GREEN
--						if (d_addr >= X"9000") and (d_addr < X"9900") then rgb_dpu := "001"; end if; --- PIA 1 2 : BLUE
--						if (d_addr >= X"9900") and (d_addr < X"A000") then rgb_dpu := "101"; end if; --- PIA 3 4 : PINK
--						if (d_addr >= X"A000") then rgb_dpu := "111"; end if;								  --- ROMS : GREY
--						
--						if RA = "100" then o_VGA_R4 <= rgb(2) & "000";  
--						elsif RA = "101" then o_VGA_R4 <= debug_vpu_we(to_integer(unsigned(video_h_counter))) & "000"; 
--						elsif RA = "110" then o_VGA_R4 <= debug_dpu_we(to_integer(unsigned(video_h_counter))) & "000"; else
--							o_VGA_R4 <= rgb_dpu(2) & "000"; end if;
--						if RA = "100" then o_VGA_G4 <= rgb(1) & "000";
--						elsif RA = "101" then o_VGA_G4 <= debug_vpu_we(to_integer(unsigned(video_h_counter))) & "000";  
--						elsif RA = "110" then o_VGA_R4 <= debug_dpu_we(to_integer(unsigned(video_h_counter))) & "000"; else
--							o_VGA_G4 <= rgb_dpu(1) & "000"; end if;
--						if RA = "100" then o_VGA_B4 <= rgb(0) & "000";
--						elsif RA = "101" then o_VGA_B4 <= debug_vpu_we(to_integer(unsigned(video_h_counter))) & "000"; 
--						elsif RA = "110" then o_VGA_R4 <= debug_dpu_we(to_integer(unsigned(video_h_counter))) & "000"; else
--							o_VGA_B4 <= rgb_dpu(0) & "000"; end if;
		end if;
	end process;
	
--		process(dpu_clock)
--			variable counter : std_logic_vector(7 downto 0) := X"00";
--		begin
--			if rising_edge(dpu_clock) then
--				-- if counter < X"FF" then 
--				counter := counter + X"01"; 
--				-- end if;			
--				debug_dpu(to_integer(unsigned(counter))) <= dpu_addr;
--				debug_dpu_we(to_integer(unsigned(counter))) <= dpu_we;
--			end if;
--		end process;
--		
--		process(vpu_clock)
--			variable counter : std_logic_vector(7 downto 0) := X"00";
--		begin
--			if rising_edge(vpu_clock) then
--				-- if counter < X"FF" then 
--				counter := counter + X"01"; 
--				-- end if;			
--				debug_vpu(to_integer(unsigned(counter))) <= vpu_addr;
--				debug_vpu_we(to_integer(unsigned(counter))) <= vpu_we;
--			end if;
--		end process;
		
	-- pixel output
	o_VGA_R4 <= video_pixel(7 downto 4);
	o_VGA_G4 <= video_pixel(7 downto 4);
	o_VGA_B4 <= video_pixel(3 downto 0);
	
	----------------------------------------------------------------------------------------------------------
	-- LED's and Color RAM Page
	----------------------------------------------------------------------------------------------------------
	leds(0) <= vpu_do(7) when vpu_addr = X"8800" and vpu_we = '1';
	leds(1) <= vpu_do(6) when vpu_addr = X"8800" and vpu_we = '1';
	leds(2) <= vpu_do(5) when vpu_addr = X"8800" and vpu_we = '1';
	leds(3) <= vpu_do(4) when vpu_addr = X"8800" and vpu_we = '1';
	leds(4) <= vpu_do(3) when vpu_addr = X"8800" and vpu_we = '1';
	leds(5) <= vpu_do(2) when vpu_addr = X"8800" and vpu_we = '1';
	color_ram_page <= vpu_do(1 downto 0) when vpu_addr = X"8800" and vpu_we = '1';

end System;