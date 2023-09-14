`timescale 1ns/1ns

module uart(input logic clk, input logic rxd, output logic txd);
    parameter CLOCK_RATE = 100_000_000;
    parameter BAUD_RATE = 9600;

    logic dataIsValid, txStart;
    byte data, tmpData, tmpDataSum;

    logic uartClk;
    ClockDivider#(.DIVIDER(CLOCK_RATE/BAUD_RATE))
    clockdiv1(.clkIn(clk), .clkOut(uartClk));

    UartRx#(.BAUD_RATE(BAUD_RATE), .CLOCK_RATE(CLOCK_RATE))
    uartRx1(.clk(clk), .rxd(rxd), .data(data), .dataIsValid(dataIsValid));

    UartTx#(.DATA_WIDTH(8))
    uartTx1(.uartClk(uartClk), .message(tmpDataSum), .start(txStart), .txd(txd));

    always_ff @(posedge dataIsValid) begin
        tmpData <= data;
        tmpDataSum <= tmpData + data;
    end

    logic lastDataIsValid;
    always_ff @(posedge uartClk) begin
        txStart <= dataIsValid & ~lastDataIsValid;
        lastDataIsValid <= dataIsValid;
    end
endmodule


module UartTx #(parameter DATA_WIDTH = 8) (
    input logic uartClk,
    input logic [DATA_WIDTH-1:0] message,
    input logic start,
    output logic txd,
    output logic idle
);
    typedef enum { IDLE, START, DATA, STOP } state_t;
    state_t state = IDLE, nextState;
    logic [$clog2(DATA_WIDTH)-1:0] bitPos = DATA_WIDTH - 8, nextBitPos;

    always_comb case(state)
        IDLE: idle = 1;
        default: idle = 0;
    endcase

    always_comb case(state)
        START: txd = 0;
        DATA: txd = message[bitPos];
        default: txd = 1;
    endcase

    always_comb case(state)
        IDLE: nextState = (start === 1) ? START : IDLE;
        START: nextState = DATA;
        DATA: nextState = (bitPos % 8 === 7) ? STOP : DATA;
        STOP: nextState = (((bitPos === DATA_WIDTH - 8) && (start === 0)) === 1) ? IDLE : START;
        default: nextState = IDLE;
    endcase

    always_comb case(state)
        START: nextBitPos = bitPos;
        DATA: begin
            if (bitPos === 7) nextBitPos = DATA_WIDTH - 8;
            else if (bitPos % 8 === 7) nextBitPos = bitPos - 15;
            else nextBitPos = bitPos + 1;
        end
        STOP: nextBitPos = bitPos;
        default: nextBitPos = DATA_WIDTH - 8;
    endcase

    always_ff @(posedge uartClk) begin
        state <= nextState;
        bitPos <= nextBitPos;
    end
endmodule


module UartRx #(parameter BAUD_RATE, parameter CLOCK_RATE) (
    input logic clk,
    input logic rxd,
    output byte data,
    output logic dataIsValid
);
    localparam PULSECNT_MAX = (10 * CLOCK_RATE) / BAUD_RATE;

    typedef enum logic [3:0] { D0, D1, D2, D3, D4, D5, D6, D7, IDLE, START, STOP } state_t;
    state_t state = IDLE, nextState;

    logic [$clog2(PULSECNT_MAX+1)-1:0] pulseCnt = 0, nextPulseCnt;
    always_comb case(state)
        IDLE: nextPulseCnt = 0;
        default: nextPulseCnt = pulseCnt + 1;
    endcase

    logic pulseCntMeasure;
    always_comb case(state)
        START:   pulseCntMeasure = (pulseCnt === ( 1 * PULSECNT_MAX) / 20);
        D0:      pulseCntMeasure = (pulseCnt === ( 3 * PULSECNT_MAX) / 20);
        D1:      pulseCntMeasure = (pulseCnt === ( 5 * PULSECNT_MAX) / 20);
        D2:      pulseCntMeasure = (pulseCnt === ( 7 * PULSECNT_MAX) / 20);
        D3:      pulseCntMeasure = (pulseCnt === ( 9 * PULSECNT_MAX) / 20);
        D4:      pulseCntMeasure = (pulseCnt === (11 * PULSECNT_MAX) / 20);
        D5:      pulseCntMeasure = (pulseCnt === (13 * PULSECNT_MAX) / 20);
        D6:      pulseCntMeasure = (pulseCnt === (15 * PULSECNT_MAX) / 20);
        D7:      pulseCntMeasure = (pulseCnt === (17 * PULSECNT_MAX) / 20);
        STOP:    pulseCntMeasure = (pulseCnt === (19 * PULSECNT_MAX) / 20);
        default: pulseCntMeasure = 0;
    endcase

    logic startBit;
    byte nextData;
    always_ff @(posedge pulseCntMeasure) case(state)
        START: startBit <= rxd;
        D0: nextData[0] <= rxd;
        D1: nextData[1] <= rxd;
        D2: nextData[2] <= rxd;
        D3: nextData[3] <= rxd;
        D4: nextData[4] <= rxd;
        D5: nextData[5] <= rxd;
        D6: nextData[6] <= rxd;
        D7: nextData[7] <= rxd;
        default:;
    endcase

    always_ff @(posedge pulseCntMeasure) case(state)
        IDLE:; START:;
        STOP: if (startBit === 0 && rxd === 1) dataIsValid <= 1;
        default: dataIsValid <= 0;
    endcase

    always_comb case(state)
        IDLE:    nextState = (rxd === 0) ? START : IDLE;
        START:   nextState = (pulseCnt === ( 2 * PULSECNT_MAX) / 20) ?   D0 : state;
        D0:      nextState = (pulseCnt === ( 4 * PULSECNT_MAX) / 20) ?   D1 : state;
        D1:      nextState = (pulseCnt === ( 6 * PULSECNT_MAX) / 20) ?   D2 : state;
        D2:      nextState = (pulseCnt === ( 8 * PULSECNT_MAX) / 20) ?   D3 : state;
        D3:      nextState = (pulseCnt === (10 * PULSECNT_MAX) / 20) ?   D4 : state;
        D4:      nextState = (pulseCnt === (12 * PULSECNT_MAX) / 20) ?   D5 : state;
        D5:      nextState = (pulseCnt === (14 * PULSECNT_MAX) / 20) ?   D6 : state;
        D6:      nextState = (pulseCnt === (16 * PULSECNT_MAX) / 20) ?   D7 : state;
        D7:      nextState = (pulseCnt === (18 * PULSECNT_MAX) / 20) ? STOP : state;
        STOP:    nextState = (pulseCntMeasure === 0) ? state : IDLE;
        default: nextState = IDLE;
    endcase

    always_ff @(posedge clk) begin
        state <= nextState;
        pulseCnt <= nextPulseCnt;
        data <= nextData;
    end
endmodule


module ClockDivider #(parameter DIVIDER = 1) (input logic clkIn, output logic clkOut);
    logic [$clog2(DIVIDER)-1:0] counter = 0;
    always @(posedge clkIn) begin
        counter <= (counter === DIVIDER) ? 0 : (counter + 1);
        clkOut <= (counter <= DIVIDER / 2) ? 1 : 0;
    end
endmodule
