------------------------------------------------------------------------------
--
--  FAMI - FPGA Arcade Machine Instauration
--  
--  Copyright (C) 2018 Denis Reischl
-- 
--  Project MiSTer and related files (C) 2017,2018 Sorgelig
--
--  Konami Framebuffer Arcade System Configuration
--  File <Framebuffer.vhd> (c) 2019 by Denis Reischl
--
--  EisernSchild/FAMI is licensed under the
--  GNU General Public License v3.0
--
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.ALL;
library work;
use work.FAMI_package.all;

entity Framebuffer is
generic 
(	
	-- generic RAM integer constants
	constant nGenRamDataWidth      : integer := 8;     -- generic RAM 8 bit data width
	constant nGenRamAddrWidth		 : integer := 12;    -- generic RAM address width
	constant nGenRamADDrWidthVideo : integer := 15;    -- video RAM address width
	
	-- latch address constants
	constant nLatch             : std_logic_vector(15 downto 0) := X"FFFF" -- TODO !! LATCH ADRESSES
	
);
port
(
	i_Clk_9216K : in std_logic; -- input clock 18.432 Mhz / 2
	i_Reset      : in std_logic; -- reset when 1
	
	i_btn_flash_bomb : in std_logic;
	i_btn_fire_left  : in std_logic;
	i_btn_fire_right : in std_logic;
	i_btn_down       : in std_logic;
	i_btn_up         : in std_logic;
	i_btn_left       : in std_logic;
	i_btn_right      : in std_logic;
	
	i_btn_left_coin  : in std_logic;
	i_btn_one_player : in std_logic;
	i_btn_two_players: in std_logic;
	
	o_RegData_cpu  : out std_logic_vector(111 downto 0);
	o_Debug_cpu    : out std_logic_vector(15 downto 0);
	
	o_HBlank  : out std_logic;
	o_VBlank  : out std_logic;
	o_HSync   : out std_logic;
	o_VSync   : out std_logic;
	
	o_VGA_R3 : out std_logic_vector(2 downto 0); -- Red Color 4Bits
	o_VGA_G3 : out std_logic_vector(2 downto 0); -- Green Color 4Bits
	o_VGA_B2 : out std_logic_vector(1 downto 0)  -- Blue Color 4Bits
      
);
end Framebuffer;

architecture System of Framebuffer is

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
	
	-- Main CPU
	signal cpu_extal      : std_logic := '0';
	signal cpu_clock_e    : std_logic;
	signal cpu_clock_q    : std_logic;
	signal cpu_addr       : std_logic_vector(15 downto 0);
	signal cpu_di         : std_logic_vector( 7 downto 0);
	signal cpu_do         : std_logic_vector( 7 downto 0);
	signal cpu_rw         : std_logic;
	signal cpu_irq        : std_logic := '0';
	signal cpu_firq       : std_logic := '1';
	signal cpu_we, cpu_oe : std_logic;
	signal cpu_state      : std_logic_vector( 5 downto 0);
	signal cpu_bs, cpu_ba : std_logic;
	
	-- Main CPU Memory Signals
	signal cpu_wram_addr  : std_logic_vector(11 downto 0);
	signal cpu_wram_we    : std_logic;
	signal cpu_wram_do    : std_logic_vector( 7 downto 0);
	signal cpu_rom_addr   : std_logic_vector(11 downto 0);
	
	-- Video RAM Memory Signals
	signal video_wram_addr        : std_logic_vector(14 downto 0);
	signal video_wram_we          : std_logic;
	signal video_wram_do          : std_logic_vector( 7 downto 0);
	
	--	machine data
	signal int_control : std_logic;
	signal flip_screen_x : std_logic := '0';
	signal flip_screen_y : std_logic := '0';
	--$8040   - Sound CPU req/ack data - TODO !!
	--$8050   - Sound CPU command data - TODO !!
	signal mem_bank_select : std_logic_vector(7 downto 0);
	signal blit_src_data : std_logic_vector(15 downto 0);
	signal blit_dst_data : std_logic_vector(15 downto 0);
	signal blit_trigger : std_logic;
	signal blit_ackn : std_logic;
	
	-- dip switches + input
	signal dip_1   : std_logic_vector(7 downto 0) := X"FF";
	signal dip_2   : std_logic_vector(7 downto 0) := X"FF";
	signal input_1 : std_logic_vector(7 downto 0) := X"FF";
	signal input_2 : std_logic_vector(7 downto 0) := X"FF";
	
	-- Video control signals
	signal video_addr_output    : std_logic_vector(14 downto 0);
	signal video_pixel		    : std_logic_vector( 7 downto 0);
	signal video_pixel_shift    : std_logic;
	signal video_pixel_palette  : std_logic_vector( 3 downto 0);
	type PALETTE is array (15 downto 0) of std_logic_vector(7 downto 0);
	signal video_palette : PALETTE := (X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00",X"00");
	signal video_scroll		    : std_logic_vector( 7 downto 0);
	signal video_clock          : std_logic;
	
	-- PROM buses
	type   prom_buses_array is array (0 to 27) of std_logic_vector(7 downto 0);
	signal prom_buses : prom_buses_array;
	
	-- debug
	signal RegData_cpu  : std_logic_vector(111 downto 0);
	type   Debug_flags is array (0 to 15) of boolean;
	signal Debug_cpu : Debug_flags := (others => false);
		
begin

	----------------------------------------------------------------------------------------------------------
	-- Clocks
	----------------------------------------------------------------------------------------------------------
	
	process(i_Clk_9216K)
	begin
		if rising_edge(i_Clk_9216K) then
			cpu_extal <= not cpu_extal;			
		end if;
	end process;
	
lite_label : if LITE_BUILD generate

end generate;
	
	----------------------------------------------------------------------------------------------------------
	-- Components
	----------------------------------------------------------------------------------------------------------
	
	-- Main CPU : MC6809 ? MHz
	cpu_we <= not cpu_oe;
lite_label1 : if LITE_BUILD generate
	Data_Processor : mc6809
	port map
	(
		D        => cpu_di,          -- cpu data input 8 bit
		DOut     => cpu_do,          -- cpu data output 8 bit
		ADDR     => cpu_addr,        -- cpu address 16 bit
		RnW      => cpu_oe,          -- write enabled
		E        => cpu_clock_e,     -- output clock E
		Q        => cpu_clock_q,     -- output clock Q
		BS       => cpu_bs,          -- bus status
		BA       => cpu_ba,          -- bus available
		nIRQ     => cpu_irq,         -- interrupt request
		nFIRQ    => '1',             -- fast interrupt request
		nNMI     => '1',             -- non-maskable interrupt
		EXTAL    => not cpu_extal,   -- input oscillator
		XTAL     => '0',             -- input oscillator
		nHALT    => '1',             -- not halt - causes the MPU to stop running
		nRESET   => not i_Reset,     -- not reset
		MRDY     => '1',             -- strech E and Q
		nDMABREQ => '1',             -- suspend execution
		RegData  => RegData_cpu      -- register data (debug)
	);
end generate;
	
	----------------------------------------------------------------------------------------------------------
	-- Memory Mapping
	----------------------------------------------------------------------------------------------------------
	
	-- Juno First
	--
	-- Read/Write memory
	-- $0000-$7FFF = Screen RAM (only written to)
	-- $8000-$800f = Palette RAM. BBGGGRRR (D7->D0)
	-- $8100-$8FFF = Work RAM
	-- Write memory
	-- $8030   - interrupt control register D0 = interrupts on or off
	-- $8031   - unknown
	-- $8032   - unknown
	-- $8033   - unknown
	-- $8034   - flip screen x
	-- $8035   - flip screen y
	-- $8040   - Sound CPU req/ack data
	-- $8050   - Sound CPU command data
	-- $8060   - Banked memory page select.
	-- $8070/1 - Blitter source data word
	-- $8072/3 - Blitter destination word. Write to $8073 triggers a blit
	-- Read memory
	-- $8010   - Dipswitch 2
	-- $801c   - Watchdog
	-- $8020   - Start/Credit IO
	--                D2 = Credit 1
	--                D3 = Start 1
	--                D4 = Start 2
	-- $8024   - P1 IO
	--                D0 = left
	--                D1 = right
	--                D2 = up
	--                D3 = down
	--                D4 = fire 2
	--                D5 = fire 1
	-- $8028   - P2 IO - same as P1 IO
	-- $802c   - Dipswitch 1
	
	-- Tutankham
	--
	--	0x0000-0x7FFF	32768	RAM, Shared	videoram
	--	0x8000-0x800F	16	Mirror, RAM Device Write, Shared	0x00f0, palette, palette_device, write, palette
	--	0x8100	1	Mirror, RAM, Shared	0x000f, , scroll
	--	0x8120	1	Mirror, Device Read	0x000f, watchdog, watchdog_timer_device, reset_r
	--	0x8160	1	Mirror, Read Port	0x000f, DSW2 (/* DSW2 (inverted bits) */)
	--		0x0003	Lives	Active High
	--		0x0003	3	Active High
	--		0x0001	4	Active High
	--		0x0002	5	Active High
	--		0x0000	255 (Cheat)	Active High
	--		0x0004	Cabinet	Active High
	--		0x0000	Upright	Active High
	--		0x0004	Cocktail	Active High
	--		0x0008	Bonus_Life	Active High
	--		0x0008	30000	Active High
	--		0x0000	40000	Active High
	--		0x0030	Difficulty	Active High
	--		0x0030	Easy	Active High
	--		0x0020	Normal	Active High
	--		0x0010	Hard	Active High
	--		0x0000	Hardest	Active High
	--		0x0040	1 per Life	Active High
	--		0x0000	1 per Game	Active High
	--		0x0080	Demo_Sounds	Active High
	--		0x0080	Off	Active High
	--		0x0000	On	Active High
	--	0x8180	1	Mirror, Read Port	0x000f, IN0 (/* IN0 I/O: Coin slots, service, 1P/2P buttons */)
	--	0x81A0	1	Mirror, Read Port	0x000f, IN1 (/* IN1: Player 1 I/O */)
	--		0x0010	Joystickright Left	Active Low
	--		0x0020	Joystickright Right	Active Low
	--		0x0040	P1 Flash Bomb	Active Low
	--	0x81C0	1	Mirror, Read Port	0x000f, IN2 (/* IN2: Player 2 I/O */)
	--		0x0010	Joystickright Left	Active Low
	--		0x0020	Joystickright Right	Active Low
	--		0x0040	Button 2	Active Low
	--	0x81E0	1	Mirror, Read Port	0x000f, DSW1 (/* DSW1 (inverted bits) */)
	--	0x8200	1	Mirror, Read NOP, Write	0x00f8, , irq_enable_w
	--	0x8202-0x8203	2	Mirror, Write	0x00f8, tutankhm_coin_counter_w
	--	0x8204	1	Mirror, Write NOP	0x00f8, (// starfield?)
	--	0x8205	1	Mirror, Write	0x00f8, sound_mute_w
	--	0x8206	1	Mirror, Write	0x00f8, tutankhm_flip_screen_x_w
	--	0x8207	1	Mirror, Write	0x00f8, tutankhm_flip_screen_y_w
	--	0x8300	1	Mirror, Write	0x00ff, tutankhm_bankselect_w
	--	0x8600	1	Mirror, Device Write	0x00ff, timeplt_audio, timeplt_audio_device, sh_irqtrigger_w
	--	0x8700	1	Mirror, Device Write	0x00ff, soundlatch, generic_latch_8_device, write
	--	0x8800-0x8FFF	2048	RAM	
	--	0x9000-0x9FFF	4096	ROM Bank	bank1
	--	0xA000-0xFFFF	24576	ROM
	
	
	-- $0000 - $7FFF : direct video RAM access 
	Video_RAM : work.dpram generic map (nGenRamADDrWidthVideo, nGenRamDataWidth)
	port map
	(
		clock_a   => cpu_clock_e,
		wren_a    => video_wram_we,
		address_a => video_wram_addr,
		data_a    => cpu_do,
		q_a       => video_wram_do,

		clock_b   => video_clock,
		address_b => video_addr_output,
		q_b       => video_pixel
	);
	
	-- $8000 - $8FFF : main cpu ram
	CPU_RAM : work.dpram generic map (nGenRamAddrWidth, nGenRamDataWidth)
	port map
	(
		clock_a   => cpu_clock_e,
		wren_a    => cpu_wram_we,
		address_a => cpu_wram_addr,
		data_a    => cpu_do,
		q_a       => cpu_wram_do,
		
		clock_b   => '0',
		address_b => (others => '0'),
		enable_b  => '0',
		q_b       => open
	);
	
	--	main cpu roms
	PROM_1H : entity work.PROM_H1 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(0));   -- $0A000
	PROM_2H : entity work.PROM_H2 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(1));   -- $0B000
	PROM_3H : entity work.PROM_H3 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(2));   -- $0C000
	PROM_4H : entity work.PROM_H4 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(3));   -- $0D000
	PROM_5H : entity work.PROM_H5 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(4));   -- $0E000
	PROM_6H : entity work.PROM_H6 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(5));   -- $0F000
	
	-- main cpu roms banked
	PROM_1I : entity work.PROM_J1 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(6));   -- $10000
	PROM_2I : entity work.PROM_J2 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(7));   -- $11000
	PROM_3I : entity work.PROM_J3 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(8));   -- $12000
	PROM_4I : entity work.PROM_J4 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(9));   -- $13000
	PROM_5I : entity work.PROM_J5 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(10));  -- $14000
	PROM_6I : entity work.PROM_J6 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(11));  -- $15000
	PROM_7I : entity work.PROM_J7	port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(12));  -- $16000
	PROM_8I : entity work.PROM_J8 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(13));  -- $17000
	PROM_9I : entity work.PROM_J9 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(14));  -- $18000
	
	--	
	-- PROM_7a : entity work.PROM_11_7A port map (CLK => spu_clock, ADDR => spu_rom_addr, DATA => prom_buses(27));
	-- PROM_8a : entity work.PROM_10_8A port map (CLK => spu_clock, ADDR => spu_rom_addr, DATA => prom_buses(27));
	
	----------------------------------------------------------------------------------------------------------
	-- Juno First Blitter Hardware
	----------------------------------------------------------------------------------------------------------
	
	--		Juno First can blit a 16x16 graphics which comes from un-memory mapped graphics roms
	--		$8070->$8071 specifies the destination NIBBLE address
	--		$8072->$8073 specifies the source NIBBLE address
	--		Depending on bit 0 of the source address either the source pixels will be copied to
	--		the destination address, or a zero will be written.
	--		Only source pixels which aren't 0 are copied or cleared.
	--		This allows the game to quickly clear the sprites from the screen
	--		TODO: Does bit 1 of the source address mean something?
	--          We have to mask it off otherwise the "Juno First" logo on the title screen is wrong

lite_label2 : if JUNO_FIRST generate	
	process(i_Clk_9216K)
		-- variable x : std_logic_vector(7 downto 0) := X"00";
	begin
		if rising_edge(i_Clk_9216K) then
			
			
		end if;
	end process;
end generate;
		
	----------------------------------------------------------------------------------------------------------
	-- Main Processor i/o control
	----------------------------------------------------------------------------------------------------------
	
lite_label3 : if JUNO_FIRST generate	
	-- mux cpu in data between roms/io/wram
	cpu_di <=
		dip_1 when cpu_addr = X"8010" else
		dip_2 when cpu_addr = X"802c" else
		prom_buses(5) when cpu_addr(15 downto 12) = X"F" else
		prom_buses(4) when cpu_addr(15 downto 12) = X"E" else
		prom_buses(3) when cpu_addr(15 downto 12) = X"D" else
		prom_buses(2) when cpu_addr(15 downto 12) = X"C" else
		prom_buses(1) when cpu_addr(15 downto 12) = X"B" else
		prom_buses(0) when cpu_addr(15 downto 12) = X"A" else
		cpu_wram_do   when cpu_addr(15 downto 12) = X"8" else video_wram_do;
		
	-- machine data
	int_control <= cpu_do(0) when cpu_addr = X"8030" and cpu_we = '1';
	flip_screen_x <= cpu_do(0) when cpu_addr = X"8034" and cpu_we = '1';
	flip_screen_y <= cpu_do(0) when cpu_addr = X"8035" and cpu_we = '1';
	mem_bank_select <= cpu_do when cpu_addr = X"8060" and cpu_we = '1';
	blit_src_data(15 downto 8) <= cpu_do when cpu_addr = X"8070" and cpu_we = '1' else X"00";
	blit_src_data( 7 downto 0) <= cpu_do when cpu_addr = X"8071" and cpu_we = '1' else X"00";
	blit_dst_data(15 downto 8) <= cpu_do when cpu_addr = X"8072" and cpu_we = '1' else X"00";
	blit_dst_data( 7 downto 0) <= cpu_do when cpu_addr = X"8073" and cpu_we = '1' else X"00";
	blit_trigger <= '0' when blit_ackn = '1' else '1' when cpu_addr = X"8073" and cpu_we = '1' else '0';
end generate;

lite_label4 : if TUTANKHAM generate
	-- mux cpu in data between roms/io/wram
	cpu_di <=	
		dip_1 when cpu_addr = X"81E0" else
		dip_2 when cpu_addr = X"8160" else
		input_1 when cpu_addr = X"81A0" else
		input_2 when cpu_addr = X"8180" else
		prom_buses(14) when cpu_addr(15 downto 12) = X"9" and mem_bank_select(3 downto 0) = X"8" else
		prom_buses(13) when cpu_addr(15 downto 12) = X"9" and mem_bank_select(3 downto 0) = X"7" else
		prom_buses(12) when cpu_addr(15 downto 12) = X"9" and mem_bank_select(3 downto 0) = X"6" else
		prom_buses(11) when cpu_addr(15 downto 12) = X"9" and mem_bank_select(3 downto 0) = X"5" else
		prom_buses(10) when cpu_addr(15 downto 12) = X"9" and mem_bank_select(3 downto 0) = X"4" else
		prom_buses(9) when cpu_addr(15 downto 12) = X"9" and mem_bank_select(3 downto 0) = X"3" else
		prom_buses(8) when cpu_addr(15 downto 12) = X"9" and mem_bank_select(3 downto 0) = X"2" else
		prom_buses(7) when cpu_addr(15 downto 12) = X"9" and mem_bank_select(3 downto 0) = X"1" else
		prom_buses(6) when cpu_addr(15 downto 12) = X"9" and mem_bank_select(3 downto 0) = X"0" else
		prom_buses(5) when cpu_addr(15 downto 12) = X"F" else
		prom_buses(4) when cpu_addr(15 downto 12) = X"E" else
		prom_buses(3) when cpu_addr(15 downto 12) = X"D" else
		prom_buses(2) when cpu_addr(15 downto 12) = X"C" else
		prom_buses(1) when cpu_addr(15 downto 12) = X"B" else
		prom_buses(0) when cpu_addr(15 downto 12) = X"A" else
		cpu_wram_do   when cpu_addr(15 downto 12) = X"8" else video_wram_do;
		
	-- machine data
	int_control <= cpu_do(0) when cpu_addr = X"8200" and cpu_we = '1';
	flip_screen_x <= cpu_do(0) when cpu_addr = X"8206" and cpu_we = '1';
	flip_screen_y <= cpu_do(0) when cpu_addr = X"8207" and cpu_we = '1';	
	mem_bank_select <= cpu_do when cpu_addr = X"8300" and cpu_we = '1';
	
	-- input
	input_1 <= '1' & not i_btn_flash_bomb & not i_btn_fire_right & not i_btn_fire_left & not i_btn_down & not i_btn_up & not i_btn_right & not i_btn_left;
	input_2 <= '1' & '1' & '1' & i_btn_two_players & i_btn_one_player & '1' & i_btn_left_coin & '1';
end generate;
		
	-- assign cpu in/out data addresses	
	cpu_rom_addr  <= cpu_addr(11 downto 0) when cpu_addr(15 downto 12) >= X"9" else X"000";
	cpu_wram_addr <= cpu_addr(11 downto 0) when (cpu_addr(15 downto 12) = X"8") else X"000";
	cpu_wram_we   <= cpu_we when (cpu_addr(15 downto 12) = X"8") else '0';
	video_wram_addr <= cpu_addr(14 downto 0) when (cpu_addr(15 downto 12) < X"8") else "000" & X"000";
	video_wram_we <= cpu_we when (cpu_addr(15 downto 12) < X"8") else '0';
	
	----------------------------------------------------------------------------------------------------------
	-- Video update
	----------------------------------------------------------------------------------------------------------
	
	-- set video palette ($8000-$800f)
	video_palette(0) <= cpu_do when cpu_addr = X"8000" and cpu_we = '1';
	video_palette(1) <= cpu_do when cpu_addr = X"8001" and cpu_we = '1';
	video_palette(2) <= cpu_do when cpu_addr = X"8002" and cpu_we = '1';
	video_palette(3) <= cpu_do when cpu_addr = X"8003" and cpu_we = '1';
	video_palette(4) <= cpu_do when cpu_addr = X"8004" and cpu_we = '1';
	video_palette(5) <= cpu_do when cpu_addr = X"8005" and cpu_we = '1';
	video_palette(6) <= cpu_do when cpu_addr = X"8006" and cpu_we = '1';
	video_palette(7) <= cpu_do when cpu_addr = X"8007" and cpu_we = '1';
	video_palette(8) <= cpu_do when cpu_addr = X"8008" and cpu_we = '1';
	video_palette(9) <= cpu_do when cpu_addr = X"8009" and cpu_we = '1';
	video_palette(10) <= cpu_do when cpu_addr = X"800a" and cpu_we = '1';
	video_palette(11) <= cpu_do when cpu_addr = X"800b" and cpu_we = '1';
	video_palette(12) <= cpu_do when cpu_addr = X"800c" and cpu_we = '1';
	video_palette(13) <= cpu_do when cpu_addr = X"800d" and cpu_we = '1';
	video_palette(14) <= cpu_do when cpu_addr = X"800e" and cpu_we = '1';
	video_palette(15) <= cpu_do when cpu_addr = X"800f" and cpu_we = '1';
	
	-- scrolling
	video_scroll <= cpu_do when cpu_addr = X"8100" and cpu_we = '1';
	
	-- output video clock
	video_clock <= i_Clk_9216K;
	
	-- video ram scan
	process(video_clock)
		variable video_h_counter : std_logic_vector(7 downto 0) := X"FF";
		variable video_v_counter : std_logic_vector(7 downto 0) := X"FF";
		variable video_h_scroll  : std_logic_vector(7 downto 0) := X"00";
		variable h_porch : std_logic_vector(7 downto 0) := X"0c"; -- set to front porch
		variable v_porch : std_logic_vector(7 downto 0) := X"08"; -- set to front porch
		variable lock_cpu : std_logic := '0';
		variable frame_skip : std_logic := '0';
	begin
		if rising_edge(video_clock) then
			-- cpu bus ?
			if (cpu_bs = '1') and (cpu_ba = '0') then lock_cpu := '1'; cpu_irq <= '1'; else lock_cpu:='0'; end if;
			
			-- irq ?
			if (h_porch = X"00") and (v_porch = X"00") and (video_v_counter = X"00") and (video_h_counter = X"00") then
					
					-- cpu irq by vertical sync ?
					if (lock_cpu = '0') and (frame_skip = '0') then
						cpu_irq <= '0';
						frame_skip := '1';
					else
						frame_skip := '0';
					end if;
			end if;
					
			
			-- horizontal sync
			if (video_h_counter = X"FF") then
				
				-- set horizontal porch
				h_porch := h_porch + X"01";
				
				-- set hblank
				o_HBlank <= '1';
				o_HSync <= '0';
			
			else
			
				-- set hblank
				o_HBlank <= '0';
				o_HSync <= '1';
				
			end if;
			
			-- horizontal porch
			if (h_porch = X"41") then
			
				-- horizontal new line
				video_h_counter := X"00";
				h_porch := X"00";
				
				-- vertical sync
				if (video_v_counter = X"FF") then
					
					-- set horizontal porch
					v_porch := v_porch + X"01";
					
					-- set vblank
					o_VBlank <= '1';
					o_VSync <= '0';
				
				else
				
					-- set vblank
					o_VBlank <= '0';
					o_VSync <= '1';
					
				end if;
				
				-- vertical porch
				if (v_porch = X"21") then
				
					-- vertical new screen
					video_v_counter := X"00";
					v_porch := X"00";
					
				elsif (v_porch = X"00") then
			
					-- set horizontal counter
					video_v_counter := video_v_counter + X"01";
			
				end if;				
			
			elsif (h_porch = X"00") then
			
				-- set horizontal counter
				video_h_counter := video_h_counter + X"01";
		
			end if;
			
			-- set current video read address .. TODO !! FLIP X/Y
			video_h_scroll := (video_scroll + video_h_counter);
			if (video_v_counter <= X"40") then video_addr_output(14 downto 7) <= video_h_counter; else video_addr_output(14 downto 7) <= video_h_scroll; end if;
			video_addr_output( 6 downto 0) <= (not video_v_counter(7 downto 1));
			video_pixel_shift <= not video_v_counter(0);
			
		end if; 
	end process;
	
	-- pixel output
	video_pixel_palette <= video_pixel(7 downto 4) when (video_pixel_shift = '1') else video_pixel(3 downto 0);
	o_VGA_R3 <= video_palette(to_integer(unsigned(video_pixel_palette)))(2 downto 0);
	o_VGA_G3 <= video_palette(to_integer(unsigned(video_pixel_palette)))(5 downto 3);
	o_VGA_B2 <= video_palette(to_integer(unsigned(video_pixel_palette)))(7 downto 6);
	

end System;
