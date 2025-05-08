// This file just defines shims
// (for IHP standard cells that are used by project.v)
// to keep the RTL test happy.

module sg13g2_inv_1 (
    input wire A,
    output wire Y
);
    assign Y = ~A;
endmodule


module sg13g2_buf_16 (
    input wire A,
    output wire X
);
    assign X = A;
endmodule
