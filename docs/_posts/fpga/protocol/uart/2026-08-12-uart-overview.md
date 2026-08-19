---
layout: post
title: UART 概览
date: 2026-08-12
categories: [fpga, protocol, uart]
order: 0
---

# UART 接口协议

## 概述

UART（Universal Asynchronous Receiver/Transmitter，通用异步收发器）是最基础的串行通信协议之一，广泛应用于嵌入式系统中的设备间通信。

### 特点

1. 全双工通信
2. 异步通信，无需时钟线
3. 仅需两条数据线：TX（发送）和 RX（接收）
4. 通信双方需约定相同的波特率

### 常见应用

- MCU 与 PC 通信（通过 USB 转串口）
- GPS 模块数据接收
- 蓝牙/WiFi 模块 AT 指令通信
- 工业设备调试接口

## 三协议对比

UART 与 SPI、I2C 同为嵌入式最常用的三种串行接口：

| | UART | SPI | I2C |
| --- | --- | --- | --- |
| 线数 | 2（TX/RX） | 4（SCK/MOSI/MISO/CS） | 2（SDA/SCL） |
| 同步方式 | 异步（约定波特率） | 同步（时钟线） | 同步（时钟线） |
| 双工 | 全双工 | 全双工 | 半双工 |
| 寻址 | 无（点对点） | 片选 CS | 器件地址 |
| 速率 | 低 | 最高 | 中 |
| 应答 | 无 | 无 | 有（ACK） |

> 简单记忆：UART 靠"约定"，SPI 靠"片选"，I2C 靠"地址"。

## 系列导读

- 物理层：TTL/RS-232/RS-485 电平与连接 → [[UART 物理层]]
- 协议层：帧格式与采样原理 → [[UART 协议层]]
