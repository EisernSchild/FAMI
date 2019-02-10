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
	constant nGenRamAddrWidth		 : integer := 10;    -- generic RAM address width
	
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
	signal cpu_irq        : std_logic;
	signal cpu_firq       : std_logic := '1';
	signal cpu_we, cpu_oe : std_logic;
	signal cpu_state      : std_logic_vector( 5 downto 0);
	signal cpu_bs, cpu_ba : std_logic;
	
	-- Main CPU Memory Signals
	signal cpu_wram_addr  : std_logic_vector(12 downto 0);
	signal cpu_wram_we    : std_logic;
	signal cpu_wram_do    : std_logic_vector( 7 downto 0);
	signal cpu_rom_addr   : std_logic_vector(10 downto 0);	
	
	-- CMOS signals (data-out and write-enabled)
	signal cmos_do         : std_logic_vector( 7 downto 0);
	signal cmos_we         : std_logic;
	
	-- Video control signals
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
	debug_02 : process(cpu_clock_e)
	begin
		if rising_edge(cpu_clock_e) then
			case RegData_cpu(111 downto 96) is
				when X"fff1" => Debug_cpu(0) <= '1';
				when X"fff2" => Debug_cpu(1) <= '1';
				when X"fff3" => Debug_cpu(2) <= '1';
				when X"fff4" => Debug_cpu(3) <= '1';
				when X"fff5" => Debug_cpu(4) <= '1';
				when X"fff6" => Debug_cpu(5) <= '1';
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
		nIRQ     => not cpu_irq, -- interrupt request
		nFIRQ    => cpu_firq,    -- fast interrupt request
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
	
	-- Main CPU
	
	
	

	
	--	Data Processor ROM Region -> U12-U19 PROM
--	PROM_U12 : entity work.prom_u12 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(12));
--	PROM_U13 : entity work.prom_u13 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(13));
--	PROM_U14 : entity work.prom_u14 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(14));
--	PROM_U15 : entity work.prom_u15 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(15));
--	PROM_U16 : entity work.prom_u16 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(16));
--	PROM_U17 : entity work.prom_u17 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(17));
--	PROM_U18 : entity work.prom_u18 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(18));
--	PROM_U19 : entity work.prom_u19 port map (CLK => cpu_clock_e, ADDR => cpu_rom_addr, DATA => prom_buses(19));
--	
--	--	Video Processor ROM Region -> U4-U10 PROM
--	PROM_U4  : entity work.prom_u4  port map (CLK => vpu_clock, ADDR => vpu_rom_addr, DATA => prom_buses( 4));
--	PROM_U5  : entity work.prom_u5  port map (CLK => vpu_clock, ADDR => vpu_rom_addr, DATA => prom_buses( 5));
--	PROM_U6  : entity work.prom_u6  port map (CLK => vpu_clock, ADDR => vpu_rom_addr, DATA => prom_buses( 6));
--	PROM_U7  : entity work.prom_u7  port map (CLK => vpu_clock, ADDR => vpu_rom_addr, DATA => prom_buses( 7));
--	PROM_U8  : entity work.prom_u8  port map (CLK => vpu_clock, ADDR => vpu_rom_addr, DATA => prom_buses( 8));
--	PROM_U9  : entity work.prom_u9  port map (CLK => vpu_clock, ADDR => vpu_rom_addr, DATA => prom_buses( 9));
--	PROM_U10 : entity work.prom_u10 port map (CLK => vpu_clock, ADDR => vpu_rom_addr, DATA => prom_buses(10));
--	
--	--	Sound Processor ROM Region -> U27 PROM
--	PROM_U27 : entity work.prom_u27 port map (CLK => spu_clock, ADDR => spu_rom_addr, DATA => prom_buses(27));
	
	----------------------------------------------------------------------------------------------------------
	-- Main Processor i/o control
	----------------------------------------------------------------------------------------------------------
	
	-- mux cpu in data between roms/io/wram
	cpu_di <=
		prom_buses(19) when cpu_addr(15 downto 8) >= X"F8" else
		prom_buses(18) when cpu_addr(15 downto 8) >= X"F0" else
		prom_buses(17) when cpu_addr(15 downto 8) >= X"E8" else
		prom_buses(16) when cpu_addr(15 downto 8) >= X"E0" else
		prom_buses(15) when cpu_addr(15 downto 8) >= X"D8" else
		prom_buses(14) when cpu_addr(15 downto 8) >= X"D0" else
		prom_buses(13) when cpu_addr(15 downto 8) >= X"C8" else
		prom_buses(12) when cpu_addr(15 downto 8) >= X"C0" else		
		cpu_wram_do    when cpu_addr(15 downto 8) >= X"84" else X"00";
		
	-- assign cpu in/out data addresses
	cpu_rom_addr  <= (others => '0'); -- cpu_addr(10 downto 0) when cpu_addr(15 downto 12) >= X"A" else "000" & X"00";
	cpu_wram_addr <= (others => '0');-- cpu_addr(12 downto 0) when ((cpu_addr(15 downto 12) >= X"8") and (cpu_addr(15 downto 12) < X"A")) else '0' & X"000";
	cpu_wram_we   <= '0'; -- cpu_we                when ((cpu_addr(15 downto 12) >= X"8") and (cpu_addr(15 downto 12) < X"A")) else '0';
	
	-- pixel output
	o_VGA_R4 <= video_pixel(7 downto 4);
	o_VGA_G4 <= video_pixel(7 downto 4);
	o_VGA_B4 <= video_pixel(3 downto 0);
	

end System;
