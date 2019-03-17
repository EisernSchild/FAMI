------------------------------------------------------------------------------
--
--  FAMI - FPGA Arcade Machine Instauration
--  
--  Copyright (C) 2018 Denis Reischl
-- 
--  Project MiSTer and related files (C) 2017,2018 Sorgelig 
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

entity emu is port
(
	-- Master input clock
	CLK_50M          : in    std_logic;

	-- Async reset from top-level module.
	-- Can be used as initial reset.
	RESET            : in    std_logic;

	-- Must be passed to hps_io module
	HPS_BUS          : inout std_logic_vector(44 downto 0);

	-- Base video clock. Usually equals to CLK_SYS.
	CLK_VIDEO        : out   std_logic;

	-- Multiple resolutions are supported using different CE_PIXEL rates.
	-- Must be based on CLK_VIDEO
	CE_PIXEL         : out   std_logic;

	-- Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	VIDEO_ARX        : out   std_logic_vector(7 downto 0);
	VIDEO_ARY        : out   std_logic_vector(7 downto 0);

	-- VGA
	VGA_R            : out   std_logic_vector(7 downto 0);
	VGA_G            : out   std_logic_vector(7 downto 0);
	VGA_B            : out   std_logic_vector(7 downto 0);
	VGA_HS           : out   std_logic; -- positive pulse!
	VGA_VS           : out   std_logic; -- positive pulse!
	VGA_DE           : out   std_logic; -- = not (VBlank or HBlank)
	VGA_F1           : out   std_logic;
	VGA_SL           : out   std_logic_vector(1 downto 0);
	
	-- LED
	LED_USER         : out   std_logic; -- 1 - ON, 0 - OFF.

	-- b[1]: 0 - LED status is system status ORed with b[0]
	--       1 - LED status is controled solely by b[0]
	-- hint: supply 2'b00 to let the system control the LED.
	LED_POWER        : out   std_logic_vector(1 downto 0);
	LED_DISK         : out   std_logic_vector(1 downto 0);

	-- AUDIO
	AUDIO_L          : out   std_logic_vector(15 downto 0);
	AUDIO_R          : out   std_logic_vector(15 downto 0);
	AUDIO_S          : out   std_logic;                    -- 1 - signed audio samples, 0 - unsigned
	AUDIO_MIX        : out   std_logic_vector(1 downto 0); -- 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	TAPE_IN          : in    std_logic;

	-- SD-SPI
	SD_SCK           : out   std_logic := 'Z';
	SD_MOSI          : out   std_logic := 'Z';
	SD_MISO          : in    std_logic;
	SD_CS            : out   std_logic := 'Z';
	SD_CD            : in    std_logic;

	-- High latency DDR3 RAM interface
	-- Use for non-critical time purposes
	DDRAM_CLK        : out   std_logic;
	DDRAM_BUSY       : in    std_logic;
	DDRAM_BURSTCNT   : out   std_logic_vector(7 downto 0);
	DDRAM_ADDR       : out   std_logic_vector(28 downto 0);
	DDRAM_DOUT       : in    std_logic_vector(63 downto 0);
	DDRAM_DOUT_READY : in    std_logic;
	DDRAM_RD         : out   std_logic;
	DDRAM_DIN        : out   std_logic_vector(63 downto 0);
	DDRAM_BE         : out   std_logic_vector(7 downto 0);
	DDRAM_WE         : out   std_logic;

	-- SDRAM interface with lower latency
	SDRAM_CLK        : out   std_logic;
	SDRAM_CKE        : out   std_logic;
	SDRAM_A          : out   std_logic_vector(12 downto 0);
	SDRAM_BA         : out   std_logic_vector(1 downto 0);
	SDRAM_DQ         : inout std_logic_vector(15 downto 0);
	SDRAM_DQML       : out   std_logic;
	SDRAM_DQMH       : out   std_logic;
	SDRAM_nCS        : out   std_logic;
	SDRAM_nCAS       : out   std_logic;
	SDRAM_nRAS       : out   std_logic;
	SDRAM_nWE        : out   std_logic;
	
	UART_CTS         : in    std_logic;
	UART_RTS         : out   std_logic;
	UART_RXD         : in    std_logic;
	UART_TXD         : out   std_logic;
	UART_DTR         : out   std_logic;
	UART_DSR         : in    std_logic;

	-- Open-drain User port.
	-- 0 - D+/RX
	-- 1 - D-/TX
	-- 2..5 - USR1..USR4
	-- Set USER_OUT to 1 to read from USER_IN.
	USER_IN          : in   std_logic_vector(5 downto 0);
	USER_OUT         : out   std_logic_vector(5 downto 0);

	OSD_STATUS       : in    std_logic
);
end emu;

architecture basic of emu is
-- menu constant strings
	constant CONF_STR : string :=
		"ROM;;" &
		"-;" &
		"FS,ROM;" &
		"-;" &
		"J,Fire 1,Fire 2,Fire 3,Start 1P,Start 2P;" &
		"-;";
--	"O1,Aspect Ratio,Original,Wide;",
--	"O2,Orientation,Vert,Horz;",
--	"O34,Scanlines(vert),No,25%,50%,75%;",
	
	constant CONF_STR2 : string :=
		"AB,Save Slot,1,2,3,4;";

	constant CONF_STR3 : string :=
		"6,Load state;";

	constant CONF_STR4 : string :=
		"7,Save state;" &
		"V,v0.01.";
		
-- "sys/pll.v" module definition in VHDL
	component pll is
	port (
		refclk   : in  std_logic; -- clk
		rst      : in  std_logic; -- reset
		outclk_0 : out std_logic; -- clk
		outclk_1 : out std_logic; -- clk
		outclk_2 : out std_logic; -- clk
		locked   : out std_logic  -- export
	);
	end component pll;
		
-- "sys/hps_io.v" module definition in VHDL		
	component hps_io generic
	(
		STRLEN : integer := 0;
		PS2DIV : integer := 1000;
		WIDE   : integer := 0;
		VDNUM  : integer := 1;
		PS2WE  : integer := 0
	);
	port
	(
		CLK_SYS           : in  std_logic;
		HPS_BUS           : inout std_logic_vector(44 downto 0);

		conf_str          : in  std_logic_vector(8*STRLEN-1 downto 0);

		buttons           : out std_logic_vector(1 downto 0);
		forced_scandoubler: out std_logic;

		joystick_0        : out std_logic_vector(15 downto 0);
		joystick_1        : out std_logic_vector(15 downto 0);
		joystick_analog_0 : out std_logic_vector(15 downto 0);
		joystick_analog_1 : out std_logic_vector(15 downto 0);
		status            : out std_logic_vector(31 downto 0);

		sd_lba            : in  std_logic_vector(31 downto 0);
		sd_rd             : in  std_logic;
		sd_wr             : in  std_logic;
		sd_ack            : out std_logic;
		sd_conf           : in  std_logic;
		sd_ack_conf       : out std_logic;

		sd_buff_addr      : out std_logic_vector(8 downto 0);
		sd_buff_dout      : out std_logic_vector(7 downto 0);
		sd_buff_din       : in  std_logic_vector(7 downto 0);
		sd_buff_wr        : out std_logic;

		img_mounted       : out std_logic;
		img_size          : out std_logic_vector(63 downto 0);
		img_readonly      : out std_logic;

		ioctl_download    : out std_logic;
		ioctl_index       : out std_logic_vector(7 downto 0);
		ioctl_wr          : out std_logic;
		ioctl_addr        : out std_logic_vector(24 downto 0);
		ioctl_dout        : out std_logic_vector(7 downto 0);
		ioctl_wait        : in  std_logic;
		
		RTC               : out std_logic_vector(64 downto 0);
		TIMESTAMP         : out std_logic_vector(32 downto 0);

		ps2_kbd_clk_out   : out std_logic;
		ps2_kbd_data_out  : out std_logic;
		ps2_kbd_clk_in    : in  std_logic;
		ps2_kbd_data_in   : in  std_logic;

		ps2_kbd_led_use   : in  std_logic_vector(2 downto 0);
		ps2_kbd_led_status: in  std_logic_vector(2 downto 0);

		ps2_mouse_clk_out : out std_logic;
		ps2_mouse_data_out: out std_logic;
		ps2_mouse_clk_in  : in  std_logic;
		ps2_mouse_data_in : in  std_logic;

		ps2_key           : out std_logic_vector(10 downto 0);
		ps2_mouse         : out std_logic_vector(24 downto 0)
	);
	end component hps_io;
	
-- module "video.sv" definition in VHDL
--lite_label : if LITE_BUILD generate
	component video is port
	(                                    
		clk : in std_logic;                
		reset_n : in std_logic;
		
		VGA_R4 : in std_logic_vector(3 downto 0);
		VGA_G4 : in std_logic_vector(3 downto 0);
		VGA_B4 : in std_logic_vector(3 downto 0);
	
		DEBUG_OUT0 : in std_logic_vector(63 downto 0);
		DEBUG_OUT1 : in std_logic_vector(63 downto 0);
		DEBUG_OUT2 : in std_logic_vector(63 downto 0);
		DEBUG_OUT3 : in std_logic_vector(63 downto 0);
		DEBUG_OUT4 : in std_logic_vector(63 downto 0);
		DEBUG_OUT5 : in std_logic_vector(63 downto 0);
		DEBUG_OUT6 : in std_logic_vector(63 downto 0);
		DEBUG_OUT7 : in std_logic_vector(63 downto 0);
		
		CE_PIXEL : out std_logic;
		VGA_HS : out std_logic;
		VGA_VS : out std_logic;
		VGA_DE : out std_logic;
		VGA_R : out std_logic_vector(7 downto 0);
		VGA_G : out std_logic_vector(7 downto 0);
		VGA_B : out std_logic_vector(7 downto 0)                                               
	);
	end component video;
--end generate;
	
-- User io helper : convert string to std_logic_vector to be given to user_io
	function to_slv(s: string) return std_logic_vector is 
	  constant ss: string(1 to s'length) := s; 
	  variable rval: std_logic_vector(1 to 8 * s'length); 
	  variable p: integer; 
	  variable c: integer; 
	begin
	  for i in ss'range loop
		 p := 8 * i;
		 c := character'pos(ss(i));
		 rval(p - 7 to p) := std_logic_vector(to_unsigned(c,8)); 
	  end loop; 
	  return rval; 
	end function; 
	
-- data fields
	signal joyA : std_logic_vector(15 downto 0);
	signal joyB : std_logic_vector(15 downto 0);
	signal joyAB : std_logic_vector(15 downto 0);
	signal buttons : std_logic_vector(1 downto 0);
	--
	signal forced_scandoubler : std_logic;
	signal ps2_kbd_clk, ps2_kbd_data : std_logic;
	signal ps2_key : std_logic_vector(10 downto 0);
	-- hps io
	signal status : std_logic_vector(31 downto 0);
	signal sd_lba : std_logic_vector(31 downto 0);
	signal sd_rd : std_logic := '0';
	signal sd_wr : std_logic := '0';
	signal sd_ack : std_logic := '0';
	signal sd_buff_addr : std_logic_vector(8 downto 0);
	signal sd_buff_dout : std_logic_vector(7 downto 0);
	signal sd_buff_din : std_logic_vector(7 downto 0);
	signal sd_buff_wr : std_logic;
	signal img_mounted : std_logic;
	signal img_readonly : std_logic;
	signal img_size : std_logic_vector(63 downto 0);

	-- clocks  
	signal clock_locked : std_logic;
	signal Clk_18432K : std_logic;
	signal Clk : std_logic;
	signal Clk_6144K : std_logic;
	
	-- video
	signal VGA_R3, VGA_G3 : std_logic_vector(2 downto 0);
	signal VGA_B2 : std_logic_vector(1 downto 0);
	signal HS_CORE, VS_CORE, Cs_CORE : std_logic;
	signal HS, VS, DE : std_logic;
	
	-- Audio
	signal AUDIO_L8, AUDIO_R8 : std_logic_vector(7 downto 0);
	
	-- debug
	signal RegData_cpu  : std_logic_vector(111 downto 0);
	signal Debug_cpu : std_logic_vector(15 downto 0);
	
begin
-- assigning audio
	AUDIO_S   <= '0';
	AUDIO_L   <= (AUDIO_L8 & AUDIO_L8);
	AUDIO_R   <= (AUDIO_R8 & AUDIO_R8);
	AUDIO_MIX <= "00";
	
-- assigning LEDs
	LED_USER  <= '0';
	LED_DISK  <= "00";
	LED_POWER <= "00";
	
-- assigning video streching, pixel enabled and clock
	VIDEO_ARX <= x"10";-- when (status(8) = '1') else x"04";
	VIDEO_ARY <= x"09";-- when (status(8) = '1') else x"03";
	CLK_VIDEO <= Clk_6144K;
	VGA_HS <= HS;
	VGA_VS <= VS;
	VGA_DE <= DE;
	
-- assigning DDRAM (zero)
	DDRAM_CLK      <= '0';
	DDRAM_BURSTCNT <= (others => '0');
	DDRAM_ADDR     <= (others => '0');
	DDRAM_DIN      <= (others => '0');
	DDRAM_BE       <= (others => '0');
	DDRAM_RD       <= '0';
	DDRAM_WE       <= '0';
		
-- assigning SD card SPI mode (z-high impedance)
	SD_SCK         <= 'Z';
	SD_MOSI        <= 'Z';
	SD_CS          <= 'Z';
	
-- assigning joy a+b
	joyAB <= joyA or joyB;
	
-- sys/hps_io implementation (User io)
	hps : hps_io
	generic map (STRLEN => (CONF_STR'length) + (CONF_STR2'length) + (CONF_STR3'length) + (CONF_STR4'length))
	port map (
		clk_sys => Clk,
		HPS_BUS => HPS_BUS,
		conf_str => to_slv(CONF_STR & CONF_STR2 & CONF_STR3 & CONF_STR4),
	
		buttons => buttons,
		forced_scandoubler => forced_scandoubler,
	
		joystick_0 => joyA,
		joystick_1 => joyB,
	
		status => status,
			
		sd_lba => sd_lba,
		sd_rd => sd_rd,
		sd_wr => sd_wr,
		sd_ack => sd_ack,
		sd_buff_addr => sd_buff_addr,
		sd_buff_dout => sd_buff_dout,
		sd_buff_din => sd_buff_din,
		sd_buff_wr => sd_buff_wr,
		
		img_mounted => img_mounted,
		img_readonly => img_readonly,
		img_size => img_size,
	
		ps2_key => ps2_key,
		ps2_kbd_led_use => "000",
		ps2_kbd_led_status => "000",
			
		--left blank
		ioctl_wait         => '0',
		sd_conf            => '0',
		ps2_kbd_clk_in     => '0',
		ps2_kbd_data_in    => '0',
		ps2_mouse_clk_in   => '0',
		ps2_mouse_data_in  => '0'
	);
	
-- sys/pll implementation =>phase-locked loop )
	mainpll : pll
	port map(
		refclk   => CLK_50M,
		rst      => '0',
		outclk_0 => Clk_18432K,
		outclk_1 => Clk,
		outclk_2 => Clk_6144K,
		locked   => clock_locked
	);
	
-- module file "video.sv" implementation
	video1 : video
	port map
	(                                    
		clk => Clk_6144K,                
		reset_n => '1',--(not reset),

		VGA_R4 => VGA_R3 & VGA_R3(2),
		VGA_G4 => VGA_G3 & VGA_G3(2),
		VGA_B4 => VGA_B2 & VGA_B2,
		
		DEBUG_OUT0 => RegData_cpu(111 downto 48),
		DEBUG_OUT1 => RegData_cpu(47 downto 0) & Debug_cpu,
		DEBUG_OUT2 => X"0000000000000000",
		DEBUG_OUT3 => X"0000000000000000",
		DEBUG_OUT4 => X"0000000000000000",
		DEBUG_OUT5 => X"0000000000000000",
		DEBUG_OUT6 => X"0000000000000000",
		DEBUG_OUT7 => X"0000000000000000",
		
		CE_PIXEL => CE_PIXEL,
		VGA_HS => HS,
		VGA_VS => VS,
		VGA_DE => DE,
		VGA_R => VGA_R,
		VGA_G => VGA_G,
		VGA_B => VGA_B
	);
	
-- Systems

	-- System Framebuffer
	System_Framebuffer : entity work.Framebuffer
	port map(	
		i_Clk_18432K => Clk_18432K,    -- clock 6.144 Mhz
		i_Clk_6144K => Clk_6144K,    -- clock 1.536 Mhz
		i_Reset     =>	RESET,        -- reset when 1
		
		i_btn_flash_bomb => joyAB(5),
		i_btn_fire_left  => joyAB(4),
		i_btn_fire_right => joyAB(6),
		i_btn_down       => joyAB(2),
		i_btn_up         => joyAB(3),
		i_btn_left       => joyAB(1),
		i_btn_right      => joyAB(0),
		
		i_btn_left_coin   => joyAB(7) or joyAB(8),
		i_btn_one_player  => joyAB(7),
		i_btn_two_players => joyAB(8),
		
		o_RegData_cpu => RegData_cpu,
		o_Debug_cpu => Debug_cpu,
		
		o_VGA_R3 => VGA_R3, -- Red Color 3Bits
		o_VGA_G3 => VGA_G3, -- Green Color 3Bits
		o_VGA_B2 => VGA_B2  -- Blue Color 2Bits
	);

end basic;