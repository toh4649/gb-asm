INCLUDE "gbhw.inc"

;**************************************
;割り込みハンドラ

SECTION "V-Blank IRQ Vector",ROM0[$40]
    jp draw

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
; 定数・変数  

;タイル用画像
Tile:  
    db $7F,$7F,$00,$FF,$FF,$00,$00,$00
    db $FF,$00,$00,$FF,$FF,$FF,$00,$00
TileEnd:

VBlankFlg EQU $C000     ;VBlank割り込みハンドラが呼ばれたら1になるフラグ

;**************************************
; メインルーチン

main:
    di                  ; いったん割り込みを無効化
    ld  sp, $ffff       ; スタックポインタをメモリ空間の底に設定

    ld  a, %11100100    ; パレット(パレットごとに2bitで白さを指定。MSBがパット番号0番)
    ld  [rBGP], a       ; BGPレジスタにパレットを設定

    ld  a,0             ; スクロールレジスタを設定し、画面を左上に固定
    ld  [rSCX], a       ; SCXレジスタ
    ld  [rSCY], a       ; SCYレジスタ

    call stopLcd

    ld  hl, Tile            ; vramcpy コピー元 (ハードコードしたタイルの画像のアドレス)
    ld  bc, _VRAM           ; vramcpy コピー先 ($8000)
    ld  de, TileEnd-Tile    ; vramcpy コピー長さ
    call  vramcpy           ; VRAMに値をコピーするするサブルーチン

    ld  b, $0               ; vramset 設定値
    ld  hl, _SCRN0          ; vramset コピー先
    ld  de, 32*32           ; vramset コピー長さ
    call  vramset           ; サブルーチン。画面全域にタイル番号0番を設定

    ld  a, LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_BGON|LCDCF_OBJ16|LCDCF_OBJOFF
    ld  [rLCDC], a          ; 画面ON

    ld a, IEF_VBLANK 
	ld [rIE], a	            ;垂直帰線割り込みを有効化
	ei                      ;割り込み有効化

mainloop:
    halt                ;何らかの割り込みが発生するまで、CPU(?)を止める。電池節約のために良いとされる。
    nop                 ;halt命令で処理が止まる前に,次の命令が実行されてしまうので、ダミーの1命令を挟む

    ;Vblankを含め、何らかの割り込みがあった場合、ここに来る
    ld  a,[VBlankFlg]   ;VBlank割り込みハンドラがフラグを立てたかチェック
    or  a
    jr  z,mainloop      ;(つまり、今回の割り込みがVBlank割り込みであれば次に進む)

    xor a               ;a=0
    ld  [VBlankFlg],a   ;VBlank判定用のフラグをクリア

    ld  a,[rSCX]        ;スクロール. xとy両方を1足す
    inc a
    ld  [rSCX],a
    ld  [rSCY],a

    jp mainloop


; **************************************
; VBlank割り込みのハンドラ
draw:
    ld      a,1
    ld      [VBlankFlg],a
    reti


; **************************************
; 画面表示を止める
stopLcd:
    ld  a, [rLY]
    cp  145                 ; 画面描画が終った=描画位置がY=145であるか?
    jr  nz, stopLcd         ; 違ったらまだ待つ(jrは相対ジャンプで、命令長が短くなる)

    ld  a, [rLCDC]
    res 7, a             
    ld  [rLCDC], a          ; VRAMに書き込むため、画面描画を止める
    ret


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
