---
layout: post
title: Verilog 代码规范
date: 2026-09-14
categories:
  - misc
  - verilog
---
# Example with FSM

```verilog
`define RST_EN 1'b0

module UpperCamelCase#(
	parameter snake_camel_case = 8'b11110000,
	parameter allow_any_data_type = 1234
)(
	input  wire clk_sys,
	input  wire rst_sys_n,
	
	// Input
	input  wire        inst_dval,// Data Valid
	input  wire [31:0] inst_din, // Data Input
	
	// Output
	output wire        inst_dval,// Data Valid
	output wire [31:0] inst_dout // Data Ouput
);

	localparam ST_IDLE = 3'b000,
			   ST_WR   = 3'b001,
			   ST_RD   = 3'b010,
			   ST_DONE = 3'b100;
	
	reg [2:0] state_c, state_n;
	
	wire idle_wr, idle_rd, wr_done, rd_done, done_idle;
	
	always @(posedge clk_sys or negedge rst_sys_n) begin
		if (rst_sys_n == `RST_EN) 
			state_c <= ST_IDLE;
		else
			state_c <= state_n;
	end
	
	always @(*) begin
		case(state_c) begin
			ST_IDLE : state_n <= idle_wr ? ST_WR : idle_rd ? ST_RD : ST_IDLE;
			ST_WR   : state_n <= wr_done ? ST_DONE : ST_WR;
			ST_RD   : state_n <= rd_done ? ST_DONE : ST_RD;
			ST_DONE : state_n <= done_idle ? ST_IDLE : ST_DONE;
			default : state_n <= ST_IDLE;
		end
	end
	
	// Other Codes...
	
	assign idle_wr = ...;
	assign idle_wr = ...;
	assign idle_wr = ...;
	assign idle_wr = ...;

endmodule
```
