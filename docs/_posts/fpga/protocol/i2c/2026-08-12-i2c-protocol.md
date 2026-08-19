---
layout: post
title: I2C 协议层
date: 2026-08-12
categories: [fpga, protocol, i2c]
order: 1
---

- 时序
```wavedrom
{
    signal: [
        { name: "SCL", wave: "n............" },
        { name: "SDA", wave: "101100100101." },
		{ name: "SDA_D", wave: "1101100100101" },
		{ name: "SDA_NEG/START", wave: "l.hl........." },
		{ name: "SDA_POS/STOP", wave: "l..........hl" },
        { name: "SDA_DATA", wave: "x..33333333x.", data: "1 1 0 0 1 0 0 1"},
    ]
}
```

- I2C的协议时序分为4个部分：
  - 空闲状态：SCL和SDA均保持高电平，无I2C设备工作
  - 起始信号：由空闲状态开始，SCL高电平时，检测到SDA下降沿（用打一拍的方式来检测）后，表示起始信号产生，此时所有I2C设备跳出空闲状态，等待控制字节输入
  - 数据读写状态：读写数据有效阶段，固定8位
  - 停止信号：完成读写操作后，SCL高电平时，检测到SDA上升沿（用打一拍的方式来检测）后，表示停止信号产生，I2C总线跳回空闲状态

## I2C设备地址和存储地址
- 每个I2C设备在出厂前都被设置了器件地址，用户不可自主更改；器件地址一般位宽为7位，有的I2C设备的器件地址设置了全部位宽，例如OV7725、OV5640摄像头；有的I2C设备的器件地址设置了部分位宽，例如某些EEPROM存储芯片，它的器件地址只设置了高4位，剩下的低3位由用户在设计硬件时自主设置。

- 在I2C主从设备通讯时，主机在发送了起始信号后，接着会向从机发送控制命令。控制命令长度为1个字节，它的高7位为上文讲解的I2C设备的器件地址，最低位为读写控制位。读写控制位为0时，表示主机要对从机进行数据写入操作；读写控制位为1时，表示主机要对从机进行数据读出操作。

## I2C读写操作
### 写时序
- 单字节写入，单字节存储地址
```wavedrom
{
    signal: [
    { name: "SCL", wave: "n...|.....|....|.." },
    { name: "SDA", wave: "34..|564..|64..|67", data: "start device_addr r/w ack word_addr ack data ack stop"},
    ]
}
```

- 页写入，单字节存储地址
```wavedrom
{
	signal: [
		{ name: "SCL", wave: "n..|....|...|..|..|.." },
		{ name: "SDA", wave: "34.|564.|64.|6x|4.|67", data: "start device_addr r/w ack word_addr ack data(n) ack data(n+x) ack stop"},
  	]
}
```

#### 附注
  1. 所有I2C设备均支持单字节数据写入操作，但只有部分I2C设备支持页写操作；且支持页写操作的设备，一次页写操作写入的字节数不能超过设备单页包含的存储单元数
  2. 对于双字节存储地址的设备，只需把地址分两个字节发送即可

### 随机读时序
- 随机读操作，单字节地址

```wavedrom
{
  signal: [
    { name: "SCL", wave: "n..|....|..|....|..|n..|....|..|....|..|.." },
    { name: "SDA", wave: "34.|563.|6.|563.|6.|34.|563.|6.|465.|6.|67", data: "start dev_addr r/w ack word_addr ack restart dev_addr r/w ack data nack stop" }
  ]
}
```

- 随机读操作，2字节地址

```wavedrom
{
  signal: [
    { name: "SCL", wave: "n..|....|..|....|..|....|..|n..|....|..|....|..|.." },
    { name: "SDA", wave: "34.|563.|6.|563.|6.|563.|6.|34.|563.|6.|465.|6.|67", data: "start dev_addr r/w ack word_addr_h ack word_addr_l ack restart dev_addr r/w ack data nack stop" }
  ]
}
```


#### 附注
1. I2C 随机读操作本质上是一个“虚拟写 + 重启 + 读”的组合过程。它通过一个“伪写入”操作将要读取的存储地址写入从机，并不是真的要写数据，而是通过这种虚写操作使**地址指针**指向虚写操作中字地址的位置，等从机应答后，从而从指定地址读出数据
2. I2C重启条件信号（Restart Condition）：在**不释放**总线（不发送停止条件）的情况下，直接发起新一轮传输（Start）的特殊信号

### 顺序读时序
I2C顺序读操作就是对寄存器或存储单元数据的顺序读取。假如要读取n字节连续数据，只需写入要读取第一个字节数据的存储地址，就可以实现连续n字节数据的顺序读取
- 顺序读操作，单字节地址

```wavedrom
{
  signal: [
    { name: "SCL", wave: "n..|....|..|....|..|n..|....|..|....|..|x.|....|..|.." },
    { name: "SDA", wave: "34.|563.|6.|563.|6.|34.|563.|6.|465.|6.|x.|465.|6.|67", data: "start dev_addr r/w ack word_addr ack restart dev_addr r/w ack data(1) ack ... data(n) nack stop" }
  ]
}
```

- 顺序读操作，2字节地址

```wavedrom
{
  signal: [
    { name: "SCL", wave: "n..|....|..|....|..|....|..|n..|....|..|....|..|x.|....|..|.." },
    { name: "SDA", wave: "34.|563.|6.|563.|6.|563.|6.|34.|563.|6.|465.|6.|x.|465.|6.|67", data: "start dev_addr r/w ack word_addr_h ack word_addr_l ack restart dev_addr r/w ack data(1) ack ... data(n) nack stop" }
  ]
}
```

> 顺序读与随机读的区别：每读完一字节，主机回 **ACK**（不是 NACK），从机地址指针自动 +1 送出下一字节；只有读到**最后一字节**主机才回 NACK，随后发停止信号。
