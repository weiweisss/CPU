---------THIS FILE CODED IN UTF-8--------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
entity controller_pipe is --定义实体, 端口
    port (
        --输入信号
        --复位信号，低电平有效
        CLR : in STD_LOGIC;

        --运行模式:读写寄存器，读写内存，执行程序
        SWA, SWB, SWC : in STD_LOGIC;

        --指令识别
        IR7, IR6, IR5, IR4 : in STD_LOGIC;

        --机器周期:W1(始终有效)，W2(当SHORT=TRUE时被跳过)，W3(LONG=TURE时才进入)
        --T3：每个机器周期的最后一个时钟周期
        W1, W2, W3, T3 : in STD_LOGIC;

        --进位和零标识
        C, Z : in STD_LOGIC;


        --输出信号
        --总线使能
        SBUS, ABUS, MBUS : out STD_LOGIC;

        --SEL3-0，(3,2)为ALU左端口MUX输入，也是 DBUS2REGISTER 的片选信号.(1,0)为ALU右端口MUX输入
        SEL_L, SEL_R : out STD_LOGIC_VECTOR(1 downto 0);

        --写寄存器使能
        DRW : out STD_LOGIC;

        --停止产生时钟信号
        STP : out STD_LOGIC;

        --ALU运算模式
        S : out STD_LOGIC_VECTOR(3 downto 0);

        --进入控制台模式
        SELCTL : out STD_LOGIC;

        --T3上升沿写入对应的寄存器，LIR读出指令写入IR
        LAR, LDZ, LDC, LPC, LIR : out STD_LOGIC;

        --将数据写入RAM中指定地址的存储单元
        MEMW : out STD_LOGIC;

        --PCINC：PC自增，PCADD：+offset
        PCINC, PCADD : out STD_LOGIC;

        --AR自增
        ARINC : out STD_LOGIC;

        --74181进位输入信号
        CIN : out STD_LOGIC;

        --运算模式:M=0为算术运算；M=1为逻辑运算
        M : out STD_LOGIC;

        --控制指令周期中机器周期数量，SHORT=TRUE时W2被跳过，LONG=TURE时才会进入W3
        SHORT, LONG : out STD_LOGIC
    );
end controller_pipe;

architecture struct of controller_pipe is
    --定义信号
    signal SW : STD_LOGIC_VECTOR(2 downto 0);
    signal IR : STD_LOGIC_VECTOR(3 downto 0);
    signal ST0, SST0 : STD_LOGIC;
    -- ST0用于标志硬布线控制器执行控制台操作的不同阶段,ST0的状态在 T3 的下降沿时发生翻转
    -- SST0用于控制 ST0 的变化,当 SST0 = 1 且 T3 的下降沿到来时，ST0 发生翻转
begin
    --定义, 组合信号
    SW <= SWC & SWB & SWA;
    IR <= IR7 & IR6 & IR5 & IR4;
    --main process
    process (W3, W2, W1, T3, SW, IR, CLR)
    begin
        --initialization
        SBUS <= '0';
        ABUS <= '0';
        MBUS <= '0';
        SEL_L <= "00";
        SEL_R <= "00";
        DRW <= '0';
        STP <= '0';
        S <= "0000";
        SELCTL <= '0';
        LAR <= '0';
        LDZ <= '0';
        LDC <= '0';
        LPC <= '0';
        LIR <= '0';
        MEMW <= '0';
        PCINC <= '0';
        PCADD <= '0';
        ARINC <= '0';
        CIN <= '0';
        M <= '0';
        SHORT <= '0';
        LONG <= '0';

        --CLR=0 -> clear PC & IR & ST0
        if CLR = '0' then
            ST0 <= '0';
            SST0 <= '0';
            --Assign SST0 2 ST0 at T3 falling edge
        elsif falling_edge(T3) then
            if SST0 = '1' then
                ST0 <= '1';
            end if;
        end if;

        --SWCBA
        case SW is
            when "001" => --写存储器
                SBUS <= '1';
                STP <= '1';
                SHORT <= '1';
                SELCTL <= '1';
                LAR <= not ST0;
                MEMW <= ST0; --将数据写入RAM中指定地址的存储单元
                ARINC <= ST0;
                if ST0 <= '0' then
                    SST0 <= '1';
                end if;

            when "010" => --读存储器   
                SHORT <= '1';
                STP <= '1';
                SELCTL <= '1';
                SBUS <= not ST0;
                LAR <= not ST0;
                MBUS <= ST0;
                ARINC <= ST0;
                if ST0 <= '0' then
                    SST0 <= '1';
                end if;

            when "100" => --写寄存器
                SBUS <= '1';
                SEL_L(1) <= ST0; --SEL3
                SEL_L(0) <= W2; --SEL2
                SEL_R(1) <= (not ST0 and W1) or (ST0 and W2); --SEL1
                SEL_R(0) <= W1; --SEL0
                if ST0 <= '0' and W2 = '1' then
                    SST0 <= '1';
                end if;
                SELCTL <= '1';
                DRW <= '1'; -- 将数据写入寄存器
                STP <= '1';

            when "011" => --读寄存器
                SEL_L(1) <= W2;
                SEL_L(0) <= '0';
                SEL_R(1) <= W2;
                SEL_R(0) <= '1';
                SELCTL <= '1';
                STP <= '1';

            when "000" => --取指
                if ST0 = '0' then
                    LPC <= W1;
                    SBUS <= W1;
                    STP <= W1 or W2;
                    LIR <= W2;
                    PCINC <= W2;
                    if ST0 <= '0' and W2 = '1'then
                        SST0 <= '1';
                    end if;

                else
                    case IR is
                        when "0000" => --NOP
                            LIR <= W1;
                            PCINC <= W1;
                            SHORT <= W1;

                        when "0001" => --ADD
                            S <= "1001";
                            M <= 0;
                            CIN <= W1;
                            ABUS <= W1;
                            DRW <= W1; -- 将数据写入寄存器
                            LDZ <= W1;
                            LDC <= W1;
                            LIR <= W2;
                            PCINC <= W2;
                            --SHORT <= W1;

                        when "0010" => --SUB
                            S <= "0110";
                            M <= '0';
                            CIN <= '0';
                            ABUS <= W1;
                            DRW <= W1; -- 将数据写入寄存器
                            LDZ <= W1;
                            LDC <= W1;
                            LIR <= W2;
                            PCINC <= W2;
                            --SHORT <= W1;

                        when "0011" => --AND
                            M <= 1;
                            S <= "1011";
                            ABUS <= W1;
                            DRW <= W1; -- 将数据写入寄存器
                            LDZ <= W1;
                            LIR <= W1;
                            PCINC <= W1;
                            SHORT <= W1;

                        when "0100" => --INC
                            S <= "0000";
                            M <= 0;
                            ABUS <= W1;
                            CIN <= not W1;
                            DRW <= W1; -- 将数据写入寄存器
                            LDZ <= W1;
                            LDC <= W1;
                            LIR <= W1;
                            PCINC <= W1;
                            SHORT <= W1;

                        when "0101" => --LD
                            S <= "1010";
                            M <= 1;
                            ABUS <= W1;
                            LAR <= W1;
                            MBUS <= W2;
                            DRW <= W2; -- 将数据写入寄存器
                            LONG <= '1';
                            LIR <= W3;
                            PCINC <= W3;

                        when "0110" => --ST
                            M <= 1;
                            if W1 = '1' then
                                S <= "1111";
                            elsif W2 = '1' then
                                S <= "1010";
                            end if;
                            ABUS <= W1 or W2;
                            LAR <= W1;
                            MEMW <= W2; --将数据写入RAM中指定地址的存储单元
                            LIR <= W2;
                            PCINC <= W2;

                        when "0111" => --JC
                            if C = '0' then
                                LIR <= W1;
                                PCINC <= W1;
                                SHORT <= W1;
                            else
                                PCADD <= W1;
                                LIR <= W3;
                                LONG <= '1';
                                PCINC <= W3;
                            end if;

                        when "1000" => --JZ
                            if Z = '0' then
                                LIR <= W1;
                                PCINC <= W1;
                                SHORT <= W1;
                            else
                                PCADD <= W1;
                                LIR <= W3;
                                LONG <= '1';
                                PCINC <= W3;
                            end if;

                        when "1001" => --JMP
                            M <= 1;
                            S <= "1111";
                            ABUS <= W1;
                            LPC <= W1;
                            LIR <= W2;
                            PCINC <= W2;

                         when "1010" => --OUT
                            M <= 1;
                            S <= "1010";
                            ABUS <= W1;
                            LIR <= W1;
                            PCINC <= W1;
                            SHORT <= W1;

                        when "1011" => --CMP
                            S <= "0110";
                            M <= 0; --Algorithmetic
                            CIN <= 0; -- ignore carry-in
                            ABUS <= W1;
                            LDC <= W1; -- save carry flag
                            LDZ <= W1; -- save zero flag
                            LIR <= W1;
                            PCINC <= W1;
                            SHORT <= W1;

                        when "1100" => --OR
                            M <= 1;
                            S <= "1110";
                            ABUS <= W1;
                            DRW <= W1; -- 将数据写入寄存器
                            LDC <= W1;
                            LIR <= W1;
                            PCINC <= W1;
                            SHORT <= W1;

			            when "1101" => --MOV
                            M <= 1;
                            S <= "1010";
                            ABUS <= W1;
                            DRW <= W1; -- 将数据写入寄存器
                            LIR <= W1;
                            PCINC <= W1;
                            SHORT <= W1;

                        when "1110" => --STP
                            STP <= W1;

                        when "1111" => --NOT
                            M <= 1;
                            S <= "0000";
                            ABUS <= W1;
                            DRW <= W1; -- 将数据写入寄存器
                            LDC <= W1;
                            LIR <= W1;
                            PCINC <= W1;
                            SHORT <= W1;

                        when others => null;

                    end case;
                end if;
            when others => null;
        end case;
    end process;
end struct;