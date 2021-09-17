;===============================================================================
; Commodore 64: "Your Game Project"
;
; File: Project 8 & 9: "Jumping State"
;===============================================================================

; Bugs found: When scrolling the screen, sometimes the wall detection is not found
; and sprite passes through it.

; Sprite animation looping is off. The animation is running fast
; Sprite Idle animation is not showing.

;===============================================================================

;===============================================================================
; SCROLLING MAP EXAMPLE 1 - C64 YouTube Game Project
; 2016/17 - Peter 'Sig' Hewett aka RetroRomIcon (contributions)
; Additional coding by Steve Morrow
;===============================================================================
Operator Calc        ; IMPORTANT - calculations are made BEFORE hi/lo bytes
                     ;             in precidence (for expressions and tables)
;===============================================================================
;          !                                                         DEFINITIONS
;===============================================================================
IncAsm "VIC_Registers.asm"             ; VICII register includes
IncAsm "Game_Macros.asm"                    ; macro includes
;===============================================================================
;===============================================================================
;                                                                     CONSTANTS
;===============================================================================

CONSOLE_TEXT = SPRITE_CONSOLE_TEXT
CONSOLE_DISPLAY = DisplaySpriteInfo

#region "Constants"
SCREEN_MEM   = $4000
SCREEN1_MEM  = $4000                 ; Bank 1 - Screen 0 ; $4000
SCREEN2_MEM  = $4400                 ; Bank 1 - Screen 1 ; $4400
SCORE_SCREEN = $5800                 ; Bank 1 - Screen 6 ; $5800

COLOR_MEM  = $D800                   ; Color mem never changes
CHAR_MEM   = $4800                   ; Base of character set memory (set 1)
SPRITE_MEM = $5C00                   ; Base of sprite memory

COLOR_DIFF = COLOR_MEM - SCREEN_MEM  ; difference between color and screen ram
                                     ; a workaround for CBM PRG STUDIOs poor
                                     ; expression handling

SPRITE_POINTER_BASE = SCREEN_MEM + $3f8 ; last 8 bytes of screen mem

SPRITE_BASE = $70                       ; the pointer to the first image#

SPRITE_0_PTR = SPRITE_POINTER_BASE + 0  ; Sprite pointers
SPRITE_1_PTR = SPRITE_POINTER_BASE + 1
SPRITE_2_PTR = SPRITE_POINTER_BASE + 2
SPRITE_3_PTR = SPRITE_POINTER_BASE + 3
SPRITE_4_PTR = SPRITE_POINTER_BASE + 4
SPRITE_5_PTR = SPRITE_POINTER_BASE + 5
SPRITE_6_PTR = SPRITE_POINTER_BASE + 6
SPRITE_7_PTR = SPRITE_POINTER_BASE + 7

SPRITE_DELTA_OFFSET_X = 8               ; Offset from SPRITE coords to Delta Char coords
SPRITE_DELTA_OFFSET_Y = 14

NUMBER_OF_SPRITES_DIV_4 = 3           ; This is for my personal version, which
                                      ; loads sprites and characters under IO ROM

LEVEL_1_MAP   = $E000                    ;Address of level 1 tiles/charsets
LEVEL_1_CHARS = $E800
#endregion

;===============================================================================
; ZERO PAGE LABELS
;===============================================================================
#region "ZeroPage"
PARAM1 = $03                 ; These will be used to pass parameters to routines
PARAM2 = $04                 ; when you can't use registers or other reasons
PARAM3 = $05                            
PARAM4 = $06                 ; essentially, think of these as extra data registers
PARAM5 = $07

TIMER = $08                  ; Timers - fast and slow, updated every frame
SLOW_TIMER = $09

WPARAM1 = $0A                ; Word length Params. Same as above only room for 2
WPARAM2 = $0C                ; bytes (or an address)
WPARAM3 = $0E

;---------------------------- $11 - $16 available

ZEROPAGE_POINTER_1 = $17     ; Similar only for pointers that hold a word long address
ZEROPAGE_POINTER_2 = $19
ZEROPAGE_POINTER_3 = $21
ZEROPAGE_POINTER_4 = $23

CURRENT_SCREEN   = $25       ; Pointer to current front screen
CURRENT_BUFFER   = $27       ; Pointer to current back buffer

SCROLL_COUNT_X   = $29       ; Current hardware scroll value
SCROLL_COUNT_Y   = $2A
SCROLL_SPEED     = $2B       ; Scroll speed (not implemented yet)
SCROLL_DIRECTION = $2C       ; Direction we are scrolling in
SCROLL_MOVING    = $2D       ; are we moving? (Set to direction of scrolling)
                             ; This is for resetting back to start frames

                            ; All data is for the top left corner of the visible map area
MAP_POS_ADDRESS = $2E       ; (2 bytes) pointer to current address in the level map
MAP_X_POS       = $30       ; Current map x position (in tiles)
MAP_Y_POS       = $31       ; Current map y position (in tiles)
MAP_X_DELTA     = $32       ; Map sub tile delta (in characters)
MAP_Y_DELTA     = $33       ; Map sub tile delta (in characters)

#endregion

;===============================================================================
; BASIC KICKSTART
;===============================================================================
KICKSTART
; Sys call to start the program - 10 SYS (2064)

*=$0801

        BYTE $0E,$08,$0A,$00,$9E,$20,$28,$32,$30,$36,$34,$29,$00,$00,$00

;===============================================================================
; START OF GAME PROJECT
;===============================================================================
*=$0810

PRG_START
        lda #0                          ; Turn off sprites 
        sta VIC_SPRITE_ENABLE

        lda VIC_SCREEN_CONTROL          ; turn screen off with bit 4 (53265)
        and #%11100000                  ; mask out bit 4 - Screen on/off
        sta VIC_SCREEN_CONTROL          ; save back - setting bit 4 to off

;===============================================================================
; SETUP VIC BANK MEMORY
;===============================================================================
#region "VIC Setup"
        ; To set the VIC bank we have to change the first 2 bits in the
        ; CIA 2 register. So we want to be careful and only change the
        ; bits we need to.

        lda VIC_BANK            ; Fetch the status of CIA 2 ($DD00)
        and #%11111100          ; mask for bits 2-8
        ora #%00000010          ; the first 2 bits are your desired VIC bank value
                                ; In this case bank 1 ($4000 - $7FFF)
        sta VIC_BANK
;===============================================================================
; CHARACTER SET ENABLE: SCREEN MEMORY
;===============================================================================
        ; Within the VIC Bank we can set where we want our screen and character
        ; set memory to be using the VIC_MEMORY_CONTROL at $D018
        ; It is important to note that the values given are RELATIVE to the start
        ; address of the VIC bank you are using.
       
        lda #%00000010   ; bits 1-3 (001) = character memory 2 : $0800 - $0FFF
                         ; bits 4-7 (000) = screen memory 0 : $0000 - $03FF

        sta VIC_MEMORY_CONTROL  ; "10" = $0800 (2048) = 2k

        ; Because these are RELATIVE to the VIC banks base address (Bank 1 = $4000)
        ; this gives us a base screen memory address of $4000 and a base
        ; character set memory of $4800
        ; 
        ; Sprite pointers are the last 8 bytes of screen memory (25 * 40 = 1000 and
        ; yet each screen reserves 1024 bytes). So Sprite pointers start at
        ; $4000 + $3f8.

        ; After alloction of VIC Memory for Screen, backbuffer, scoreboard, and
        ; 2 character sets , arranged to one solid block of mem,
        ; Sprite data starts at $5C00 - giving the initial image a pointer value of $70
        ; and allowing for up to 144 sprite images

#endregion        
;===============================================================================
; SYSTEM INITIALIZATION
;===============================================================================
#region "System Setup"
System_Setup

        ; Here is where we copy level 1 data from the start setup to under
        ; $E000 so we can use it later when the game resets.
        ; A little bank switching is involved here.
        sei           

        ; Here you load and store the Processor Port ($0001), then use 
        ; it to turn off LORAM (BASIC), HIRAM (KERNAL), CHAREN (CHARACTER ROM)
        ; then use a routine to copy your sprite and character mem under there
        ; before restoring the original value of $0001 and turning interrupts
        ; back on.

        lda PROC_PORT                   ; store ram setup
        sta PARAM1

        lda #%00110000                  ; Switch out BASIC, KERNAL, CHAREN, IO
        sta PROC_PORT

        ; When the game starts, Level 1 tiles and characters are stored in place to run,
        ; However, when the game resets we will need to restore these levels intact.
        ; So we're saving them away to load later under the KERNAL at $E000-$EFFF (4k)
        ; To do this we need to do some bank switching, copy data, then restore as
        ; we may use the KERNAL later for some things.

        loadPointer ZEROPAGE_POINTER_1, MAP_MEM         ; source
        loadPointer ZEROPAGE_POINTER_2, LEVEL_1_MAP     ; destination

        jsr CopyChars                   ; CopyChars for charsets copys 2048 bytes of character
                                        ; data, the same size as our tile maps, so we use that
                                        ; routine

        loadPointer ZEROPAGE_POINTER_1, CHAR_MEM
        loadPointer ZEROPAGE_POINTER_2, LEVEL_1_CHARS

        jsr  CopyChars

        lda PARAM1                      ; restore ram setup
        sta PROC_PORT
        cli
#endregion
;===============================================================================
; SCREEN SETUP
;===============================================================================
#region "Screen Setup"
Screen_Setup
        lda #COLOR_BLACK
        sta VIC_BACKGROUND_COLOR 
        lda #COLOR_ORANGE
        sta VIC_CHARSET_MULTICOLOR_1
        lda #COLOR_BROWN
        sta VIC_CHARSET_MULTICOLOR_2

        loadPointer CURRENT_SCREEN,SCREEN1_MEM
        loadPointer CURRENT_BUFFER,SCREEN2_MEM
i
        ldx #71                        ; Y start pos (in tile coords) (92,26=default)
        ldy #0                          ; X start pos (in tile coords)

        jsr DrawMap                     ; Draw the level map (Screen1)
                                        ; And initialize it
        jsr CopyToBuffer                ; Copy to the backbuffer(Screen2) 

        loadpointer ZEROPAGE_POINTER_1, CONSOLE_TEXT

        lda #0                          ; PARAM1 contains X screen coord (column)
        sta PARAM1
        lda #19                         ; PARAM2 contains Y screen coord (row)
        sta PARAM2
        lda #COLOR_WHITE                ; PARAM3 contains the color to use
        sta PARAM3
        jsr DisplayText                 ; Then we display the text

;        jsr DisplaySpriteInfoNow        ; Now update it with the debug info
     
        jsr WaitFrame
        jsr InitRasterIRQ               ; Setup raster interrupts
        jsr WaitFrame
        
        lda #%00011011                  ; Default (Y scroll = 3 by default)    
        sta VIC_SCREEN_CONTROL          ; $D011 (53265)
        lda #COLOR_BLACK
        sta VIC_BORDER_COLOR

#endregion

;===================================================================================================
;  SPRITE SETUP
;===================================================================================================
#region "Sprite Setup"

Sprite_Setup
        lda #0
        sta VIC_SPRITE_ENABLE           ; Turn all sprites off
        sta VIC_SPRITE_X_EXTEND         ; clear all extended X bits
        sta SPRITE_POS_X_EXTEND         ; in registers and data
        jsr PlayerInit
        lda #%11111111                  ; Turn on sprites 0 1 and 7
        sta VIC_SPRITE_ENABLE 

#endregion 

;===================================================================================================
;  MAIN LOOP
;===================================================================================================
MainLoop
        jsr WaitFrame                   ; wait for the vertical blank period
        jsr UpdateTimers
        jsr UpdatePlayer                 ; Player animation, etc.
        jsr UpdateScroll
        jsr DisplaySpriteInfoNow              ; Display simple debug info
        jmp MainLoop

;===============================================================================
; FILES IN GAME PROJECT
;===============================================================================
        incAsm "Collision_Detection.asm"
        incAsm "Game_Interrupts.asm"
        incAsm "Game_Routines.asm"                  ; core framework routines
        incAsm "Player_Routines.asm"
        incAsm "Screen_Memory.asm"                ; screen drawing and handling
        incAsm "Start_Level.asm
        incAsm "Scrolling.asm"
        incAsm "Sprite_Routines.asm"

;===================================================================================================
;  JOYSTICK
;===================================================================================================
DisplaySpriteInfo
                                        ; Only update if Joystick is used
        lda JOY_X
        bne DisplaySpriteInfoNow
        lda JOY_Y
        bne DisplaySpriteInfoNow
        rts
                                                ; Display Sprite debug info
DisplaySpriteInfoNow
       
        loadPointer WPARAM1,SCORE_SCREEN
        
        lda COLLIDER_ATTR                      ; Display sprite X and Y coords
        ldx #19
        ldy #7
        jsr DisplayByte

        lda SPRITE_CHAR_POS_Y
        ldx #19
        ldy #19
        jsr DisplayByte

        lda MAP_X_DELTA
        ldx #21
        ldy #28
        jsr DisplayByte

        lda MAP_Y_DELTA
        ldx #21
        ldy #37
        jsr DisplayByte

        lda MAP_X_POS
        ldx #19
        ldy #28
        jsr DisplayByte

        lda MAP_Y_POS
        ldx #19
        ldy #37
        jsr DisplayByte

        lda JOY_X                           
        ldx #20
        ldy #7
        jsr DisplayByte

        lda SCROLL_COUNT_X
        ldx #22
        ldy #28
        jsr DisplayByte

        lda SCROLL_COUNT_Y
        ldx #22
        ldy #37
        jsr DisplayByte
        rts

SPRITE_CONSOLE_TEXT
        byte ' coll:$     spsy:$    mapx:$   mapy:$    /'
        byte ' joyx:$     dlty:$ /'
        byte '                      mapx:$   mapy:$    /'
        byte ' score:               sclx:$   scly:$    /'
        byte ' attr:',0

JOY_X                           ; current positon of Joystick(2)
        byte $00                ; -1 0 or +1
JOY_Y
        byte $00                ; -1 0 or +1

NE_DIR
        byte $00

JOY_NW
        byte $00

BUTTON_PRESSED                  ; holds 1 when the button is held down
        byte $00
                                ; holds 1 when a single press is made (button released)
BUTTON_ACTION                   
        byte $00

;---------------------------------------------------------------------------------------------------
; Bit Table
; Take a value from 0 to 7 and return it's bit value
BIT_TABLE
        byte 1,2,4,8,16,32,64,128


*=$4000
;===============================================================================
;                                                       VIC MEMORY BLOCK
;                                                       CHARSET AND SPRITE DATA
;===============================================================================
; Charset and Sprite data directly loaded here.

VIC_DATA_INCLUDES

; VIC VIDEO MEMORY LAYOUT - BANK 1 ($4000 - $7FFF)
; SCREEN_1      = $4000 - $43FF         (Screen 0)      ; Double buffered
; SCREEN_2      = $4400 - $47FF         (Screen 1)      ; game screen
; MAP_CHARS     = $4800 - $5FFF         (Charset 1)     ; game chars (tiles)
; SCORE_CHARS   = $5000 - $57FF         (Charset 2)     ; Scoreboard chars
; SCORE_SCREEN  = $5800 - $5BFF         (Screen 6)      ; Scoreboard Screen
; SPRITES       = $5COO - $7FFF         (144 Sprite Images)

;---------------------
; CHARACTER SET SETUP
;---------------------
; Going with the 'Bear Essentials' model would be :
;
; 000 - 063    Normal font (letters / numbers / punctuation, sprite will pass over)
; 064 - 127    Backgrounds (sprite will pass over)
; 128 - 143    Collapsing platforms (deteriorate and eventually disappear when stood on)
; 144 - 153    Conveyors (move the character left or right when stood on)
; 154 - 191    Semi solid platforms (can be stood on, but can jump and walk through)
; 192 - 239    Solid platforms (cannot pass through)
; 240 - 255    Death (spikes etc)
;
; I would prefer to follow this model for organization, but it is useful to note that
; Charpad allows the setting the upper 4 bits of Color data (which is ignored by the VIC)
; to use as 16 'attribute' values.  Something I am taking advantage of.
;

*=$4800
MAP_CHAR_MEM                            ; Character set for map screen
incbin"Parkour_Maps/Parkour Mat Chset9h6.bin"

;---------------------------------------------------------- SPRITE DATA

; Location of Sprite Editor (imports)folder:
; J:\BackUpCDrive2015\C64\MLP Caver 0.6a
*=$5000
SCORE_CHAR_MEM
incbin "ScoreChars.cst",0,255           ; Character set for scoreboard

*=$5C00
incbin "yoursprite.spt",1,4,true        ; idle (28,33)
incbin "yoursprite.spt",5,6,true
incbin "yoursprite.spt",7,12,true        ; rope climb (36-39)
incbin "yoursprite.spt",13,18,true       ; Walking left (14-27)
incbin "yoursprite.spt",19,24,true       ; Walking right (0 - 13)!
incbin "yoursprite.spt",25,28,true       ; Punching to the right
incbin "yoursprite.spt",29,32,true       ; Punching to the left
incbin "yoursprite.spt",33,42,true
incbin "yoursprite.spt",43,46,true       ; Swimming to the right
incbin "yoursprite.spt",47,50,true       ; Swimming to the left
incbin "yoursprite.spt",51,56,true
incbin "yoursprite.spt",57,80,true       ; Enemy player   
incbin "yoursprite.spt",81,110,true

;===================================================================================================
;  LEVEL DATA
;===================================================================================================
; Each Level has a character set (2k) an attribute/color list (256 bytes) 64 4x4 tiles (1k)
; and a 64 x 32 (or 32 x 64) map (2k).

; The current level map will be put at $8000 with Attribute lists (256 bytes) and Tiles (1k)
; Starting after it at 8800

*=$8000
MAP_MEM
;incbin"Parkour_Maps/Parkour Redo Map6.bin"
incbin"Parkour_Maps/Parkour Mat Map9h6.bin"

ATTRIBUTE_MEM
;incbin"Parkour_Maps/Parkour Redo ChsetAttrib6.bin"
incbin"Parkour_Maps/Parkour Mat ChsetAttrib9h6.bin"

TILE_MEM
;incbin"Parkour_Maps/Parkour Redo Tileset6.bin"
incbin"Parkour_Maps/Parkour Mat Tileset9h6.bin"
