/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_layernorm (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);


  wire valid = uio_in[0];
  wire start = uio_in[1];

  // State machine

  localparam STATE_IDLE = 3'd0;
  localparam STATE_MEAN = 3'd1;
  localparam STATE_VAR = 3'd2;
  localparam STATE_OUT = 3'd3;

  reg [2:0] state;

  reg signed [7:0] samples [0:7];
  reg [3:0] idx;

  reg signed [15:0] sum;
  reg signed [15:0] mean;

  reg signed [31:0] variance_sum;
  reg signed [31:0] variance;

  reg signed [15:0] centered;
  reg signed [15:0] output_data;

  assign uo_out = output_data[7:0];

  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;


  always @(posedge clk) begin
    if (!rst_n) begin
      state <= STATE_IDLE;
      idx <= 0; 
      sum <= 0;
      mean <= 0;
      variance_sum <= 0;
      variance <= 0;

      centered <= 0;
      output_data <= 0;
    end else begin
      case (state)
        STATE_IDLE: begin
          if (start) begin
            idx <= 0;
            sum <= 0;
            state <= STATE_MEAN;
          end
        end
        STATE_MEAN: begin
          if (valid) begin
              samples[idx] <= $signed(ui_in);
              sum <= sum + $signed(ui_in);

              if (idx == 7) begin
                  mean <= (sum + $signed(ui_in)) >>> 3;
                  idx <= 0;
                  variance_sum <= 0;
                  state <= STATE_VAR;
              end else begin
                  idx <= idx + 1;
              end
          end
        end 

        default: begin
          state <= STATE_IDLE;
        end
      endcase    
    end
  end 




  wire _unused = &{ena, clk, rst_n, 1'b0};

endmodule
