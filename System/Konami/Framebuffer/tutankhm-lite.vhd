------------------------------------------------------------------------------
--
--  FAMI - FPGA Arcade Machine Instauration
--  
--  Copyright (C) 2018 Denis Reischl
-- 
--  Project MiSTer and related files (C) 2017,2018 Sorgelig
--
--  Konami Framebuffer Arcade System Configuration
--  File <tutankhm-lite.vhd> (c) 2019 by Denis Reischl
--
--  EisernSchild/FAMI is licensed under the
--  GNU General Public License v3.0
--
------------------------------------------------------------------------------

package FAMI_package is

	-- game rom name, lite build enabled, game >Tutankham<
	type game_rom_enum is (junofrst, tutankhm);
	constant LITE_BUILD : boolean := true;
	constant JUNO_FIRST : boolean := false;
	constant TUTANKHAM : boolean := true;
	constant GAME_ROM : game_rom_enum := tutankhm;
	
end package;