module CAM #(
    parameter logd  = 12,
    parameter logw = 7
    ) (
    input               clk,
    input               rst,
    input               fire,
    input   [logd-1:0]  code,
    input   [7:0]       c,

    output              busy_o,
    output              valid_o,
    output  [logd:0]    encoding_o
);
    parameter depth = 2**logd;
    parameter width = 2**logw;

    logic busy;
    logic valid;
    logic [logd:0] encoding;

    logic   [logd-1:0]  code_q;
    logic   [width-1:0]  full_word_d, full_word_q;
    logic   [7:0]       c_q;

    logic [depth-1:0]   lookup_match_d, lookup_match_q;
    logic [width-1:0]     lookup_data;
    logic [logw-1:0]      lookup_size;
    logic [logd-1:0]    lookup_index;
    logic               lookup_found;

    logic [logd:0]    size;
    logic [depth-1:0]   data    [width-1:0];
    logic [depth-1:0]   data_length  [logw-1:0];

    logic [2:0]         state;

    always_comb begin // assign the constants
        for(int i = 0; i < 256; i++) begin
            data[i] = i;
            data_length[i] = 8;
        end
        data_length[256] = '0;
        data_length[257] = '0;
    end

    always_comb begin
        lookup_match_d = '0;
        for(int i = 0; i < depth; i++) begin
            if(data[i] == full_word_q && data_length[i] == lookup_size) begin
                lookup_match_d[i] = 1'b1;
            end
        end
    end

    assign lookup_found = |lookup_match_q;

    always_comb begin
        lookup_index = '0;
        for(int i = 0; i < depth; i++) begin
            if(lookup_match_q[i]) begin
                lookup_index = i;
            end
        end
    end

    always_comb begin
        full_word_d = data[code_q];
        if(data_length[code_q]<width-8) begin
            full_word_d[data_length[code_q]+:8] = c_q;
        end
    end

    always_ff @( posedge clk ) begin
        if(rst) begin
            size <= 12'd258;
            valid <= 1'b0;
            state   <= 2'b0;
            valid <= 1'b0;
            encoding <= '0;
            data_length[depth-1:258] <= '0;
        end else begin
            case(state)
                2'b0: begin
                    valid <= 1'b0;
                    busy  <= fire;
                    if(fire) begin
                        c_q     <= c;
                        code_q  <= code;
                        state   <= 2'b1;
                    end
                end
                2'b1: begin
                    full_word_q <= full_word_d;
                    lookup_size <= data_length[code_q] + 8;
                    state <= 2'b10;
                end
                2'b10: begin
                    lookup_match_q <= lookup_match_d;
                    state <= 2'b11;
                end
                2'b11: begin
                    valid <= 1'b1;
                    if(size<depth) begin
                        data[size] <= full_word_q;
                        data_length[size] <= lookup_size;
                    end
                    state <= 2'b0;
                    if(lookup_found) begin
                        encoding <= lookup_index;
                    end else begin
                        encoding <= size;
                        if(size<depth) begin
                            size <= size + 1;
                        end
                    end
                end
            endcase
        end
    end

    assign busy_o = busy;
    assign encoding_o = encoding;
    assign valid_o = valid;

endmodule
