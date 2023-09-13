module uart_tb();
    parameter TX_MESSAGE = {8'h11, 8'h22, 8'h33, 8'h44, 8'h00, 8'h00};
    parameter CLOCK_RATE = 10_000_000;
    parameter BAUD_RATE = 115_200;

    logic adderRx, adderTx, clk = 1, uartClk = 1;

    uart#(.CLOCK_RATE(CLOCK_RATE), .BAUD_RATE(BAUD_RATE))
    uartAdder0(.clk(clk), .uartClk(uartClk), .rx(adderRx), .tx(adderTx));

    logic startTx;
    UartTx#(.DATA_WIDTH($size(TX_MESSAGE)))
    uartTx0(.uartClk(uartClk), .tx(adderRx), .message(TX_MESSAGE), .start(startTx));

    byte data;
    logic dataIsValid;
    UartRx#(.CLOCK_RATE(CLOCK_RATE), .BAUD_RATE(BAUD_RATE))
    uartRx0(.clk(clk), .rx(adderTx), .data(data), .dataIsValid(dataIsValid));

    byte validData;
    always @(posedge dataIsValid) begin
        $display("Received byte 0x%h", data);
        validData <= data;
    end

    initial forever #(0.5s/CLOCK_RATE) clk = ~clk;
    initial forever #(0.5s/BAUD_RATE) uartClk = ~uartClk;
    initial begin startTx = 1; #(2.0s/BAUD_RATE) startTx = 0; end
    initial #1ms $finish;
    initial begin
        $dumpfile("uart.vcd");
        $dumpvars(0, uart_tb);
    end
endmodule
