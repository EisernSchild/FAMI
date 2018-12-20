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
	i_Clk_20M   : in std_logic; -- input clock 20 Mhz
	i_Clk_0921K : in std_logic; -- input clock 0.9216 MHz -- Sound CPU : M6802 @ 921.6 Khz
	i_Reset     : in std_logic  -- reset when 1
      
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
	component crtc6845 is 
	port(
	-- CRT INTERFACE SIGNALS
		MA     : out STD_LOGIC_VECTOR (13 downto 0);   -- Refresh memory address lines (16K max.)
		RA     : out STD_LOGIC_VECTOR (4 downto 0);    -- Raster address lines
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
		D      : inout STD_LOGIC_VECTOR (7 downto 0);  -- Data bus in-/output (8-bits)
		
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
	constant FRQ_Q    : std_logic_vector(15 downto 0):= "0000111100001111";
	constant FRQ_QX   : std_logic_vector(15 downto 0):= "0001111000011110";
	constant FRQ_E    : std_logic_vector(15 downto 0):= "0011110000111100";
	constant FRQ_MUX  : std_logic_vector(15 downto 0):= "0011001100110011";
	constant FRQ_RSZ  : std_logic_vector(15 downto 0):= "0011001100110011";
	
	signal Clk_10M : std_logic := '0'; -- 10Mhz
	signal Clk_5M : std_logic; -- 5Mhz
	signal Clk_2500K : std_logic; -- 2.5Mhz
	signal Clk_1250K : std_logic; -- 2 x M6809 @ 1.25Mhz (& All but Qix/Qix2 have a M68705 @ 1Mhz as well) 
	signal Clk_C : std_logic; -- composite clock
	signal Clk_DE, Clk_Qx, Clk_E, Clk_Q_Inv, Clk_DQ : std_logic;
	signal VEQ, RSZ, RSZ_INV, MUX, MUX_INV, RAS_INV, CAS_INV : std_logic;
	
	signal Ctr_FRQ : integer range 0 to 15 := 0; -- frequency counter
	
	-- Data Processor 
	signal dpu_clock      : std_logic;
	signal dpu_addr       : std_logic_vector(15 downto 0);
	signal dpu_di         : std_logic_vector( 7 downto 0);
	signal dpu_do         : std_logic_vector( 7 downto 0);
	signal dpu_rw         : std_logic;
	signal dpu_irq        : std_logic;
	signal dpu_firq       : std_logic;
	signal dpu_we, dpu_oe : std_logic;
	signal dpu_state      : std_logic_vector( 5 downto 0);
	
	-- Video Processor
	signal vpu_clock      : std_logic;
	signal vpu_addr       : std_logic_vector(15 downto 0);
	signal vpu_di         : std_logic_vector( 7 downto 0);
	signal vpu_do         : std_logic_vector( 7 downto 0);
	signal vpu_rw         : std_logic;
	signal vpu_irq        : std_logic;
	signal vpu_firq       : std_logic;
	signal vpu_we, vpu_oe : std_logic;
	signal vpu_state      : std_logic_vector( 5 downto 0);
	
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
	signal dpu_rom_addr   : std_logic_vector(11 downto 0);
	
	-- Video Processor Memory Signals
	signal vpu_wram_addr        : std_logic_vector(12 downto 0);
	signal vpu_wram_we          : std_logic;
	signal vpu_wram_do          : std_logic_vector( 7 downto 0);
	signal vpu_wram_video_addr  : std_logic_vector(15 downto 0);
	signal vpu_wram_video_we    : std_logic;
	signal vpu_wram_video_do    : std_logic_vector( 7 downto 0);
	signal vpu_rom_addr         : std_logic_vector(11 downto 0);
		
	-- Sound Processor Memory Signals
	signal spu_wram_addr  : std_logic_vector(13 downto 0);
	signal spu_wram_we    : std_logic;
	signal spu_wram_do    : std_logic_vector( 7 downto 0);
	signal spu_rom_addr   : std_logic_vector(11 downto 0);
		
	-- dual RAM (Data+Video) Memory Signals
	signal dual_clock      : std_logic;
	signal dual_di         : std_logic_vector( 7 downto 0);
	signal dual_wram_addr  : std_logic_vector(10 downto 0);
	signal dual_wram_we    : std_logic;
	signal dual_wram_do    : std_logic_vector( 7 downto 0);
			
	-- CRTC
	signal CLOCK : std_logic;    
	signal Clk_CRTC : std_logic;    
	signal nRESET : std_logic;    
	signal CRTC_TYPE : std_logic;    
	signal ENABLE : std_logic;    
	signal nCS : std_logic;    
	signal R_nW : std_logic;    
	signal DI : std_logic_vector(7 downto 0);  
	signal DO : std_logic_vector(7 downto 0);
	signal VSYNC : std_logic;
	signal HSYNC : std_logic;
	signal DE : std_logic;
	signal FIELD : std_logic;
	signal MA : std_logic_vector(13 downto 0);
	signal RA : std_logic_vector(4 downto 0);
	signal CURSOR :  STD_LOGIC;
	signal LPSTBn :  STD_LOGIC;
	signal E      :  STD_LOGIC;
	signal RS     :  STD_LOGIC;
	signal CSn    :  STD_LOGIC;
	signal RW     :  STD_LOGIC;
	signal D      :  STD_LOGIC_VECTOR(7 downto 0);
	signal RESETn :  STD_LOGIC;
	signal REG_INIT: STD_LOGIC; -- used for initial crtc register setting
	
	-- PROM buses
	type   prom_buses_array is array (0 to 27) of std_logic_vector(7 downto 0);
	signal prom_buses : prom_buses_array;
	
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
	
	-- assign processor clocks
	dpu_clock <= Clk_DE;
	vpu_clock <= Clk_E;
	spu_clock <= i_Clk_0921K;
	dual_clock<= i_Clk_20M;
	
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
		cpu_clk      => dpu_clock, -- clock
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
		cpu_clk      => vpu_clock, -- clock TODO !! VPU CLOCK 1/4 AFTER DPU
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
	
	-- create clock Clk_CRTC :
	-- All timing  in  the  CRTC  is  derived from the  ClK  input.  In
	-- alphanumeric terminals, this signal  is  the character rate. The
	-- video rate or  "dot"  clock  is  externally divided by high-speed
	-- logic  (TTL)  to generate the  ClK  input.
	process (i_Clk_20M)
		variable counter : std_logic_vector(2 downto 0) := "000";
		variable E_counter : integer := 0; 
	begin
		if rising_edge(i_Clk_20M) then
		
			-- create clock
			counter := counter + 1;
			if (counter = "100") then Clk_CRTC <= '1'; else Clk_CRTC <= '0'; end if;
			
			-- manually init CRTC using E and REG_INIT
			E_counter := E_counter +1;
			if ((E_counter > 10) and (E_counter < 30)) then E <= '1';
			elsif ((E_counter > 50) and (E_counter < 70)) then E <= '0';
			else E <= '1'; end if;
			
		end if;		 
	end process;
	REG_INIT <= '1';

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
		D => D,
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
	dual_port_ram : entity work.gen_ram
	generic map( dWidth => 8, aWidth => 11)
	port map(
		clk  => dual_clock,
		we   => dual_wram_we,
		addr => dual_wram_addr(10 downto 0),
		d    => dual_di,
		q    => dual_wram_do
	);
	
	-- $8000 - $9FFF : data control memory ($8000-$8400 = dual port RAM -> shared with video CPU)
	dpu_control_ram : entity work.gen_ram
	generic map( dWidth => 8, aWidth => 13)
	port map(
		clk  => dpu_clock,
		we   => dpu_wram_we,
		addr => dpu_wram_addr(12 downto 0),
		d    => dpu_do,
		q    => dpu_wram_do
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
	vpu_video_ram : entity work.gen_ram
	generic map( dWidth => 8, aWidth => 16)
	port map(
		clk  => vpu_clock,
		we   => vpu_wram_video_we,
		addr => vpu_wram_video_addr(15 downto 0),
		d    => vpu_do,
		q    => vpu_wram_video_do
	);
	
	-- $8000 - $9FFF : video control memory ($8000-$8400 = dual port RAM -> shared with data CPU)
	vpu_control_ram : entity work.gen_ram
	generic map( dWidth => 8, aWidth => 13)
	port map(
		clk  => vpu_clock,
		we   => vpu_wram_we,
		addr => vpu_wram_addr(12 downto 0),
		d    => vpu_do,
		q    => vpu_wram_do
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
	spu_internal_ram : entity work.gen_ram
	generic map(dWidth => 8, aWidth => 7)
	port map(
		clk  => spu_clock,
		we   => spu_wram_we,
		addr => spu_wram_addr(6 downto 0),
		d    => spu_do,
		q    => spu_wram_do
	);
	
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

end System;