----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.11.2021 11:48:00
-- Design Name: 
-- Module Name: LineBuffer - Behavioral
-- Project Name: Sobel Processer
-- Version v2.0
-- @modified by Zijie NING & Guoxiong SUN
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY LineBuffer IS
    GENERIC (
        CONSTANT FILTER_SIZE : NATURAL;
        CONSTANT PIXEL_BW : NATURAL;
        CONSTANT IMAGE_WIDTH : NATURAL;
        CONSTANT IMAGE_HEIGHT : NATURAL
    );
    PORT (
        clk : IN STD_LOGIC;
        rst_n : IN STD_LOGIC;
        pixel_in : IN STD_LOGIC_VECTOR (PIXEL_BW - 1 DOWNTO 0); --8 bit to store 1 pix
        valid_in : IN STD_LOGIC;
        data_out : OUT STD_LOGIC_VECTOR (FILTER_SIZE * PIXEL_BW - 1 DOWNTO 0); --24
        read_en : IN STD_LOGIC
    );
END LineBuffer;

ARCHITECTURE Behavioral OF LineBuffer IS

    TYPE LineBuff IS ARRAY (0 TO IMAGE_WIDTH - 1) OF STD_LOGIC_VECTOR(PIXEL_BW-1 DOWNTO 0);
    SIGNAL LineBuffer : LineBuff;
    SIGNAL rd_ptr : INTEGER RANGE 0 TO IMAGE_WIDTH - FILTER_SIZE := 0;
    SIGNAL wr_ptr : INTEGER RANGE 0 TO IMAGE_WIDTH - 1 := 0;
    
BEGIN

    PROCESS (clk, rst_n)
    BEGIN
        -- TODO 
        IF (rst_n = '0') THEN --reset
            LineBuffer <= (OTHERS => (OTHERS => '0')); --clear the buffer
            rd_ptr <= 0;
            wr_ptr <= 0;
        ELSIF rising_edge(clk) THEN
            IF (valid_in = '1') THEN --data coming
                LineBuffer(wr_ptr) <= pixel_in; --store one pixel
                IF (wr_ptr < IMAGE_WIDTH - 1) THEN
                    wr_ptr <= wr_ptr + 1;
                ELSE
                    wr_ptr <= 0;
                END IF;
            END IF;

            IF (read_en = '1') THEN --ready to read
                IF (rd_ptr < IMAGE_WIDTH - FILTER_SIZE) THEN
                    rd_ptr <= rd_ptr + 1;
                ELSE
                    rd_ptr <= 0;
                END IF;
            END IF;
        END IF;

    END PROCESS;

    
    G_data_out : for i in 0 to FILTER_SIZE-1 generate
        data_out((i+1)*PIXEL_BW-1 downto i*PIXEL_BW) <= LineBuffer(rd_ptr+FILTER_SIZE-i-1);
    end generate G_data_out;
    
--    data_out <= LineBuffer(rd_ptr) & LineBuffer(rd_ptr + 1) & LineBuffer(rd_ptr + 2);

END Behavioral;