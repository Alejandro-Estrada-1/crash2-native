/* Presentation-only 512x240 -> 512x216 vertical crop for Crash Bandicoot 2.
 *
 * Strips the unrendered 12-line top and 12-line bottom CRT overscan margins
 * outside DrawEnv.clip (512x216 at y=12 inside a 512x240 DispEnv), presenting
 * the active image at its exact unstretched 40:27 aspect ratio instead of
 * letterboxing 24 black rows inside 4:3.
 *
 * Leaves GTE projection, FOV, GPU VRAM, guest memory, savestates, and all game
 * logic bit-identical. Set CRASH2NATIVE_NO_CROP=1 to disable at runtime. */

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#include "gpu.h"
#include "psx_memory.h"
#include "../re/structs.h"

_Static_assert(sizeof(DisplayContext) == 0x2094u,
               "DisplayContext size must match confirmed RE layout");
_Static_assert(offsetof(DisplayContext, disp_env) == 0x2018u,
               "DisplayContext.disp_env offset mismatch");
_Static_assert(offsetof(DisplayContext, draw_env) == 0x202Cu,
               "DisplayContext.draw_env offset mismatch");
_Static_assert(offsetof(PsxDispEnv, disp) == 0u,
               "PsxDispEnv.disp offset mismatch");
_Static_assert(offsetof(PsxDrawEnv, clip) == 0u,
               "PsxDrawEnv.clip offset mismatch");

#define CRASH2_ADDR_PHYS_MASK        0x1FFFFFFFu
#define CRASH2_LETTERBOX_LEVEL_MAX   64

static int crash2_crop_disabled(void) {
    static int cached = -1;
    if (cached < 0) {
        const char *env = getenv("CRASH2NATIVE_NO_CROP");
        cached = (env && env[0] && env[0] != '0') ? 1 : 0;
    }
    return cached;
}

static int crash2_peek_i16_pair(uint32_t addr, int16_t *lo, int16_t *hi) {
    uint32_t word = 0u;
    if (!psx_peek_word(addr, &word))
        return 0;
    *lo = (int16_t)(word & 0xFFFFu);
    *hi = (int16_t)(word >> 16);
    return 1;
}

static int crash2_try_slot_crop(uint32_t ctx_addr, const GpuDisplayInfo *info,
                                uint32_t *out_crop_y, uint32_t *out_crop_h) {
    int16_t dx = 0, dy = 0, dw = 0, dh = 0;
    int16_t cx = 0, cy = 0, cw = 0, ch = 0;
    const uint32_t disp_base = ctx_addr + (uint32_t)offsetof(DisplayContext, disp_env);
    const uint32_t draw_base = ctx_addr + (uint32_t)offsetof(DisplayContext, draw_env);

    if (!crash2_peek_i16_pair(disp_base + 0u, &dx, &dy) ||
        !crash2_peek_i16_pair(disp_base + 4u, &dw, &dh))
        return 0;

    if (dx < 0 || dy < 0 || dw <= 0 || dh <= 0)
        return 0;

    if ((uint32_t)dx != info->display_x ||
        (uint32_t)dy != info->display_y ||
        (uint32_t)dw != info->width ||
        (uint32_t)dh != info->height)
        return 0;

    if (!crash2_peek_i16_pair(draw_base + 0u, &cx, &cy) ||
        !crash2_peek_i16_pair(draw_base + 4u, &cw, &ch))
        return 0;

    /* Guard against full-240-line screens or malformed regions: only crop when
     * DrawEnv.clip matches width/x and sits strictly inside DispEnv.disp. */
    if (cx != dx || cw != dw || cy <= dy || ch <= 0 || ch >= dh)
        return 0;
    if ((int32_t)(cy - dy) + (int32_t)ch > (int32_t)dh)
        return 0;

    *out_crop_y = (uint32_t)(cy - dy);
    *out_crop_h = (uint32_t)ch;
    return 1;
}

static int crash2_present_crop(const GpuDisplayInfo *info,
                               PsxDisplayPresentCrop *out) {
    uint32_t front = 0u;
    uint32_t front_phys = 0u;
    uint32_t raw_letterbox = 0u;
    int32_t letterbox = 0;
    const uint32_t slot0 = CRASH2_ADDR_DISPLAY_CTX_POOL;
    const uint32_t slot1 = CRASH2_ADDR_DISPLAY_CTX_POOL +
                           (uint32_t)sizeof(DisplayContext);
    uint32_t other_slot = 0u;

    if (crash2_crop_disabled())
        return 0;
    if (!info || !out || info->disabled || info->depth24)
        return 0;
    if (info->width != 512u || info->height != 240u)
        return 0;

    /* Verify disp_ctx_front points into the initialized two-slot DisplayContext
     * pool so OpenBIOS boot screens (before display_init) remain uncropped 4:3. */
    if (!psx_peek_word(CRASH2_ADDR_DISP_CTX_FRONT, &front) || front == 0u)
        return 0;
    front_phys = front & CRASH2_ADDR_PHYS_MASK;
    if (front_phys != (slot0 & CRASH2_ADDR_PHYS_MASK) &&
        front_phys != (slot1 & CRASH2_ADDR_PHYS_MASK))
        return 0;
    other_slot = (front_phys == (slot0 & CRASH2_ADDR_PHYS_MASK)) ? slot1 : slot0;

    /* Validate letterbox_level (0x8006CC94). When > 0, draw_letterbox_and_fov
     * paints intentional black cutscene bars inside DrawEnv.clip; keep cropping
     * bounded strictly to DrawEnv.clip so cutscene framing stays intact and the
     * presentation aspect never snaps back to 4:3 mid-cutscene. */
    if (!psx_peek_word(CRASH2_ADDR_LETTERBOX_LEVEL, &raw_letterbox))
        return 0;
    letterbox = (int32_t)raw_letterbox;
    if (letterbox < 0 || letterbox > CRASH2_LETTERBOX_LEVEL_MAX)
        return 0;

    if (!crash2_try_slot_crop(front, info, &out->crop_y, &out->crop_h) &&
        !crash2_try_slot_crop(other_slot, info, &out->crop_y, &out->crop_h))
        return 0;

    out->aspect_num = 0;
    out->aspect_den = 0;
    return 1;
}

__attribute__((constructor))
static void crash2_register_present_crop(void) {
    gpu_set_present_crop_callback(crash2_present_crop);
}
