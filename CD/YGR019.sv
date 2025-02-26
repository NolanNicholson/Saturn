module YGR019 (
	input             CLK,
	input             RST_N,
	
	input             RES_N,
	
	input             CE_R,
	input             CE_F,
	input      [14:1] AA,
	input      [15:0] ADI,
	output     [15:0] ADO,
	input       [1:0] AFC,
	input             ACS2_N,
	input             ARD_N,
	input             AWRL_N,
	input             AWRU_N,
	input             ATIM0_N,
	input             ATIM2_N,
	output            AWAIT_N,
	output            ARQT_N,
	
	input             SHCE_R,
	input             SHCE_F,
	input      [21:1] SA,
	input      [15:0] SDI,
	input      [15:0] BDI,
	output     [15:0] SDO,
	input             SWRL_N,
	input             SWRH_N,
	input             SRD_N,
	input             SCS2_N,
	input             SCS6_N,
	input             DACK0,
	input             DACK1,
	output            DREQ0_N,
	output            DREQ1_N,
	output reg        SIRQL_N,
	output reg        SIRQH_N,

	input             CDD_CE,	//44100Hz*2*2
		
	input      [17:0] CD_D,
	input             CD_CK,
	
	output     [15:0] CD_SL,
	output     [15:0] CD_SR
	
`ifdef DEBUG
	                  ,
	output     [31:0] DBG_HEADER,
//	output     [7:0] DBG_CNT,
//	output     [7:0] FIFO_CNT_DBG,
	output    [15:0] ABUS_READ_CNT_DBG,
	output     [7:0] ABUS_WAIT_CNT_DBG,
	output reg  HOOK,
	output reg  HOOK2,
	output reg  DBG_HIRQ_CLR,
	output reg  DBG_HIRQ_SET,
	output reg [7:0] DBG_E0_CNT,
	output reg [7:0] DBG_E1_CNT,
	output     [11:0] DBG_CDD_CNT
`endif
);
	import YGR019_PKG::*;

	CR_t       CR[4];
	CR_t       RR[4];
	bit [15:0]/*HIRQREQ_t*/  HIRQ;
	bit [15:0]/*HIRQMSK_t*/  HMASK;
	bit [15:0] DTR;
	bit [15:0] TRCTL;
	bit [15:0] CDIRQL;
	bit [15:0] CDIRQU;
	bit [15:0] CDMASKU;
	bit [15:0] CDMASKL;
	bit [15:0] REG1A;
	//bit [15:0] REG1C;
		
	bit [15:0] FIFO_BUF[8];
	bit  [2:0] FIFO_WR_POS;
	bit  [2:0] FIFO_RD_POS;
	bit  [2:0] FIFO_AMOUNT;
//	bit        FIFO_FULL;
	bit        FIFO_EMPTY;
	bit        FIFO_DREQ;
	bit  [1:0] CDD_DREQ;
	
	bit        CDFIFO_RD;
	bit        CDFIFO_WR;
	bit [17:0] CDFIFO_Q;
	bit        CDFIFO_EMPTY;
	bit        CDFIFO_FULL;
	bit        CD_CK_OLD;
	bit [15:0] CDD_DATA;
	
	bit        CDD_CE_DIV;
	always @(posedge CLK) if (CDD_CE) CDD_CE_DIV <= ~CDD_CE_DIV;

	always @(posedge CLK) CD_CK_OLD <= CD_CK;
	assign CDFIFO_WR = CD_CK & ~CD_CK_OLD;
	
	CDFIFO fifo 
	(
		.clock(CLK),
		.data(CD_D),
		.wrreq(CDFIFO_WR),
		.rdreq(CDFIFO_RD),
		.q(CDFIFO_Q),
		.empty(CDFIFO_EMPTY),
		.full(CDFIFO_FULL)
	);
	
	wire CD_SPEED = CDFIFO_Q[16];
	wire CD_AUDIO = CDFIFO_Q[17];
	
	wire SCU_REG_SEL = (AA[14:12] == 3'b000) & ~ACS2_N;
	wire SH_REG_SEL = (SA[21:20] == 2'b00) & ~SCS2_N;
	wire SH_MPEG_SEL = (SA[21:20] == 2'b01) & ~SCS2_N;
	wire ABUS_WAIT_EN = SCU_REG_SEL && AA[5:2] == 4'b0000;
	bit [15:0] SCU_REG_DO;
	bit        ABUS_WAIT;
	bit [15:0] SH_REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		bit        AWR_N_OLD;
		bit        ARD_N_OLD;
		bit        SWR_N_OLD;
		bit        SRD_N_OLD;
		bit        DACK0_OLD;
		bit        DACK1_OLD;
		bit        FIFO_INC_AMOUNT;
		bit        FIFO_DEC_AMOUNT;
		bit        FIFO_DREQ_PEND;
		bit        TRCTL1_OLD,TRCTL2_OLD;
		bit        CDD_SYNCED;
		bit [11:0] CDD_CNT;
		bit        CDD_PEND;
		bit        CDDA_CHAN;

		if (!RST_N) begin
			CR <= '{4{'0}};
			RR <= '{4{'0}};
			HIRQ <= '0;
			HMASK <= '0;

			CDIRQL <= '0;
			CDMASKL <= '0;
			REG1A <= '0;
			//REG1C <= '0;
			
			CDIRQU <= '0;
			CDMASKU <= '0;
			
			SH_REG_DO <= '0;
			ABUS_WAIT <= 0;
			
			FIFO_BUF <= '{8{'0}};
			FIFO_WR_POS <= '0;
			FIFO_RD_POS <= '0;
			FIFO_AMOUNT <= '0;
//			FIFO_FULL <= 0;
			FIFO_EMPTY <= 0;
			FIFO_DREQ_PEND <= 0;
			FIFO_DREQ <= 0;
			
			CDD_DREQ <= '0;
			CDD_SYNCED <= 0;
			CDD_CNT <= 4'd0;
			CDD_PEND <= 0;
			CDDA_CHAN <= 0;
					
`ifdef DEBUG
			HOOK <= 0;
			DBG_E0_CNT <= '0;
			DBG_E1_CNT <= '0;
`endif
		end else begin
			if (!RES_N) begin
				
			end else begin
				if (CE_R) begin
					AWR_N_OLD <= AWRL_N & AWRU_N;
					ARD_N_OLD <= ARD_N;
				end

`ifdef DEBUG
				if (ABUS_WAIT_CNT_DBG < 8'hF0 && CE_R) ABUS_WAIT_CNT_DBG <= ABUS_WAIT_CNT_DBG + 8'd1;
				
				DBG_HIRQ_CLR <= 0; 
				DBG_HIRQ_SET <= 0;
`endif
				if (SCU_REG_SEL) begin
					if ((!AWRL_N || !AWRU_N) && AWR_N_OLD && CE_R) begin
						case ({AA[5:2],2'b00})
//							6'h00: DTR <= ADI;
							6'h08: begin 
								for (int i=0; i<16; i++) if (!ADI[i]) HIRQ[i] <= 0;
							end
							6'h0C: HMASK <= ADI;
							6'h18: CR[0] <= ADI; 
							6'h1C: CR[1] <= ADI;
							6'h20: CR[2] <= ADI;
							6'h24: begin CR[3] <= ADI; CDIRQL[0] <= 1; CDIRQL[1] <= 0; end
							default:;
						endcase
						
`ifdef DEBUG
						case ({AA[5:2],2'b00})
							6'h08: begin 
								DBG_HIRQ_CLR <= 1; 
							end
							6'h24: begin
								if (CR[0] == 16'h1081 && CR[1] == 16'hAE58) HOOK <= 1;
								if (CR[0][15:8] == 8'hE0) DBG_E0_CNT <= DBG_E0_CNT + 1'd1;
								if (CR[0][15:8] == 8'hE1) DBG_E1_CNT <= DBG_E1_CNT + 1'd1;
							end
							default:;
						endcase
`endif
					end else if (!ARD_N && ARD_N_OLD && CE_F) begin
						case ({AA[5:2],2'b00})
							6'h00: begin
								ABUS_WAIT <= 1;
`ifdef DEBUG
								ABUS_WAIT_CNT_DBG <= '0;
								ABUS_READ_CNT_DBG <= ABUS_READ_CNT_DBG + 1;
`endif
							end
							6'h08: SCU_REG_DO <= HIRQ;
							6'h0C: SCU_REG_DO <= HMASK;
							6'h18: SCU_REG_DO <= RR[0];
							6'h1C: SCU_REG_DO <= RR[1];
							6'h20: SCU_REG_DO <= RR[2];
							6'h24: begin 
								SCU_REG_DO <= RR[3]; 
								CDIRQL[1] <= 1; 
							end
							default: SCU_REG_DO <= '0;
						endcase
					end
				end
				
				if (CE_F) begin
					if (ABUS_WAIT && (!FIFO_EMPTY || TRCTL[3])) begin
						SCU_REG_DO <= FIFO_BUF[FIFO_RD_POS]; 
						FIFO_RD_POS <= FIFO_RD_POS + 3'd1;
						FIFO_DEC_AMOUNT <= 1;
						if (FIFO_AMOUNT <= 7'd1) begin
							FIFO_DREQ_PEND <= 1;
						end
						ABUS_WAIT <= 0;
`ifdef DEBUG
						ABUS_WAIT_CNT_DBG <= 8'hFF;
`endif
					end
				end
				
				if (SHCE_R) begin
					SWR_N_OLD <= SWRL_N & SWRH_N;
					SRD_N_OLD <= SRD_N;
					if (SH_REG_SEL) begin
						if ((!SWRL_N || !SWRH_N) && SWR_N_OLD) begin
							case ({SA[4:1],1'b0})
								5'h00:  begin 
									if (TRCTL[2]) begin
										FIFO_BUF[FIFO_WR_POS] <= SDI;
										FIFO_WR_POS <= FIFO_WR_POS + 3'd1;
										FIFO_INC_AMOUNT <= 1;
									end
								end
								5'h02: TRCTL <= SDI & TRCTL_WMASK; 
								5'h04: CDIRQL <= SDI & CDIRQL_WMASK;
								5'h06: CDIRQU <= SDI & CDIRQU_WMASK;
								5'h08: CDMASKL <= SDI & CDMASKL_WMASK;
								5'h0A: CDMASKU <= SDI & CDMASKU_WMASK;
								5'h10: RR[0] <= SDI;
								5'h12: RR[1] <= SDI;
								5'h14: RR[2] <= SDI;
								5'h16: RR[3] <= SDI;
								5'h1A: REG1A <= SDI & REG1A_WMASK;
		//						5'h1C: REG1C <= SDI;
								5'h1E: begin 
									for (int i=0; i<16; i++) if (SDI[i]) HIRQ[i] <= 1;
`ifdef DEBUG
									DBG_HIRQ_SET <= 1;
									if (CR[0] == 16'h5100 && RR[3] == 16'h00C8 && SDI[0]) HOOK2 <= HOOK;
`endif
								end
								default:;
							endcase
						end else if (!SRD_N && SRD_N_OLD) begin
							case ({SA[4:1],1'b0})
								5'h00: begin
									SH_REG_DO <= FIFO_BUF[FIFO_RD_POS]; 
									FIFO_RD_POS <= FIFO_RD_POS + 3'd1;
									FIFO_DEC_AMOUNT <= 1;
									if (FIFO_RD_POS[1:0] == 2'd3) begin
										FIFO_DREQ_PEND <= 1;
									end
								end
								5'h02: SH_REG_DO <= TRCTL & TRCTL_RMASK;
								5'h04: SH_REG_DO <= CDIRQL & CDIRQL_RMASK;
								5'h06: SH_REG_DO <= CDIRQU & CDIRQU_RMASK;
								5'h08: SH_REG_DO <= CDMASKL & CDMASKL_RMASK;
								5'h0A: SH_REG_DO <= CDMASKU & CDMASKU_RMASK;
								5'h10: SH_REG_DO <= CR[0];
								5'h12: SH_REG_DO <= CR[1];
								5'h14: SH_REG_DO <= CR[2];
								5'h16: SH_REG_DO <= CR[3];
								5'h1A: SH_REG_DO <= REG1A & REG1A_RMASK;
								5'h1C: SH_REG_DO <= 16'h0016;//REG1C;
								default: SH_REG_DO <= '0;
							endcase
						end
					end else if (SH_MPEG_SEL) begin
						if (!SRD_N && SRD_N_OLD) begin
							case ({SA[4:1],1'b0})
								5'h02: SH_REG_DO <= 16'h006C;
								default: SH_REG_DO <= '0;
							endcase
						end
					end
				end
				
				//DREQ1
				if (SHCE_R) begin
//					if (FIFO_CNT_DBG < 8'h80) FIFO_CNT_DBG <= FIFO_CNT_DBG + 8'd1;
					
					TRCTL2_OLD <= TRCTL[2];
					if (TRCTL[2] && !TRCTL2_OLD) begin
						FIFO_DREQ <= 1;
					end
					if (FIFO_DREQ_PEND) begin
						FIFO_DREQ_PEND <= 0;
						FIFO_DREQ <= 1;
//						FIFO_CNT_DBG <= '0;
					end

					DACK1_OLD <= DACK1;
					if (TRCTL[2] && DACK1 && !DACK1_OLD) begin
						FIFO_BUF[FIFO_WR_POS] <= BDI;
						FIFO_WR_POS <= FIFO_WR_POS + 3'd1;
						FIFO_INC_AMOUNT <= 1;
						if (FIFO_AMOUNT > 7'd2 && FIFO_DREQ) begin
							FIFO_DREQ <= 0;
//							FIFO_CNT_DBG <= 8'hFF;
						end
					end
					
					TRCTL1_OLD <= TRCTL[1];
					if (TRCTL[1] && !TRCTL1_OLD) begin
						FIFO_WR_POS <= '0;
						FIFO_RD_POS <= '0;
						FIFO_AMOUNT <= '0;
//						FIFO_FULL <= 0;
						FIFO_EMPTY <= 1;
						FIFO_DREQ <= 0;
`ifdef DEBUG
						ABUS_WAIT_CNT_DBG <= 8'hFF;
						ABUS_READ_CNT_DBG <= '0;
`endif
					end
				end
				
				if (FIFO_INC_AMOUNT && FIFO_DEC_AMOUNT) begin
					FIFO_INC_AMOUNT <= 0;
					FIFO_DEC_AMOUNT <= 0;
				end else if (FIFO_INC_AMOUNT) begin
					FIFO_AMOUNT <= FIFO_AMOUNT + 3'd1;
					if (FIFO_AMOUNT == 3'd7) FIFO_AMOUNT <= 3'd7;
//					if (FIFO_AMOUNT == 3'd6) FIFO_FULL <= 1;
					FIFO_EMPTY <= 0;
					FIFO_INC_AMOUNT <= 0;
				end else if (FIFO_DEC_AMOUNT) begin
					FIFO_AMOUNT <= FIFO_AMOUNT - 3'd1;
					if (FIFO_AMOUNT == 3'd0) FIFO_AMOUNT <= 3'd0;
					if (FIFO_AMOUNT == 3'd1) FIFO_EMPTY <= 1;
//					FIFO_FULL <= 0;
					FIFO_DEC_AMOUNT <= 0;
				end
				
				//DREQ0
				CDFIFO_RD <= 0;
				if (CDD_CE) begin
					if (CD_SPEED || CDD_CE_DIV) begin
						if (!CDFIFO_EMPTY) begin
							CDFIFO_RD <= 1;
							if (!CD_AUDIO) begin
								CDD_CNT <= CDD_CNT + 12'd2;
								if (!CDD_SYNCED) begin
									if (CDD_CNT == 12'd10) begin
										CDD_SYNCED <= 1; 
										REG1A[7] <= 1; 
									end
								end else if (CDD_CNT == 12'd12) begin
`ifdef DEBUG
									DBG_HEADER[31:16] <= CDFIFO_Q[15:0];
`endif
								end else if (CDD_CNT == 12'd14) begin
									CDIRQU[4] <= 1;
`ifdef DEBUG
									DBG_HEADER[15:0] <= CDFIFO_Q[15:0];
`endif
								end else if (CDD_CNT == 12'd2352-2) begin
									CDD_SYNCED <= 0;
									CDD_CNT <= 12'd0;
								end
								CDD_DATA <= CDFIFO_Q[15:0];
								CDD_PEND <= CDD_SYNCED;
								
								CD_SL <= '0;
								CD_SR <= '0;
								
							end else begin
								CDDA_CHAN <= ~CDDA_CHAN;
								if (!CDDA_CHAN) CD_SL <= {CDFIFO_Q[7:0],CDFIFO_Q[15:8]};
								if ( CDDA_CHAN) CD_SR <= {CDFIFO_Q[7:0],CDFIFO_Q[15:8]};
							end
						end else begin
							CD_SL <= '0;
							CD_SR <= '0;
						end
					end
				end
`ifdef DEBUG
				DBG_CDD_CNT <= CDD_CNT;
`endif
				
				if (SHCE_R) begin
//					if (DBG_CNT < 8'h80) DBG_CNT <= DBG_CNT + 8'd1;
					
					if (CDD_PEND) begin
						CDD_DREQ[0] <= REG1A[7];
						CDD_PEND <= 0;
//						if (REG1A[7]) DBG_CNT <= '0;
					end else if (CDD_DREQ[0]) begin
						CDD_DREQ[0] <= 0;
					end
					CDD_DREQ[1] <= CDD_DREQ[0];
					
					DACK0_OLD <= DACK0;
					if (DACK0 && !DACK0_OLD) begin
//						DBG_CNT <= 8'hFF;
					end
				end
			end
		end
	end

	assign ADO = SCU_REG_DO;
	assign AWAIT_N = ~(ABUS_WAIT & ABUS_WAIT_EN);
	assign ARQT_N = 1;//TODO
	
	assign SDO = !DACK0 ? CDD_DATA : SH_REG_DO;
	
	assign SIRQL_N = ~|(CDIRQL & CDMASKL);
	assign SIRQH_N = ~|(CDIRQU & CDMASKU);
	assign DREQ0_N = ~|CDD_DREQ;
	assign DREQ1_N = ~FIFO_DREQ;
	
	
endmodule
