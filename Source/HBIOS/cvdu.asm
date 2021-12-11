;======================================================================
;	COLOR VDU DRIVER FOR SBC PROJECT
;
;	WRITTEN BY: DAN WERNER -- 11/4/2011
;	ROMWBW ADAPTATION BY: WAYNE WARTHEN -- 11/9/2012
;======================================================================
;
; TODO:
;   - IMPLEMENT CONSTANTS FOR SCREEN DIMENSIONS
;   - IMPLEMENT SET CURSOR STYLE (VDASCS) FUNCTION
;   - IMPLEMENT ALTERNATE DISPLAY MODES?
;   - IMPLEMENT DYNAMIC READ/WRITE OF CHARACTER BITMAP DATA?
;   - IMPLEMENT TIMEOUT ON PROBE
;
;======================================================================
; CVDU DRIVER - CONSTANTS
;======================================================================
;
CVDU_BASE	.EQU	$E0
;
#IF (CVDUMODE == CVDUMODE_ECB)
CVDU_KBDDATA	.EQU	CVDU_BASE + $02	; KBD CTLR DATA PORT
CVDU_KBDST	.EQU	CVDU_BASE + $0A	; KBD CTLR STATUS/CMD PORT
CVDU_STAT	.EQU	CVDU_BASE + $04	; READ M8563 STATUS
CVDU_REG	.EQU	CVDU_BASE + $04	; SELECT M8563 REGISTER
CVDU_DATA	.EQU	CVDU_BASE + $0C	; READ/WRITE M8563 DATA
#ENDIF
;
#IF (CVDUMODE == CVDUMODE_MBC)
CVDU_KBDDATA	.EQU	CVDU_BASE + $02	; KBD CTLR DATA PORT
CVDU_KBDST	.EQU	CVDU_BASE + $03	; KBD CTLR STATUS/CMD PORT
CVDU_STAT	.EQU	CVDU_BASE + $04	; READ M8563 STATUS
CVDU_REG	.EQU	CVDU_BASE + $04	; SELECT M8563 REGISTER
CVDU_DATA	.EQU	CVDU_BASE + $05	; READ/WRITE M8563 DATA
#ENDIF
;
CVDU_ROWS	.EQU	25
CVDU_COLS	.EQU	80
;
#IF (CVDUMON == CVDUMON_CGA)
  #DEFINE	USEFONTCGA
  #DEFINE	CVDU_FONT FONTCGA
#ENDIF
;
#IF (CVDUMON == CVDUMON_EGA)
  #DEFINE	USEFONT8X16
  #DEFINE	CVDU_FONT FONT8X16
#ENDIF
;
TERMENABLE	.SET	TRUE		; INCLUDE TERMINAL PSEUDODEVICE DRIVER
;
;======================================================================
; CVDU DRIVER - INITIALIZATION
;======================================================================
;
CVDU_INIT:
	LD	IY,CVDU_IDAT		; POINTER TO INSTANCE DATA

	CALL	NEWLINE			; FORMATTING
	PRTS("CVDU: IO=0x$")
	LD	A,CVDU_STAT
	CALL	PRTHEXBYTE
	CALL	CVDU_PROBE		; CHECK FOR HW PRESENCE
	JR	Z,CVDU_INIT1		; CONTINUE IF HW PRESENT
;
	; HARDWARE NOT PRESENT
	PRTS(" NOT PRESENT$")
	OR	$FF			; SIGNAL FAILURE
	RET
;
CVDU_INIT1:
	PRTS(" VDURAM=$")
	CALL 	CVDU_CRTINIT		; SETUP THE CVDU CHIP REGISTERS
	CALL	PRTDEC
	PRTS("KB$")
	CALL	CVDU_LOADFONT		; LOAD FONT DATA FROM ROM TO CVDU STRORAGE
	CALL	CVDU_VDARES
	CALL	KBD_INIT		; INITIALIZE KEYBOARD DRIVER

	; ADD OURSELVES TO VDA DISPATCH TABLE
	LD	BC,CVDU_FNTBL		; BC := FUNCTION TABLE ADDRESS
	LD	DE,CVDU_IDAT		; DE := CVDU INSTANCE DATA PTR
	CALL	VDA_ADDENT		; ADD ENTRY, A := UNIT ASSIGNED

	; INITIALIZE EMULATION
	LD	C,A			; C := ASSIGNED VIDEO DEVICE NUM
	LD	DE,CVDU_FNTBL		; DE := FUNCTION TABLE ADDRESS
	LD	HL,CVDU_IDAT		; HL := CVDU INSTANCE DATA PTR
	CALL	TERM_ATTACH		; DO IT

	XOR	A			; SIGNAL SUCCESS
	RET
;
;======================================================================
; CVDU DRIVER - VIDEO DISPLAY ADAPTER (VDA) FUNCTIONS
;======================================================================
;
CVDU_FNTBL:
	.DW	CVDU_VDAINI
	.DW	CVDU_VDAQRY
	.DW	CVDU_VDARES
	.DW	CVDU_VDADEV
	.DW	CVDU_VDASCS
	.DW	CVDU_VDASCP
	.DW	CVDU_VDASAT
	.DW	CVDU_VDASCO
	.DW	CVDU_VDAWRC
	.DW	CVDU_VDAFIL
	.DW	CVDU_VDACPY
	.DW	CVDU_VDASCR
	.DW	KBD_STAT
	.DW	KBD_FLUSH
	.DW	KBD_READ
	.DW	CVDU_VDARDC
#IF (($ - CVDU_FNTBL) != (VDA_FNCNT * 2))
	.ECHO	"*** INVALID CVDU FUNCTION TABLE ***\n"
	!!!!!
#ENDIF

CVDU_VDAINI:
	; RESET VDA
	; CURRENTLY IGNORES VIDEO MODE AND BITMAP DATA
	CALL	CVDU_VDARES		; RESET VDA
	XOR	A			; SIGNAL SUCCESS
	RET

CVDU_VDAQRY:
	LD	C,$00		; MODE ZERO IS ALL WE KNOW
	LD	D,CVDU_ROWS	; ROWS
	LD	E,CVDU_COLS	; COLS
	LD	HL,0		; EXTRACTION OF CURRENT BITMAP DATA NOT SUPPORTED YET
	XOR	A		; SIGNAL SUCCESS
	RET

CVDU_VDARES:
	LD	A,$0E			; ATTRIBUTE IS STANDARD WHITE ON BLACK
	LD	(CVDU_ATTR),A		; SAVE IT

	LD	DE,0			; ROW = 0, COL = 0
	CALL	CVDU_XY			; SEND CURSOR TO TOP LEFT
	LD	A,' '			; BLANK THE SCREEN
	LD	DE,$800			; FILL ENTIRE BUFFER
	CALL	CVDU_FILL		; DO IT
	LD	DE,0			; ROW = 0, COL = 0
	CALL	CVDU_XY			; SEND CURSOR TO TOP LEFT

	XOR	A
	RET

CVDU_VDADEV:
	LD	D,VDADEV_CVDU	; D := DEVICE TYPE
	LD	E,0		; E := PHYSICAL UNIT IS ALWAYS ZERO
	LD	H,0		; H := 0, DRIVER HAS NO MODES
	LD	L,CVDU_BASE	; L := BASE I/O ADDRESS
	XOR	A		; SIGNAL SUCCESS
	RET

CVDU_VDASCS:
	CALL	SYSCHK		; NOT IMPLEMENTED (YET)
	LD	A,ERR_NOTIMPL
	OR	A
	RET

CVDU_VDASCP:
	CALL	CVDU_XY		; SET CURSOR POSITION
	XOR	A		; SIGNAL SUCCESS
	RET

CVDU_VDASAT:
	; INCOMING IS:  -----RUB (R=REVERSE, U=UNDERLINE, B=BLINK)
	; TRANSFORM TO: -RUB----
	LD	A,E		; GET THE INCOMING ATTRIBUTE
	RLCA			; TRANSLATE TO OUR DESIRED BIT
	RLCA			; "
	RLCA			; "
	RLCA			; "
	AND	%01110000	; REMOVE ANYTHING EXTRANEOUS
	LD	E,A		; SAVE IT IN E
	LD	A,(CVDU_ATTR)	; GET CURRENT ATTRIBUTE SETTING
	AND	%10001111	; CLEAR OUT OLD ATTRIBUTE BITS
	OR	E		; STUFF IN THE NEW ONES
	LD	(CVDU_ATTR),A	; AND SAVE THE RESULT
	XOR	A		; SIGNAL SUCCESS
	RET

CVDU_VDASCO:
	; INCOMING IS:  IBGRIBGR (I=INTENSITY, B=BLUE, G=GREEN, R=RED)
	; TRANSFORM TO: ----RGBI (DISCARD BACKGROUND COLOR IN HIGH NIBBLE)
	XOR	A		; CLEAR A
	LD	B,4		; LOOP 4 TIMES (4 BITS)
CVDU_VDASCO1:
	RRC	E		; ROTATE LOW ORDER BIT OUT OF E INTO CF
	RLA			; ROTATE CF INTO LOW ORDER BIT OF A
	DJNZ	CVDU_VDASCO1	; DO FOUR BITS OF THIS
	LD	E,A		; SAVE RESULT IN E
	LD	A,(CVDU_ATTR)	; GET CURRENT VALUE INTO A
	AND	%11110000	; CLEAR OUT OLD COLOR BITS
	OR	E		; STUFF IN THE NEW ONES
	LD	(CVDU_ATTR),A	; AND SAVE THE RESULT
	XOR	A		; SIGNAL SUCCESS
	RET

CVDU_VDAWRC:
	LD	A,E		; CHARACTER TO WRITE GOES IN A
	CALL	CVDU_PUTCHAR	; PUT IT ON THE SCREEN
	XOR	A		; SIGNAL SUCCESS
	RET

CVDU_VDAFIL:
	LD	A,E		; FILL CHARACTER GOES IN A
	EX	DE,HL		; FILL LENGTH GOES IN DE
	CALL	CVDU_FILL	; DO THE FILL
	XOR	A		; SIGNAL SUCCESS
	RET

CVDU_VDACPY:
	; LENGTH IN HL, SOURCE ROW/COL IN DE, DEST IS CVDU_POS
	; BLKCPY USES: HL=SOURCE, DE=DEST, BC=COUNT
	PUSH	HL		; SAVE LENGTH
	CALL	CVDU_XY2IDX	; ROW/COL IN DE -> SOURCE ADR IN HL
	POP	BC		; RECOVER LENGTH IN BC
	LD	DE,(CVDU_POS)	; PUT DEST IN DE
	JP	CVDU_BLKCPY	; DO A BLOCK COPY

CVDU_VDASCR:
	LD	A,E		; LOAD E INTO A
	OR	A		; SET FLAGS
	RET	Z		; IF ZERO, WE ARE DONE
	PUSH	DE		; SAVE E
	JP	M,CVDU_VDASCR1	; E IS NEGATIVE, REVERSE SCROLL
	CALL	CVDU_SCROLL	; SCROLL FORWARD ONE LINE
	POP	DE		; RECOVER E
	DEC	E		; DECREMENT IT
	JR	CVDU_VDASCR	; LOOP
CVDU_VDASCR1:
	CALL	CVDU_RSCROLL	; SCROLL REVERSE ONE LINE
	POP	DE		; RECOVER E
	INC	E		; INCREMENT IT
	JR	CVDU_VDASCR	; LOOP

;----------------------------------------------------------------------
; READ VALUE AT CURRENT VDU BUFFER POSITION
; RETURN E = CHARACTER, B = COLOUR, C = ATTRIBUTES
;----------------------------------------------------------------------

CVDU_VDARDC:
	OR	$FF		; UNSUPPORTED FUNCTION
	RET
;
;======================================================================
; CVDU DRIVER - PRIVATE DRIVER FUNCTIONS
;======================================================================
;
;----------------------------------------------------------------------
; UPDATE M8563 REGISTERS
;   CVDU_WR WRITES VALUE IN A TO VDU REGISTER SPECIFIED IN C
;   CVDU_WRX WRITES VALUE IN DE TO VDU REGISTER PAIR IN C, C+1
;----------------------------------------------------------------------
;
CVDU_WR:
	PUSH	AF			; SAVE VALUE TO WRITE
	LD	A,C			; SET A TO CVDU REGISTER TO SELECT
	OUT	(CVDU_REG),A		; WRITE IT TO SELECT THE REGISTER
CVDU_WR1:
	IN	A,(CVDU_STAT)		; GET CVDU STATUS
	BIT	7,A			; CHECK BIT 7
	JR	Z,CVDU_WR1		; LOOP WHILE NOT READY (BIT 7 NOT SET)
	POP	AF			; RESTORE VALUE TO WRITE
	OUT	(CVDU_DATA),A		; WRITE IT
	RET
;
CVDU_WRX:
	LD	A,H			; SETUP MSB TO WRITE
	CALL	CVDU_WR			; DO IT
	INC	C			; NEXT CVDU REGISTER
	LD	A,L			; SETUP LSB TO WRITE
	JR	CVDU_WR			; DO IT & RETURN
;
;----------------------------------------------------------------------
; READ M8563 REGISTERS
;   CVDU_RD READS VDU REGISTER SPECIFIED IN C AND RETURNS VALUE IN A
;   CVDU_RDX READS VDU REGISTER PAIR SPECIFIED BY C, C+1
;     AND RETURNS VALUE IN HL
;----------------------------------------------------------------------
;
CVDU_RD:
	LD	A,C			; SET A TO CVDU REGISTER TO SELECT
	OUT	(CVDU_REG),A		; WRITE IT TO SELECT THE REGISTER
CVDU_RD1:
	IN	A,(CVDU_STAT)		; GET CVDU STATUS
	BIT	7,A			; CHECK BIT 7
	JR	Z,CVDU_RD1		; LOOP WHILE NOT READY (BIT 7 NOT SET)
	IN	A,(CVDU_DATA)		; READ IT
	RET
;
CVDU_RDX:
	CALL	CVDU_RD			; GET VALUE FROM REGISTER IN C
	LD	H,A			; SAVE IN H
	INC	C			; BUMP TO NEXT REGISTER OF PAIR
	CALL	CVDU_RD			; READ THE VALUE
	LD	L,A			; SAVE IT IN L
	RET
;
;----------------------------------------------------------------------
; PROBE FOR CVDU HARDWARE
;----------------------------------------------------------------------
;
; ON RETURN, ZF SET INDICATES HARDWARE FOUND
;
CVDU_PROBE:
	; WRITE TEST PATTERN $A5 $5A TO START OF VRAM
	LD	HL,0			; POINT TO FIRST BYTE OF VRAM
	LD	C,18			; ADDRESS REGISTER PAIR
	CALL	CVDU_WRX		; UPDATE VRAM ADDRESS POINTER
	LD	A,$A5			; INITIAL TEST VALUE
	LD	B,A			; SAVE IN B
	LD	C,31			; DATA REGISTER
	CALL	CVDU_WR			; WRITE VALUE TO LOC 0, ADR PTR INCREMENTS
	CPL				; INVERT TEST VALUE
	CALL	CVDU_WR			; WRITE INVERTED VALUE TO LOC 1
	; READ TEST PATTERN BACK TO CONFIRM HARDWARE EXISTS
	LD	HL,0			; POINT TO FIRST BYTE OF VRAM
	LD	C,18			; ADDRESS REGISTER PAIR
	CALL	CVDU_WRX		; UPDATE VRAM ADDRESS POINTER
	LD	C,31			; DATA REGISTER
	CALL	CVDU_RD			; GET BYTE AT LOC 0, ADR PTR INCREMENTS
	CP	B			; CHECK IT
	RET	NZ			; ABORT IF BAD COMPARE
	CALL	CVDU_RD			; GET BYTE AT LOC 1
	CPL				; INVERT IT
	CP	B			; CHECK FOR INVERTED TEST VALUE
	RET				; RETURN WITH ZF SET BASED ON CP
;
;----------------------------------------------------------------------
; MOS 8563 DISPLAY CONTROLLER CHIP INITIALIZATION
;----------------------------------------------------------------------
;
CVDU_CRTINIT:
    	LD 	C,0			; START WITH REGISTER 0
	LD	B,37			; INIT 37 REGISTERS
    	LD 	HL,CVDU_INIT8563	; HL = POINTER TO THE DEFAULT VALUES
CVDU_CRTINIT1:
	LD	A,(HL)			; GET VALUE
	CALL	CVDU_WR			; WRITE IT
	INC	HL			; POINT TO NEXT VALUE
	INC	C			; POINT TO NEXT REGISTER
	DJNZ	CVDU_CRTINIT1		; LOOP
;
; NOW DETERMINE VDU RAM SIZE DYNAMICALLY
; ASSUMES THAT VDU RAM SIZE IS SET FOR 64KB ABOVE
;   A.  WRITE ZERO TO ADDRESS $0000
;   B.  WRITE NON-ZERO TO ADDRESS $0100
;   C.  CHECK THE VALUE IN ADDRESS $0000; IF IT CHANGED,
;       16K DRAM CHIPS INSTALLED; IF NOT, 64K DRAM CHIPS INSTALLED
; IF 16KB RAM DETECTED, ADJUST VDU REGISTERS APPROPRIATELY
;
	; WRITE $00 TO VDU RAM LOCATION $0000
	LD	HL,$0000		; POINT TO VDU RAM LOC $0000
	LD	C,18			; UPDATE ADDRESS REGISTER PAIR
	CALL	CVDU_WRX		; DO IT
	XOR	A			; ZERO IN ACCUM
	LD	C,31			; DATA REGISTER
	CALL	CVDU_WR			; WRITE ZERO TO $0000
	; WRITE $FF TO VDU RAM LOCATION $0100
	LD	HL,$0100		; POINT TO VDU RAM LOC $0100
	LD	C,18			; UPDATE ADDRESS REGISTER PAIR
	CALL	CVDU_WRX		; DO IT
	LD	A,$FF			; $FF IN ACCUM
	LD	C,31			; DATA REGISTER
	CALL	CVDU_WR			; WRITE ZERO TO $0100
	; READ VALUE FROM VDU RAM LOCATION $0000
	LD	HL,$0000		; POINT TO VDU RAM LOC $0000
	LD	C,18			; UPDATE ADDRESS REGISTER PAIR
	CALL	CVDU_WRX		; DO IT
	LD	C,31			; DATA REGISTER
	CALL	CVDU_RD			; READ VALUE AT $0000
	; CHECK VALUE, IF NOT $00, ADJUST RAM SIZE
	OR	A			; SET FLAGS
	JR	NZ,CVDU_CRTINIT2	; IF NOT ZERO, ADJUST RAM SIZE
	LD	HL,64			; RETURN RAMSIZE IN HL
	RET				; 64K CHIPS USED, ALL DONE
;
CVDU_CRTINIT2:	; ADJUST FOR 16K RAM SIZE
	LD	A,$20			; NEW VALUE
	LD	C,28			; FOR REG 28
	CALL	CVDU_WR			; DO IT
	LD	HL,16			; RETURN RAMSIZE IN HL
    	RET
;
;----------------------------------------------------------------------
; LOAD FONT DATA
;----------------------------------------------------------------------
;
CVDU_LOADFONT:
	LD	HL,$2000		; START OF FONT BUFFER
	LD	C,18			; UPDATE ADDRESS REGISTER PAIR
	CALL	CVDU_WRX		; DO IT

#IF USELZSA2
	LD	(CVDU_STACK),SP		; SAVE STACK
	LD	HL,(CVDU_STACK)		; AND SHIFT IT
	LD	DE,$2000		; DOWN 4KB TO
	OR	A			; CREATE A
	SBC	HL,DE			; DECOMPRESSION BUFFER
	LD	SP,HL			; HL POINTS TO BUFFER
	EX	DE,HL			; START OF STACK BUFFER
	PUSH	DE			; SAVE IT
	LD	HL,CVDU_FONT		; START OF FONT DATA
	CALL	DLZSA2			; DECOMPRESS TO DE
	POP	HL			; RECALL STACK BUFFER POSITION
#ELSE
	LD	HL,CVDU_FONT		; START OF FONT DATA
#ENDIF

	LD	DE,$2000		; LENGTH OF FONT DATA
	LD	C,31			; DATA REGISTER
CVDU_LOADFONT1:
	LD	A,(HL)			; LOAD NEXT BYTE OF FONT DATA
	CALL	CVDU_WR			; WRITE IT
	INC	HL			; INCREMENT FONT DATA POINTER
	DEC	DE			; DECREMENT LOOP COUNTER
	LD	A,D			; CHECK DE...
	OR	E			; FOR COUNTER EXHAUSTED
	JR	NZ,CVDU_LOADFONT1	; LOOP TILL DONE

#IF USELZSA2
	LD	HL,(CVDU_STACK)		; ERASE DECOMPRESS BUFFER
	LD	SP,HL			; BY RESTORING THE STACK
	RET				; DONE
CVDU_STACK	.DW	0
#ELSE
	RET
#ENDIF
;
;----------------------------------------------------------------------
; SET CURSOR POSITION TO ROW IN D AND COLUMN IN E
;----------------------------------------------------------------------
;
CVDU_XY:
	CALL	CVDU_XY2IDX		; CONVERT ROW/COL TO BUF IDX
	LD	(CVDU_POS),HL		; SAVE THE RESULT (DISPLAY POSITION)
    	LD 	C,14			; CURSOR POSITION REGISTER PAIR
	JP	CVDU_WRX		; DO IT AND RETURN
;
;----------------------------------------------------------------------
; CONVERT XY COORDINATES IN DE INTO LINEAR INDEX IN HL
; D=ROW, E=COL
;----------------------------------------------------------------------
;
CVDU_XY2IDX:
	LD	A,E			; SAVE COLUMN NUMBER IN A
	LD	H,D			; SET H TO ROW NUMBER
	LD	E,CVDU_COLS		; SET E TO ROW LENGTH
	CALL	MULT8			; MULTIPLY TO GET ROW OFFSET
	LD	E,A			; GET COLUMN BACK
	ADD	HL,DE			; ADD IT IN
	RET				; RETURN
;
;----------------------------------------------------------------------
; WRITE VALUE IN A TO CURRENT VDU BUFFER POSITION, ADVANCE CURSOR
;----------------------------------------------------------------------
;
CVDU_PUTCHAR:
	PUSH	AF			; SAVE CHARACTER

	; SET MEMORY LOCATION FOR CHARACTER
	LD	HL,(CVDU_POS)		; LOAD CURRENT POSITION INTO HL
	LD	C,18			; UPDATE ADDRESS REGISTER PAIR
	CALL	CVDU_WRX		; DO IT

	; PUT THE CHARACTER THERE
	POP	AF			; RECOVER CHARACTER VALUE TO WRITE
	LD	C,31			; DATA REGISTER
	CALL	CVDU_WR			; DO IT

	; BUMP THE CURSOR FORWARD
	INC	HL			; BUMP HL TO NEXT POSITION
	LD	(CVDU_POS),HL		; SAVE IT
	LD	C,14			; CURSOR POSITION REGISTER PAIR
	CALL	CVDU_WRX		; DO IT

	; SET MEMORY LOCATION FOR ATTRIBUTE
	LD	DE,$800 - 1		; SETUP DE TO ADD OFFSET INTO ATTRIB BUFFER
	ADD	HL,DE			; HL NOW POINTS TO ATTRIB POS FOR CHAR JUST WRITTEN
	LD	C,18			; UPDATE ADDRESS REGISTER PAIR
	CALL	CVDU_WRX		; DO IT

	; PUT THE ATTRIBUTE THERE
	LD	A,(CVDU_ATTR)		; LOAD THE ATTRIBUTE VALUE
	LD	C,31			; DATA REGISTER
	JP	CVDU_WR			; DO IT AND RETURN
;
;----------------------------------------------------------------------
; FILL AREA IN BUFFER WITH SPECIFIED CHARACTER AND CURRENT COLOR/ATTRIBUTE
; STARTING AT THE CURRENT FRAME BUFFER POSITION
;   A: FILL CHARACTER
;   DE: NUMBER OF CHARACTERS TO FILL
;----------------------------------------------------------------------
;
CVDU_FILL:
	PUSH	DE			; SAVE FILL COUNT
	LD	HL,(CVDU_POS)		; SET CHARACTER BUFFER POSITION TO FILL
	PUSH	HL			; SAVE BUF POS
	CALL	CVDU_FILL1		; DO THE CHARACTER FILL
	POP	HL			; RECOVER BUF POS
	LD	DE,$800			; INCREMENT FOR ATTRIBUTE FILL
	ADD	HL,DE			; HL := BUF POS FOR ATTRIBUTE FILL
	POP	DE			; RECOVER FILL COUNT
	LD	A,(CVDU_ATTR)		; SET ATTRIBUTE VALUE FOR ATTRIBUTE FILL
	JR	CVDU_FILL1		; DO ATTRIBUTE FILL AND RETURN

CVDU_FILL1:
	LD	B,A			; SAVE REQUESTED FILL VALUE

	; CHECK FOR VALID FILL LENGTH
	LD	A,D			; LOAD D
	OR	E			; OR WITH E
	RET	Z			; BAIL OUT IF LENGTH OF ZERO SPECIFIED

	; POINT TO BUFFER LOCATION TO START FILL
	LD	C,18			; UPDATE ADDRESS REGISTER PAIR
	CALL	CVDU_WRX		; DO IT

	; SET MODE TO BLOCK WRITE
	LD	C,24			; BLOCK MODE CONTROL REGISTER
	CALL	CVDU_RD			; GET CURRENT VALUE
	AND	$7F			; CLEAR BIT 7 FOR FILL MODE
	CALL	CVDU_WR			; DO IT

	; SET CHARACTER TO WRITE (WRITES ONE CHARACTER)
	LD	A,B			; RECOVER FILL VALUE
	LD	C,31			; DATA REGISTER
	CALL	CVDU_WR			; DO IT
	DEC	DE			; REFLECT ONE CHARACTER WRITTEN

	; LOOP TO DO BULK WRITE (UP TO 255 BYTES PER LOOP)
	EX	DE,HL			; NOW USE HL FOR COUNT
	LD	C,30			; BYTE COUNT REGISTER
CVDU_FILL2:
	LD	A,H			; GET HIGH BYTE
	OR	A			; SET FLAGS
	LD	A,L			; PRESUME WE WILL WRITE L COUNT (ALL REMAINING) BYTES
	JR	Z,CVDU_FILL3		; IF H WAS ZERO, WRITE L BYTES
	LD	A,$FF			; H WAS > 0, NEED MORE LOOPS, WRITE 255 BYTES
CVDU_FILL3:
	CALL	CVDU_WR			; DO IT (SOURCE/DEST REGS AUTO INCREMENT)
	LD	D,0			; CLEAR D
	LD	E,A			; SET E TO BYTES WRITTEN
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; SUBTRACT FROM HL
	RET	Z			; IF ZERO, WE ARE DONE
	JR	CVDU_FILL2		; OTHERWISE, WRITE SOME MORE
;
;----------------------------------------------------------------------
; SCROLL ENTIRE SCREEN FORWARD BY ONE LINE (CURSOR POSITION UNCHANGED)
;----------------------------------------------------------------------
;
CVDU_SCROLL:
	; SCROLL THE CHARACTER BUFFER
	LD	A,' '			; CHAR VALUE TO FILL NEW EXPOSED LINE
	LD	HL,0			; SOURCE ADDRESS OF CHARACER BUFFER
	CALL	CVDU_SCROLL1		; SCROLL CHARACTER BUFFER

	; SCROLL THE ATTRIBUTE BUFFER
	LD	A,(CVDU_ATTR)		; ATTRIBUTE VALUE TO FILL NEW EXPOSED LINE
	LD	HL,$800			; SOURCE ADDRESS OF ATTRIBUTE BUFFER
	JR	CVDU_SCROLL1		; SCROLL ATTRIBUTE BUFFER

CVDU_SCROLL1:
	PUSH	AF			; SAVE FILL VALUE FOR NOW

	; SET MODE TO BLOCK COPY
	LD	C,24			; BLOCK MODE CONTROL REGISTER
	CALL	CVDU_RD			; GET CURRENT VALUE
	OR	$80			; SET BIT 7 FOR COPY MODE
	CALL	CVDU_WR			; DO IT

	; SET INITIAL BLOCK COPY DESTINATION (USING HL PASSED IN)
    	LD 	C,18			; UPDATE ADDRESS (DESTINATION) REGISTER
	CALL	CVDU_WRX		; DO IT

	; COMPUTE SOURCE (INCREMENT ONE ROW)
	LD	DE,CVDU_COLS			; SOURCE ADDRESS IS ONE ROW PAST DESTINATION
	ADD	HL,DE			; ADD IT TO BUF ADDRESS

	; SET INITIAL BLOCK COPY SOURCE
    	LD 	C,32			; BLOCK START ADDRESS REGISTER
	CALL	CVDU_WRX		; DO IT

	LD	B,CVDU_ROWS - 1	; ITERATIONS (ROWS - 1)
CVDU_SCROLL2:
	; SET BLOCK COPY COUNT (WILL EXECUTE COPY)
	LD	A,CVDU_COLS			; COPY 80 BYTES
	LD	C,30			; WORD COUNT REGISTER
	CALL	CVDU_WR			; DO IT

	; LOOP TILL DONE WITH ALL LINES
	DJNZ	CVDU_SCROLL2		; REPEAT FOR ALL LINES

	; SET MODE TO BLOCK WRITE TO CLEAR NEW LINE EXPOSED BY SCROLL
	LD	C,24			; BLOCK MODE CONTROL REGISTER
	CALL	CVDU_RD			; GET CURRENT VALUE
	AND	$7F			; CLEAR BIT 7 FOR FILL MODE
	CALL	CVDU_WR			; DO IT

	; SET VALUE TO WRITE
	POP	AF			; RESTORE THE FILL VALUE PASSED IN
	LD	C,31			; DATA REGISTER
	CALL	CVDU_WR			; DO IT

	; SET BLOCK WRITE COUNT (WILL EXECUTE THE WRITE)
	LD	A,CVDU_COLS - 1	; SET WRITE COUNT TO LINE LENGTH - 1 (1 CHAR ALREADY WRITTEN)
	LD	C,30			; WORD COUNT REGISTER
	CALL	CVDU_WR			; DO IT

	RET
;
;----------------------------------------------------------------------
; REVERSE SCROLL ENTIRE SCREEN BY ONE LINE (CURSOR POSITION UNCHANGED)
;----------------------------------------------------------------------
;
CVDU_RSCROLL:
	; SCROLL THE CHARACTER BUFFER
	LD	A,' '			; CHAR VALUE TO FILL NEW EXPOSED LINE
	LD	HL,$0 + ((CVDU_ROWS - 1) * CVDU_COLS) 	; SOURCE ADDRESS OF CHARACER BUFFER
	CALL	CVDU_RSCROLL1		; SCROLL CHARACTER BUFFER

	; SCROLL THE ATTRIBUTE BUFFER
	LD	A,(CVDU_ATTR)		; ATTRIBUTE VALUE TO FILL NEW EXPOSED LINE
	LD	HL,$800 + ((CVDU_ROWS - 1) * CVDU_COLS)	; SOURCE ADDRESS OF ATTRIBUTE BUFFER
	JR	CVDU_RSCROLL1		; SCROLL ATTRIBUTE BUFFER AND RETURN

CVDU_RSCROLL1:
	PUSH	AF			; SAVE FILL VALUE FOR NOW

	; SET MODE TO BLOCK COPY
	LD	C,24			; BLOCK MODE CONTROL REGISTER
	CALL	CVDU_RD			; GET CURRENT VALUE
	OR	$80			; SET BIT 7 FOR COPY MODE
	CALL	CVDU_WR			; DO IT

	; LOOP TO SCROLL EACH LINE WORKING FROM BOTTOM TO TOP
	LD	B,CVDU_ROWS - 1	; ITERATIONS (ROWS - 1)
CVDU_RSCROLL2:

	; SET BLOCK COPY DESTINATION (USING HL PASSED IN)
    	LD 	C,18			; UPDATE ADDRESS (DESTINATION) REGISTER
	CALL	CVDU_WRX		; DO IT

	; COMPUTE SOURCE (DECREMENT ONE ROW)
	LD	DE,CVDU_COLS		; SOURCE ADDRESS IS ONE ROW PAST DESTINATION
	OR	A			; CLEAR CARRY
	SBC	HL,DE			; SUBTRACT IT FROM BUF ADDRESS

	; SET BLOCK COPY SOURCE
    	LD 	C,32			; BLOCK START ADDRESS REGISTER
	CALL	CVDU_WRX		; DO IT

	; SET BLOCK COPY COUNT (WILL EXECUTE COPY)
	LD	A,CVDU_COLS		; COPY 80 BYTES
	LD	C,30			; WORD COUNT REGISTER
	CALL	CVDU_WR			; DO IT

	DJNZ	CVDU_RSCROLL2		; REPEAT FOR ALL LINES

	; SET FILL DESTINATION (USING HL PASSED IN)
    	LD 	C,18			; UPDATE ADDRESS (DESTINATION) REGISTER
	CALL	CVDU_WRX		; DO IT

	; SET MODE TO BLOCK WRITE TO CLEAR NEW LINE EXPOSED BY SCROLL
	LD	C,24			; BLOCK MODE CONTROL REGISTER
	CALL	CVDU_RD			; GET CURRENT VALUE
	AND	$7F			; CLEAR BIT 7 FOR FILL MODE
	CALL	CVDU_WR			; DO IT

	; SET VALUE TO WRITE
	POP	AF			; RESTORE THE FILL VALUE PASSED IN
	LD	C,31			; DATA REGISTER
	CALL	CVDU_WR			; DO IT

	; SET BLOCK WRITE COUNT (WILL EXECUTE THE WRITE)
	LD	A,CVDU_COLS - 1	; SET WRITE COUNT TO LINE LENGTH - 1 (1 CHAR ALREADY WRITTEN)
	LD	C,30			; WORD COUNT REGISTER
	CALL	CVDU_WR			; DO IT

	RET
;
;----------------------------------------------------------------------
; BLOCK COPY BC BYTES FROM HL TO DE
;----------------------------------------------------------------------
;
CVDU_BLKCPY:
	; SETUP PARMS FOR FIRST PASS (CHARS)
	PUSH	BC		; LENGTH
	PUSH	HL		; SOURCE
	PUSH	DE		; DEST
	; PUT A RETURN ADDRESS ON THE STACK FOR SECOND PASS
	PUSH	HL		; PUT CURRENT HL ON STACK
	LD	HL,CVDU_BLKCPY1	; NOW SET HL TO RETURN ADDRESS
	EX	(SP),HL		; GET ORIG HL BACK, AND PUT RET ADR ON STACK
	; SETUP PARMS FOR SECOND PASS (ATTRIBUTES)
	PUSH	BC		; LENGTH
	LD	BC,$800		; USE BC TO ADD OFFSET TO ATTR BUF
	ADD	HL,BC		; ADD THE OFFSET TO HL
	PUSH	HL		; SAVE PARM (SOURCE ADR)
	EX	DE,HL		; GET DE INTO HL
	ADD	HL,BC		; ADD THE OFFSET
	PUSH	HL		; SAVE PARM (DESTINATION ADR)
;
CVDU_BLKCPY1:
	; SET MODE TO BLOCK COPY
	LD	C,24		; BLOCK MODE CONTROL REGISTER
	CALL	CVDU_RD		; GET CURRENT VALUE
	OR	$80		; SET BIT 7 FOR COPY MODE
	CALL	CVDU_WR		; DO IT
;
	; SET DESTINATION
	POP	HL		; RECOVER DESTINATION ADDRESS
	LD	C,18		; REGISTER = UPDATE ADDRESS
	CALL	CVDU_WRX	; DO IT
;
	; SET SOURCE
	POP	HL		; RECOVER SOURCE ADDRESS
	LD	C,32		; REGISTER = BLOCK START
	CALL	CVDU_WRX	; DO IT
;
	; SET LENGTH
	POP	HL		; RECOVER LENGTH
	LD	A,L		; BYTES TO COPY GOES IN A
	LD	C,30		; REGSITER = WORD COUNT
	JP	CVDU_WR		; DO IT (COPY OCCURS HERE) AND RETURN
;
;==================================================================================================
;   CVDU DRIVER - DATA
;==================================================================================================
;
CVDU_ATTR		.DB	0	; CURRENT COLOR
CVDU_POS		.DW 	0	; CURRENT DISPLAY POSITION
;
; ATTRIBUTE ENCODING:
;   BIT 7: ALTERNATE CHARACTER SET
;   BIT 6: REVERSE VIDEO
;   BIT 5: UNDERLINE
;   BIT 4: BLINK
;   BIT 3: RED
;   BIT 2: GREEN
;   BIT 1: BLUE
;   BIT 0: INTENSITY
;
;==================================================================================================
;   CVDU DRIVER - 8563 REGISTER INITIALIZATION
;==================================================================================================
;
; Reg	Hex	Bit 7	Bit 6	Bit 5	Bit 4	Bit 3	Bit 2	Bit 1	Bit 0	Description
; 0	$00	HT7	HT6	HT5	HT4	HT3	HT2	HT1	HT0	Horizontal Total
; 1	$01	HD7	HD6	HD5	HD4	HD3	HD2	HD1	HD0	Horizontal Displayed
; 2	$02	HP7	HP6	HP5	HP4	HP3	HP2	HP1	HP0	Horizontal Sync Position
; 3	$03	VW3	VW2	VW1	VW0	HW3	HW2	HW1	HW0	Vertical/Horizontal Sync Width
; 4	$04	VT7	VT6	VT5	VT4	VT3	VT2	VT1	VT0	Vertical Total
; 5	$05	--	--	--	VA4	VA3	VA2	VA1	VA0	Vertical Adjust
; 6	$06	VD7	VD6	VD5	VD4	VD3	VD2	VD1	VD0	Vertical Displayed
; 7	$07	VP7	VP6	VP5	VP4	VP3	VP2	VP1	VP0	Vertical Sync Position
; 8	$08	--	--	--	--	--	--	IM1	IM0	Interlace Mode
; 9	$09	--	--	--	--	CTV4	CTV3	CTV2	CTV1	Character Total Vertical
; 10	$0A	--	CM1	CM0	CS4	CS3	CS2	CS1	CS0	Cursor Mode, Start Scan
; 11	$0B	--	--	--	CE4	CE3	CE2	CE1	CE0	Cursor End Scan Line
; 12	$0C	DS15	DS14	DS13	DS12	DS11	DS10	DS9	DS8	Display Start Address High Byte
; 13	$0D	DS7	DS6	DS5	DS4	DS3	DS2	DS1	DS0	Display Start Address Low Byte
; 14	$0E	CP15	CP14	CP13	CP12	CP11	CP10	CP9	CP8	Cursor Position High Byte
; 15	$0F	CP7	CP6	CP5	CP4	CP3	CP2	CP1	CP0	Cursor Position Low Byte
; 16	$10	LPV7	LPV6	LPV5	LPV4	LPV3	LPV2	LPV1	LPV0	Light Pen Vertical Position
; 17	$11	LPH7	LPH6	LPH5	LPH4	LPH3	LPH2	LPH1	LPH0	Light Pen Horizontal Position
; 18	$12	UA15	UA14	UA13	UA12	UA11	UA10	UA9	UA8	Update Address High Byte
; 19	$13	UA7	UA6	UA5	UA4	UA3	UA2	UA1	UA0	Update Address Low Byte
; 20	$14	AA15	AA14	AA13	AA12	AA11	AA10	AA9	AA8	Attribute Start Address High Byte
; 21	$15	AA7	AA6	AA5	AA4	AA3	AA2	AA1	AA0	Attribute Start Address Low Byte
; 22	$16	CTH3	CTH2	CTH1	CTH0	CDH3	CDH2	CDH1	CDH0	Character Total Horizontal, Character Display Horizontal
; 23	$17	--	--	--	CDV4	CDV3	CDV2	CDV1	CDV0	Character Display Vertical
; 24	$18	COPY	RVS	CBRATE	VSS4	VSS3	VSS2	VSS1	VSS0	Vertical Smooth Scrolling
; 25	$19	TEXT	ATR	SEMI	DBL	HSS3	HSS2	HSS1	HSS0	Horizontal Smooth Scrolling
; 26	$1A	FG3	FG2	FG1	FG0	BG3	BG2	BG1	BG0	Foreground/Background color
; 27	$1B	AI7	AI6	AI5	AI4	AI3	AI2	AI1	AI0	Address Increment per Row
; 28	$1C	CB15	CB14	CB13	RAM	--	--	--	--	Character Base Address
; 29	$1D	--	--	--	UL4	UL3	UL2	UL1	UL0	Underline Scan Line
; 30	$1E	WC7	WC6	WC5	WC4	WC3	WC2	WC1	WC0	Word Count
; 31	$1F	DA7	DA6	DA5	DA4	DA3	DA2	DA1	DA0	Data Register
; 32	$20	BA15	BA14	BA13	BA12	BA11	BA10	BA9	BA8	Block Start Address High Byte
; 33	$21	BA7	BA6	BA5	BA4	BA3	BA2	BA1	BA0	Block Start Address Low Byte
; 34	$22	DEB7	DEB6	DEB5	DEB4	DEB3	DEB2	DEB1	DEB0	Display Enable Begin
; 35	$23	DEE7	DEE6	DEE5	DEE4	DEE3	DEE2	DEE1	DEE0	Display Enable End
; 36	$24	--	--	--	--	DRR3	DRR2	DRR1	DRR0	DRAM Refresh Rate
;
;
CVDU_INIT8563:
;
#IF (CVDUMON == CVDUMON_CGA)
;
; CGA 640x200  8-BIT CHARACTERS
;   - requires 16.000Mhz oscillator frequency
;
	.DB	$7E		; 0: hor. total - 1
	.DB	$50		; 1: hor. displayed
	.DB	$66		; 2: hor. sync position 85
	.DB	$49		; 3: vert/hor sync width 		or 0x4F -- MDA
	.DB	$20		; 4: vert total
	.DB	$E0		; 5: vert total adjust
	.DB	$19		; 6: vert. displayed
	.DB	$1D		; 7: vert. sync postition
	.DB	$FC		; 8: interlace mode
	.DB	$E7		; 9: char height - 1
	.DB	$A0		; 10: cursor mode, start line
	.DB	$E7		; 11: cursor end line
	.DB	$00		; 12: display start addr hi
	.DB	$00		; 13: display start addr lo
	.DB	$07		; 14: cursor position hi
	.DB	$80		; 15: cursor position lo
	.DB	$12		; 16: light pen vertical
	.DB	$17		; 17: light pen horizontal
	.DB	$0F		; 18: update address hi
	.DB	$D0		; 19: update address lo
	.DB	$08		; 20: attribute start addr hi
	.DB	$20		; 21: attribute start addr lo
	.DB	$78		; 22: char hor size cntrl 		0x78
	.DB	$E8		; 23: vert char pixel space - 1, increase to 13 with new font
	.DB	$20		; 24: copy/fill, reverse, blink rate; vertical scroll
	.DB	$47		; 25: gr/txt, color/mono, pxl-rpt, dbl-wide; horiz. scroll
	.DB	$F0		; 26: fg/bg colors (monochr)
	.DB	$00		; 27: row addr display incr
	.DB	$2F		; 28: char set addr; RAM size (64/16)
	.DB	$E7		; 29: underline position
	.DB	$4F		; 30: word count - 1
	.DB	$07		; 31: data
	.DB	$0F		; 32: block copy src hi
	.DB	$D0		; 33: block copy src lo
	.DB	$7D		; 34: display enable begin
	.DB	$64		; 35: display enable end
	.DB	$F5		; 36: refresh rate
#ENDIF
;
#IF (CVDUMON == CVDUMON_EGA)
;
; EGA 720X350  9-BIT CHARACTERS
;   - requires 16.257Mhz oscillator frequency
;
	.DB	$61		; 0: hor. total - 1
	.DB	$50		; 1: hor. displayed
	.DB	$5A		; 2: hor. sync position 85
	.DB	$14		; 3: vert/hor sync width 		or 0x4F -- MDA
	.DB	$1A		; 4: vert total
	.DB	$02		; 5: vert total adjust
	.DB	$19		; 6: vert. displayed
	.DB	$1A		; 7: vert. sync postition
	.DB	$00		; 8: interlace mode
	.DB	$0D		; 9: char height - 1
	.DB	$4C		; 10: cursor mode, start line
	.DB	$0D		; 11: cursor end line
	.DB	$00		; 12: display start addr hi
	.DB	$00		; 13: display start addr lo
	.DB	$00		; 14: cursor position hi
	.DB	$00		; 15: cursor position lo
	.DB	$00		; 16: light pen vertical
	.DB	$00		; 17: light pen horizontal
	.DB	$00		; 18: update address hi
	.DB	$00		; 19: update address lo
	.DB	$08		; 20: attribute start addr hi
	.DB	$00		; 21: attribute start addr lo
	.DB	$89		; 22: char hor size cntrl 		0x78
	.DB	$0D		; 23: vert char pixel space - 1, increase to 13 with new font
	.DB	$00		; 24: copy/fill, reverse, blink rate; vertical scroll
	.DB	$48		; 25: gr/txt, color/mono, pxl-rpt, dbl-wide; horiz. scroll
	.DB	$E0		; 26: fg/bg colors (monochr)
	.DB	$00		; 27: row addr display incr
	.DB	$30		; 28: char set addr; RAM size (64/16)
	.DB	$0D		; 29: underline position
	.DB	$00		; 30: word count - 1
	.DB	$00		; 31: data
	.DB	$00		; 32: block copy src hi
	.DB	$00		; 33: block copy src lo
	.DB	$06		; 34: display enable begin
	.DB	$56		; 35: display enable end
	.DB	$00		; 36: refresh rate
#ENDIF
;
;==================================================================================================
;   CVDU DRIVER - INSTANCE DATA
;==================================================================================================
;
CVDU_IDAT:
	.DB	CVDU_KBDST
	.DB	CVDU_KBDDATA
