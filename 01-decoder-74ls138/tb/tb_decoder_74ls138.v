`timescale 1ns / 1ps

// Testbench for both 74LS138 models. Every select code is applied under every enable combination,
// and both decoders are compared with the datasheet truth table: outputs are active low, and only
// Y[{C, B, A}] is low, and only while G1 = 1 and G2A = G2B = 0.
module tb_decoder_74ls138;

    reg        A, B, C;
    reg        G1, G2A, G2B;
    wire [7:0] y_gates;
    wire [7:0] y_behavioural;

    integer errors = 0;
    integer checks = 0;
    integer sel, en;

    decoder_74ls138_gates u_gates (
        .G1(G1), .G2A(G2A), .G2B(G2B),
        .A(A), .B(B), .C(C),
        .Y(y_gates)
    );

    decoder_74ls138 u_behavioural (
        .G1(G1), .G2A(G2A), .G2B(G2B),
        .A(A), .B(B), .C(C),
        .Y(y_behavioural)
    );

    function [7:0] expected_y(input g1, input g2a, input g2b, input [2:0] cba);
        expected_y = (g1 && !g2a && !g2b) ? ~(8'b1 << cba) : 8'hFF;
    endfunction

    task check;
        reg [7:0] exp;
        begin
            exp = expected_y(G1, G2A, G2B, {C, B, A});
            checks = checks + 1;
            if (y_gates !== exp || y_behavioural !== exp) begin
                errors = errors + 1;
                $display("MISMATCH G1=%b G2A=%b G2B=%b CBA=%b%b%b:", G1, G2A, G2B, C, B, A);
                $display("         gates=%b behavioral=%b expected=%b",
                         y_gates, y_behavioural, exp);
            end
        end
    endtask

    initial begin
        for (en = 0; en < 8; en = en + 1) begin
            for (sel = 0; sel < 8; sel = sel + 1) begin
                {G1, G2A, G2B} = en[2:0];
                {C, B, A} = sel[2:0];
                #10 check;
            end
        end
        if (errors == 0)
            $display("PASS: 74LS138 truth table, %0d vectors", checks);
        else
            $display("FAIL: %0d of %0d vectors mismatched", errors, checks);
        $finish;
    end

endmodule
