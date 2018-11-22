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
      cpu_Clk1250K : in std_logic; -- 2 x M6809 @ 1.25Mhz (& All but Qix/Qix2 have a M68705 @ 1Mhz as well) 
		apu_Clk9216K : in std_logic  -- Sound CPU : M6802 @ 921.6 Khz 
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

begin



end System;