module SMPC (
	input             CLK,
	input             RST_N,
	input             CE,
	
	input             MRES_N,
	input             TIME_SET,
	
	input       [3:0] AC,
	
	input       [6:1] A,
	input       [7:0] DI,
	output      [7:0] DO,
	input             CS_N,
	input             RW_N,
	
	input             SRES_N,
	
	input             IRQV_N,
	input             EXL,
	
	output reg        MSHRES_N,
	output reg        MSHNMI_N,
	output reg        SSHRES_N,
	output reg        SSHNMI_N,
	output reg        SYSRES_N,
	output reg        SNDRES_N,
	output reg        CDRES_N,
	
	output reg        MIRQ_N,
	
	input      [15:0] JOY1,
	input      [15:0] JOY2,

    input       [7:0] JOY1_X1,
    input       [7:0] JOY1_Y1,
    input       [7:0] JOY1_X2,
    input       [7:0] JOY1_Y2,
    input       [7:0] JOY2_X1,
    input       [7:0] JOY2_Y1,
    input       [7:0] JOY2_X2,
    input       [7:0] JOY2_Y2,

	input       [2:0] JOY1_TYPE,
	input       [2:0] JOY2_TYPE
);

	//Registers
	bit   [7:0] COMREG;
	bit   [7:0] SR;
	bit         SF;
	bit   [7:0] IREG[7];
	bit   [7:0] PDR1O;
	bit   [7:0] PDR2O;
	bit   [6:0] DDR1;
	bit   [6:0] DDR2;
//	bit   [1:0] IOSEL;
//	bit   [1:0] EXLE;
	bit   [6:0] PDR1I;
	bit   [6:0] PDR2I;
	
	bit         DOTSEL;
	bit         RESD;
	bit         STE;
	
	bit   [7:0] SEC;
	bit   [7:0] MIN;
	bit   [7:0] HOUR;
	bit   [7:0] DAY;
	
	bit   [7:0] SMEM[4];

	parameter SR_PDE = 2;
	parameter SR_RESB = 3;
	
	always_comb begin
		PDR1I = 7'h7F;
		if (DDR1 == 7'h00) begin
			PDR1I = 7'h7C;
		end else if (DDR1 == 7'h40) begin
			case (PDR1O[6])
				1'b0:  PDR1I = {3'b011,JOY1[15:12]};
				1'b1:  PDR1I = {3'b111,JOY1[ 3: 3],3'b100};
			endcase
		end else if (DDR1 == 7'h60) begin
			case (PDR1O[6:5])
				2'b00: PDR1I = {3'b001,JOY1[ 7: 4]};
				2'b01: PDR1I = {3'b001,JOY1[15:12]};
				2'b10: PDR1I = {3'b001,JOY1[11: 8]};
				2'b11: PDR1I = {3'b001,JOY1[ 3: 3],3'b100};
			endcase
		end
		
		PDR2I = 7'h7F;
		if (DDR2 == 7'h00) begin
			PDR2I = 7'h7C;
		end else if (DDR1 == 7'h40) begin
			case (PDR2O[6])
				1'b0:  PDR2I = {3'b011,JOY2[15:12]};
				1'b1:  PDR2I = {3'b111,JOY2[ 3: 3],3'b100};
			endcase
		end else if (DDR2 == 7'h60) begin
			case (PDR2O[6:5])
				2'b00: PDR2I = {3'b001,JOY2[ 7: 4]};
				2'b01: PDR2I = {3'b001,JOY2[15:12]};
				2'b10: PDR2I = {3'b001,JOY2[11: 8]};
				2'b11: PDR2I = {3'b001,JOY2[ 3: 3],3'b100};
			endcase
		end
	end
	
	bit SEC_CLK;
	always @(posedge CLK or negedge RST_N) begin
		bit [21:0] CLK_CNT;
		
		if (!RST_N) begin
			SEC_CLK <= 0;
			CLK_CNT <= '0;
		end else if (CE) begin
			SEC_CLK <= 0;
				
			CLK_CNT <= CLK_CNT + 3'd1;
			if (CLK_CNT == 22'd4000000-1) begin
				CLK_CNT <= 22'd0;
				SEC_CLK <= 1;
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			SEC <= '0;
			MIN <= '0;
			HOUR <= '0;
			DAY <= '0;
		end else if (SEC_CLK && CE) begin
			SEC[3:0] <= SEC[3:0] + 4'd1;
			if (SEC[3:0] == 4'd9) begin
				SEC[3:0] <= 4'd0;
				SEC[7:4] <= SEC[7:4] + 4'd1;
				if (SEC[7:4] == 4'd5) begin
					SEC[7:4] <= 4'd0;
					MIN[3:0] <= MIN[3:0] + 4'd1;
					if (MIN[3:0] == 4'd9) begin
						MIN[3:0] <= 4'd0;
						MIN[7:4] <= MIN[7:4] + 4'd1;
						if (MIN[7:4] == 4'd5) begin
							MIN[7:4] <= 4'd0;
							HOUR[3:0] <= HOUR[3:0] + 4'd1;
							if (HOUR[3:0] == 4'd9) begin
								HOUR[3:0] <= 4'd0;
								HOUR[7:4] <= HOUR[7:4] + 4'd1;
								if (HOUR[7:4] == 4'd2 && HOUR[3:0] == 4'd3) begin
									HOUR[7:4] <= 4'd0;
									HOUR[3:0] <= 4'd0;
									DAY[3:0] <= DAY[3:0] + 4'd1;
									if (DAY[3:0] == 4'd9) begin
										DAY[7:4] <= DAY[7:4] + 4'd1;
										DAY[3:0] <= 4'd0;
										if (DAY[7:4] == 4'd3 && HOUR[3:0] == 4'd1) begin//TODO
											DAY[7:4] <= 4'd0;
											DAY[3:0] <= 4'd1;
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	
	typedef enum bit [6:0] {
		CS_IDLE	        = 7'b0000001,
		CS_START        = 7'b0000010, 
		CS_WAIT         = 7'b0000100, 
		CS_EXEC         = 7'b0001000,
		CS_INTBACK_WAIT = 7'b0010000,
		CS_INTBACK_PERI = 7'b0100000,
		CS_END          = 7'b1000000
	} CommExecState_t;
	CommExecState_t COMM_ST;

	typedef enum {
		PADSTATE_STATUS,
		PADSTATE_ID,

		PADSTATE_DIGITAL_MSB,
		PADSTATE_DIGITAL_LSB,

		PADSTATE_ANALOG_BUTTONSMSB,
		PADSTATE_ANALOG_BUTTONSLSB,
		PADSTATE_ANALOG_X1,
		PADSTATE_ANALOG_Y1,
		PADSTATE_ANALOG_Z1,
		PADSTATE_ANALOG_DUMMY,
		PADSTATE_ANALOG_X2,
		PADSTATE_ANALOG_Y2,
		PADSTATE_ANALOG_Z2,

		PADSTATE_IDLE
	} PadState_t;
	PadState_t PADSTATE;

	parameter PAD_DIGITAL     = 0;
	parameter PAD_OFF         = 1;
	parameter PAD_WHEEL       = 2;
	parameter PAD_MISSION     = 3;
	parameter PAD_3D          = 4;
	parameter PAD_DUALMISSION = 5;
	parameter PAD_LIGHTGUN    = 6;
	
	bit [7:0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		bit [ 4:0] OREG_CNT;
		bit        RW_N_OLD;
		bit        CS_N_OLD;
		bit        IRQV_N_OLD;
		bit [15:0] WAIT_CNT;
		bit [15:0] INTBACK_WAIT_CNT;
		bit        SRES_EXEC;
		bit        INTBACK_EXEC;
		bit        INTBACK_PERI;
		bit        COMREG_SET;
		bit        CONT;
		bit [1:0]  CURRPAD_ID;
		bit [2:0]  CURRPAD_TYPE;
		bit [15:0] CURRPAD_BUTTONS;
		bit [7:0]  CURRPAD_ANALOGX1;
		bit [7:0]  CURRPAD_ANALOGY1;
		bit [7:0]  CURRPAD_ANALOGX2;
		bit [7:0]  CURRPAD_ANALOGY2;
		
		if (!RST_N) begin
			COMREG <= '0;
			SR <= '0;
			SF <= 0;
			IREG <= '{7{'0}};
			PDR1O <= '0;
			PDR2O <= '0;
			DDR1 <= '0;
			DDR2 <= '0;
//			IOSEL <= '0;
//			EXLE <= '0;
			
			MSHRES_N <= 0;
			MSHNMI_N <= 0;
			SSHRES_N <= 0;
			SSHNMI_N <= 0;
			SYSRES_N <= 0;
			SNDRES_N <= 0;
			CDRES_N <= 0;
			MIRQ_N <= 1;
			RESD <= 1;
			STE <= 0;
			
			REG_DO <= '0;
			RW_N_OLD <= 1;
			CS_N_OLD <= 1;
			IRQV_N_OLD <= 1;
			COMM_ST <= CS_IDLE;
			SRES_EXEC <= 0;
			INTBACK_EXEC <= 0;
			INTBACK_PERI <= 0;	  
			CONT <= 0;
		end
		else if (!MRES_N) begin
			MSHRES_N <= 1;
			MSHNMI_N <= 1;
			SSHRES_N <= 0;
			SSHNMI_N <= 1;
			SYSRES_N <= 1;
			SNDRES_N <= 0;
			CDRES_N <= 1;
			MIRQ_N <= 1;
			SR <= '0;
			RESD <= 1;
			STE <= TIME_SET;/////////////////
		end else begin
			OREG_RAM_WE <= 0;
			
			if (CE) begin
				IRQV_N_OLD <= IRQV_N;
				
				if (WAIT_CNT) WAIT_CNT <= WAIT_CNT - 16'd1;
				
				if (INTBACK_WAIT_CNT) INTBACK_WAIT_CNT <= INTBACK_WAIT_CNT - 16'd1;
				if (IRQV_N && !IRQV_N_OLD) INTBACK_WAIT_CNT <= 16'd40000;
				
				if (!SRES_N && !RESD && !SRES_EXEC) begin
					MSHNMI_N <= 0;
					SSHNMI_N <= 0;
					WAIT_CNT <= 16'd60000;
					SRES_EXEC <= 1;
				end else if (SRES_EXEC && !WAIT_CNT) begin
					MSHNMI_N <= 1;
					SSHNMI_N <= 1;
				end
				
				SR[4:0] <= {~SRES_N,IREG[1][7:4]};
				
				case (COMM_ST)
					CS_IDLE: begin
						if (INTBACK_PERI && !INTBACK_WAIT_CNT && !SRES_EXEC && IRQV_N) begin
							INTBACK_PERI <= 0;
							OREG_CNT <= '0;
							COMM_ST <= CS_INTBACK_PERI;
							PADSTATE <= PADSTATE_STATUS;
							CURRPAD_ID <= 0;
						end else if (COMREG_SET && !SRES_EXEC) begin
							COMREG_SET <= 0;
							OREG_CNT <= '0;
							COMM_ST <= CS_START;
						end
						MIRQ_N <= 1;
					end
					
					CS_START: begin
						case (COMREG) 
							8'h00: begin		//MSHON
								WAIT_CNT <= 16'd120;
								COMM_ST <= CS_WAIT;
							end
							
							8'h02: begin		//SSHON
								WAIT_CNT <= 16'd120;
								COMM_ST <= CS_WAIT;
							end
							
							8'h03: begin		//SSHOFF
								WAIT_CNT <= 16'd120;
								COMM_ST <= CS_WAIT;
							end
							
							8'h06: begin		//SNDON
								WAIT_CNT <= 16'd120;
								COMM_ST <= CS_WAIT;
							end
							
							8'h07: begin		//SNDOFF
								WAIT_CNT <= 16'd120;
								COMM_ST <= CS_WAIT;
							end
							
							8'h08: begin		//CDON
								WAIT_CNT <= 16'd159;
								COMM_ST <= CS_WAIT;
							end
							
							8'h09: begin		//CDOFF
								WAIT_CNT <= 16'd159;
								COMM_ST <= CS_WAIT;
							end
							
							8'h0D: begin		//SYSRES
								WAIT_CNT <= 16'd400;
								COMM_ST <= CS_WAIT;
							end
							
							8'h0E: begin		//CKCHG352
								WAIT_CNT <= 16'd400;
								COMM_ST <= CS_WAIT;
							end
							
							8'h0F: begin		//CKCHG320
								WAIT_CNT <= 16'd400;
								COMM_ST <= CS_WAIT;
							end
							
							8'h10: begin		//INTBACK
								if (IREG[2] == 8'hF0 && (IREG[0][0] || IREG[1][3])) begin
									if (IREG[0][0]) begin
										WAIT_CNT <= 16'd500;
										COMM_ST <= CS_WAIT;
									end else begin
										INTBACK_EXEC <= 1;
										INTBACK_PERI <= 1;
										CONT <= 0;
										SR[7:5] <= 3'b010;
										SF <= 1;
										COMM_ST <= CS_END;
									end
								end else begin
									COMM_ST <= CS_END;
								end
							end
							
							8'h16: begin		//SETTIME
								WAIT_CNT <= 16'd279;
								COMM_ST <= CS_WAIT;
							end
							
							8'h17: begin		//SETSMEM
								WAIT_CNT <= 16'd159;
								COMM_ST <= CS_WAIT;
							end
							
							8'h18: begin		//NMIREQ
								WAIT_CNT <= 16'd127;
								COMM_ST <= CS_WAIT;
							end
							
							8'h19: begin		//RESENAB
								WAIT_CNT <= 16'd127;
								COMM_ST <= CS_WAIT;
							end
							
							8'h1A: begin		//RESDISA
								WAIT_CNT <= 16'd127;
								COMM_ST <= CS_WAIT;
							end
							
							default: begin
								COMM_ST <= CS_EXEC;
							end
						endcase
					end
					
					CS_WAIT: begin
						if (!WAIT_CNT) COMM_ST <= CS_EXEC;
					end
					
					CS_EXEC: begin
						SF <= 0;
						OREG_RAM_WA <= 5'd31;
						OREG_RAM_D <= COMREG;
						OREG_RAM_WE <= 1;
						case (COMREG) 
							8'h00: begin		//MSHON
								MSHRES_N <= 1;
								MSHNMI_N <= 1;//?
								COMM_ST <= CS_END;
							end
							
							8'h02: begin		//SSHON
								SSHRES_N <= 1;
								SSHNMI_N <= 1;//?
								COMM_ST <= CS_END;
							end
							
							8'h03: begin		//SSHOFF
								SSHRES_N <= 0;
								SSHNMI_N <= 1;//?
								COMM_ST <= CS_END;
							end
							
							8'h06: begin		//SNDON
								SNDRES_N <= 1;
								COMM_ST <= CS_END;
							end
							
							8'h07: begin		//SNDOFF
								SNDRES_N <= 0;
								COMM_ST <= CS_END;
							end
							
							8'h08: begin		//CDON
								CDRES_N <= 1;
								COMM_ST <= CS_END;
							end
							
							8'h09: begin		//CDOFF
								CDRES_N <= 0;
								COMM_ST <= CS_END;
							end
							
							8'h0D: begin		//SYSRES
								MSHRES_N <= 0;
								MSHNMI_N <= 0;
								SSHRES_N <= 0;
								SSHNMI_N <= 0;
								SNDRES_N <= 0;
								CDRES_N <= 0;
								SYSRES_N <= 0;
								COMM_ST <= CS_END;
							end
							
							8'h0E: begin		//CKCHG352
								MSHNMI_N <= 0;
								SSHRES_N <= 0;
								SSHNMI_N <= 0;
								SNDRES_N <= 0;
								SYSRES_N <= 0;
								DOTSEL <= 1;
								COMM_ST <= CS_END;
							end
							
							8'h0F: begin		//CKCHG320
								MSHNMI_N <= 0;
								SSHRES_N <= 0;
								SSHNMI_N <= 0;
								SNDRES_N <= 0;
								SYSRES_N <= 0;
								DOTSEL <= 0;
								COMM_ST <= CS_END;
							end
							
							8'h10: begin		//INTBACK
								if (!INTBACK_EXEC) begin
									OREG_RAM_WA <= OREG_CNT;
									case (OREG_CNT)
										5'd0: OREG_RAM_D <= {STE,RESD,6'b000000};
										5'd1: OREG_RAM_D <= 8'h20;
										5'd2: OREG_RAM_D <= 8'h22;
										5'd3: OREG_RAM_D <= 8'h01;
										5'd4: OREG_RAM_D <= DAY;
										5'd5: OREG_RAM_D <= HOUR;
										5'd6: OREG_RAM_D <= MIN;
										5'd7: OREG_RAM_D <= SEC;
										5'd8: OREG_RAM_D <= 8'h00;
										5'd9: OREG_RAM_D <= {4'b0000,AC};
										5'd10: OREG_RAM_D <= {1'b0,DOTSEL,2'b11,~MSHNMI_N,1'b1,~SYSRES_N,~SNDRES_N};
										5'd11: OREG_RAM_D <= {1'b0,~CDRES_N,6'b000000};
										5'd12: OREG_RAM_D <= SMEM[0];
										5'd13: OREG_RAM_D <= SMEM[1];
										5'd14: OREG_RAM_D <= SMEM[2];
										5'd15: OREG_RAM_D <= SMEM[3];
										5'd31: OREG_RAM_D <= COMREG;
										default:OREG_RAM_D <= 8'h00;
									endcase
									OREG_RAM_WE <= 1;
									
									if (OREG_CNT == 5'd31) begin
										SR[7:5] <= 3'b010;
										INTBACK_EXEC <= 1;
										if (IREG[1][3]) begin
											SR[5] <= 1;
										end
										CONT <= 0;
										MIRQ_N <= 0;
										COMM_ST <= CS_END;
									end
									OREG_CNT <= OREG_CNT + 5'd1;
								end else
									COMM_ST <= CS_END;
							end
							
							8'h16: begin		//SETTIME
								STE <= 1;
								COMM_ST <= CS_END;
							end
							
							8'h17: begin		//SETSMEM
								SMEM[0] <= IREG[0];
								SMEM[1] <= IREG[1];
								SMEM[2] <= IREG[2];
								SMEM[3] <= IREG[3];
								COMM_ST <= CS_END;
							end
							
							8'h18: begin		//NMIREQ
								MSHNMI_N <= 0;
								COMM_ST <= CS_END;
							end
							
							8'h19: begin		//RESENAB
								RESD <= 0;
								COMM_ST <= CS_END;
							end
							
							8'h1A: begin		//RESDISA
								RESD <= 1;
								COMM_ST <= CS_END;
							end
							
							default: begin
								COMM_ST <= CS_END;
							end
						endcase
					end
					
					CS_INTBACK_WAIT: begin
						if (!WAIT_CNT) begin
							COMM_ST <= CS_INTBACK_PERI;
							PADSTATE <= PADSTATE_STATUS;
							CURRPAD_ID <= 0;
						end
					end
					
					CS_INTBACK_PERI: begin
						OREG_RAM_WA <= OREG_CNT;

						case (PADSTATE)
							// STATUS and ID are common to all pads
							// STATUS: F1 for directly connected, F0 for not
							PADSTATE_STATUS: begin
								case (CURRPAD_ID)
									0: begin
										CURRPAD_TYPE <= JOY1_TYPE;
										CURRPAD_BUTTONS <= JOY1;
										// MiSTer gives signed with 0,0 at center.
										// Saturn uses unsigned with 0,0 at top-left.
										CURRPAD_ANALOGX1 <= {~JOY1_X1[7], JOY1_X1[6:0]};
										CURRPAD_ANALOGY1 <= {~JOY1_Y1[7], JOY1_Y1[6:0]};
										CURRPAD_ANALOGX2 <= {~JOY1_X2[7], JOY1_X2[6:0]};
										CURRPAD_ANALOGY2 <= {~JOY1_Y2[7], JOY1_Y2[6:0]};

										case (JOY1_TYPE)
											PAD_OFF: begin
												OREG_RAM_D <= 8'hF0;

												// done with this peripheral
												PADSTATE <= PADSTATE_STATUS;
												CURRPAD_ID <= CURRPAD_ID + 1;
											end
											default: begin
												OREG_RAM_D <= 8'hF1;
												PADSTATE <= PADSTATE_ID;
											end
										endcase
									end
									1: begin
										CURRPAD_TYPE <= JOY2_TYPE;
										CURRPAD_BUTTONS <= JOY2;
										// MiSTer gives signed with 0,0 at center.
										// Saturn uses unsigned with 0,0 at top-left.
										CURRPAD_ANALOGX1 <= {~JOY2_X1[7], JOY2_X1[6:0]};
										CURRPAD_ANALOGY1 <= {~JOY2_Y1[7], JOY2_Y1[6:0]};
										CURRPAD_ANALOGX2 <= {~JOY2_X2[7], JOY2_X2[6:0]};
										CURRPAD_ANALOGY2 <= {~JOY2_Y2[7], JOY2_Y2[6:0]};

										case (JOY2_TYPE)
											PAD_OFF: begin
												OREG_RAM_D <= 8'hF0;

												// done with this peripheral
												PADSTATE <= PADSTATE_STATUS;
												CURRPAD_ID <= CURRPAD_ID + 1;
											end
											default: begin
												OREG_RAM_D <= 8'hF1;
												PADSTATE <= PADSTATE_ID;
											end
										endcase
									end
									2: begin
										OREG_RAM_D <= 8'hF0;
										PADSTATE <= PADSTATE_IDLE;
									end
								endcase
							end

							// ID: unique for each pad
							PADSTATE_ID: begin
								case (CURRPAD_TYPE)
									// TODO: lightgun currently just digital
									PAD_DIGITAL, PAD_LIGHTGUN: begin
										OREG_RAM_D <= 8'h02;
										PADSTATE <= PADSTATE_DIGITAL_MSB;
									end
									// Wheel is a 1-axis analog device
									PAD_WHEEL: begin
										OREG_RAM_D <= 8'h13;
										PADSTATE <= PADSTATE_ANALOG_BUTTONSMSB;
									end
									// Mission Stick is a 3-axis analog device
									PAD_MISSION: begin
										OREG_RAM_D <= 8'h15;
										PADSTATE <= PADSTATE_ANALOG_BUTTONSMSB;
									end
									// 3D Pad is a 4-axis analog device
									PAD_3D: begin
										OREG_RAM_D <= 8'h16;
										PADSTATE <= PADSTATE_ANALOG_BUTTONSMSB;
									end
									// Dual Mission is a 6-axis device,
									// with a dummy/expansion byte
									PAD_DUALMISSION: begin
										OREG_RAM_D <= 8'h19;
										PADSTATE <= PADSTATE_ANALOG_BUTTONSMSB;
									end
								endcase
							end


							// Saturn 6-button digital pad
							PADSTATE_DIGITAL_MSB: begin
								OREG_RAM_D <= CURRPAD_BUTTONS[15:8];
								PADSTATE <= PADSTATE_DIGITAL_LSB;
							end
							PADSTATE_DIGITAL_LSB: begin
								OREG_RAM_D <= CURRPAD_BUTTONS[7:0];

								// done with this peripheral
								PADSTATE <= PADSTATE_STATUS;
								CURRPAD_ID <= CURRPAD_ID + 1;
							end

							// Button encoding is the same for analog pads
							PADSTATE_ANALOG_BUTTONSMSB: begin
								OREG_RAM_D <= CURRPAD_BUTTONS[15:8];
								PADSTATE <= PADSTATE_ANALOG_BUTTONSLSB;
							end
							PADSTATE_ANALOG_BUTTONSLSB: begin
								OREG_RAM_D <= CURRPAD_BUTTONS[7:0];
								PADSTATE <= PADSTATE_ANALOG_X1;
							end

							PADSTATE_ANALOG_X1: begin
								OREG_RAM_D <= CURRPAD_ANALOGX1;

								case (CURRPAD_TYPE)
									PAD_WHEEL: begin
										// done with this peripheral
										PADSTATE <= PADSTATE_STATUS;
										CURRPAD_ID <= CURRPAD_ID + 1;
									end
									default: begin
										PADSTATE <= PADSTATE_ANALOG_Y1;
									end
								endcase
							end

							PADSTATE_ANALOG_Y1: begin
								OREG_RAM_D <= CURRPAD_ANALOGY1;

								case (CURRPAD_TYPE)
									// On 3D Pad, the RIGHT trigger is first
									PAD_3D: begin
										PADSTATE <= PADSTATE_ANALOG_Z2;
									end
									// Mission and Dual Mission go to Z1
									default: begin
										PADSTATE <= PADSTATE_ANALOG_Z1;
									end
								endcase
							end

							PADSTATE_ANALOG_Z1: begin
								OREG_RAM_D <= 0; // TODO: left shoulder trigger

								case (CURRPAD_TYPE)
									PAD_DUALMISSION: begin
										PADSTATE <= PADSTATE_ANALOG_DUMMY;
									end
									default: begin
										// done with this peripheral
										PADSTATE <= PADSTATE_STATUS;
										CURRPAD_ID <= CURRPAD_ID + 1;
									end
								endcase
							end

							// DUMMY, X2, Y2 all Dual Mission only
							PADSTATE_ANALOG_DUMMY: begin
								OREG_RAM_D <= 0;
								PADSTATE <= PADSTATE_ANALOG_X2;
							end
							PADSTATE_ANALOG_X2: begin
								OREG_RAM_D <= CURRPAD_ANALOGX2;
								PADSTATE <= PADSTATE_ANALOG_Y2;
							end
							PADSTATE_ANALOG_Y2: begin
								OREG_RAM_D <= CURRPAD_ANALOGY2;
								PADSTATE <= PADSTATE_ANALOG_Z2;
							end

							// Z2 reached by Dual Mission and 3D Pad
							PADSTATE_ANALOG_Z2: begin
								OREG_RAM_D <= 0; // TODO: right shoulder trigger

								case (CURRPAD_TYPE)
									PAD_3D: begin
										// triggers reversed on 3D Pad
										PADSTATE <= PADSTATE_ANALOG_Z1;
									end
									default: begin
										// done with this peripheral
										PADSTATE <= PADSTATE_STATUS;
										CURRPAD_ID <= CURRPAD_ID + 1;
									end
								endcase
							end


							// all connected peripherals finished
							PADSTATE_IDLE: begin
								OREG_RAM_D <= 8'h00;
							end

						endcase

						OREG_RAM_WE <= 1;
									
						if (OREG_CNT == 5'd31) begin
							OREG_RAM_D <= COMREG;
							SR[7:5] <= {1'b1,1'b1,1'b0};
							SF <= 0;
							MIRQ_N <= 0;
							COMM_ST <= CS_IDLE;
						end
						OREG_CNT <= OREG_CNT + 5'd1;
					end
					
					CS_END: begin
						case (COMREG) 
							8'h00: begin		//MSHON
								
							end
							
							8'h02: begin		//SSHON
								
							end
							
							8'h03: begin		//SSHOFF
								
							end
							
							8'h06: begin		//SNDON
								
							end
							
							8'h07: begin		//SNDOFF
								
							end
							
							8'h08: begin		//CDON
								
							end
							
							8'h09: begin		//CDOFF
								
							end
							
							8'h0D: begin		//SYSRES
								MSHRES_N <= 1;
								MSHNMI_N <= 1;
								SSHRES_N <= 1;
								SSHNMI_N <= 1;
								SNDRES_N <= 1;
								CDRES_N <= 1;
								SYSRES_N <= 1;
							end
							
							8'h0E: begin		//CKCHG352
								MSHNMI_N <= 1;
								SNDRES_N <= 1;
								SYSRES_N <= 1;
							end
							
							8'h0F: begin		//CKCHG320
								MSHNMI_N <= 1;
								SNDRES_N <= 1;
								SYSRES_N <= 1;
							end
							
							8'h10: begin		//INTBACK

							end
							
							8'h16: begin		//SETTIME
								
							end
							
							8'h17: begin		//SETSMEM
								
							end
							
							8'h18: begin		//NMIREQ
								MSHNMI_N <= 1;
							end
							
							8'h19: begin		//RESENAB
								
							end
							
							8'h1A: begin		//RESDISA
								
							end
							
							default:;
						endcase
						COMM_ST <= CS_IDLE;
					end
				endcase
			end
			
			if (!IRQV_N && IRQV_N_OLD) begin
				INTBACK_EXEC <= 0;
				INTBACK_PERI <= 0;
				SF <= 0;
				SR[7:5] <= 3'b000;
			end
			
			RW_N_OLD <= RW_N;
			if (!RW_N && RW_N_OLD && !CS_N) begin
				case ({A,1'b1})
					7'h01: begin 
						if (INTBACK_EXEC) begin
							if (DI[6]) begin
								INTBACK_EXEC <= 0;
								SF <= 0;
								SR[7:5] <= 3'b000;
							end else if (CONT != DI[7]) begin
								INTBACK_PERI <= 1;
								SF <= 1;
							end
							CONT <= DI[7];
						end else begin
							IREG[0] <= DI;
						end
					end
					7'h03: IREG[1] <= DI;
					7'h05: IREG[2] <= DI;
					7'h07: IREG[3] <= DI;
					7'h09: IREG[4] <= DI;
					7'h0B: IREG[5] <= DI;
					7'h0D: IREG[6] <= DI;
					7'h1F: begin COMREG <= DI; COMREG_SET <= 1; end
					7'h63: if (DI[0]) SF <= 1;
					7'h75: PDR1O <= DI;
					7'h77: PDR2O <= DI;
					7'h79: DDR1 <= DI[6:0];
					7'h7B: DDR2 <= DI[6:0];
//					7'h7D: IOSEL <= DI[1:0];
//					7'h7F: EXLE <= DI[1:0];
					default:;
				endcase
			end 
			
			CS_N_OLD <= CS_N;
			if (!CS_N && CS_N_OLD && RW_N) begin
				if ({A,1'b1} <= 7'h5F)
					REG_DO <= OREG_RAM_Q;
				else
					case ({A,1'b1})
						7'h61: REG_DO <= SR;
						7'h63: REG_DO <= {7'b0000000,SF};
						7'h75: REG_DO <= {PDR1O[7],PDR1I};
						7'h77: REG_DO <= {PDR2O[7],PDR2I};
						default: REG_DO <= '0;
					endcase
			end
		end
	end
	
	bit [4:0] OREG_RAM_WA;
	bit [7:0] OREG_RAM_D;
	bit       OREG_RAM_WE;
	bit [7:0] OREG_RAM_Q;
	SMPC_OREG_RAM OREG_RAM (CLK, OREG_RAM_WA, OREG_RAM_D, OREG_RAM_WE, (A - 6'h10), OREG_RAM_Q);
	
	assign DO = REG_DO;

endmodule


module SMPC_OREG_RAM
(
	input        CLK,
	input  [4:0] WADDR,
	input  [7:0] DATA,
	input  [1:0] WREN,
	input  [4:0] RADDR,
	output [7:0] Q
);

	wire [7:0] sub_wire0;
	
	altdpram	altdpram_component (
				.data (DATA),
				.inclock (CLK),
				.rdaddress (RADDR),
				.wraddress (WADDR),
				.wren (WREN[0]),
				.q (sub_wire0),
				.aclr (1'b0),
				.byteena (1'b1),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
//				.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = 8,
		altdpram_component.widthad = 5,
		altdpram_component.width_byteena = 1,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";
		
	assign Q = sub_wire0;
	
endmodule
