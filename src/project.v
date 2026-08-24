/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_layernorm (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,

    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,

    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire valid = uio_in[0];
    wire start = uio_in[1];

    localparam STATE_IDLE = 3'd0;
    localparam STATE_MEAN = 3'd1;
    localparam STATE_VAR  = 3'd2;
    localparam STATE_OUT  = 3'd3;

    reg [2:0] state;
    reg signed [7:0] samples [0:7];
    reg [3:0] idx;
    reg signed [15:0] sum;
    reg signed [15:0] mean;
    reg signed [31:0] variance_sum;
    reg signed [31:0] variance;
    reg signed [15:0] centered;

    assign uo_out = (state == STATE_OUT)
                  ? (samples[idx] - mean)
                  : 8'b0;

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
                            mean <=
                                (sum + $signed(ui_in)) >>> 3;
                            idx <= 0;
                            variance_sum <= 0;
                            state <= STATE_VAR;
                        end else begin
                            idx <= idx + 1;
                        end
                    end
                end

                STATE_VAR: begin
                    centered <= samples[idx] - mean;
                    variance_sum <=
                        variance_sum +
                        (samples[idx] - mean) *
                        (samples[idx] - mean);
                    if (idx == 7) begin
                        variance <=
                            (
                                variance_sum +
                                (samples[idx] - mean) *
                                (samples[idx] - mean)
                            ) >>> 3;
                        idx <= 0;
                        state <= STATE_OUT;
                    end else begin
                        idx <= idx + 1;
                    end
                end

                STATE_OUT: begin
                    if (idx == 7) begin
                        idx <= 0;
                        state <= STATE_IDLE;
                    end else begin
                        idx <= idx + 1;
                    end
                end
                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

    wire _unused = ena;

endmodule