/*
 * Copyright (c) 2026 jakubie
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
    reg [2:0] idx;

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
    reg signed [7:0] mean;

    reg [7:0] variance_sum;

    reg [3:0] mul_a;
    reg [8:0] mul_b;
    reg [12:0] mul_result;

    reg mul_sign;

    reg [8:0] inv_sqrt;

    wire signed [10:0] sum_next = sum + $signed({{3{ui_in[7]}}, ui_in});

    wire signed [8:0] diff = $signed({current_sample[7], current_sample}) - $signed({mean[7], mean});

    wire [12:0] variance_total = {5'b0, variance_sum} + mul_result;
    wire variance_overflow = |variance_total[12:7];
    wire [7:0] variance_sum_next = variance_overflow ? 8'd128 : {1'b0, variance_total[6:0]};
    wire [3:0] variance_next = variance_overflow ? 4'd0 : variance_total[6:3];

    wire [8:0] diff_abs = diff[8] ? -diff : diff;

    wire [3:0] diff_mag = (|diff_abs[8:4]) ? 4'd15 : diff_abs[3:0];

    wire signed [7:0] norm_magnitude = $signed({4'b0, mul_result[12:9]});
    wire signed [7:0] norm_value = mul_sign ? -norm_magnitude : norm_magnitude;

    assign uo_out = (state == STATE_OUT) ? norm_value : 8'b0;

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            idx <= 3'd0;

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

            mul_a <= 0;
            mul_b <= 0;
            mul_result <= 0;
            mul_sign <= 0;

            inv_sqrt <= 0;
        end else begin
            case (state)

                STATE_IDLE: begin
                    if (start) begin
                        idx <= 3'd0;
                        sum <= 0;
                        state <= STATE_MEAN;
                    end
                end

                STATE_MEAN: begin
                    if (valid) begin
                        case (idx)
                            3'd0: sample0 <= $signed(ui_in);
                            3'd1: sample1 <= $signed(ui_in);
                            3'd2: sample2 <= $signed(ui_in);
                            3'd3: sample3 <= $signed(ui_in);
                            3'd4: sample4 <= $signed(ui_in);
                            3'd5: sample5 <= $signed(ui_in);
                            3'd6: sample6 <= $signed(ui_in);
                            3'd7: sample7 <= $signed(ui_in);
                        endcase

                        sum <= sum_next;

                        if (idx == 3'd7) begin
                            mean <= sum_next[10:3];
                            idx <= 3'd0;
                            variance_sum <= 0;
                            state <= STATE_VAR_LOAD;
                        end else begin
                            idx <= idx + 3'd1;
                        end
                    end
                end

                STATE_VAR_LOAD: begin
                    case (idx)
                        3'd0: current_sample <= sample0;
                        3'd1: current_sample <= sample1;
                        3'd2: current_sample <= sample2;
                        3'd3: current_sample <= sample3;
                        3'd4: current_sample <= sample4;
                        3'd5: current_sample <= sample5;
                        3'd6: current_sample <= sample6;
                        3'd7: current_sample <= sample7;
                    endcase

                    state <= STATE_VAR_MUL;
                end

                STATE_VAR_MUL: begin
                    mul_a <= diff_mag;
                    mul_b <= {5'b0, diff_mag};
                    state <= STATE_VAR_ACC;
                end

                STATE_VAR_ACC: begin
                    mul_result <= mul_a * mul_b;
                    state <= STATE_INV_SQRT;
                end

                STATE_INV_SQRT: begin
                    variance_sum <= variance_sum_next;

                    if (idx == 3'd7) begin
                        case (variance_next)
                            4'd1:  inv_sqrt <= 9'd511;
                            4'd2:  inv_sqrt <= 9'd362;
                            4'd3:  inv_sqrt <= 9'd296;
                            4'd4:  inv_sqrt <= 9'd256;
                            4'd5:  inv_sqrt <= 9'd229;
                            4'd6:  inv_sqrt <= 9'd209;
                            4'd7:  inv_sqrt <= 9'd194;
                            4'd8:  inv_sqrt <= 9'd181;
                            4'd9:  inv_sqrt <= 9'd171;
                            4'd10: inv_sqrt <= 9'd162;
                            4'd11: inv_sqrt <= 9'd154;
                            4'd12: inv_sqrt <= 9'd148;
                            4'd13: inv_sqrt <= 9'd142;
                            4'd14: inv_sqrt <= 9'd137;
                            4'd15: inv_sqrt <= 9'd132;
                            default: inv_sqrt <= 9'd0;
                        endcase

                        idx <= 3'd0;
                        state <= STATE_NORM_LOAD;
                    end else begin
                        idx <= idx + 3'd1;
                        state <= STATE_VAR_LOAD;
                    end
                end

                STATE_NORM_LOAD: begin
                    case (idx)
                        3'd0: current_sample <= sample0;
                        3'd1: current_sample <= sample1;
                        3'd2: current_sample <= sample2;
                        3'd3: current_sample <= sample3;
                        3'd4: current_sample <= sample4;
                        3'd5: current_sample <= sample5;
                        3'd6: current_sample <= sample6;
                        3'd7: current_sample <= sample7;
                    endcase

                    state <= STATE_NORM_MUL;
                end

                STATE_NORM_MUL: begin
                    mul_a <= diff_mag;
                    mul_b <= inv_sqrt;
                    mul_sign <= diff[8];
                    state <= STATE_NORM_ACC;
                end

                STATE_NORM_ACC: begin
                    mul_result <= mul_a * mul_b;
                    state <= STATE_OUT;
                end

                STATE_OUT: begin
                    if (idx == 3'd7) begin
                        idx <= 3'd0;
                        state <= STATE_IDLE;
                    end else begin
                        idx <= idx + 3'd1;
                        state <= STATE_NORM_LOAD;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end

            endcase
        end
    end

    wire _unused = &{ena, uio_in[7:2], 1'b0};

endmodule
