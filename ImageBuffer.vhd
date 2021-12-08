----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 24.11.2021 08:44:34
-- Design Name: 
-- Module Name: ImageBuffer - Behavioral
-- Project Name: Sobel Processer
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- modified by Zijie NING & Guoxiong SUN
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

ENTITY ImageBuffer IS
    GENERIC (
        CONSTANT PIXEL_BW : NATURAL;
        CONSTANT IMAGE_WIDTH : NATURAL;
        CONSTANT IMAGE_HEIGHT : NATURAL
    );
    PORT (
        clk : IN STD_LOGIC;
        rst_n : IN STD_LOGIC;
        pixel_in : IN STD_LOGIC_VECTOR (PIXEL_BW - 1 DOWNTO 0); --8 bit to store 1 pix
        valid_in : IN STD_LOGIC;
        neighbourhood_out : OUT STD_LOGIC_VECTOR (9 * PIXEL_BW - 1 DOWNTO 0); --72
        valid_out : OUT STD_LOGIC
    );

END ImageBuffer;

ARCHITECTURE Behavioral OF ImageBuffer IS

    COMPONENT LineBuffer IS
        GENERIC (
            CONSTANT PIXEL_BW : NATURAL;
            CONSTANT IMAGE_WIDTH : NATURAL;
            CONSTANT IMAGE_HEIGHT : NATURAL
        );
        PORT (
            clk : IN STD_LOGIC;
            rst_n : IN STD_LOGIC;
            pixel_in : IN STD_LOGIC_VECTOR (PIXEL_BW - 1 DOWNTO 0); --8 bit to store 1 pix
            valid_in : IN STD_LOGIC;
            data_out : OUT STD_LOGIC_VECTOR (3 * PIXEL_BW - 1 DOWNTO 0);
            read_en : IN STD_LOGIC
        );
    END COMPONENT LineBuffer;

    SIGNAL data_out_0, data_out_1, data_out_2, data_out_3 : STD_LOGIC_VECTOR(3 * PIXEL_BW - 1 DOWNTO 0); --output of each linebuffer
    SIGNAL valid_0, valid_1, valid_2, valid_3 : STD_LOGIC; --valid write for each linebuffer
    SIGNAL read_en_0, read_en_1, read_en_2, read_en_3 : STD_LOGIC; --valid write for each linebuffer
    SIGNAL LineBuffer_rd_ptr : STD_LOGIC_VECTOR (1 DOWNTO 0) := "00"; --which buffer will be read
    SIGNAL LineBuffer_wr_ptr : STD_LOGIC_VECTOR (1 DOWNTO 0) := "00"; --which buffer will be written
    SIGNAL count_read : INTEGER RANGE 0 TO IMAGE_WIDTH - 3 := 0; --which pixel to read in the line
    SIGNAL count_write : INTEGER RANGE 0 TO IMAGE_WIDTH - 1 := 0; --which pixel to write in the line
    SIGNAL count_read_line : INTEGER RANGE 0 TO IMAGE_HEIGHT - 1 := 0; --which line to read
    SIGNAL count_write_line : INTEGER RANGE 0 TO IMAGE_HEIGHT - 1 := 0; --which line to write

BEGIN
    LineBuffer_0 : LineBuffer
    GENERIC MAP(
        PIXEL_BW => PIXEL_BW,
        IMAGE_WIDTH => IMAGE_WIDTH,
        IMAGE_HEIGHT => IMAGE_HEIGHT
    )
    PORT MAP(
        clk => clk,
        rst_n => rst_n,
        pixel_in => pixel_in,
        valid_in => valid_0,
        data_out => data_out_0,
        read_en => read_en_0
    );
    LineBuffer_1 : LineBuffer
    GENERIC MAP(
        PIXEL_BW => PIXEL_BW,
        IMAGE_WIDTH => IMAGE_WIDTH,
        IMAGE_HEIGHT => IMAGE_HEIGHT
    )
    PORT MAP(
        clk => clk,
        rst_n => rst_n,
        pixel_in => pixel_in,
        valid_in => valid_1,
        data_out => data_out_1,
        read_en => read_en_1
    );

    LineBuffer_2 : LineBuffer
    GENERIC MAP(
        PIXEL_BW => PIXEL_BW,
        IMAGE_WIDTH => IMAGE_WIDTH,
        IMAGE_HEIGHT => IMAGE_HEIGHT
    )
    PORT MAP(
        clk => clk,
        rst_n => rst_n,
        pixel_in => pixel_in,
        valid_in => valid_2,
        data_out => data_out_2,
        read_en => read_en_2
    );

    LineBuffer_3 : LineBuffer
    GENERIC MAP(
        PIXEL_BW => PIXEL_BW,
        IMAGE_WIDTH => IMAGE_WIDTH,
        IMAGE_HEIGHT => IMAGE_HEIGHT
    )
    PORT MAP(
        clk => clk,
        rst_n => rst_n,
        pixel_in => pixel_in,
        valid_in => valid_3,
        data_out => data_out_3,
        read_en => read_en_3
    );

    proc_write : PROCESS (clk, rst_n)
    BEGIN
        IF (rst_n = '0') THEN
            valid_0 <= '0';
            valid_1 <= '0';
            valid_2 <= '0';
            valid_3 <= '0';
            LineBuffer_rd_ptr <= "00";
            LineBuffer_wr_ptr <= "00";
        ELSIF (rising_edge(clk) AND ((count_write_line - count_read_line = 3) OR count_write_line <= 3) AND count_write <= IMAGE_HEIGHT) THEN
            IF (valid_in = '1') THEN
                CASE LineBuffer_wr_ptr IS
                    WHEN "00" => valid_0 <= '1';
                        valid_1 <= '0';
                        valid_2 <= '0';
                        valid_3 <= '0';
                    WHEN "01" => valid_1 <= '1';
                        valid_0 <= '0';
                        valid_2 <= '0';
                        valid_3 <= '0';
                    WHEN "10" => valid_2 <= '1';
                        valid_0 <= '0';
                        valid_1 <= '0';
                        valid_3 <= '0';
                    WHEN "11" => valid_3 <= '1';
                        valid_0 <= '0';
                        valid_1 <= '0';
                        valid_2 <= '0';
                    WHEN OTHERS => valid_0 <= '0';
                        valid_1 <= '0';
                        valid_2 <= '0';
                        valid_3 <= '0';
                END CASE;
            ELSE
                valid_0 <= '0';
                valid_1 <= '0';
                valid_2 <= '0';
                valid_3 <= '0';
            END IF;

        END IF;
    END PROCESS proc_write;

    increment_LineBuffer_wr_ptr : PROCESS (clk, rst_n)
    BEGIN
        IF (rst_n = '0') THEN
            count_write <= 0;
            count_write_line <= 0;
        ELSIF (rising_edge(clk) AND valid_in = '1') THEN
            IF (count_write = IMAGE_WIDTH - 1) THEN
                count_write <= 0;
                count_write_line <= count_write_line + 1;
                CASE LineBuffer_wr_ptr IS
                    WHEN "00" => LineBuffer_wr_ptr <= "01";
                    WHEN "01" => LineBuffer_wr_ptr <= "10";
                    WHEN "10" => LineBuffer_wr_ptr <= "11";
                    WHEN OTHERS => LineBuffer_wr_ptr <= "00";
                END CASE;
            ELSE
                count_write <= count_write + 1;
            END IF;
        END IF;

    END PROCESS increment_LineBuffer_wr_ptr;

    proc_read : PROCESS (clk, rst_n)
    BEGIN
        IF (rst_n = '0') THEN
            read_en_0 <= '0';
            read_en_1 <= '0';
            read_en_2 <= '0';
            read_en_3 <= '0';
            neighbourhood_out <= (OTHERS => '0');
            valid_out <= '0';
        ELSIF (rising_edge(clk) AND (count_write_line - count_read_line >= 3)) THEN --if 3 lines are filled

            CASE LineBuffer_rd_ptr IS
                WHEN "00" => read_en_0 <= '1';
                    read_en_1 <= '1';
                    read_en_2 <= '1';
                    read_en_3 <= '0';
                    neighbourhood_out <= data_out_0 & data_out_1 & data_out_2;
                    valid_out <= '1';
                WHEN "01" => read_en_1 <= '1';
                    read_en_0 <= '0';
                    read_en_2 <= '1';
                    read_en_3 <= '1';
                    neighbourhood_out <= data_out_1 & data_out_2 & data_out_3;
                    valid_out <= '1';
                WHEN "10" => read_en_2 <= '1';
                    read_en_0 <= '1';
                    read_en_1 <= '0';
                    read_en_3 <= '1';
                    neighbourhood_out <= data_out_2 & data_out_3 & data_out_0;
                    valid_out <= '1';
                WHEN "11" => read_en_3 <= '1';
                    read_en_0 <= '1';
                    read_en_1 <= '1';
                    read_en_2 <= '0';
                    neighbourhood_out <= data_out_3 & data_out_0 & data_out_1;
                    valid_out <= '1';
                WHEN OTHERS => read_en_0 <= '0';
                    read_en_1 <= '0';
                    read_en_2 <= '0';
                    read_en_3 <= '0';
                    neighbourhood_out <= (OTHERS => '0');
                    valid_out <= '0';
            END CASE;

        END IF;
    END PROCESS proc_read;

    increment_LineBuffer_rd_ptr : PROCESS (clk, rst_n)
    BEGIN
        IF (rst_n = '0') THEN
            count_read <= 0;
            count_read_line <= 0;
        ELSIF (rising_edge(clk) AND (count_write_line - count_read_line >= 3)) THEN --same as proc_read
            IF (count_read = IMAGE_WIDTH - 3) THEN
                count_read <= 0;
                count_read_line <= count_read_line + 1;
                CASE LineBuffer_rd_ptr IS
                    WHEN "00" => LineBuffer_rd_ptr <= "01";
                    WHEN "01" => LineBuffer_rd_ptr <= "10";
                    WHEN "10" => LineBuffer_rd_ptr <= "11";
                    WHEN OTHERS => LineBuffer_rd_ptr <= "00";
                END CASE;
            ELSE
                count_read <= count_read + 1;
            END IF;
        END IF;
    END PROCESS increment_LineBuffer_rd_ptr;
END Behavioral;