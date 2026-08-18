

# SPI 协议层详解

## 时钟极性与时钟相位
- 时钟极性：决定 SPI 空闲时的时钟信号是**高电平**（CPOL=1）还是**低电平**（CPOL=0）
- 时钟相位：决定 SPI 总线从 SCK 的**第1个**跳变沿（CPHA=0）还是**第2个**跳变沿（CPHA=1）开始采样数据

### SPI 传输模式
- CPOL与CPHA共同决定SPI的四种模式
- 模式 0：CPOL = 0，CPHA = 0；sclk 上升沿采样，sclk 下降沿发送
- 模式 1：CPOL = 0，CPHA = 1；sclk 上升沿发送，sclk 下降沿采样
- 模式 2：CPOL = 1，CPHA = 0；sclk 下降沿采样，sclk 上升沿发送
- 模式 3：CPOL = 1，CPHA = 1；sclk 下降沿发送，sclk 上升沿采样
## 数据传输时序

