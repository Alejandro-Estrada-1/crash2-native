# ------------------------------------------------------------------
# Experiment 008: Phase 3 closure — 3rd 5/8 path (0x8003d3cc/0x8001bd84),
#                 projection, cam_mode_dispatch (0x80026ca0) and zone_gfx_mode_apply (0x80020a24)
#
# Precondition:  PCSX-Redux running (unpaused) with Crash Bandicoot 2 (SCUS-94154):
#                - Level with Pause/HUD menu visible or 3D text for draw_text_3d (0x8001bd84)
#                  and model_view_matrix_build (0x8003d3cc), or
#                - Title screen / cutscene with black bars to observe
#                  letterbox_level != 0 and proportional H reduction in SetGeomScreen.
# BIOS:          OpenBIOS (automatically recorded by scripts/gdb-psx)
# Module:        main (SCUS_941.54)
# Hypothesis:
#   1. cam_mode_dispatch (0x80026ca0, from 0x80011b60) and zone_gfx_mode_apply (0x80020a24,
#      from cam_update 0x80017bd8) execute every frame during normal gameplay
#      (with DAT_8005b994 == 5, DAT_800608f0 and DAT_80062ad8 / level_flags coherent).
#   2. When 3D/HUD text exists (*anim_seq == 4), gool_render_enqueue chains into
#      draw_text_3d (0x8001bd84) -> model_view_matrix_build (0x8003d3cc), where block
#      0x8003d8f8..0x8003d94c scales s3/s0/s4 by -(val * 5) >> 3 in the GTE Y row.
#   3. If active sprites exist (*anim_seq == 2) or the GOOL projection opcode is used,
#      sprite_billboard_draw (0x80044830) and/or world_to_screen (0x8001ed60) fire.
#   4. If letterbox_level (0x8006cc94) > 0, draw_letterbox_and_fov (0x80016c58) reduces
#      geom_screen (0x80060884) = H_base - (H_base / 24) * letterbox_level via SetGeomScreen.
# Success:
#   - cam_mode_dispatch (0x80026ca0) and zone_gfx_mode_apply (0x80020a24) hit.
#   - When 3D/HUD text is displayed, draw_text_3d (0x8001bd84) and model_view_matrix_build
#     (0x8003d3cc) hit showing the exact -(val*5)>>3 arithmetic from 0x8003d8f8 -> 0x8003d94c.
#   - If letterbox_level != 0, H is observed reduced relative to the base value 288.
# Failure:
#   - Required breakpoints do not hit within 5 frames / PSX_GDB_TIMEOUT seconds, or the
#     arithmetic observed at 0x8003d8f8..0x8003d94c does not match -(val*5)>>3.
# Writes memory: no (read-only + temporary SW breakpoints; no writes to the game)
# ------------------------------------------------------------------

set pagination off
set print pretty off

printf "=== Exp 008: Cierre Fase 3 (3ra ruta 5/8, proyeccion, camara y letterbox) ===\n"
printf "pc = 0x%08x, level_id = 0x%x, demo_mode = %d\n", \
  $pc, *(int *)0x8005f3ec, *(int *)0x8006cd14

printf "\n[Estado de camara, letterbox y shaders WGEO (solo lectura)]\n"
printf "geom_screen       (0x80060884) = %d (0x%x)\n", *(int *)0x80060884, *(int *)0x80060884
printf "letterbox_level   (0x8006cc94) = %d, letterbox_prev (0x8005f1d4) = %d\n", \
  *(int *)0x8006cc94, *(int *)0x8005f1d4
printf "cam_trans_state   (0x8005b994) = %d, cam_submode (0x800608f0) = %d\n", \
  *(unsigned char *)0x8005b994, *(int *)0x800608f0
printf "zone_gfx_flags    (0x80062ad8) = 0x%08x, level_flags (0x8006cb94) = 0x%08x, ctrl_scale (0x8006cbb4) = 0x%x\n", \
  *(unsigned int *)0x80062ad8, *(unsigned int *)0x8006cb94, *(unsigned int *)0x8006cbb4
printf "wgeo_shaders (0x80062a28..38): "
x/5wx 0x80062a28

printf "\n[Ventana acotada 5 cuadros (frame_end_sync 0x8001645c) para 008]\n"
break *0x8001645c
set $bp_frame = $bpnum

break *0x80026ca0
set $bp_cam = $bpnum
set $arm_cam = 1

break *0x80020a24
set $bp_gfx = $bpnum
set $arm_gfx = 1

break *0x8001bd84
set $bp_txt = $bpnum
set $arm_txt = 1

break *0x8003d3cc
set $bp_mv = $bpnum
set $arm_mv = 1

break *0x8003d8f8
set $bp_pre = $bpnum
set $arm_pre = 1

break *0x8003d94c
set $bp_post = $bpnum
set $arm_post = 1

break *0x80044830
set $bp_spr = $bpnum
set $arm_spr = 1

break *0x8001ed60
set $bp_w2s = $bpnum
set $arm_w2s = 1

break *0x8004f008
set $bp_gs = $bpnum
set $arm_gs = 1

set $frames = 0
set $hops = 0
set $hit_cam = 0
set $hit_gfx = 0
set $hit_txt = 0
set $hit_mv = 0
set $hit_pre = 0
set $hit_post = 0
set $hit_spr = 0
set $hit_w2s = 0
set $hit_gs = 0
set $done = 0

while ($frames < 5 && $hops < 300 && $done == 0)
  continue
  if ((unsigned int)$pc == 0x80026ca0U)
    set $hit_cam = 1
    printf "  HIT cam_mode_dispatch (0x80026ca0) frame=%d: ra=0x%08x trans(5b994)=%d mode(608f0)=%d level_flags=0x%08x\n", \
      $frames, $ra, *(unsigned char *)0x8005b994, *(int *)0x800608f0, *(unsigned int *)0x8006cb94
    delete $bp_cam
    set $arm_cam = 0
  else
    if ((unsigned int)$pc == 0x80020a24U)
      set $hit_gfx = 1
      printf "  HIT zone_gfx_mode_apply (0x80020a24) frame=%d: ra=0x%08x zone_gfx=0x%08x level_flags=0x%08x shader0=0x%08x\n", \
        $frames, $ra, *(unsigned int *)0x80062ad8, *(unsigned int *)0x8006cb94, *(unsigned int *)0x80062a28
      delete $bp_gfx
      set $arm_gfx = 0
    else
      if ((unsigned int)$pc == 0x8001bd84U)
        set $hit_txt = 1
        printf "  HIT draw_text_3d (0x8001bd84) frame=%d: ra=0x%08x obj(a0)=0x%08x hdr(a1)=0x%08x idx(a2)=%d rmode=%u\n", \
          $frames, $ra, $a0, $a1, $a2, *(unsigned char *)($a0 + 0x120)
        delete $bp_txt
        set $arm_txt = 0
      else
        if ((unsigned int)$pc == 0x8003d3ccU)
          set $hit_mv = 1
          printf "  HIT model_view_matrix_build (0x8003d3cc) frame=%d: ra=0x%08x a0=0x%08x a1=0x%08x is2d(a2)=%d sh(a3)=%d mat=0x%08x\n", \
            $frames, $ra, $a0, $a1, $a2, $a3, *(unsigned int *)($sp + 0x10)
          delete $bp_mv
          set $arm_mv = 0
        else
          if ((unsigned int)$pc == 0x8003d8f8U)
            set $hit_pre = 1
            printf "    PRE  5/8 (0x8003d8f8): IR(s3,s0,s4)=(%d, %d, %d) R11/12/13(s2,s7,s1)=(%d, %d, %d)\n", \
              $s3, $s0, $s4, $s2, $s7, $s1
            delete $bp_pre
            set $arm_pre = 0
          else
            if ((unsigned int)$pc == 0x8003d94cU)
              set $hit_post = 1
              printf "    POST 5/8 (0x8003d94c): -(v*5>>3) (s3,s0,s4)=(%d, %d, %d) packed t0=0x%08x t1=0x%08x t2=0x%08x\n", \
                $s3, $s0, $s4, $t0, $t1, $t2
              delete $bp_post
              set $arm_post = 0
            else
              if ((unsigned int)$pc == 0x80044830U)
                set $hit_spr = 1
                printf "  HIT sprite_billboard_draw (0x80044830) frame=%d: ra=0x%08x gp(obj)=0x%08x v1=0x%08x\n", \
                  $frames, $ra, $gp, $v1
                delete $bp_spr
                set $arm_spr = 0
              else
                if ((unsigned int)$pc == 0x8001ed60U)
                  set $hit_w2s = 1
                  printf "  HIT world_to_screen (0x8001ed60) frame=%d: ra=0x%08x a0=0x%08x (%d,%d,%d) out(a1)=0x%08x\n", \
                    $frames, $ra, $a0, *(int *)$a0, *(int *)($a0 + 4), *(int *)($a0 + 8), $a1
                  delete $bp_w2s
                  set $arm_w2s = 0
                else
                  if ((unsigned int)$pc == 0x8004f008U)
                    set $hit_gs = 1
                    printf "  HIT SetGeomScreen (0x8004f008) frame=%d: ra=0x%08x a0(H)=%d letterbox=%d\n", \
                      $frames, $ra, $a0, *(int *)0x8006cc94
                    delete $bp_gs
                    set $arm_gs = 0
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
            end
          end
        end
      end
    end
  end
end

delete $bp_frame
if ($arm_cam)
  delete $bp_cam
end
if ($arm_gfx)
  delete $bp_gfx
end
if ($arm_txt)
  delete $bp_txt
end
if ($arm_mv)
  delete $bp_mv
end
if ($arm_pre)
  delete $bp_pre
end
if ($arm_post)
  delete $bp_post
end
if ($arm_spr)
  delete $bp_spr
end
if ($arm_w2s)
  delete $bp_w2s
end
if ($arm_gs)
  delete $bp_gs
end

printf "\nResumen 5 cuadros: frames=%d hops=%d cam=%d gfx=%d txt=%d mv=%d(pre=%d,post=%d) spr=%d w2s=%d setH=%d\n", \
  $frames, $hops, $hit_cam, $hit_gfx, $hit_txt, $hit_mv, $hit_pre, $hit_post, $hit_spr, $hit_w2s, $hit_gs

detach
