`timescale 1ns/1ns

module UartTx #(parameter DATA_WIDTH) (
    input logic clk,
    input logic [DATA_WIDTH-1:0] message,
    input logic start,
    output logic tx = 1,
    output logic idle
);
    typedef enum logic [1:0] { IDLE, START, DATA, STOP } txState;
    txState state = IDLE, nextState;
    logic [10:0] bitPos = DATA_WIDTH - 8, nextBitPos;
    logic nextTx;
    
    always_comb case(state)
        IDLE: idle = 1;
        default: idle = 0;
    endcase

    always_comb case(state)
        IDLE: tx = 1;
        START: tx = 0;
        DATA: tx = message[bitPos];
        STOP: tx = 1;
    endcase

    always_comb case(state)
        IDLE: nextState = (start === 1) ? START : IDLE;
        START: nextState = DATA;
        DATA: nextState = (bitPos % 8 === 7) ? STOP : DATA;
        STOP: nextState = (((bitPos === DATA_WIDTH - 8) && (start === 0)) === 1) ? IDLE : START;
    endcase
    
    always_comb case(state)
        IDLE: nextBitPos = DATA_WIDTH - 8;
        START: nextBitPos = bitPos;
        DATA: begin
            if (bitPos === 7) nextBitPos = DATA_WIDTH - 8;
            else if (bitPos % 8 === 7) nextBitPos = bitPos - 15;
            else nextBitPos = bitPos + 1;
        end
        STOP: nextBitPos = bitPos;
    endcase

    always_ff @(posedge clk) begin
        state <= nextState;
        bitPos <= nextBitPos;
    end
endmodule


module UartRx #(
    parameter DATA_WIDTH,
    parameter BAUD_RATE,
    parameter CLOCK_RATE
) (
    input logic clk,
    input logic rx,
    output logic [DATA_WIDTH-1:0] data
);
    typedef enum logic [1:0] { IDLE, START, DATA, STOP } rxState;
    localparam PULSES = CLOCK_RATE / BAUD_RATE;

    logic [9:0] pulseCnt = 0, nextPulseCnt;
    logic [9:0] bitCnt = 0, nextBitCnt;
    rxState state = IDLE, nextState = IDLE;

    logic [DATA_WIDTH-1:0] buffer, nextData;
    logic rxEdgeDetected = 0;
    logic startBit;

    logic readyToMeasure;
    assign readyToMeasure = pulseCnt === PULSES / 2;

    always_ff @(posedge clk) begin
        rxEdgeDetected <= 0;
        state <= nextState;
        bitCnt <= nextBitCnt;
        pulseCnt <= nextPulseCnt % PULSES;
        data <= nextData;
    end

    always_comb case(state)
        IDLE: begin
            nextState = (rxEdgeDetected === 1) ? START : IDLE;
            nextPulseCnt = 0;
            nextBitCnt = 0;
        end
        START: begin
            nextState = (pulseCnt === PULSES - 1) ? DATA : START;
            nextPulseCnt = pulseCnt + 1;
            nextBitCnt = 0;
            if (readyToMeasure) startBit = rx;
        end
        DATA: begin
            nextState = (bitCnt === DATA_WIDTH) ? STOP : DATA;
            nextPulseCnt = pulseCnt + 1;
            nextBitCnt = (bitCnt === DATA_WIDTH) ? 0 : ((pulseCnt === PULSES - 1) ? (bitCnt + 1) : bitCnt);
            if (readyToMeasure) buffer[bitCnt] = rx;
        end
        STOP: begin
            if (readyToMeasure) begin
                nextState = (rxEdgeDetected === 1) ? START : IDLE;
                if (startBit === 0 && rx === 1) nextData = buffer;
                nextBitCnt = 0;
                nextPulseCnt = 0;
            end else begin
                nextPulseCnt = pulseCnt + 1;
                nextState = STOP;
            end
        end
    endcase
    
    always_ff @(negedge rx) rxEdgeDetected <= 1;
endmodule