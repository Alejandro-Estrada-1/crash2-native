# Experiment 005 — ISO9660 CD table and dynamic NSD/NSF paging system
#
# Precondition: PCSX-Redux running (unpaused) with Crash Bandicoot 2
#               (SCUS-94154) loaded on any playable screen or title (preferably
#               slot 1 in the first level, S1/S0000010, or title screen S3/S000003C);
#               GDB server active.
# BIOS: OpenBIOS (record version/SHA-256 on execution)
# Module: main (SCUS-941.54)
# Hypothesis:
#   1. iso9660_scan_levels (0x800316ec) populated disc_file_table at 0x80069034 with the
#      exact ISO9660 LBAs and sizes of each Sxxxxxxx.NSD/.NSF pair (12-byte stride).
#   2. level_load (0x80014c68) tracks the active level in nsd_paging_state (0x80067588):
#      active=1, current_level_id (0x8005f3ec) matches nsd_paging_state+0x4,
#      nsf_base_lba (0x800675a8) matches disc_file_table[level_id].w2 & 0xffffff,
#      and allocates dynamic buffers in the heap (>= 0x8006f1f4) including N contiguous
#      64 KiB physical pages (<= 21) at 0x800675b4.
#   3. The NSF pages loaded in RAM contain data/chunks (magic 0x1234 when type!=1),
#      and the active execution frame keeps tick quantization a multiple of 0x11 in
#      *(DAT_80063450 + 0x14) written by quantize_frame_ticks (0x80016f04).
# Success:
#   - disc_file_table at 0x02, 0x10 and 0x3c matches the exact ISO LBAs/sizes:
#       0x02 (0x8006904c): nsd_lba=0x00e029 (57385), nsd_size=0x016d4 (5844), nsf_lba=0x00e02c (57388)
#       0x10 (0x800690f4): nsd_lba=0x000019 (25),    nsd_size=0x01524 (5412), nsf_lba=0x00001c (28)
#       0x3c (0x80069304): nsd_lba=0x00dc66 (56422), nsd_size=0x00cd4 (3284), nsf_lba=0x00dc68 (56424)
#   - nsd_paging_state+0x0 == 1, +0x4 == current_level_id, +0x20 == active level nsf_lba,
#     num_phys_pages <= 21, num_virt_pages == 0x25 (37), nsd_buf >= 0x8006f1f4 and each
#     loaded physical slot points to nsd_pool + i * 0x10000.
#   - *(DAT_80063450 + 0x14) is a multiple of 0x11 (typically 0x11 or 0x22).
# Failure:
#   - Table 0x80069034 empty or with LBAs differing from the ISO9660 disc.
#   - Inconsistent nsd_paging_state, buffers outside heap range, or connection timeout.
#
# Writes memory: no (read-only; no continue/breakpoints to avoid SIGTRAP at 0x80000080)

set pagination off
set print pretty off

printf "=== Exp 005: Snapshot solo lectura (main / NSD / NSF / heap) ===\n"
printf "pc = 0x%08x, sp = 0x%08x, gp = 0x%08x\n", $pc, $sp, $gp

set $lvl = *(int *)0x8005f3ec
set $nxt = *(int *)0x8005f3f0
set $cd_mode = *(int *)0x8005f1a4
printf "\n[estado global nivel]\n"
printf "cd_mode (0x8005f1a4) = %d\n", $cd_mode
printf "current_level_id (0x8005f3ec) = 0x%x (%d)\n", $lvl, $lvl
printf "next_level_id    (0x8005f3f0) = 0x%x (%d)\n", $nxt, $nxt
printf "frame_counter    (0x8006ccf0) = %u\n", *(unsigned int *)0x8006ccf0
printf "rcnt2_tick_count (0x8003bea4) = %u\n", *(unsigned int *)0x8003bea4
printf "geom_screen      (0x80060884) = %d\n", *(int *)0x80060884

printf "\n[disc_file_table 0x80069034: muestras fijas + nivel activo]\n"
printf "id=0x02 @0x8006904c: raw={0x%08x, 0x%08x, 0x%08x} -> nsd_lba=%u (0x%x), nsd_size=%u (0x%x), nsf_lba=%u (0x%x)\n", \
  *(unsigned int *)0x8006904c, *(unsigned int *)0x80069050, *(unsigned int *)0x80069054, \
  (*(unsigned int *)0x8006904c & 0x7fffff), (*(unsigned int *)0x8006904c & 0x7fffff), \
  (*(unsigned int *)0x80069050 & 0x1ffff),  (*(unsigned int *)0x80069050 & 0x1ffff), \
  (*(unsigned int *)0x80069054 & 0xffffff), (*(unsigned int *)0x80069054 & 0xffffff)
printf "id=0x10 @0x800690f4: raw={0x%08x, 0x%08x, 0x%08x} -> nsd_lba=%u (0x%x), nsd_size=%u (0x%x), nsf_lba=%u (0x%x)\n", \
  *(unsigned int *)0x800690f4, *(unsigned int *)0x800690f8, *(unsigned int *)0x800690fc, \
  (*(unsigned int *)0x800690f4 & 0x7fffff), (*(unsigned int *)0x800690f4 & 0x7fffff), \
  (*(unsigned int *)0x800690f8 & 0x1ffff),  (*(unsigned int *)0x800690f8 & 0x1ffff), \
  (*(unsigned int *)0x800690fc & 0xffffff), (*(unsigned int *)0x800690fc & 0xffffff)
printf "id=0x3c @0x80069304: raw={0x%08x, 0x%08x, 0x%08x} -> nsd_lba=%u (0x%x), nsd_size=%u (0x%x), nsf_lba=%u (0x%x)\n", \
  *(unsigned int *)0x80069304, *(unsigned int *)0x80069308, *(unsigned int *)0x8006930c, \
  (*(unsigned int *)0x80069304 & 0x7fffff), (*(unsigned int *)0x80069304 & 0x7fffff), \
  (*(unsigned int *)0x80069308 & 0x1ffff),  (*(unsigned int *)0x80069308 & 0x1ffff), \
  (*(unsigned int *)0x8006930c & 0xffffff), (*(unsigned int *)0x8006930c & 0xffffff)

if ($lvl >= 0 && $lvl < 0x80)
  set $cur_ent = (unsigned int)(0x80069034 + $lvl * 12)
  printf "activo id=0x%x @0x%08x: nsd_lba=%u (0x%x), nsd_size=%u (0x%x), nsf_lba=%u (0x%x)\n", \
    $lvl, $cur_ent, \
    (*(unsigned int *)$cur_ent & 0x7fffff), (*(unsigned int *)$cur_ent & 0x7fffff), \
    (*(unsigned int *)($cur_ent + 4) & 0x1ffff), (*(unsigned int *)($cur_ent + 4) & 0x1ffff), \
    (*(unsigned int *)($cur_ent + 8) & 0xffffff), (*(unsigned int *)($cur_ent + 8) & 0xffffff)
end

printf "\n[heap propio del juego]\n"
printf "bss_end/heap_start (0x8005cb28) = 0x%08x\n", *(unsigned int *)0x8005cb28
printf "heap_head          (0x80062bac) = 0x%08x\n", *(unsigned int *)0x80062bac
printf "heap_brk           (0x8005f2a4) = 0x%08x\n", *(unsigned int *)0x8005f2a4
printf "heap_limit         (0x8005f2b4) = 0x%08x\n", *(unsigned int *)0x8005f2b4
printf "heap_init_flag     (0x8005f2bc) = %d\n",     *(int *)0x8005f2bc

printf "\n[nsd_paging_state 0x80067588]\n"
printf "+0x00 active          = %d\n", *(int *)0x80067588
printf "+0x04 level_id        = 0x%x (%d)\n", *(int *)0x8006758c, *(int *)0x8006758c
printf "+0x08 eid_buckets_ptr = 0x%08x\n", *(unsigned int *)0x80067590
printf "+0x0c eid_list_ptr    = 0x%08x\n", *(unsigned int *)0x80067594
printf "+0x14 world_hdr_ptr   = 0x%08x\n", *(unsigned int *)0x8006759c
set $nsd = *(unsigned int *)0x800675a0
printf "+0x18 nsd_buf         = 0x%08x\n", $nsd
printf "+0x20 nsf_base_lba    = %u (0x%x)\n", *(unsigned int *)0x800675a8, *(unsigned int *)0x800675a8
printf "+0x28 num_phys_pages  = %d\n", *(int *)0x800675b0
printf "num_virt_pages  (0x80067950) = %d\n", *(int *)0x80067950
printf "pending_pages   (0x80067fb0) = %d\n", *(int *)0x80067fb0
printf "active_cd_page  (0x80067fb4) = 0x%08x\n", *(unsigned int *)0x80067fb4
printf "eid_lut_ptr     (0x80067fc4) = 0x%08x\n", *(unsigned int *)0x80067fc4

if ($nsd >= 0x80010000U && $nsd < 0x80200000U)
  printf "\n[cabecera NSD en *nsd_buf + 0x400]\n"
  printf "nsf_page_count = 0x%x (%u), eid_count = 0x%x (%u)\n", \
    *(unsigned int *)($nsd + 0x400), *(unsigned int *)($nsd + 0x400), \
    *(unsigned int *)($nsd + 0x404), *(unsigned int *)($nsd + 0x404)
end

printf "\n[primeros 4 slots fisicos 0x800675b4 (stride 0x2c)]\n"
set $i = 0
set $nphys = *(int *)0x800675b0
while ($i < 4 && $i < $nphys && $i < 21)
  set $slot = (unsigned int)(0x800675b4 + $i * 0x2c)
  set $pbuf = *(unsigned int *)$slot
  set $state = *(unsigned short *)($slot + 4)
  set $kind = *(unsigned short *)($slot + 0x0a)
  set $idx = *(short *)($slot + 0x0c)
  set $pid = *(unsigned int *)($slot + 0x14)
  printf "  phys[%d] @0x%08x: buf=0x%08x state=0x%x kind=%u idx=%d page_id=0x%x", \
    $i, $slot, $pbuf, $state, $kind, $idx, $pid
  if ($pbuf >= 0x80010000U && $pbuf < 0x80200000U)
    printf " | page_hdr={magic=0x%04x type=%u eid=0x%08x cnt=%u}", \
      *(unsigned short *)$pbuf, *(unsigned short *)($pbuf + 2), \
      *(unsigned int *)($pbuf + 4), *(unsigned int *)($pbuf + 8)
  end
  printf "\n"
  set $i = $i + 1
end

printf "\n[verificacion secundaria: buffers de cuadro y quantize_frame_ticks]\n"
set $fb0 = *(unsigned int *)0x80063450
set $fb1 = *(unsigned int *)0x80063454
printf "fb_cur  (0x80063450) = 0x%08x, fb_prev (0x80063454) = 0x%08x\n", $fb0, $fb1
if ($fb0 >= 0x80010000U && $fb0 < 0x80200000U)
  printf "*(fb_cur  + 0x0c raw_ticks) = %u, *(fb_cur  + 0x14 quant_ticks) = %u (0x%x)\n", \
    *(unsigned int *)($fb0 + 0x0c), *(int *)($fb0 + 0x14), *(int *)($fb0 + 0x14)
end
if ($fb1 >= 0x80010000U && $fb1 < 0x80200000U)
  printf "*(fb_prev + 0x0c raw_ticks) = %u, *(fb_prev + 0x14 quant_ticks) = %u (0x%x)\n", \
    *(unsigned int *)($fb1 + 0x0c), *(int *)($fb1 + 0x14), *(int *)($fb1 + 0x14)
end

printf "\n[backtrace / pila actual]\n"
printf "ra = 0x%08x\n", $ra
bt 4
x/32wx $sp
detach
