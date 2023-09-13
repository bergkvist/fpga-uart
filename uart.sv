`timescale 1ns/1ns

module uart(input logic clk, input logic uartClk, input logic rx, output logic tx);
    parameter CLOCK_RATE = 100_000_000;
    parameter BAUD_RATE = 9600;

    logic dataIsValid, txStart, idle;
    byte data, tmpData, tmpDataSum;

    // logic uartClk;
    // ClockDivider#(.DIVIDER(CLOCK_RATE/BAUD_RATE))
    // clockdiv1(.clkIn(clk), .clkOut(uartClk));

    UartRx#(.BAUD_RATE(BAUD_RATE), .CLOCK_RATE(CLOCK_RATE))
    uartRx1(.clk(clk), .rx(rx), .data(data), .dataIsValid(dataIsValid));

    UartTx#(.DATA_WIDTH(8))
    uartTx1(.uartClk(uartClk), .message(tmpDataSum), .start(txStart), .tx(tx), .idle(idle));

    always_ff @(posedge dataIsValid) begin
        tmpData <= data;
        tmpDataSum <= tmpData + data;
        txStart <= 1;
    end
    always_ff @(posedge uartClk) txStart <= 0;
endmodule


module UartTx #(parameter DATA_WIDTH = 8) (
    input logic uartClk,
    input logic [DATA_WIDTH-1:0] message,
    input logic start,
    output logic tx = 1,
    output logic idle
);
    typedef enum { IDLE, START, DATA, STOP } state_t;
    state_t state = IDLE, nextState;
    logic [$clog2(DATA_WIDTH)-1:0] bitPos = DATA_WIDTH - 8, nextBitPos;
    logic nextTx;

    always_comb case(state)
        IDLE: idle = 1;
        default: idle = 0;
    endcase

    always_comb case(state)
        START: tx = 0;
        DATA: tx = message[bitPos];
        default: tx = 1;
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
    input logic rx,
    output byte data,
    output logic dataIsValid = 0
);
    localparam PULSECNT_MAX = (10 * CLOCK_RATE) / BAUD_RATE;
    localparam PULSECNT_WIDTH = $clog2(PULSECNT_MAX + 1);
    typedef enum logic [3:0] { D0, D1, D2, D3, D4, D5, D6, D7, IDLE, START, STOP } state_t;
    // 10, 11, 10, 11, ... ???

    state_t state = IDLE, nextState = IDLE;
    logic [PULSECNT_WIDTH:0] pulseCnt = 0, nextPulseCnt;
    logic startBit, pulseCntDone, pulseCntMeasure;
    byte nextData;

    always_comb case(state)
        START:   pulseCntDone = (pulseCnt === ( 2 * PULSECNT_MAX) / 20);
        D0:      pulseCntDone = (pulseCnt === ( 4 * PULSECNT_MAX) / 20);
        D1:      pulseCntDone = (pulseCnt === ( 6 * PULSECNT_MAX) / 20);
        D2:      pulseCntDone = (pulseCnt === ( 8 * PULSECNT_MAX) / 20);
        D3:      pulseCntDone = (pulseCnt === (10 * PULSECNT_MAX) / 20);
        D4:      pulseCntDone = (pulseCnt === (12 * PULSECNT_MAX) / 20);
        D5:      pulseCntDone = (pulseCnt === (14 * PULSECNT_MAX) / 20);
        D6:      pulseCntDone = (pulseCnt === (16 * PULSECNT_MAX) / 20);
        D7:      pulseCntDone = (pulseCnt === (18 * PULSECNT_MAX) / 20);
        STOP:    pulseCntDone = (pulseCnt === (20 * PULSECNT_MAX) / 20);
        default: pulseCntDone = 0;
    endcase
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

    always_ff @(posedge clk) begin
        state <= nextState;
        pulseCnt <= nextPulseCnt;
        data <= nextData;
    end

    always_ff @(posedge pulseCntMeasure) case(state)
        IDLE:; START:;
        STOP: if (startBit === 0 && rx === 1) dataIsValid <= 1;
        default: dataIsValid <= 0;
    endcase

    always_ff @(posedge pulseCntMeasure) case(state)
        START: startBit <= rx;
        D0: nextData[0] <= rx;
        D1: nextData[1] <= rx;
        D2: nextData[2] <= rx;
        D3: nextData[3] <= rx;
        D4: nextData[4] <= rx;
        D5: nextData[5] <= rx;
        D6: nextData[6] <= rx;
        D7: nextData[7] <= rx;
        default:;
    endcase

    always_comb case(state)
        IDLE: nextState = (rx === 0) ? START : IDLE;
        START: nextState = (pulseCntDone === 1) ? D0 : START;
        D0: nextState = (pulseCntDone === 1) ? D1 : D0;
        D1: nextState = (pulseCntDone === 1) ? D2 : D1;
        D2: nextState = (pulseCntDone === 1) ? D3 : D2;
        D3: nextState = (pulseCntDone === 1) ? D4 : D3;
        D4: nextState = (pulseCntDone === 1) ? D5 : D4;
        D5: nextState = (pulseCntDone === 1) ? D6 : D5;
        D6: nextState = (pulseCntDone === 1) ? D7 : D6;
        D7: nextState = (pulseCntDone === 1) ? STOP : D7;
        STOP: nextState = (pulseCntMeasure === 0) ? STOP : IDLE;
        default: nextState = IDLE;
    endcase

    always_comb case(state)
        IDLE: nextPulseCnt = 0;
        default: nextPulseCnt = pulseCnt + 1;
    endcase
endmodule


module ClockDivider #(parameter DIVIDER = 1) (input logic clkIn, output logic clkOut);
    logic [$clog2(DIVIDER)-1:0] counter = 0;
    always @(posedge clkIn) begin
        counter <= (counter === DIVIDER) ? 0 : (counter + 1);
        clkOut <= (counter <= DIVIDER/2) ? 1 : 0;
    end
endmodule
