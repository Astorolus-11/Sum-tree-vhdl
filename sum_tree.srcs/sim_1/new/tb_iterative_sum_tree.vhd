--FPGA
--Autor: Gustavo Oliveira Alves
--Lista 2 - Mentoria

--BIBLIOTECAS:
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.MATH_REAL.ALL; -- Utiliza fun��es, como log2 e ceil

--ENTIDADE:
ENTITY tb_iterative_sum_tree IS
END ENTITY tb_iterative_sum_tree;

ARCHITECTURE Comportamento OF tb_iterative_sum_tree IS

    -- Par�metros do teste (devem ser os mesmos da DUT)
    CONSTANT N : INTEGER := 8;
    CONSTANT M : INTEGER := 4;

    -- Calcula a lat�ncia e a largura da sa�da para o teste
    CONSTANT LATENCY   : INTEGER := INTEGER(CEIL(LOG2(real(N))));
    CONSTANT OUT_WIDTH : INTEGER := M + LATENCY;

    -- Sinais para conectar � DUT (Device Under Test)
    SIGNAL clk     : STD_LOGIC := '0';
    SIGNAL rst     : STD_LOGIC;
    SIGNAL data_in : STD_LOGIC_VECTOR(N * M - 1 DOWNTO 0);
    SIGNAL sum_out : STD_LOGIC_VECTOR(OUT_WIDTH - 1 DOWNTO 0);

BEGIN

    -- Instancia��o 
    UUT: ENTITY WORK.iterative_sum_tree
        GENERIC MAP (
            N => N,
            M => M
        )
        PORT MAP (
            clk     => clk,
            rst     => rst,
            data_in => data_in,
            sum_out => sum_out
        );

    -- Gera��o do Clock (per�odo de 10 ns)
    clk <= NOT clk AFTER 5 ns;

    -- Processo de est�mulo
    stimulus: PROCESS
        
        -- Teste 1: 1+2+3+4+5+6+7+8 = 36
        CONSTANT expected_sum_1 : UNSIGNED(OUT_WIDTH - 1 DOWNTO 0) := TO_UNSIGNED(36, OUT_WIDTH);
        -- Teste 2: 8 * 15 = 120, 8+8+8+8+8+8+8+8+8+8+8+8+8+8+8
        CONSTANT expected_sum_2 : UNSIGNED(OUT_WIDTH - 1 DOWNTO 0) := TO_UNSIGNED(120, OUT_WIDTH); 
    BEGIN
        -- Parte sequ�ncial
        
        --Reset
        rst <= '1';
        WAIT FOR 12 ns;
        rst <= '0';
        WAIT FOR 10 ns;

        -- Teste 1: Somar 1+2+3+4+5+6+7+8
        REPORT "INICIANDO TESTE: Somando 1 a 8..."; --VERIFICAR NO TCL
        data_in <= x"87654321"; -- M=4 bits
        
        -- Espera a lat�ncia de 3 ciclos
        WAIT FOR LATENCY * 10 ns;

        -- Verifica��o do resultado:
        ASSERT UNSIGNED(sum_out) = expected_sum_1
            REPORT "FALHA NO TESTE 1! Esperado: " & to_string(to_INTEGER(expected_sum_1)) & 
                   ", Recebido: " & to_string(to_INTEGER(UNSIGNED(sum_out))) --VERIFICAR NO TCL
            SEVERITY error;
        REPORT "SUCESSO NO TESTE 1!";
        
        WAIT FOR 50 ns;
        
        -- Teste 2: Todos os operandos com valor m�ximo (15)
        REPORT "INICIANDO TESTE: Somando 8 elementos com valor 15";
        data_in <= x"FFFFFFFF";
        
        -- Espera a lat�ncia
        WAIT FOR LATENCY * 10 ns;

        -- 5. Verifica��o do resultado
        ASSERT UNSIGNED(sum_out) = expected_sum_2
            REPORT "FALHA NO TESTE 2! Esperado: " & to_string(to_INTEGER(expected_sum_2)) & 
                   ", Recebido: " & to_string(to_INTEGER(UNSIGNED(sum_out)))
            SEVERITY error;
        REPORT "SUCESSO NO TESTE 2!";
        
        REPORT "Simula��o conclu�da." SEVERITY note;
        WAIT; -- Fim da simula��o
    END PROCESS stimulus;

END Comportamento;