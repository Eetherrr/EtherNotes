---
layout: post
title: Asynchronous FIFO
date: 2026-08-17
categories: [fpga, hardware, async_fifo]
tags: [fpga, fifo, hardware, async]
---

# 设计结构
## 数据通路
```mermaid
flowchart LR
    subgraph W["写侧 (wclk 域)"]
        WRQ["wrreq"] --> WR["async_fifo_wr<br/>写指针 + 满判断"]
        WD["wdata"]
    end
    subgraph R["读侧 (rclk 域)"]
        RDQ["rdreq"] --> RD["async_fifo_rd<br/>读指针 + 空判断"]
        Q["q (读数据)"]
    end
    MEM["async_fifo_mem<br/>双端口 RAM"]
    WR -- "waddr / wren" --> MEM
    WD -- wdata --> MEM
    RD -- raddr --> MEM
    MEM -- q --> Q
```
## 指针通路
```mermaid
flowchart LR
    subgraph W["写侧 (wclk 域)"]
        WPTR["格雷码 wptr (写指针)"]
        WFULL["满判断 wrfull"]
    end
    subgraph R["读侧 (rclk 域)"]
        RPTR["格雷码 rptr (读指针)"]
        REMPTY["空判断 rdempty"]
    end
    WPTR -- "wptr_gray (2级同步)" --> REMPTY
    RPTR -- "rptr_gray (2级同步)" --> WFULL
```
# 技术要点
- 双端口RAM：
	1. reg [7:0] mem [255:0]
	2. 调用IP核（移植性差）
- bin -> gray
```verilog
	assign gray_ptr = bin_ptr ^ (bin_ptr >> 1);
```
- gray -> bin
```verilog
	wire [AW:0] bin_sync;
    assign bin_sync[AW] = ptr_gray_sync[AW];// 同步后的另一侧指针
    genvar gi;
    generate
        for (gi = AW-1; gi >= 0; gi = gi - 1)
            assign bin_sync[gi] = bin_sync[gi+1] ^ ptr_gray_sync[gi];
    endgenerate
```
