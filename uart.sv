module uart_tx(input logic clk, output logic tx);
    typedef enum logic [1:0] { IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11 } state_t;

    state_t state = IDLE;
    string message = "Hello World!\n";
    localparam str_length = 13;
    logic [3:0] char_idx = 0;
    logic [2:0] bit_cnt = 0;
    logic [7:0] current_char;

    always_comb current_char = message[char_idx];

    always_ff @(posedge clk) begin
        case(state)
            IDLE: begin
                tx <= 1;
                state <= START;
            end
            START: begin
                tx <= 0;
                state <= DATA;
                bit_cnt <= 0;
            end
            DATA: begin
                bit_cnt <= bit_cnt + 1;
                tx <= current_char[bit_cnt];
                state <= (bit_cnt == 7) ? STOP : DATA;
            end
            STOP: begin
                tx <= 1;
                char_idx <= (char_idx < str_length) ? (char_idx + 1) : 0;
                state <= (char_idx < str_length) ? START : IDLE;
            end
        endcase
    end
endmodule
