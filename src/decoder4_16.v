//------------------------------------------------------------
// decoder4_16: coloca un '1' en la posicion indicada por iArr4
//   iArr4 = 0000 -> oArr16 = 0000_0000_0000_0001
//   iArr4 = 1111 -> oArr16 = 1000_0000_0000_0000
//------------------------------------------------------------

module decoder4_16 (
    input  wire [3:0]  iArr4,   // posicion del pulso
    output wire [15:0] oArr16   // simbolo PPM
);

    assign oArr16 = 16'd1 << iArr4;

endmodule
