module uart_tb();
    localparam TX_MESSAGE = {8'h11, 8'h22, 8'h44};
    localparam CLOCK_RATE = 100_000;
    localparam BAUD_RATE = 9600;
    initial begin
        $dumpfile("uart.vcd");
        $dumpvars(0, uart_tb);
    end

    logic tx, idle, startTx = 0;
    logic clk = 1, uartClk = 1;
    initial forever #(0.5s/CLOCK_RATE) clk = ~clk;
    initial forever #(0.5s/BAUD_RATE) uartClk = ~uartClk;

    initial begin
        #100ms startTx = 1;
        #150us startTx = 0;
    end

    UartTx #(.DATA_WIDTH($size(TX_MESSAGE))) uartTx0(
        .uartClk(uartClk),
        .message(TX_MESSAGE),
        .start(startTx),
        .tx(tx),
        .idle(idle)
    );

    logic [7:0] rxdata;
    UartRx #(.BAUD_RATE(BAUD_RATE), .CLOCK_RATE(CLOCK_RATE)) uartRx0(
        .clk(clk),
        .rx(tx),
        .data(rxdata)
    );

    initial #1s $finish;
endmodule
