module uart_tb();
    parameter TX_MESSAGE = {8'h11, 8'h22, 8'h44};
    localparam CLOCK_RATE = 100_000;
    localparam BAUD_RATE = 9600;
    initial begin
        $dumpfile("uart.vcd");
        $dumpvars(0, uart_tb);
    end

    logic rx, tx, clk = 1, uartClk = 1;
    initial forever #(0.5s/CLOCK_RATE) clk = ~clk;
    initial forever #(0.5s/BAUD_RATE) uartClk = ~uartClk;

    uart#(.CLOCK_RATE(CLOCK_RATE), .BAUD_RATE(BAUD_RATE))
    uartAdder0(.clk(clk), .rx(rx), .tx(tx));

    logic startTx;
    UartTx#(.DATA_WIDTH($size(TX_MESSAGE)))
    uartTx0(.uartClk(uartClk), .tx(rx), .message(TX_MESSAGE), .start(startTx));

    byte data;
    logic dataIsValid;
    UartRx#(.CLOCK_RATE(CLOCK_RATE), .BAUD_RATE(BAUD_RATE))
    uartRx0(.clk(clk), .rx(tx), .data(data), .dataIsValid(dataIsValid));

    initial begin
        #100ms startTx = 1;
        #150us startTx = 0;
    end
    initial #1s $finish;
endmodule
