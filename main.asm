; From https://gbdev.io/gb-asm-tutorial/part1/hello_world.html
; Used GB ASM tutorial as starter code
; I'm really sorry about how gross this code is

INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]

  jp EntryPoint

  ds $150 - @, 0 ; Make room for the header

EntryPoint:
  ; Shut down audio circuitry
  ld a, 0
  ld [rNR52], a

  ; Do not turn the LCD off outside of VBlank
WaitVBlank:
  ld a, [rLY]
  cp 144
  jp c, WaitVBlank

  ; Turn the LCD off
  ld a, 0
  ld [rLCDC], a

  ; Copy the tile data
  ld de, Tiles
  ld hl, $9000
  ld bc, TilesEnd - Tiles
  call Memcopy

  ; Copy the tilemap
  ld de, Tilemap
  ld hl, $9800
  ld bc, TilemapEnd - Tilemap
  call Memcopy
  
  ; Copy ship tile
  ld de, ShipTiles
  ld hl, $8000
  ld bc, ShipTilesEnd - ShipTiles
  call Memcopy
  
  ; Copy Bullet tiles
  ld de, BulletTiles
  ld hl, $8010
  ld bc, BulletTilesEnd - BulletTiles
  call Memcopy
  
  ; Copy enemy tiles
  ld de, EnemyTiles
  ld hl, $8020
  ld bc, EnemyTilesEnd - EnemyTiles
  call Memcopy
  
  ; Clearing the OAM
  ld a, 0
  ld b, 160
  ld hl, _OAMRAM
ClearOam:
  ld [hli], a
  dec b
  jp nz, ClearOam
  
  ; Making ship object
    ld hl, _OAMRAM
    ld a, 128 + 16
    ld [hli], a
    ld a, 16 + 8
    ld [hli], a
    ld a, 0
    ld [hli], a
    ld [hli], a
    ; Now initialize the bullet
    ld a, 100 + 16
    ld [hli], a
    ld a, 32 + 8
    ld [hli], a
    ld a, 1
    ld [hli], a
    ld a, 0
    ld [hli], a
    ; Now we initialize the enemy
    ld a, 72 + 16
    ld [hli], a
    ld a, 48 + 8
    ld [hli], a
    ld a, 2
    ld [hli], a
    ld a, 0
    ld [hli], a
    
  ; set default bullet position 
  ld a, 1
  ld [_OAMRAM + 4], a
  ; setting bullet to inactive
  ld a, 1
  ld [wIsActive], a
  
  ; setting defualt position of enemy
  ld a, 20
  ld [_OAMRAM + 8], a
  ld a, 80
  ld [_OAMRAM + 9], a
  ld a, 0
  ld [wCanMoveCounter], a
  
  ; set "random value"
  ld a, %11001101
  ld [wRandData], a
  
  ; Turn the LCD on
  ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
  ld [rLCDC], a

  ; During the first (blank) frame, initialize display registers
  ld a, %11100100
  ld [rBGP], a
  ld a, %11100100
  ld [rOBP0], a


; Taken from GB ASM Tutorial
; https://gbdev.io/gb-asm-tutorial/part2/input.html
Main:
    ld a, [rLY]
    cp 144
    jp nc, Main
WaitVBlank2:
    ld a, [rLY]
    cp 144
    jp c, WaitVBlank2

    ; Check the current keys every frame and move left or right.
    call UpdateKeys
    
    ; Update enemy
    call UpdateEnemy
    
    ; move the bullet if it's active
    ld a, [wIsActive]
    dec a
    jp z, CheckLeft
    call UpdateBullet
    inc a
   

    ; First, check if the left button is pressed.
CheckLeft:
    ld a, [wCurKeys]
    and a, PADF_LEFT
    jp z, CheckRight
Left:
    ; Move the paddle one pixel to the left.
    ld a, [_OAMRAM + 1]
    dec a
    ; If we've already hit the edge of the playfield, don't move.
    cp a, 8
    jp z, Main
    ld [_OAMRAM + 1], a
    jp Main

; Then check the right button.
CheckRight:
    ld a, [wCurKeys]
    and a, PADF_RIGHT
    jp z, CheckUp
Right:
    ; Move the paddle one pixel to the right.
    ld a, [_OAMRAM + 1]
    inc a
    ; If we've already hit the edge of the playfield, don't move.
    cp a, 160
    jp z, Main
    ld [_OAMRAM + 1], a
    jp Main
    
; I wrote CheckUp and CheckDown but it was based on the code I got from above
CheckUp:
  ld a, [wCurKeys]
  and a, PADF_UP
  jp z, CheckDown
Up:
  ld a, [_OAMRAM]
  dec a
  cp a, 15
  jp z, Main
  ld [_OAMRAM], a
  jp Main
  
CheckDown:
  ld a, [wCurKeys]
  and a, PADF_DOWN
  jp z, TryShoot
Down:
  ld a, [_OAMRAM]
  inc a
  cp a, 152
  jp z, Main
  ld [_OAMRAM], a
  jp Main
  
TryShoot:
  ld a, [wCurKeys]
  and a, PADF_A
  jp z, Main
  ; If bullet is already active don't fire
  ld a, [wIsActive]
  dec a
  jp nz, Main
Shoot:
  call FireBullet
  jp Main
  

  
; Code taken from GB ASM Tutorial
; https://gbdev.io/gb-asm-tutorial/part2/input.html
UpdateKeys:
  ; Poll half the controller
  ld a, P1F_GET_BTN
  call .onenibble
  ld b, a ; B7-4 = 1; B3-0 = unpressed buttons

  ; Poll the other half
  ld a, P1F_GET_DPAD
  call .onenibble
  swap a ; A3-0 = unpressed directions; A7-4 = 1
  xor a, b ; A = pressed buttons + directions
  ld b, a ; B = pressed buttons + directions

  ; And release the controller
  ld a, P1F_GET_NONE
  ldh [rP1], a

  ; Combine with previous wCurKeys to make wNewKeys
  ld a, [wCurKeys]
  xor a, b ; A = keys that changed state
  and a, b ; A = keys that changed to pressed
  ld [wNewKeys], a
  ld a, b
  ld [wCurKeys], a
  ret

; Code taken from GB ASM Tutorial
; https://gbdev.io/gb-asm-tutorial/part2/input.html
.onenibble
  ldh [rP1], a ; switch the key matrix
  call .knownret ; burn 10 cycles calling a known ret
  ldh a, [rP1] ; ignore value while waiting for the key matrix to settle
  ldh a, [rP1]
  ldh a, [rP1] ; this read counts
  or a, $F0 ; A7-4 = 1; A3-0 = unpressed keys
.knownret
  ret


; Updates the enemy position and checks if it is out of bounds  
UpdateEnemy:
  ; Check if it is time for enemy to move
  ; basically this just slows down enemy movement
  ld a, [wCanMoveCounter]
  cp a, 6
  jp nz, next
  
  ; if the enemy can move, reset the move counter then move
  ld a, 0
  ld [wCanMoveCounter], a
  ld a, [_OAMRAM + 8]
  inc a
  ld [_OAMRAM + 8], a
  
  next:
  ; increment move counter
  ld a, [wCanMoveCounter]
  inc a
  ld [wCanMoveCounter], a
  
  ; Now check for collisions
  ; putting enemy y in b, and bullet y in a
  ld a, [_OAMRAM + 8]
  ld b, a
  ld a, [_OAMRAM + 4]
  cp a, b
  jp nz, end
  
  ; now check x pos
  ld a, [_OAMRAM + 9]
  ld b, a
  ld a, [_OAMRAM + 5]
  sub a, 8
  cp a, b
  jp nc, end
  
  ; Collision happned so KILL THE ENEMY!!!! (reset the y and change the x pos)
  ld a, 10
  ld [_OAMRAM + 8], a
  
  ; getting psuedo random number into x pos
  ld a, [_OAMRAM + 9]
  rl a
  ld [_OAMRAM + 9], a
  
  end:
  ret
  

 


  
; function that copies memory from one location to another
; taken from GB ASM Tutorial 
; https://gbdev.io/gb-asm-tutorial/part2/functions.html
; https://github.com/gbdev/gb-asm-tutorial
; @param de: Source
; @param hl: Destination
; @param bc: Length
Memcopy:
  ld a, [de]
  ld [hli], a
  inc de
  dec bc
  ld a, b
  or a, c
  jp nz, Memcopy
  ret
  
; Move bullet from offscreen to where the player is
FireBullet:
  ; change y position
  ld a, [_OAMRAM]
  dec a
  dec a
  dec a
  dec a
  dec a
  dec a
  ld [_OAMRAM + 4], a
  
  ; keep x position the same
  ld a, [_OAMRAM + 1]
  ld [_OAMRAM + 5], a
  
  ; activate the bullet
  ld a, 3
  ld [wIsActive], a
  ret
  
; Moves the bullet acrosss the screen, and checks if the bullet is out of bounds 
UpdateBullet:
  ; move bullet
  ld a, [_OAMRAM + 4]
  dec a
  ld [_OAMRAM + 4], a
  
  ; Check if bullet is off the screen
  cp a, 10
  jp z, DeactivateBullet
  jp leave
  
  DeactivateBullet:
    ld a, 1
    ld [wIsActive], a
    
  leave:
  ret



; All tiles were made using GameBoy Tile Desingner 
; http://www.devrs.com/gb/hmgd/gbtd.html
SECTION "Tile data", ROM0

Tiles:
  db $00,$00,$00,$00,$00,$00,$00,$00,
  db $00,$00,$00,$00,$00,$00,$00,$00,
  db $80,$80,$80,$80,$80,$80,$80,$80,
  db $80,$80,$80,$80,$80,$80,$80,$80,
  db $FF,$FF,$00,$00,$00,$00,$00,$00,
  db $00,$00,$00,$00,$00,$00,$00,$00,
  db $01,$01,$01,$01,$01,$01,$01,$01,
  db $01,$01,$01,$01,$01,$01,$01,$01,
  db $00,$00,$00,$00,$00,$00,$00,$00,
  db $00,$00,$00,$00,$00,$00,$FF,$FF,
  db $00,$00,$01,$01,$03,$02,$03,$02,
  db $03,$02,$0A,$0B,$0A,$0B,$1E,$1F,
  db $00,$00,$80,$80,$C0,$40,$40,$C0,
  db $40,$C0,$50,$D0,$50,$D0,$78,$F8,
  db $39,$36,$71,$4E,$81,$FE,$79,$7E,
  db $05,$06,$06,$07,$02,$03,$01,$01,
  db $8C,$7C,$82,$7E,$81,$7F,$1E,$FE,
  db $20,$E0,$60,$E0,$40,$C0,$80,$80,
  db $FF,$FF,$80,$80,$80,$80,$80,$80,
  db $80,$80,$80,$80,$80,$80,$80,$80,
  db $FF,$FF,$01,$01,$01,$01,$01,$01,
  db $01,$01,$01,$01,$01,$01,$01,$01,
  db $80,$80,$80,$80,$80,$80,$80,$80,
  db $80,$80,$80,$80,$80,$80,$FF,$FF,
  db $01,$01,$01,$01,$01,$01,$01,$01,
  db $01,$01,$01,$01,$01,$01,$FF,$FF,
TilesEnd:


SECTION "Tilemap", ROM0

; I actually made the tilemap lol
; it sucked :(
Tilemap:
db $09, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02,  $0a,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $01, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20,  $03,    0,0,0,0,0,0,0,0,0,0,0,0,
db $0b, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04,  $0c,    0,0,0,0,0,0,0,0,0,0,0,0,
TilemapEnd:

ShipTiles:
  db $00,$00,$18,$18,$24,$3C,$3C,$24
  db $5A,$66,$99,$E7,$66,$7E,$18,$18
ShipTilesEnd:

BulletTiles:
  db $00,$00,$18,$18,$3C,$24,$3C,$24
  db $3C,$24,$3C,$24,$18,$18,$00,$00
BulletTilesEnd:

EnemyTiles:
  db $18,$18,$24,$3C,$42,$7E,$A5,$DB
  db $81,$FF,$5A,$66,$24,$3C,$18,$18
EnemyTilesEnd:

SECTION "Input Variables", WRAM0
wCurKeys: db
wNewKeys: db

SECTION "Bullet Variables", WRAM0
; If wIsActive is 0 then bullet is inactive, but if it is one then its active
wIsActive: db

SECTION "Enemy Variables", WRAM0
wCanMoveCounter: db
wBulletPos: db
wRandData: db

