module uart_tb();
    localparam CLOCK_RATE = 100_000;
    localparam BAUD_RATE = 9600;

    initial begin
        $dumpfile("uart.vcd");
        $dumpvars(0, uart_tb);
    end

    logic tx, idle, start = 0;
    logic clk = 1, uart_clk = 1;
    initial forever #(0.5s/CLOCK_RATE) clk = ~clk;
    initial forever #(0.5s/BAUD_RATE) uart_clk = ~uart_clk;

    initial begin #100ms start = 1; #150us start = 0; end

    UartTx #(.DATA_WIDTH(13*8)) uartTx0(
        .clk(uart_clk),
        .message("Hello World! "),
        .start(start),
        .tx(tx),
        .idle(idle)
    );

    logic [7:0] rxdata;
    UartRx #(
        .DATA_WIDTH(8),
        .BAUD_RATE(BAUD_RATE),
        .CLOCK_RATE(CLOCK_RATE)
    ) uartRx0(
        .clk(clk),
        .rx(tx),
        .data(rxdata)
    );

    initial #1s $finish;
endmodule
