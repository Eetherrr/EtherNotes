---
layout: post
title: I2C 实现
date: 2026-08-12
categories: [fpga, protocol, i2c]
order: 3
---

# 主机控制的Verilog实现
采用两级状态机架构，用于实现 I2C 总线协议的单字节读写、启动和停止操作
```verilog
module i2c_master #(
	parameter SYS_FREQ = 50_000_000
    parameter I2C_FREQ = 100_000  // I2C时钟频率 (Hz)
) (
    input wire clk,
    input wire rst_n,
    input wire req,
    
    input wire [3:0] cmd,  // 命令: bit0=START, bit1=WRITE, bit2=READ, bit3=STOP
    input wire [7:0] din,

    output reg [7:0] dout,
    output reg       done,
    output reg       slave_ack,
    
    output wire i2c_scl,
    inout  wire i2c_sda
);

    // 参数定义
    localparam CMD_START = 4'b0001,
        CMD_WRITE = 4'b0010, CMD_READ = 4'b0100, CMD_STOP = 4'b1000;

    // 时钟参数
    localparam CNT_MAX = SYS_FREQ / I2C_FREQ;
    localparam HALF = CNT_MAX / 2;

    // 主状态机
    localparam M_IDLE = 0,
        M_START = 1, M_WRITE = 2, M_READ = 3, M_ACK = 4, M_STOP = 5;
    reg [2:0] main_state;

    // 位状态机
    localparam B_IDLE = 0,
        B_START = 1, B_SEND = 2, B_RECV = 3, B_ACK = 4, B_STOP = 5;
    reg [2:0] bit_state;

    // 内部信号
    reg [3:0] current_cmd;
    reg [7:0] tx_data;
    reg [7:0] rx_data;

    reg sda_out;
    reg sda_oe;
    reg scl_reg;

    reg [3:0] bit_cnt;
    localparam TIMER_W = $clog2(CNT_MAX);
    reg [TIMER_W-1:0] timer;

    reg bit_done;
    reg ack_recv;

    // 三态门
    assign i2c_sda = sda_oe ? sda_out : 1'bz;
    assign i2c_scl = scl_reg;

    // 边沿检测
    reg req_d;
    wire req_rise;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) req_d <= 1'b0;
        else req_d <= req;
    end
    assign req_rise = req & ~req_d;

    // 主状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            main_state  <= M_IDLE;
            current_cmd <= 4'b0;
            tx_data     <= 8'b0;
            done        <= 1'b0;
            slave_ack   <= 1'b1;
        end else begin
            done <= 1'b0;
            case (main_state)
                M_IDLE: begin
                    if (req_rise) begin
                        current_cmd <= cmd;
                        tx_data     <= din;
                        if (cmd & CMD_START) main_state <= M_START;
                        else if (cmd & CMD_WRITE) main_state <= M_WRITE;
                        else if (cmd & CMD_READ) main_state <= M_READ;
                    end
                end
                M_START: begin
                    if (bit_done) begin
                        if (current_cmd & CMD_WRITE) main_state <= M_WRITE;
                        else if (current_cmd & CMD_READ) main_state <= M_READ;
                    end
                end
                M_WRITE: begin
                    if (bit_done) main_state <= M_ACK;
                end
                M_READ: begin
                    if (bit_done) begin
                        dout       <= rx_data;
                        main_state <= M_ACK;
                    end
                end
                M_ACK: begin
                    if (bit_done) begin
                        slave_ack <= ack_recv;
                        if (current_cmd & CMD_STOP) main_state <= M_STOP;
                        else main_state <= M_IDLE;
                        done <= 1'b1;
                    end
                end
                M_STOP: begin
                    if (bit_done) begin
                        main_state <= M_IDLE;
                        done       <= 1'b1;
                    end
                end
                default: main_state <= M_IDLE;
            endcase
        end
    end

    // 位状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_state <= B_IDLE;
            timer     <= 0;
            bit_cnt   <= 0;
            rx_data   <= 0;
            sda_out   <= 1;
            sda_oe    <= 0;
            scl_reg   <= 1;
            bit_done  <= 0;
            ack_recv  <= 1;
        end else begin
            bit_done <= 0;
            case (bit_state)
                B_IDLE: begin
                    if (main_state != M_IDLE && !bit_done) begin
                        case (main_state)
                            M_START: bit_state <= B_START;
                            M_WRITE: bit_state <= B_SEND;
                            M_READ:  bit_state <= B_RECV;
                            M_ACK:   bit_state <= B_ACK;
                            M_STOP:  bit_state <= B_STOP;
                        endcase
                        timer   <= 0;
                        bit_cnt <= 0;
                    end
                end
                B_START: begin
                    if (timer < HALF) begin
                        scl_reg <= 1;
                        sda_out <= 1;
                        sda_oe  <= 1;
                    end else begin
                        scl_reg <= 1;
                        sda_out <= 0;
                        sda_oe  <= 1;
                    end
                    if (timer == CNT_MAX - 1) begin
                        bit_state <= B_IDLE;
                        bit_done  <= 1;
                        scl_reg   <= 0;
                    end else timer <= timer + 1;
                end
                B_SEND: begin
                    if (timer < HALF) scl_reg <= 0;
                    else scl_reg <= 1;
                    if (timer == 0) begin
                        sda_out <= tx_data[7-bit_cnt];
                        sda_oe  <= 1;
                    end
                    if (timer == CNT_MAX - 1) begin
                        if (bit_cnt == 7) begin
                            bit_state <= B_IDLE;
                            bit_done  <= 1;
                            scl_reg   <= 0;
                        end else bit_cnt <= bit_cnt + 1;
                        timer <= 0;
                    end else timer <= timer + 1;
                end
                B_RECV: begin
                    if (timer < HALF) scl_reg <= 0;
                    else scl_reg <= 1;
                    if (timer == 0) sda_oe <= 0;
                    if (timer == HALF + HALF / 2) rx_data[7-bit_cnt] <= i2c_sda;
                    if (timer == CNT_MAX - 1) begin
                        if (bit_cnt == 7) begin
                            bit_state <= B_IDLE;
                            bit_done  <= 1;
                            scl_reg   <= 0;
                        end else bit_cnt <= bit_cnt + 1;
                        timer <= 0;
                    end else timer <= timer + 1;
                end
                B_ACK: begin
                    if (timer < HALF) scl_reg <= 0;
                    else scl_reg <= 1;
                    if (timer == 0) sda_oe <= 0;
                    if (timer == HALF + HALF / 2) ack_recv <= i2c_sda;
                    if (timer == CNT_MAX - 1) begin
                        bit_state <= B_IDLE;
                        bit_done  <= 1;
                        scl_reg   <= 0;
                        timer     <= 0;
                    end else timer <= timer + 1;
                end
                B_STOP: begin
                    if (timer < HALF) begin
                        scl_reg <= 0;
                        sda_out <= 0;
                        sda_oe  <= 1;
                    end else begin
                        scl_reg <= 1;
                        sda_out <= 0;
                        sda_oe  <= 1;
                    end
                    if (timer == CNT_MAX - 1) begin
                        bit_state <= B_IDLE;
                        bit_done  <= 1;
                        sda_oe    <= 0;
                        timer     <= 0;
                    end else timer <= timer + 1;
                end
                default: bit_state <= B_IDLE;
            endcase
        end
    end
endmodule
```
