------------------------------------------------------------------------------
--
--  Arcade: Taito - Taito Arcade Systems FPGA Configuration for Project MiSTer
--  
--  Copyright (C) 2018 Denis Reischl
-- 
--  Project MiSTer and related files (C) 2017,2018 Sorgelig
--
--  Taito Super Qix Arcade System Configuration
--  File <SuperQix.vhd> (c) 2018 by Denis Reischl
--
--  EisernSchild/Arcade-Taito is licensed under the
--  GNU General Public License v3.0
--
------------------------------------------------------------------------------

--	Super Qix (Kaneko / Taito, 1987)
--
-- http://www.jammarcade.net/tag/super-qix/
--
--	Memory Area:main_map
--	Address Range		Length	Function					Description
--	0x0000-0x7FFF		32768		ROM	
--	0x8000-0xBFFF		16384		ROM Bank					bank1
--	0xE000-0xE0FF		256		RAM, Shared				spriteram
--	0xE100-0xE7FF		1792		RAM	
--	0xE800-0xEFFF		2048		RAM Write, Shared		superqix_videoram_w, videoram
--	0xF000-0xFFFF		4096		RAM	
--
--	Memory Area:sqix_mcu_io_map
--	Address Range		Length	Function					Description
--	0x0000				1			Read						sqix_system_status_r
--	0x0000				1			Read Port				DSW1
--	0x0000				1			Write						sqixu_mcu_p2_w
--	0x0000				1			Read/Write				sqixu_mcu_p3_r, mcu_p3_w
--
--	Memory Area:sqix_port_map
--	Address Range		Length	Function							Description
--	0x0000-0x00FF		256		RAM Device Write, Shared	palette, palette_device, write, palette
--	0x0401				1			Device Read						ay1, ay8910_device, data_r
--	0x0402-0x0403		2			Device Write					ay1, ay8910_device, data_address_w
--	0x0405				1			Device Read						ay2, ay8910_device, data_r
--	0x0406-0x0407		2			Device Write					ay2, ay8910_device, data_address_w
--	0x0408				1			Read								mcu_acknowledge_r
--	0x0410				1			Write								superqix_0410_w (/* ROM bank, NMI enable, tile bank, bitmap bank */)
--	0x0418				1			Read								nmi_ack_r
--	0x0800-0x77FF		28672		RAM Write, Shared				superqix_bitmapram_w, bitmapram
--	0x8800-0xF7FF		28672		RAM Write, Shared				superqix_bitmapram2_w, bitmapram2

--	ROM Map for this game
--	 
--	Memory Area:gfx1
--	Address Range		Length	Label/Location													Description
--	0x0000-0x7FFF		32768		"b03__04.s8"													CRC(f815ef45)
--
--	Memory Area:gfx2
--	Address Range		Length	Label/Location													Description
--	0x0000-0x1FFFF		131072	"taito_sq-iu3__lh231041__sharp_japan__8709_d.p8"	CRC(b8d0c493),Sharp LH231041 28 pin 128K x 8bit mask rom
--
--	Memory Area:gfx3
--	Address Range		Length	Label/Location													Description
--	0x0000-0xFFFF		65536		"b03__05.t8"													CRC(df326540)
--
--	Memory Area:maincpu
--	Address Range		Length	Label/Location													Description
--	0x0000-0x7FFF		32768		"b03__01-2.ef3"												CRC(5ded636b)
--	0x10000-0x1FFFF	65536		"b03__02.h3"													CRC(9c23cb64)
--
--	Memory Area:mcu
--	Address Range		Length	Label/Location													Description
--	0x0000-0x0FFF		4096		"b03__03.l2"													BAD_DUMP CRC(f0c3af2b),Original Taito ID code for this set's MCU


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.ALL;

entity SuperQix is port
(
);
end SuperQix;

architecture System of SuperQix is
begin
end System;