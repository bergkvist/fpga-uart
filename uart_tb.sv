module uart_tx_tb();
    initial begin
        $dumpfile("uart.vcd");
        $dumpvars(0, uart_tx_tb);
    end

    logic tx;
    logic clk = 1;
    initial forever #5 clk = ~clk;

    uart_tx uart0(clk, tx);
    initial #5000 $finish;
endmodule
