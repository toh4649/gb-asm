INCLUDE "gbhw.inc"

;**************************************
;割り込みハンドラ(何もしない) 

SECTION "V-Blank IRQ Vector",ROM0[$40]
    reti    ;なにもせずリターン(retiは、割り込みを再有効化してくれるret)

SECTION "LCD IRQ Vector",ROM0[$48]
    reti

SECTION "Timer IRQ Vector",ROM0[$50]
    reti

SECTION "Serial IRQ Vector",ROM0[$58]
    reti

SECTION "Joypad IRQ Vector",ROM0[$60]
    reti



;**************************************
; リセット時、ここから実行が始まる 


SECTION "Start",ROM0[$100]  
    nop         ;(多分)サイズ合わせようのダミー命令
    jp  main

    ;gbhw.incに含まれる、ROM情報を自動生成してくれる便利なマクロ
    ROM_HEADER ROM_NOMBC, ROM_SIZE_32KBYTE, RAM_SIZE_0KBYTE

;**************************************
; 定数など  

;タイル用画像
;2バイトで1ラインを表し、各バイトの各ビットが1ピクセルに対応する。
;偶数バイトが、パレット番号の下位ビットを表し、奇数バイトが上位ビットを表す
Tile:  
    ;1行目8ピクセルのパレット番号は, 0,3,3,3, 3,3,3,3
    db  %01111111   ;1行目, パレット番号下位ビット 
    db  %01111111   ;1行目, パレット番号上位ビット

    ;2行目8ピクセルのパレット番号は, 2,2,2,2, 2,2,2,2
    db  %00000000   ;2行目, パレット番号下位ビット
    db  %11111111   ;2行目, パレット番号上位ビット

    db  %11111111   ;3行目
    db  %00000000
    db  %00000000   ;4
    db  %00000000
    db  %11111111   ;5
    db  %00000000
    db  %00000000   ;6
    db  %11111111   
    db  %11111111   ;7
    db  %11111111   
    db  %00000000   ;8
    db  %00000000
TileEnd:

    

;**************************************
; メインルーチン

main:
    di                  ; いったん割り込みを無効化
    ld  sp, $ffff       ; スタックポインタをメモリ空間の底に設定

    ld  a, %11100100    ; パレット(パレットごとに2bitで白さを指定。MSBがパット番号0番)
    ld  [rBGP], a       ; BGPレジスタにパレットを設定

    ld  a,0             ; スクロールレジスタを設定し、画面を右上に固定
    ld  [rSCX], a       ; SCXレジスタ
    ld  [rSCY], a       ; SCYレジスタ

.waitVBlank:                ; 画面描画を止めるため、まず現在の描画が終るのを待つ
    ld  a, [rLY]
    cp  145                 ; 画面描画が終った=描画位置がY=145であるか?
    jr  nz, .waitVBlank     ; 違ったらまだ待つ(jrは相対ジャンプで、命令長が短くなる)

    ld  a, [rLCDC]
    res 7, a             
    ld  [rLCDC], a          ; VRAMに書き込むため、画面描画を止める

    ld  hl, Tile            ; vramcpy コピー元
    ld  bc, _VRAM           ; vramcpy コピー先
    ld  de, TileEnd-Tile    ; vramcpy コピー長さ
    call  vramcpy           ; ROMからタイルをロード

    ld  b, $0               ; vramset 設定値
    ld  hl, _SCRN0          ; vramset コピー先
    ld  de, 32*32           ;vramset コピー長さ
    call  vramset           ; 画面全域にタイル番号0番を設定

    ld  a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_BGON|LCDCF_OBJ16|LCDCF_OBJOFF
    ld  [rLCDC], a          ; 画面ON

mainloop:
    halt
    nop
    jr mainloop

; **************************************
; vramへメモリの内容をコピー
; 入力
;   hl - コピー元アドレス
;   bc - コピー先アドレス
;   de - 長さ
vramcpy:
    inc  d
    inc  e 
    jr   .loopEnd
.loop:
    di
    ld  a,[rSTAT]   
    and STATF_BUSY
    jr  nz, .loop     ;vramが受け入れ態勢になるまでまつ
    ei

    ld  a, [hl]
    ld  [bc], a
    inc hl
    inc bc
.loopEnd:
    dec e 
    jr  nz, .loop 
    dec d  ;e(下位バイト)が0になるとここに来る
    jr  nz, .loop
    ret

; **************************************
; vramへ値をセット
; 入力
;   b  - 設定したい値
;   hl - コピー先アドレス
;   de - 長さ
vramset:

    inc  d
    inc  e 
    jr   .loopEnd
.loop:
    di
    ld  a,[rSTAT]   
    and a,STATF_BUSY
    jr  nz, .loop     ;vramが受け入れ態勢になるまでまつ
    ei

    ld  a, b
    ld  [hl], a
    inc hl
.loopEnd:
    dec e 
    jr  nz, .loop 
    dec d  ;e(下位バイト)が0になるとここに来る
    jr  nz, .loop
    ret
