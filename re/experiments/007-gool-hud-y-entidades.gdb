# ------------------------------------------------------------------
# Experiment 007: GOOL entities, DispEnv/DrawEnv, 2D HUD and 5/8 aspect
#
# Precondition:  PCSX-Redux running (unpaused) with Crash Bandicoot 2 (SCUS-94154)
#                loaded in a playable level (ideally with Crash movable and/or HUD
#                or pause screen visible to trigger hud_transform_2d 0x80044558).
# BIOS:          OpenBIOS (automatically recorded by scripts/gdb-psx)
# Module:        main (SCUS_941.54)
# Hypothesis:
#   1. At runtime, gool_player_ptr (0x8005f38c) points to gool_player_slot (0x8006cb10,
#      Crash), gool_object_pool (0x8006cb14) holds dynamic slots and the 8 root
#      buckets gool_root_buckets (0x8006cb18..0x8006cb57) link active nodes (+0x04 == 3)
#      with coherent pos (+0x60..+0x68), rot (+0x6c..+0x74), scale (+0x78..+0x80),
#      anim_seq (+0xe8) and anim_frame (+0xec), updated by gool_object_tick (0x8001c718)
#      and gool_physics_step (0x8001d63c), and drawn via render_queue_flush (0x8003db94).
#   2. In disp_ctx_front (0x80063450), +0x2018 holds DISPENV (512x240) and +0x202c
#      holds DRAWENV (clip 512x216, y=12, ofs_y=12), alongside +0x14 quant_ticks.
#   3. draw_letterbox_and_fov (0x80016c58) and quantize_frame_ticks (0x80016f04) run
#      every frame inside frame_end_sync (0x8001645c). With sky active (0x8006cb94 &
#      0x2000) draw_bg_tile (0x80016a60) triggers, and with HUD/pause visible
#      hud_transform_2d (0x80044558) triggers calling matrix_aspect_scale_local (0x80043090,
#      factor 5/8 = 0xa0 >> 8).
# Success:
#   - Crash and active nodes (+0x04 == 3) in gool_root_buckets show coherent pos/rot/scale/anim;
#     DISPENV == (w=512, h=240) and DRAWENV == (y=12, w=512, h=216); gool_object_tick,
#     gool_physics_step, render_queue_flush, draw_letterbox_and_fov and
#     quantize_frame_ticks hit (and hud_transform_2d/matrix_aspect_scale_local/draw_bg_tile if
#     active on the current screen).
# Failure:
#   - Null/corrupt GOOL pointers, DISPENV/DRAWENV do not match 512x240 / 512x216 y=12,
#     or the main game-loop tbreaks do not hit within PSX_GDB_TIMEOUT seconds.
# Writes memory: no (read-only + temporary SW breakpoints; no writes to the game)
# ------------------------------------------------------------------

set pagination off
set print pretty off

printf "=== Exp 007: Entidades GOOL, DisplayContext, HUD/5_8 y Bucle ===\n"
printf "pc = 0x%08x, level_id = 0x%x\n", $pc, *(int *)0x8005f3ec

set $rng_a0 = *(unsigned int *)0x8005f220
set $rng_b0 = *(unsigned int *)0x8005f224
printf "\n[RNG y entrada procesada (solo lectura)]\n"
printf "rng_a (0x8005f220) = 0x%08x, rng_b (0x8005f224) = 0x%08x\n", $rng_a0, $rng_b0
printf "pad_count (0x8006991c) = %d, demo_mode (0x8006cd14) = %d\n", \
  *(int *)0x8006991c, *(int *)0x8006cd14
printf "Pad1: raw_stat=0x%02x type=0x%02x pressed=0x%08x held=0x%08x prev1=0x%08x angle=%d mag=%d dir=%d\n", \
  *(unsigned char *)0x80069920, *(unsigned char *)0x80069921, \
  *(unsigned int *)0x80069944, *(unsigned int *)0x80069948, *(unsigned int *)0x8006994c, \
  *(int *)0x80069958, *(int *)0x8006995c, *(int *)0x80069960

printf "\n[Entidades GOOL: jugador, pool y 8 cubetas raiz]\n"
set $player = *(unsigned int *)0x8005f38c
set $pslot  = *(unsigned int *)0x8006cb10
set $pool   = *(unsigned int *)0x8006cb14
printf "gool_player_ptr  (0x8005f38c) = 0x%08x\n", $player
printf "gool_player_slot (0x8006cb10) = 0x%08x\n", $pslot
printf "gool_object_pool (0x8006cb14) = 0x%08x\n", $pool

if ($player >= 0x80060000U && $player < 0x80200000U)
  printf "  Player handle=%d kind=%d meta=0x%08x gool=0x%08x zone=0x%08x eid=0x%08x\n", \
    *(int *)$player, *(int *)($player + 4), *(unsigned int *)($player + 8), \
    *(unsigned int *)($player + 0x0c), *(unsigned int *)($player + 0x18), *(unsigned int *)($player + 0xb8)
  printf "  Player tree: self=0x%08x parent=0x%08x next=0x%08x child=0x%08x rider=0x%08x\n", \
    *(unsigned int *)($player + 0x40), *(unsigned int *)($player + 0x44), \
    *(unsigned int *)($player + 0x48), *(unsigned int *)($player + 0x4c), *(unsigned int *)($player + 0x58)
  printf "  Player pos   (+0x60..+0x68) = (%d, %d, %d)\n", \
    *(int *)($player + 0x60), *(int *)($player + 0x64), *(int *)($player + 0x68)
  printf "  Player rot   (+0x6c..+0x74) = (%d, %d, %d)\n", \
    *(int *)($player + 0x6c), *(int *)($player + 0x70), *(int *)($player + 0x74)
  printf "  Player scale (+0x78..+0x80) = (%d, %d, %d)\n", \
    *(int *)($player + 0x78), *(int *)($player + 0x7c), *(int *)($player + 0x80)
  printf "  Player vel   (+0x84..+0x8c) = (%d, %d, %d)\n", \
    *(int *)($player + 0x84), *(int *)($player + 0x88), *(int *)($player + 0x8c)
  printf "  Player anim: seq(+0xe8)=0x%08x frame(+0xec)=%d (>>8 = %d)\n", \
    *(unsigned int *)($player + 0xe8), *(int *)($player + 0xec), (*(int *)($player + 0xec) >> 8)
end

printf "\n[Recorrido de las 8 cubetas raiz gool_root_buckets (0x8006cb18..0x8006cb57)]\n"
set $tree_active = 0
set $b = 0
while ($b < 8)
  set $baddr = (unsigned int)(0x8006cb18 + $b * 8)
  set $btype = *(int *)$baddr
  set $cur   = *(unsigned int *)($baddr + 4)
  printf "  bucket[%d] @ 0x%08x: type=%d first_child=0x%08x\n", $b, $baddr, $btype, $cur
  set $hops_s1 = 0
  while ($cur >= 0x80060000U && $cur < 0x80200000U && $hops_s1 < 96)
    set $kind = *(int *)($cur + 4)
    if ($kind == 3)
      set $tree_active = $tree_active + 1
      if ($tree_active <= 20)
        printf "    [L1 b=%d] 0x%08x eid=0x%08x pos=(%d,%d,%d) rot=(%d,%d,%d) sc=(%d,%d,%d) seq=0x%08x frm=%d\n", \
          $b, $cur, *(unsigned int *)($cur + 0xb8), \
          *(int *)($cur + 0x60), *(int *)($cur + 0x64), *(int *)($cur + 0x68), \
          *(int *)($cur + 0x6c), *(int *)($cur + 0x70), *(int *)($cur + 0x74), \
          *(int *)($cur + 0x78), *(int *)($cur + 0x7c), *(int *)($cur + 0x80), \
          *(unsigned int *)($cur + 0xe8), *(int *)($cur + 0xec)
      end
    end
    set $ch = *(unsigned int *)($cur + 0x4c)
    set $hops_s2 = 0
    while ($ch >= 0x80060000U && $ch < 0x80200000U && $hops_s2 < 64)
      set $ckind = *(int *)($ch + 4)
      if ($ckind == 3)
        set $tree_active = $tree_active + 1
        if ($tree_active <= 20)
          printf "      [L2 b=%d] 0x%08x eid=0x%08x pos=(%d,%d,%d) rot=(%d,%d,%d) sc=(%d,%d,%d) seq=0x%08x frm=%d\n", \
            $b, $ch, *(unsigned int *)($ch + 0xb8), \
            *(int *)($ch + 0x60), *(int *)($ch + 0x64), *(int *)($ch + 0x68), \
            *(int *)($ch + 0x6c), *(int *)($ch + 0x70), *(int *)($ch + 0x74), \
            *(int *)($ch + 0x78), *(int *)($ch + 0x7c), *(int *)($ch + 0x80), \
            *(unsigned int *)($ch + 0xe8), *(int *)($ch + 0xec)
        end
      end
      set $gc = *(unsigned int *)($ch + 0x4c)
      set $hops_s3 = 0
      while ($gc >= 0x80060000U && $gc < 0x80200000U && $hops_s3 < 32)
        if (*(int *)($gc + 4) == 3)
          set $tree_active = $tree_active + 1
        end
        set $gc = *(unsigned int *)($gc + 0x48)
        set $hops_s3 = $hops_s3 + 1
      end
      set $ch = *(unsigned int *)($ch + 0x48)
      set $hops_s2 = $hops_s2 + 1
    end
    set $cur = *(unsigned int *)($cur + 0x48)
    set $hops_s1 = $hops_s1 + 1
  end
  set $b = $b + 1
end
printf "Total nodos activos (+0x04 == 3) recorridos en cubetas (profundidad <=3) = %d\n", $tree_active

set $free_cnt = 0
set $fcur = *(unsigned int *)0x8006cb5c
while ($fcur >= 0x80060000U && $fcur < 0x80200000U && $free_cnt < 96)
  set $free_cnt = $free_cnt + 1
  set $fcur = *(unsigned int *)($fcur + 0x48)
end
printf "Lista libre (0x8006cb58, type=%d first=0x%08x): nodos = %d\n", \
  *(int *)0x8006cb58, *(unsigned int *)0x8006cb5c, $free_cnt

set $pool_active = 0
if ($pool >= 0x80060000U && $pool < 0x80200000U)
  set $idx = 0
  while ($idx < 96)
    set $obj = (unsigned int)($pool + $idx * 0x23c)
    if (*(int *)($obj + 4) == 3)
      set $pool_active = $pool_active + 1
    end
    set $idx = $idx + 1
  end
end
printf "Total slots activos (+0x04 == 3) en gool_object_pool (96 slots) = %d\n", $pool_active

printf "\n[DisplayContext: DISPENV (+0x2018) y DRAWENV (+0x202c) en disp_ctx_front]\n"
set $front = *(unsigned int *)0x80063450
set $draw  = *(unsigned int *)0x80063454
set $work  = *(unsigned int *)0x80063458
printf "front=0x%08x draw=0x%08x work=0x%08x\n", $front, $draw, $work
if ($front >= 0x80010000U && $front < 0x80200000U)
  printf "front +0x00 id=%d +0x0c raw_ticks=%d +0x10 draw_ticks=%d +0x14 quant_ticks=%d (0x%x)\n", \
    *(int *)$front, *(int *)($front + 0x0c), *(int *)($front + 0x10), \
    *(int *)($front + 0x14), *(unsigned int *)($front + 0x14)
  set $de = (unsigned int)($front + 0x2018)
  printf "DISPENV (+0x2018 = 0x%08x): disp=(%d, %d, %d, %d) screen=(%d, %d, %d, %d) inter=%u rgb24=%u\n", \
    $de, *(short *)$de, *(short *)($de + 2), *(short *)($de + 4), *(short *)($de + 6), \
    *(short *)($de + 8), *(short *)($de + 10), *(short *)($de + 12), *(short *)($de + 14), \
    *(unsigned char *)($de + 16), *(unsigned char *)($de + 17)
  set $dr = (unsigned int)($front + 0x202c)
  printf "DRAWENV (+0x202c = 0x%08x): clip=(%d, %d, %d, %d) ofs=(%d, %d) tw=(%u,%u,%u,%u) isbg=%u +0x17=%u\n", \
    $dr, *(short *)$dr, *(short *)($dr + 2), *(short *)($dr + 4), *(short *)($dr + 6), \
    *(short *)($dr + 8), *(short *)($dr + 10), \
    *(short *)($dr + 12), *(short *)($dr + 14), *(short *)($dr + 16), *(short *)($dr + 18), \
    *(unsigned char *)($dr + 0x16), *(unsigned char *)($dr + 0x17)
  printf "work +0x2088..+0x2094:\n"
  x/4wx ($work + 0x2084)
end

printf "\n[Traps dinamicos 1/5: gool_object_tick (0x8001c718)]\n"
tbreak *0x8001c718
set $hops = 0
set $hit = 0
while ($hops < 150 && $hit == 0)
  continue
  if ((unsigned int)$pc == 0x8001c718U)
    set $hit = 1
  else
    if ((unsigned int)$pc == 0x80000080U)
      set $hops = $hops + 1
    else
      set $hops = 999
    end
  end
end
printf "hit=%d hops=%d pc=0x%08x ra=0x%08x a0(node)=0x%08x a1=0x%08x\n", \
  $hit, $hops, $pc, $ra, $a0, $a1
if ($hit == 1 && (unsigned int)$a0 >= 0x80060000U && (unsigned int)$a0 < 0x80200000U)
  printf "  node kind=%d pos=(%d,%d,%d) rot=(%d,%d,%d)\n", \
    *(int *)($a0 + 4), *(int *)($a0 + 0x60), *(int *)($a0 + 0x64), *(int *)($a0 + 0x68), \
    *(int *)($a0 + 0x6c), *(int *)($a0 + 0x70), *(int *)($a0 + 0x74)
end

printf "\n[Traps dinamicos 2/5: gool_physics_step (0x8001d63c)]\n"
tbreak *0x8001d63c
set $hops = 0
set $hit = 0
while ($hops < 150 && $hit == 0)
  continue
  if ((unsigned int)$pc == 0x8001d63cU)
    set $hit = 1
  else
    if ((unsigned int)$pc == 0x80000080U)
      set $hops = $hops + 1
    else
      set $hops = 999
    end
  end
end
printf "hit=%d hops=%d pc=0x%08x ra=0x%08x a0(obj)=0x%08x a1(sp18)=0x%08x dt=%d\n", \
  $hit, $hops, $pc, $ra, $a0, $a1, *(int *)(*(unsigned int *)0x80063450 + 0x14)
if ($hit == 1 && (unsigned int)$a0 >= 0x80060000U)
  printf "  obj pos=(%d,%d,%d) vel=(%d,%d,%d) player_pos_copy=(%d,%d,%d)\n", \
    *(int *)($a0 + 0x60), *(int *)($a0 + 0x64), *(int *)($a0 + 0x68), \
    *(int *)($a0 + 0x84), *(int *)($a0 + 0x88), *(int *)($a0 + 0x8c), \
    *(int *)0x8005f494, *(int *)0x8005f498, *(int *)0x8005f49c
end

printf "\n[Traps dinamicos 3/5: render_queue_flush (0x8003db94)]\n"
tbreak *0x8003db94
set $hops = 0
set $hit = 0
while ($hops < 150 && $hit == 0)
  continue
  if ((unsigned int)$pc == 0x8003db94U)
    set $hit = 1
  else
    if ((unsigned int)$pc == 0x80000080U)
      set $hops = $hops + 1
    else
      set $hops = 999
    end
  end
end
set $cw = *(unsigned int *)0x80063458
printf "hit=%d hops=%d pc=0x%08x ra=0x%08x a0=0x%08x work+2088=0x%08x work+2090=0x%08x\n", \
  $hit, $hops, $pc, $ra, $a0, *(unsigned int *)($cw + 0x2088), *(unsigned int *)($cw + 0x2090)

printf "\n[Traps dinamicos 4/5: draw_letterbox_and_fov (0x80016c58)]\n"
tbreak *0x80016c58
set $hops = 0
set $hit = 0
while ($hops < 150 && $hit == 0)
  continue
  if ((unsigned int)$pc == 0x80016c58U)
    set $hit = 1
  else
    if ((unsigned int)$pc == 0x80000080U)
      set $hops = $hops + 1
    else
      set $hops = 999
    end
  end
end
printf "hit=%d hops=%d pc=0x%08x ra=0x%08x a0(lb_cur)=%d a1(lb_prev)=%d geom_screen=%d\n", \
  $hit, $hops, $pc, $ra, $a0, $a1, *(int *)0x80060884

printf "\n[Traps dinamicos 5/5: quantize_frame_ticks (0x80016f04)]\n"
tbreak *0x80016f04
set $hops = 0
set $hit = 0
while ($hops < 150 && $hit == 0)
  continue
  if ((unsigned int)$pc == 0x80016f04U)
    set $hit = 1
  else
    if ((unsigned int)$pc == 0x80000080U)
      set $hops = $hops + 1
    else
      set $hops = 999
    end
  end
end
printf "hit=%d hops=%d pc=0x%08x ra=0x%08x a0(raw_ticks)=%d (0x%x)\n", \
  $hit, $hops, $pc, $ra, $a0, $a0

printf "\n[Traps acotados por 5 cuadros: hud_transform_2d (0x80044558), matrix_aspect_scale_local (0x80043090), draw_bg_tile (0x80016a60)]\n"
printf "level_flags (0x8006cb94) = 0x%08x (bit 0x2000 sky = %d)\n", \
  *(unsigned int *)0x8006cb94, ((*(unsigned int *)0x8006cb94 >> 13) & 1)

break *0x8001645c
set $bp_frame = $bpnum
break *0x80044558
set $bp_hud = $bpnum
set $arm_hud = 1
break *0x80043090
set $bp_scale = $bpnum
set $arm_scale = 1
break *0x80016a60
set $bp_tile = $bpnum
set $arm_tile = 1

set $frames = 0
set $hops = 0
set $hit_hud = 0
set $hit_scale = 0
set $hit_tile = 0
set $done = 0

while ($frames < 5 && $hops < 300 && $done == 0)
  continue
  if ((unsigned int)$pc == 0x80044558U)
    set $hit_hud = 1
    printf "  HIT hud_transform_2d (0x80044558) frame=%d: ra=0x%08x gp(obj)=0x%08x v1=0x%08x x=%d y=%d\n", \
      $frames, $ra, $gp, $v1, *(int *)($gp + 0x60), *(int *)($gp + 0x64)
    delete $bp_hud
    set $arm_hud = 0
  else
    if ((unsigned int)$pc == 0x80043090U)
      set $hit_scale = 1
      printf "  HIT matrix_aspect_scale_local (0x80043090) frame=%d: ra=0x%08x PRE t0=0x%08x t1=0x%08x t2=0x%08x t3=0x%08x t4=0x%08x\n", \
        $frames, $ra, $t0, $t1, $t2, $t3, $t4
      delete $bp_scale
      set $arm_scale = 0
      tbreak *0x80043088
      set $sh = 0
      while ($sh < 30 && (unsigned int)$pc != 0x80043088U)
        continue
        set $sh = $sh + 1
      end
      if ((unsigned int)$pc == 0x80043088U)
        printf "  RET matrix_aspect_scale_local (0x80043088): POST t0=0x%08x t1=0x%08x t2=0x%08x t3=0x%08x t4=0x%08x\n", \
          $t0, $t1, $t2, $t3, $t4
      end
    else
      if ((unsigned int)$pc == 0x80016a60U)
        set $hit_tile = 1
        printf "  HIT draw_bg_tile (0x80016a60) frame=%d: ra=0x%08x a0=%d a1=%d a2=%d a3=%d c=(%u,%u,%u)\n", \
          $frames, $ra, $a0, $a1, $a2, $a3, \
          *(unsigned char *)($sp + 0x10), *(unsigned char *)($sp + 0x14), *(unsigned char *)($sp + 0x18)
        delete $bp_tile
        set $arm_tile = 0
      else
        if ((unsigned int)$pc == 0x8001645cU)
          set $frames = $frames + 1
        else
          if ((unsigned int)$pc == 0x80000080U)
            set $hops = $hops + 1
          else
            set $done = 1
          end
        end
      end
    end
  end
  if ($hit_hud && $hit_scale && $hit_tile)
    set $done = 1
  end
end

delete $bp_frame
if ($arm_hud)
  delete $bp_hud
end
if ($arm_scale)
  delete $bp_scale
end
if ($arm_tile)
  delete $bp_tile
end

printf "Resumen ventana 5 cuadros: frames=%d hops=%d hit_hud=%d hit_scale=%d hit_tile=%d\n", \
  $frames, $hops, $hit_hud, $hit_scale, $hit_tile

set $rng_a1 = *(unsigned int *)0x8005f220
set $rng_b1 = *(unsigned int *)0x8005f224
printf "\n[Delta RNG tras varios cuadros]\n"
printf "rng_a: 0x%08x -> 0x%08x, rng_b: 0x%08x -> 0x%08x\n", $rng_a0, $rng_a1, $rng_b0, $rng_b1

detach
