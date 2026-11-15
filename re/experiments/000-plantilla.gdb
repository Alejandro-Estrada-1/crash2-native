# ------------------------------------------------------------------
# Experimento NNN: <descripción corta>
#
# Precondición:  <estado de guardado o pantalla exacta en PCSX-Redux>
#                p. ej. "slot 1: inicio de Turtle Woods, Crash quieto"
# BIOS:          <BIOS del emulador, p. ej. OpenBIOS (PCSX-Redux build ...)>
# Módulo:        main | overlay:<id>  (¿está cargado en ese momento?)
# Hipótesis:     <qué creemos que hace la dirección/función>
# Éxito:         <qué debe observarse>, p. ej. "el breakpoint salta al girar la cámara
#                y a0 apunta a una estructura cuyo +0x1c cambia"
# Fallo:         el breakpoint no salta en PSX_GDB_TIMEOUT segundos,
#                o <otra observación que descarte la hipótesis>
# Escribe en memoria: no | sí (guardar estado antes)
# ------------------------------------------------------------------

# break *0x80000000
# continue
# info registers
# x/16wx $a0

detach
