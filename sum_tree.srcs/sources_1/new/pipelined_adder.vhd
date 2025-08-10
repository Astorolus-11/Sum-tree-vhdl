--FPGA
--Autor: Gustavo Oliveira Alves
--Lista 2 - Mentoria

--BIBLIOTECAS:
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pipelined_adder IS
    GENERIC (
        DATA_WIDTH : INTEGER := 8 -- Largura em bits dos operandos de entrada
    );
    PORT (
        clk     : IN  STD_LOGIC;
        rst     : IN  STD_LOGIC; -- Reset assíncrono
        a_in    : IN  STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
        b_in    : IN  STD_LOGIC_VECTOR(DATA_WIDTH - 1 DOWNTO 0);
        sum_out : OUT STD_LOGIC_VECTOR(DATA_WIDTH DOWNTO 0) -- Saída com DATA_WIDTH + 1 bits
    );
END ENTITY pipelined_adder;

ARCHITECTURE Comportamento OF pipelined_adder IS
    -- Sinal interno para guardar o resultado da soma antes de ser registrado.
    SIGNAL s_sum_unregistered : STD_LOGIC_VECTOR(DATA_WIDTH DOWNTO 0);
BEGIN

    -- Lógica Combinacional: Realiza a soma.
    -- Redimensionamos 'a_in' para DATA_WIDTH+1 e somamos com 'b_in' (que é promovido automaticamente).
    -- Isso garante que a soma não tenha overflow dentro desta operação.
    s_sum_unregistered <= STD_LOGIC_VECTOR(RESIZE(UNSIGNED(a_in), DATA_WIDTH + 1) + UNSIGNED(b_in));

    -- Lógica Sequencial (Registrador de Pipeline)
    -- Na borda de subida do clock, o resultado da soma é capturado e enviado para a saída.
    PROCESS(clk, rst)
    BEGIN
        IF (rst = '1') THEN
            sum_out <= (OTHERS => '0');
        ELSIF (RISING_EDGE(clk)) THEN
            sum_out <= s_sum_unregistered;
        END IF;
    END PROCESS;

END Comportamento;