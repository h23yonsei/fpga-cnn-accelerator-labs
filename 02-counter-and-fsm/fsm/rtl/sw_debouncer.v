`timescale 1ns / 1ps

// Switch debouncer. The switch is sampled by two flip-flops on the slow clock, and the output only
// changes once both samples agree: it goes high after two high samples and low after two low ones.
module sw_debouncer (
    input  wire clk,
    input  wire sw,
    output reg  level
);

    wire sample_new;
    wire sample_old;

    dflipflop u_sample_new (
        .clk(clk),
        .d(sw),
        .q(sample_new)
    );

    dflipflop u_sample_old (
        .clk(clk),
        .d(sample_new),
        .q(sample_old)
    );

    always @(posedge clk) begin
        if (sample_new & sample_old)
            level <= 1'b1;
        else if (~sample_new & ~sample_old)
            level <= 1'b0;
    end

endmodule
