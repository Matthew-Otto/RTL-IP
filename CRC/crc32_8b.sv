// CRC-32 (IEEE 802.3, reflected) byte-wise update (for Ethernet FCS)
// poly (reflected) = 0xEDB88320
// check value = 0x2144DF1C
// start value = 0xFFFFFFFF; final = bitwise NOT
// - Input:  8-bit stream of the entire frame
// - Output: 'good' or 'bad' bit asserted after last byte of frame
// Detects end of frame by gap in data_valid signal. 
// Entire frame must be streamed without breaks.

module crc32_8b (
  input  logic       clk,
  input  logic       reset,

  input  logic       data_valid,
  input  logic [7:0] data_in,

  output logic       fcs_good,
  output logic       fcs_bad
);

  localparam logic [31:0] CHECK_VALUE = 32'h2144DF1C;

  logic last_valid;
  logic falling_edge;
  logic match_check_val;
  logic [31:0] crc;
  logic [7:0]  lut_idx;
  logic [31:0] lut_data;
  logic [31:0] crc_rom [255:0];

  assign lut_idx = crc[7:0] ^ data_in;
  assign lut_data = crc_rom[lut_idx];

  always_ff @(posedge clk) begin
    if (reset || ~data_valid)
      crc <= 32'hFFFFFFFF;
    else if (data_valid)
      crc <= {8'b0,crc[31:8]} ^ lut_data;

    if (reset) last_valid <= 0;
    else last_valid <= data_valid;
  end

  assign falling_edge = last_valid && ~data_valid;
  assign match_check_val = ~crc == CHECK_VALUE;

  assign fcs_good = falling_edge && match_check_val;
  assign fcs_bad = falling_edge && ~match_check_val;

  initial begin
    crc_rom[0] = 32'h00000000;
    crc_rom[1] = 32'h77073096;
    crc_rom[2] = 32'hee0e612c;
    crc_rom[3] = 32'h990951ba;
    crc_rom[4] = 32'h076dc419;
    crc_rom[5] = 32'h706af48f;
    crc_rom[6] = 32'he963a535;
    crc_rom[7] = 32'h9e6495a3;
    crc_rom[8] = 32'h0edb8832;
    crc_rom[9] = 32'h79dcb8a4;
    crc_rom[10] = 32'he0d5e91e;
    crc_rom[11] = 32'h97d2d988;
    crc_rom[12] = 32'h09b64c2b;
    crc_rom[13] = 32'h7eb17cbd;
    crc_rom[14] = 32'he7b82d07;
    crc_rom[15] = 32'h90bf1d91;
    crc_rom[16] = 32'h1db71064;
    crc_rom[17] = 32'h6ab020f2;
    crc_rom[18] = 32'hf3b97148;
    crc_rom[19] = 32'h84be41de;
    crc_rom[20] = 32'h1adad47d;
    crc_rom[21] = 32'h6ddde4eb;
    crc_rom[22] = 32'hf4d4b551;
    crc_rom[23] = 32'h83d385c7;
    crc_rom[24] = 32'h136c9856;
    crc_rom[25] = 32'h646ba8c0;
    crc_rom[26] = 32'hfd62f97a;
    crc_rom[27] = 32'h8a65c9ec;
    crc_rom[28] = 32'h14015c4f;
    crc_rom[29] = 32'h63066cd9;
    crc_rom[30] = 32'hfa0f3d63;
    crc_rom[31] = 32'h8d080df5;
    crc_rom[32] = 32'h3b6e20c8;
    crc_rom[33] = 32'h4c69105e;
    crc_rom[34] = 32'hd56041e4;
    crc_rom[35] = 32'ha2677172;
    crc_rom[36] = 32'h3c03e4d1;
    crc_rom[37] = 32'h4b04d447;
    crc_rom[38] = 32'hd20d85fd;
    crc_rom[39] = 32'ha50ab56b;
    crc_rom[40] = 32'h35b5a8fa;
    crc_rom[41] = 32'h42b2986c;
    crc_rom[42] = 32'hdbbbc9d6;
    crc_rom[43] = 32'hacbcf940;
    crc_rom[44] = 32'h32d86ce3;
    crc_rom[45] = 32'h45df5c75;
    crc_rom[46] = 32'hdcd60dcf;
    crc_rom[47] = 32'habd13d59;
    crc_rom[48] = 32'h26d930ac;
    crc_rom[49] = 32'h51de003a;
    crc_rom[50] = 32'hc8d75180;
    crc_rom[51] = 32'hbfd06116;
    crc_rom[52] = 32'h21b4f4b5;
    crc_rom[53] = 32'h56b3c423;
    crc_rom[54] = 32'hcfba9599;
    crc_rom[55] = 32'hb8bda50f;
    crc_rom[56] = 32'h2802b89e;
    crc_rom[57] = 32'h5f058808;
    crc_rom[58] = 32'hc60cd9b2;
    crc_rom[59] = 32'hb10be924;
    crc_rom[60] = 32'h2f6f7c87;
    crc_rom[61] = 32'h58684c11;
    crc_rom[62] = 32'hc1611dab;
    crc_rom[63] = 32'hb6662d3d;
    crc_rom[64] = 32'h76dc4190;
    crc_rom[65] = 32'h01db7106;
    crc_rom[66] = 32'h98d220bc;
    crc_rom[67] = 32'hefd5102a;
    crc_rom[68] = 32'h71b18589;
    crc_rom[69] = 32'h06b6b51f;
    crc_rom[70] = 32'h9fbfe4a5;
    crc_rom[71] = 32'he8b8d433;
    crc_rom[72] = 32'h7807c9a2;
    crc_rom[73] = 32'h0f00f934;
    crc_rom[74] = 32'h9609a88e;
    crc_rom[75] = 32'he10e9818;
    crc_rom[76] = 32'h7f6a0dbb;
    crc_rom[77] = 32'h086d3d2d;
    crc_rom[78] = 32'h91646c97;
    crc_rom[79] = 32'he6635c01;
    crc_rom[80] = 32'h6b6b51f4;
    crc_rom[81] = 32'h1c6c6162;
    crc_rom[82] = 32'h856530d8;
    crc_rom[83] = 32'hf262004e;
    crc_rom[84] = 32'h6c0695ed;
    crc_rom[85] = 32'h1b01a57b;
    crc_rom[86] = 32'h8208f4c1;
    crc_rom[87] = 32'hf50fc457;
    crc_rom[88] = 32'h65b0d9c6;
    crc_rom[89] = 32'h12b7e950;
    crc_rom[90] = 32'h8bbeb8ea;
    crc_rom[91] = 32'hfcb9887c;
    crc_rom[92] = 32'h62dd1ddf;
    crc_rom[93] = 32'h15da2d49;
    crc_rom[94] = 32'h8cd37cf3;
    crc_rom[95] = 32'hfbd44c65;
    crc_rom[96] = 32'h4db26158;
    crc_rom[97] = 32'h3ab551ce;
    crc_rom[98] = 32'ha3bc0074;
    crc_rom[99] = 32'hd4bb30e2;
    crc_rom[100] = 32'h4adfa541;
    crc_rom[101] = 32'h3dd895d7;
    crc_rom[102] = 32'ha4d1c46d;
    crc_rom[103] = 32'hd3d6f4fb;
    crc_rom[104] = 32'h4369e96a;
    crc_rom[105] = 32'h346ed9fc;
    crc_rom[106] = 32'had678846;
    crc_rom[107] = 32'hda60b8d0;
    crc_rom[108] = 32'h44042d73;
    crc_rom[109] = 32'h33031de5;
    crc_rom[110] = 32'haa0a4c5f;
    crc_rom[111] = 32'hdd0d7cc9;
    crc_rom[112] = 32'h5005713c;
    crc_rom[113] = 32'h270241aa;
    crc_rom[114] = 32'hbe0b1010;
    crc_rom[115] = 32'hc90c2086;
    crc_rom[116] = 32'h5768b525;
    crc_rom[117] = 32'h206f85b3;
    crc_rom[118] = 32'hb966d409;
    crc_rom[119] = 32'hce61e49f;
    crc_rom[120] = 32'h5edef90e;
    crc_rom[121] = 32'h29d9c998;
    crc_rom[122] = 32'hb0d09822;
    crc_rom[123] = 32'hc7d7a8b4;
    crc_rom[124] = 32'h59b33d17;
    crc_rom[125] = 32'h2eb40d81;
    crc_rom[126] = 32'hb7bd5c3b;
    crc_rom[127] = 32'hc0ba6cad;
    crc_rom[128] = 32'hedb88320;
    crc_rom[129] = 32'h9abfb3b6;
    crc_rom[130] = 32'h03b6e20c;
    crc_rom[131] = 32'h74b1d29a;
    crc_rom[132] = 32'head54739;
    crc_rom[133] = 32'h9dd277af;
    crc_rom[134] = 32'h04db2615;
    crc_rom[135] = 32'h73dc1683;
    crc_rom[136] = 32'he3630b12;
    crc_rom[137] = 32'h94643b84;
    crc_rom[138] = 32'h0d6d6a3e;
    crc_rom[139] = 32'h7a6a5aa8;
    crc_rom[140] = 32'he40ecf0b;
    crc_rom[141] = 32'h9309ff9d;
    crc_rom[142] = 32'h0a00ae27;
    crc_rom[143] = 32'h7d079eb1;
    crc_rom[144] = 32'hf00f9344;
    crc_rom[145] = 32'h8708a3d2;
    crc_rom[146] = 32'h1e01f268;
    crc_rom[147] = 32'h6906c2fe;
    crc_rom[148] = 32'hf762575d;
    crc_rom[149] = 32'h806567cb;
    crc_rom[150] = 32'h196c3671;
    crc_rom[151] = 32'h6e6b06e7;
    crc_rom[152] = 32'hfed41b76;
    crc_rom[153] = 32'h89d32be0;
    crc_rom[154] = 32'h10da7a5a;
    crc_rom[155] = 32'h67dd4acc;
    crc_rom[156] = 32'hf9b9df6f;
    crc_rom[157] = 32'h8ebeeff9;
    crc_rom[158] = 32'h17b7be43;
    crc_rom[159] = 32'h60b08ed5;
    crc_rom[160] = 32'hd6d6a3e8;
    crc_rom[161] = 32'ha1d1937e;
    crc_rom[162] = 32'h38d8c2c4;
    crc_rom[163] = 32'h4fdff252;
    crc_rom[164] = 32'hd1bb67f1;
    crc_rom[165] = 32'ha6bc5767;
    crc_rom[166] = 32'h3fb506dd;
    crc_rom[167] = 32'h48b2364b;
    crc_rom[168] = 32'hd80d2bda;
    crc_rom[169] = 32'haf0a1b4c;
    crc_rom[170] = 32'h36034af6;
    crc_rom[171] = 32'h41047a60;
    crc_rom[172] = 32'hdf60efc3;
    crc_rom[173] = 32'ha867df55;
    crc_rom[174] = 32'h316e8eef;
    crc_rom[175] = 32'h4669be79;
    crc_rom[176] = 32'hcb61b38c;
    crc_rom[177] = 32'hbc66831a;
    crc_rom[178] = 32'h256fd2a0;
    crc_rom[179] = 32'h5268e236;
    crc_rom[180] = 32'hcc0c7795;
    crc_rom[181] = 32'hbb0b4703;
    crc_rom[182] = 32'h220216b9;
    crc_rom[183] = 32'h5505262f;
    crc_rom[184] = 32'hc5ba3bbe;
    crc_rom[185] = 32'hb2bd0b28;
    crc_rom[186] = 32'h2bb45a92;
    crc_rom[187] = 32'h5cb36a04;
    crc_rom[188] = 32'hc2d7ffa7;
    crc_rom[189] = 32'hb5d0cf31;
    crc_rom[190] = 32'h2cd99e8b;
    crc_rom[191] = 32'h5bdeae1d;
    crc_rom[192] = 32'h9b64c2b0;
    crc_rom[193] = 32'hec63f226;
    crc_rom[194] = 32'h756aa39c;
    crc_rom[195] = 32'h026d930a;
    crc_rom[196] = 32'h9c0906a9;
    crc_rom[197] = 32'heb0e363f;
    crc_rom[198] = 32'h72076785;
    crc_rom[199] = 32'h05005713;
    crc_rom[200] = 32'h95bf4a82;
    crc_rom[201] = 32'he2b87a14;
    crc_rom[202] = 32'h7bb12bae;
    crc_rom[203] = 32'h0cb61b38;
    crc_rom[204] = 32'h92d28e9b;
    crc_rom[205] = 32'he5d5be0d;
    crc_rom[206] = 32'h7cdcefb7;
    crc_rom[207] = 32'h0bdbdf21;
    crc_rom[208] = 32'h86d3d2d4;
    crc_rom[209] = 32'hf1d4e242;
    crc_rom[210] = 32'h68ddb3f8;
    crc_rom[211] = 32'h1fda836e;
    crc_rom[212] = 32'h81be16cd;
    crc_rom[213] = 32'hf6b9265b;
    crc_rom[214] = 32'h6fb077e1;
    crc_rom[215] = 32'h18b74777;
    crc_rom[216] = 32'h88085ae6;
    crc_rom[217] = 32'hff0f6a70;
    crc_rom[218] = 32'h66063bca;
    crc_rom[219] = 32'h11010b5c;
    crc_rom[220] = 32'h8f659eff;
    crc_rom[221] = 32'hf862ae69;
    crc_rom[222] = 32'h616bffd3;
    crc_rom[223] = 32'h166ccf45;
    crc_rom[224] = 32'ha00ae278;
    crc_rom[225] = 32'hd70dd2ee;
    crc_rom[226] = 32'h4e048354;
    crc_rom[227] = 32'h3903b3c2;
    crc_rom[228] = 32'ha7672661;
    crc_rom[229] = 32'hd06016f7;
    crc_rom[230] = 32'h4969474d;
    crc_rom[231] = 32'h3e6e77db;
    crc_rom[232] = 32'haed16a4a;
    crc_rom[233] = 32'hd9d65adc;
    crc_rom[234] = 32'h40df0b66;
    crc_rom[235] = 32'h37d83bf0;
    crc_rom[236] = 32'ha9bcae53;
    crc_rom[237] = 32'hdebb9ec5;
    crc_rom[238] = 32'h47b2cf7f;
    crc_rom[239] = 32'h30b5ffe9;
    crc_rom[240] = 32'hbdbdf21c;
    crc_rom[241] = 32'hcabac28a;
    crc_rom[242] = 32'h53b39330;
    crc_rom[243] = 32'h24b4a3a6;
    crc_rom[244] = 32'hbad03605;
    crc_rom[245] = 32'hcdd70693;
    crc_rom[246] = 32'h54de5729;
    crc_rom[247] = 32'h23d967bf;
    crc_rom[248] = 32'hb3667a2e;
    crc_rom[249] = 32'hc4614ab8;
    crc_rom[250] = 32'h5d681b02;
    crc_rom[251] = 32'h2a6f2b94;
    crc_rom[252] = 32'hb40bbe37;
    crc_rom[253] = 32'hc30c8ea1;
    crc_rom[254] = 32'h5a05df1b;
    crc_rom[255] = 32'h2d02ef8d;
  end

endmodule : crc32_8b
