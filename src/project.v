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

    localparam STATE_IDLE      = 4'd0;
    localparam STATE_MEAN      = 4'd1;
    localparam STATE_VAR_LOAD  = 4'd2;
    localparam STATE_VAR_MUL   = 4'd3;
    localparam STATE_VAR_ACC   = 4'd4;
    localparam STATE_INV_SQRT  = 4'd5;
    localparam STATE_NORM_LOAD = 4'd6;
    localparam STATE_NORM_MUL  = 4'd7;
    localparam STATE_NORM_ACC  = 4'd8;
    localparam STATE_OUT       = 4'd9;

    reg [3:0] state;
    reg [3:0] idx;

    reg signed [7:0] sample0;
    reg signed [7:0] sample1;
    reg signed [7:0] sample2;
    reg signed [7:0] sample3;
    reg signed [7:0] sample4;
    reg signed [7:0] sample5;
    reg signed [7:0] sample6;
    reg signed [7:0] sample7;

    reg signed [7:0] current_sample;

    reg signed [10:0] sum;
    reg signed [10:0] mean;

    reg signed [13:0] variance_sum;
    reg signed [13:0] variance;

    reg signed [7:0] normalized;

    reg [8:0] mul_a;
    reg [8:0] mul_b;
    reg [17:0] mul_result;

    reg mul_sign;

    reg [8:0] inv_sqrt;

    wire signed [8:0] diff =
        $signed(current_sample) - mean;

    wire [8:0] diff_abs =
        diff < 0 ? -diff : diff;

    wire signed [17:0] norm_value =
        mul_sign
            ? -$signed(mul_result >>> 9)
            :  $signed(mul_result >>> 9);

    assign uo_out = (state == STATE_OUT)
                  ? norm_value[7:0]
                  : 8'b0;

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            idx <= 0;

            sample0 <= 0;
            sample1 <= 0;
            sample2 <= 0;
            sample3 <= 0;
            sample4 <= 0;
            sample5 <= 0;
            sample6 <= 0;
            sample7 <= 0;

            current_sample <= 0;

            sum <= 0;
            mean <= 0;

            variance_sum <= 0;
            variance <= 0;

            normalized <= 0;

            mul_a <= 0;
            mul_b <= 0;
            mul_result <= 0;
            mul_sign <= 0;

            inv_sqrt <= 0;
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
                        case (idx)
                            4'd0: sample0 <= $signed(ui_in);
                            4'd1: sample1 <= $signed(ui_in);
                            4'd2: sample2 <= $signed(ui_in);
                            4'd3: sample3 <= $signed(ui_in);
                            4'd4: sample4 <= $signed(ui_in);
                            4'd5: sample5 <= $signed(ui_in);
                            4'd6: sample6 <= $signed(ui_in);
                            4'd7: sample7 <= $signed(ui_in);
                        endcase

                        sum <= sum + $signed(ui_in);

                        if (idx == 7) begin
                            mean <= (sum + $signed(ui_in)) >>> 3;
                            idx <= 0;
                            variance_sum <= 0;
                            state <= STATE_VAR_LOAD;
                        end else begin
                            idx <= idx + 1;
                        end
                    end
                end

                STATE_VAR_LOAD: begin
                    case (idx)
                        4'd0: current_sample <= sample0;
                        4'd1: current_sample <= sample1;
                        4'd2: current_sample <= sample2;
                        4'd3: current_sample <= sample3;
                        4'd4: current_sample <= sample4;
                        4'd5: current_sample <= sample5;
                        4'd6: current_sample <= sample6;
                        4'd7: current_sample <= sample7;
                    endcase

                    state <= STATE_VAR_MUL;
                end

                STATE_VAR_MUL: begin
                    mul_a <= diff_abs;
                    mul_b <= diff_abs;
                    state <= STATE_VAR_ACC;
                end

                STATE_VAR_ACC: begin
                    mul_result <= mul_a * mul_b;
                    state <= STATE_INV_SQRT;
                end

                STATE_INV_SQRT: begin
                    variance_sum <= variance_sum + mul_result;

                    if (idx == 7) begin
                        variance <= (variance_sum + mul_result) >>> 3;

                        case ((variance_sum + mul_result) >>> 3)
                            14'd1: inv_sqrt <= 9'd511;
                            14'd2: inv_sqrt <= 9'd362;
                            14'd3: inv_sqrt <= 9'd296;
                            14'd4: inv_sqrt <= 9'd256;
                            14'd5: inv_sqrt <= 9'd229;
                            default: inv_sqrt <= 9'd0;
                        endcase

                        idx <= 0;
                        state <= STATE_NORM_LOAD;
                    end else begin
                        idx <= idx + 1;
                        state <= STATE_VAR_LOAD;
                    end
                end

                STATE_NORM_LOAD: begin
                    case (idx)
                        4'd0: current_sample <= sample0;
                        4'd1: current_sample <= sample1;
                        4'd2: current_sample <= sample2;
                        4'd3: current_sample <= sample3;
                        4'd4: current_sample <= sample4;
                        4'd5: current_sample <= sample5;
                        4'd6: current_sample <= sample6;
                        4'd7: current_sample <= sample7;
                    endcase

                    state <= STATE_NORM_MUL;
                end

                STATE_NORM_MUL: begin
                    mul_a <= diff_abs;
                    mul_b <= inv_sqrt;
                    mul_sign <= diff < 0;
                    state <= STATE_NORM_ACC;
                end

                STATE_NORM_ACC: begin
                    mul_result <= mul_a * mul_b;
                    state <= STATE_OUT;
                end

                STATE_OUT: begin
                    normalized <= norm_value[7:0];

                    if (idx == 7) begin
                        idx <= 0;
                        state <= STATE_IDLE;
                    end else begin
                        idx <= idx + 1;
                        state <= STATE_NORM_LOAD;
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