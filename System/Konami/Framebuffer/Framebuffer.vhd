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
	i_Clk       : in std_logic; -- input clock  !! TODO !!
	i_Reset     : in std_logic; -- reset when 1
	
	o_RegData_cpu  : out std_logic_vector(111 downto 0);
	o_Debug_cpu : out std_logic_vector(15 downto 0);
	
	o_VGA_R4 : out std_logic_vector(3 downto 0); -- Red Color 4Bits
	o_VGA_G4 : out std_logic_vector(3 downto 0); -- Green Color 4Bits
	o_VGA_B4 : out std_logic_vector(3 downto 0)  -- Blue Color 4Bits
      
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
	
	-- dip switches
	signal dip_1 : std_logic_vector(7 downto 0) := X"00";
	signal dip_2 : std_logic_vector(7 downto 0) := X"00";
	
	-- Video control signals
	signal video_addr_output    : std_logic_vector(14 downto 0);
	signal video_pixel		    : std_logic_vector( 7 downto 0);
	
	-- PROM buses
	type   prom_buses_array is array (0 to 27) of std_logic_vector(7 downto 0);
	signal prom_buses : prom_buses_array;
	
	-- debug
	signal RegData_cpu  : std_logic_vector(111 downto 0);
	signal Debug_cpu : std_logic_vector(15 downto 0) := X"0000";
		
begin

	----------------------------------------------------------------------------------------------------------
	-- Clocks
	----------------------------------------------------------------------------------------------------------

lite_label : if LITE_BUILD generate
	-- debug program counter markers	
	debug_02 : process(i_Clk)
	begin
		if rising_edge(i_Clk) then
			case RegData_cpu(111 downto 96) is				
				when X"a372" => Debug_cpu(0) <= '1';
				when X"a373" => Debug_cpu(1) <= '1';
				when X"a376" => Debug_cpu(2) <= '1';
				when X"a379" => Debug_cpu(3) <= '1';
				when X"a37b" => Debug_cpu(4) <= '1';
				when X"a37c" => Debug_cpu(5) <= '1';
				when X"a37e" => Debug_cpu(6) <= '1';
				when X"a380" => Debug_cpu(7) <= '1';
				when X"a382" => Debug_cpu(8) <= '1';
				when X"a3d6" => Debug_cpu(9) <= '1';
				when X"a3e5" => Debug_cpu(10) <= '1';				
				when X"a470" => Debug_cpu(11) <= '1';
				when X"a488" => Debug_cpu(12) <= '1';
				when X"a48f" => Debug_cpu(13) <= '1';
				when X"a49b" => Debug_cpu(14) <= '1';
				-- when X"d71a" => Debug_cpu(6) <= '1';
				when others => Debug_cpu(15) <= '1';
			end case;
			

		end if;	
	end process debug_02;	
	o_RegData_cpu <= RegData_cpu;
	o_Debug_cpu <= Debug_cpu;
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
		D        => cpu_di,      -- cpu data input 8 bit
		DOut     => cpu_do,      -- cpu data output 8 bit
		ADDR     => cpu_addr,    -- cpu address 16 bit
		RnW      => cpu_oe,      -- write enabled
		E        => cpu_clock_e, -- output clock E
		Q        => cpu_clock_q, -- output clock Q
		BS       => cpu_bs,      -- bus status
		BA       => cpu_ba,      -- bus available
		nIRQ     => '1',         -- interrupt request
		nFIRQ    => '1',         -- fast interrupt request
		nNMI     => '1',         -- non-maskable interrupt
		EXTAL    => i_Clk,       -- input oscillator
		XTAL     => '0',         -- input oscillator
		nHALT    => '1',         -- not halt - causes the MPU to stop running
		nRESET   => not i_Reset, -- not reset
		MRDY     => '1',         -- strech E and Q
		nDMABREQ => '1',         -- suspend execution
		RegData  => RegData_cpu  -- register data (debug)
	);
end generate;
	
	----------------------------------------------------------------------------------------------------------
	-- Memory Mapping
	----------------------------------------------------------------------------------------------------------
	
	--Read/Write memory
	--$0000-$7FFF = Screen RAM (only written to)
	--$8000-$800f = Palette RAM. BBGGGRRR (D7->D0)
	--$8100-$8FFF = Work RAM
	--Write memory
	--$8030   - interrupt control register D0 = interrupts on or off
	--$8031   - unknown
	--$8032   - unknown
	--$8033   - unknown
	--$8034   - flip screen x
	--$8035   - flip screen y
	--$8040   - Sound CPU req/ack data
	--$8050   - Sound CPU command data
	--$8060   - Banked memory page select.
	--$8070/1 - Blitter source data word
	--$8072/3 - Blitter destination word. Write to $8073 triggers a blit
	--Read memory
	--$8010   - Dipswitch 2
	--$801c   - Watchdog
	--$8020   - Start/Credit IO
	--                D2 = Credit 1
	--                D3 = Start 1
	--                D4 = Start 2
	--$8024   - P1 IO
	--                D0 = left
	--                D1 = right
	--                D2 = up
	--                D3 = down
	--                D4 = fire 2
	--                D5 = fire 1
	--$8028   - P2 IO - same as P1 IO
	--$802c   - Dipswitch 1
	
	-- $0000 - $7FFF : direct video RAM access 
	Video_RAM : work.dpram generic map (nGenRamADDrWidthVideo, nGenRamDataWidth)
	port map
	(
		clock_a   => cpu_clock_e,
		wren_a    => video_wram_we,
		address_a => video_wram_addr,
		data_a    => cpu_do,
		q_a       => video_wram_do,

		clock_b   => i_Clk,
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
	
	process(i_Clk)
		-- variable x : std_logic_vector(7 downto 0) := X"00";
	begin
		if rising_edge(i_Clk) then
			
			
		end if;
	end process;
		
	----------------------------------------------------------------------------------------------------------
	-- Main Processor i/o control
	----------------------------------------------------------------------------------------------------------
	
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
		
	-- assign cpu in/out data addresses	
	cpu_rom_addr  <= cpu_addr(11 downto 0) when cpu_addr(15 downto 12) >= X"A" else X"000";
	cpu_wram_addr <= cpu_addr(11 downto 0) when (cpu_addr(15 downto 12) = X"8") else X"000";
	cpu_wram_we   <= cpu_we when (cpu_addr(15 downto 12) = X"8") else '0';
	video_wram_addr <= cpu_addr(14 downto 0) when (cpu_addr(15 downto 12) < X"8") else "000" & X"000";
	video_wram_we <= cpu_we when (cpu_addr(15 downto 12) < X"8") else '0';
	
	-- machine data
	int_control <= cpu_do(0) when cpu_addr = X"8030" and cpu_we = '1' else '0';
	flip_screen_x <= cpu_do(0) when cpu_addr = X"8034" and cpu_we = '1' else '0';
	flip_screen_y <= cpu_do(0) when cpu_addr = X"8035" and cpu_we = '1' else '0';
	mem_bank_select <= cpu_do when cpu_addr = X"8060" and cpu_we = '1' else X"00";
	blit_src_data(15 downto 8) <= cpu_do when cpu_addr = X"8070" and cpu_we = '1' else X"00";
	blit_src_data( 7 downto 0) <= cpu_do when cpu_addr = X"8071" and cpu_we = '1' else X"00";
	blit_dst_data(15 downto 8) <= cpu_do when cpu_addr = X"8072" and cpu_we = '1' else X"00";
	blit_dst_data( 7 downto 0) <= cpu_do when cpu_addr = X"8073" and cpu_we = '1' else X"00";
	blit_trigger <= '0' when blit_ackn = '1' else '1' when cpu_addr = X"8073" and cpu_we = '1' else '0';
	
	----------------------------------------------------------------------------------------------------------
	-- Video update
	----------------------------------------------------------------------------------------------------------
	
	-- TODO !! FLIP X/Y
	
	-- vrambyte = m_videoram[effy * 128 + effx / 2];
	
	process(i_Clk)
		variable video_h_counter : std_logic_vector(7 downto 0) := X"00";
		variable video_v_counter : std_logic_vector(7 downto 0) := X"00";
		variable h_buff : std_logic_vector(7 downto 0) := X"00";
		variable v_buff : std_logic_vector(7 downto 0) := X"00";
	begin
		if rising_edge(i_Clk) then
			
			if (video_h_counter = X"FF") then 
				h_buff := X"40";
			
				if (v_buff > X"00") then
					v_buff := v_buff - X"01";
				else
					video_v_counter := video_v_counter + X"01";
				end if;
				
			end if;
			
			if (video_v_counter = X"FF") then
				v_buff := X"20";
			
			end if;
			
			if (h_buff > X"00") then
				h_buff := h_buff - X"01";
			else
				video_h_counter := video_h_counter + X"01";
			end if;
			
			video_addr_output <= video_v_counter(7 downto 0) & video_h_counter(7 downto 1);
			
		end if;
	end process;
	
	-- pixel output
	o_VGA_R4 <= video_pixel(7 downto 4);
	o_VGA_G4 <= video_pixel(7 downto 4);
	o_VGA_B4 <= video_pixel(3 downto 0);
	

end System;
