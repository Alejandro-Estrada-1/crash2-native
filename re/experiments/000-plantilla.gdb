# ------------------------------------------------------------------
# Experiment NNN: <short description>
#
# Precondition:  <exact save state or screen in PCSX-Redux>
#                e.g. "slot 1: start of Turtle Woods, Crash standing still"
# BIOS:          <emulator BIOS, e.g. OpenBIOS (PCSX-Redux build ..., sha256 <hash> of 0xbfc00000+512KiB)>
# Module:        main | overlay:<id>  (is it loaded at that moment?)
# Hypothesis:    <what we think the address/function does>
# Success:       <what must be observed>, e.g. "breakpoint hits when turning camera
#                and a0 points to a struct whose +0x1c changes"
# Failure:       breakpoint does not hit within PSX_GDB_TIMEOUT seconds,
#                or <another observation that rules out the hypothesis>
# Writes memory: no | yes (save state first)
# ------------------------------------------------------------------

# break *0x80000000
# continue
# info registers
# x/16wx $a0

detach
