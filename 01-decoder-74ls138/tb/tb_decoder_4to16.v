`timescale 1ns / 1ps

// Testbench for a 4-to-16 decoder built from two gate-level 74LS138s. D selects the enabled chip
// (G1 = ~D for the low half, G1 = D for the high half). With G2A = G2B = 0, only y[{D, C, B, A}] is
// low; if either G2 input is high, every output stays high.
module tb_decoder_4to16;

    reg         A, B, C, D;
    reg         G2A, G2B;
    wire [7:0]  y_low, y_high;
    wire [15:0] y = {y_high, y_low};

    integer errors = 0;
    integer checks = 0;
    integer code, g2;

    decoder_74ls138_gates u_low (
        .G1(~D), .G2A(G2A), .G2B(G2B),
        .A(A), .B(B), .C(C),
        .Y(y_low)
    );

    decoder_74ls138_gates u_high (
        .G1(D), .G2A(G2A), .G2B(G2B),
        .A(A), .B(B), .C(C),
        .Y(y_high)
    );

    task check;
        reg [15:0] exp;
        begin
            exp = (!G2A && !G2B) ? ~(16'b1 << {D, C, B, A}) : 16'hFFFF;
            checks = checks + 1;
            if (y !== exp) begin
                errors = errors + 1;
                $display("MISMATCH G2A=%b G2B=%b DCBA=%b%b%b%b: y=%b expected=%b",
                         G2A, G2B, D, C, B, A, y, exp);
            end
        end
    endtask

    initial begin
        for (g2 = 0; g2 < 4; g2 = g2 + 1) begin
            for (code = 0; code < 16; code = code + 1) begin
                {G2A, G2B} = g2[1:0];
                {D, C, B, A} = code[3:0];
                #10 check;
            end
        end
        if (errors == 0)
            $display("PASS: 4-to-16 decoder, %0d vectors", checks);
        else
            $display("FAIL: %0d of %0d vectors mismatched", errors, checks);
        $finish;
    end

endmodule
