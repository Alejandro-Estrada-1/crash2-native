# ------------------------------------------------------------------
# Experimento 006: Codigo MIPS nativo en GOOL (tipo 11, 0x8003aad4) y camara/proyeccion
#
# Precondicion:  PCSX-Redux corriendo (sin pausa) con Crash Bandicoot 2 (SCUS-94154)
#                cargado en pantalla de titulo o nivel jugable (p. ej. nivel activo
#                0x1e de la sesion), con el servidor GDB activo tras correr 005.
# BIOS:          OpenBIOS (registrada automaticamente por scripts/gdb-psx)
# Modulo:        main (SCUS_941.54) + chunks GOOL (tipo 11) en paginas NSF en heap RAM
# Hipotesis:
#   1. En runtime existen chunks GOOL (tipo 11) cargados dentro de los slots fisicos
#      de nsd_paging_state (0x800675b4) cuya seccion sec[1] contiene bytecode 0x49xxxxxx
#      intercalado con bloques MIPS nativos terminados en 0x03e0a809 (jalr s5, ra) o
#      0x03e00008 + 0x34150000 (jr ra; ori s5, zero, 0).
#   2. gool_interpret (0x8003a014), al despachar el opcode 0x49 por 0x8005c514[0x49],
#      ejecuta `0x8003aad4: jalr s5` saltando directamente al bloque MIPS en RAM heap
#      ($s5 dentro del pool >= 0x8006f1f4, $s8 == 0x1f800000, $s0 -> objeto GOOL).
#   3. Las variables de pantalla/camara/proyeccion reflejan:
#      - display_ctx_pool: DispEnv 512x240 y DrawEnv 512x216 con y=12;
#      - geom_screen (0x80060884) tipicamente 0x120 (288), cam_pos (0x800607f4..fc),
#        cam_rot (0x80060800..08), cam_view_matrix (0x80060774) con fila Y escalada -5/8,
#        geom_offset_x/y (0x8006cc20/24) y SetGeomOffset centrado en (0x100, 0x6c).
# Exito:
#   - Al menos una pagina fisica cargada contiene un chunk GOOL (tipo 11) con sec[1]
#     que incluye bloques MIPS nativos en RAM.
#   - El tbreak en 0x8003aad4 salta y muestra $pc == 0x8003aad4, $s8 == 0x1f800000, $s5
#     apuntando dentro de sec[1] de una pagina NSF residente (>= 0x8006f1f4) e
#     instrucciones MIPS validas desensambladas desde $s5.
#   - El tbreak en 0x8004efe8 (SetGeomOffset llamado desde cam_update en 0x80017f70)
#     muestra $a0 == 0x100 + geom_offset_x y $a1 == 0x6c + (cam_shake_y >> 8) + geom_offset_y.
# Fallo:
#   - Ninguna pagina fisica residente contiene tipo 11 con sec[1] MIPS, o bien
#     $s5 en 0x8003aad4 apunta fuera del heap / a codigo estatico de SCUS_941.54,
#     o los breakpoints no saltan dentro de PSX_GDB_TIMEOUT segundos.
# Escribe en memoria: no (temporalmente usa tbreak SW; sin escrituras persistentes al juego)
# ------------------------------------------------------------------

set pagination off
set print pretty off

printf "=== Exp 006: Estado camara/pantalla + inspeccion GOOL tipo 11 + trap 0x8003aad4 ===\n"
printf "pc = 0x%08x, level_id = 0x%x\n", $pc, *(int *)0x8005f3ec

printf "\n[proyeccion, recorte y camara]\n"
printf "geom_screen       (0x80060884) = %d (0x%x)\n", *(int *)0x80060884, *(int *)0x80060884
printf "letterbox_level   (0x8006cc94) = %d\n", *(int *)0x8006cc94
printf "letterbox_prev    (0x8005f1d4) = %d\n", *(int *)0x8005f1d4
printf "geom_offset_x     (0x8006cc20) = %d\n", *(int *)0x8006cc20
printf "geom_offset_y     (0x8006cc24) = %d\n", *(int *)0x8006cc24
printf "cam_shake_y       (0x8006cb78) = %d (>>8 = %d)\n", *(int *)0x8006cb78, (*(int *)0x8006cb78 >> 8)
printf "current_zone      (0x800608cc) = 0x%08x\n", *(unsigned int *)0x800608cc
printf "current_cam_path  (0x800608d4) = 0x%08x, progress (0x800608e0) = 0x%x\n", \
  *(unsigned int *)0x800608d4, *(unsigned int *)0x800608e0
printf "cam_pos (0x800607f4..fc) = (%d, %d, %d)\n", \
  *(int *)0x800607f4, *(int *)0x800607f8, *(int *)0x800607fc
printf "cam_rot (0x80060800..08) = (%d, %d, %d)\n", \
  *(int *)0x80060800, *(int *)0x80060804, *(int *)0x80060808
printf "cam_rot_matrix (0x80060754):\n"
x/8wx 0x80060754
printf "cam_view_matrix (0x80060774, fila Y escalada -5/8):\n"
x/8wx 0x80060774

printf "\n[auditoria BSS jalr: DAT_80062a18 (arg2 de FUN_80041e5c -> +0x10 en 0x80041f34)]\n"
x/10wx 0x80062a18

printf "\n[display_ctx_pool / DispEnv / DrawEnv]\n"
printf "disp_ctx_count (0x8006344c) = %d\n", *(int *)0x8006344c
set $front = *(unsigned int *)0x80063450
set $draw  = *(unsigned int *)0x80063454
set $work  = *(unsigned int *)0x80063458
printf "disp_ctx_front = 0x%08x, disp_ctx_draw = 0x%08x, disp_ctx_work = 0x%08x\n", $front, $draw, $work
if ($front >= 0x80010000U && $front < 0x80200000U)
  printf "primeras 20 palabras de *disp_ctx_front (0x%08x):\n", $front
  x/20wx $front
end

printf "\n[busqueda solo-lectura de chunks GOOL (tipo 11) residentes en slots fisicos]\n"
set $nphys = *(int *)0x800675b0
set $i = 0
while ($i < $nphys && $i < 21)
  set $slot = (unsigned int)(0x800675b4 + $i * 0x2c)
  set $state = *(unsigned short *)($slot + 4)
  set $pbuf  = *(unsigned int *)$slot
  if (($state == 0x14 || $state == 0x15) && $pbuf >= 0x80060000U && $pbuf < 0x80200000U)
    set $magic = *(unsigned short *)$pbuf
    set $ptype = *(unsigned short *)($pbuf + 2)
    if ($magic == 0x1234 && ($ptype == 0 || $ptype == 5))
      set $ecnt = *(int *)($pbuf + 8)
      set $j = 0
      while ($j < $ecnt && $j < 64)
        set $ent = *(unsigned int *)($pbuf + 0x10 + $j * 4)
        if ($ent >= 0x80060000U && $ent < 0x80200000U)
          set $etype = *(int *)($ent + 8)
          if ($etype == 11)
            set $eid = *(unsigned int *)($ent + 4)
            set $sec1 = *(unsigned int *)($ent + 0x14)
            printf "  phys[%d] (%08x) ent[%d]=0x%08x EID=0x%08x GOOL sec[1]=0x%08x\n", \
              $i, $pbuf, $j, $ent, $eid, $sec1
          end
        end
        set $j = $j + 1
      end
    end
  end
  set $i = $i + 1
end

printf "\n[verificacion viva 1: salto a MIPS en heap en 0x8003aad4 (gool_op49_exec_mips)]\n"
tbreak *0x8003aad4
set $hops1 = 0
set $hit1 = 0
while ($hops1 < 150 && $hit1 == 0)
  continue
  if ((unsigned int)$pc == 0x8003aad4U)
    set $hit1 = 1
  else
    if ((unsigned int)$pc == 0x80000080U)
      set $hops1 = $hops1 + 1
    else
      set $hops1 = 999
    end
  end
end
printf "hit1=%d (hops1=%d) pc = 0x%08x, s5 = 0x%08x, s0 (obj) = 0x%08x, s8 = 0x%08x, ra = 0x%08x\n", \
  $hit1, $hops1, (unsigned int)$pc, (unsigned int)$s5, (unsigned int)$s0, (unsigned int)$s8, (unsigned int)$ra
if ((unsigned int)$pc == 0x8003aad4U && (unsigned int)$s5 >= 0x80060000U && (unsigned int)$s5 < 0x80200000U)
  printf "primeras 16 instrucciones MIPS en RAM ($s5 = 0x%08x):\n", (unsigned int)$s5
  x/16i (unsigned int)$s5
end

printf "\n[verificacion viva 2: SetGeomOffset (0x8004efe8) desde cam_update (ra=0x80017f78)]\n"
tbreak *0x8004efe8
set $hops2 = 0
set $hit2 = 0
while ($hops2 < 150 && $hit2 == 0)
  continue
  if ((unsigned int)$pc == 0x8004efe8U)
    set $hit2 = 1
  else
    if ((unsigned int)$pc == 0x80000080U)
      set $hops2 = $hops2 + 1
    else
      set $hops2 = 999
    end
  end
end
printf "hit2=%d (hops2=%d) pc = 0x%08x, ra = 0x%08x, a0 (OFX) = %d (0x%x), a1 (OFY) = %d (0x%x)\n", \
  $hit2, $hops2, (unsigned int)$pc, (unsigned int)$ra, $a0, $a0, $a1, $a1

detach
