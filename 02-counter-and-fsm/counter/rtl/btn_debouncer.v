`timescale 1ns / 1ps

// Button debouncer and rising-edge detector. The button is sampled by two flip-flops on the slow
// clock; pulse is high for one clock period when the newer sample is high and the older one low,
// so each press produces exactly one pulse.
module btn_debouncer (
    input  wire clk,
    input  wire btn,
    output wire pulse
);

    wire sample_new;
    wire sample_old;

    dflipflop u_sample_new (
        .clk(clk),
        .d(btn),
        .q(sample_new)
    );

    dflipflop u_sample_old (
        .clk(clk),
        .d(sample_new),
        .q(sample_old)
    );

    assign pulse = sample_new & ~sample_old;

endmodule
