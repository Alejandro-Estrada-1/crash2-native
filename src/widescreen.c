/* Presentation crop and controlled 16:9 FOV scaling for Crash Bandicoot 2.
 *
 * Step 5A: Strips the unrendered 12-line top and 12-line bottom CRT overscan
 * margins outside DrawEnv.clip (512x216 at y=12 inside a 512x240 DispEnv),
 * presenting the active image at unstretched 40:27 when 4:3 is selected.
 * Set CRASH2NATIVE_NO_CROP=1 to disable vertical cropping at runtime.
 *
 * Step 5B: When the crash2.enhancement.widescreen mod enables 16:9 (with
 * [widescreen] native_wide = false, ws_mode = 1), derives the GTE squash ratio
 * from the cropped 40:27 base rather than 4:3:
 *   - Default k_fov = 9/8 (1.125x horizontal opening -> 3:2 GTE target -> 8/9
 *     X-squash -> ~16/15 = 1.067x subtle residual stretch up to 16:9).
 *   - Set via the mod's fov_opening option or CRASH2NATIVE_FOV (e.g. "1.125",
 *     "1.10", "1.20", "9/8", "11/10", "6/5").
 * Keeps 4:3 (mod disabled) as a strict 1:1 GTE identity, and keeps OpenBIOS
 * and 24-bit FMVs unstretched at 4:3. */

#include <ctype.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "gpu.h"
#include "mod_plugins.h"
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
#define CRASH2_WS_PACKAGE_ID         "crash2.enhancement.widescreen"
#define CRASH2_WS_FEATURE_ID         "widescreen"
#define CRASH2_WS_OPTION_FOV         "fov_opening"
#define CRASH2_WS_PLUGIN_ID          "crash2.widescreen"

static int s_fov_num = 9;
static int s_fov_den = 8;

static int crash2_crop_disabled(void) {
    static int cached = -1;
    if (cached < 0) {
        const char *env = getenv("CRASH2NATIVE_NO_CROP");
        cached = (env && env[0] && env[0] != '0') ? 1 : 0;
    }
    return cached;
}

static void crash2_reduce_ratio(int64_t *n_io, int64_t *d_io) {
    int64_t n = *n_io;
    int64_t d = *d_io;
    int64_t a, b;
    if (n <= 0 || d <= 0)
        return;
    a = n;
    b = d;
    while (b != 0) {
        int64_t t = a % b;
        a = b;
        b = t;
    }
    if (a > 0) {
        n /= a;
        d /= a;
    }
    *n_io = n;
    *d_io = d;
}

static int crash2_parse_uint(const char **p_io, int64_t *out) {
    const char *p = *p_io;
    int64_t v = 0;
    if (!isdigit((unsigned char)*p))
        return 0;
    while (isdigit((unsigned char)*p)) {
        if (v > 1000000)
            return 0;
        v = v * 10 + (*p - '0');
        p++;
    }
    *p_io = p;
    *out = v;
    return 1;
}

static int crash2_parse_fov(const char *text, int *out_num, int *out_den) {
    const char *p = text;
    int64_t num = 0, den = 1;
    if (!text || !text[0])
        return 0;
    if (strcmp(text, "1.125") == 0) { *out_num = 9; *out_den = 8; return 1; }
    if (strcmp(text, "1.10") == 0 || strcmp(text, "1.1") == 0) {
        *out_num = 11; *out_den = 10; return 1;
    }
    if (strcmp(text, "1.20") == 0 || strcmp(text, "1.2") == 0) {
        *out_num = 6; *out_den = 5; return 1;
    }
    if (!crash2_parse_uint(&p, &num))
        return 0;
    if (*p == '/' || *p == ':') {
        p++;
        if (!crash2_parse_uint(&p, &den) || *p != '\0' || den <= 0)
            return 0;
    } else if (*p == '.') {
        int64_t scale = 1;
        p++;
        if (!isdigit((unsigned char)*p))
            return 0;
        while (isdigit((unsigned char)*p)) {
            if (scale >= 1000000)
                return 0;
            num = num * 10 + (*p - '0');
            scale *= 10;
            p++;
        }
        if (*p != '\0')
            return 0;
        den = scale;
    } else if (*p == '\0') {
        den = 1;
    } else {
        return 0;
    }
    /* Keep horizontal FOV opening bounded to safe corridor limits [1.0, 1.25]. */
    if (num < den || num * 4 > den * 5)
        return 0;
    crash2_reduce_ratio(&num, &den);
    if (num > 9999 || den > 9999)
        return 0;
    *out_num = (int)num;
    *out_den = (int)den;
    return 1;
}

static void crash2_refresh_fov_option(void) {
    char buf[32] = "";
    int n = 9, d = 8;
    if (psx_mod_option_value(CRASH2_WS_PACKAGE_ID, CRASH2_WS_FEATURE_ID,
                             CRASH2_WS_OPTION_FOV, buf, (uint32_t)sizeof(buf)) &&
        crash2_parse_fov(buf, &n, &d)) {
        s_fov_num = n;
        s_fov_den = d;
    } else {
        s_fov_num = 9;
        s_fov_den = 8;
    }
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

static int crash2_widescreen_projection_aspect(int disp_num, int disp_den,
                                               int *proj_num, int *proj_den) {
    int fov_n = s_fov_num;
    int fov_d = s_fov_den;
    const char *env = getenv("CRASH2NATIVE_FOV");
    int64_t max_n, max_d, eff_n, eff_d;

    if (disp_num <= 0 || disp_den <= 0 || !proj_num || !proj_den)
        return 0;

    if (env && env[0])
        (void)crash2_parse_fov(env, &fov_n, &fov_d);

    /* Cropped 512x216 base has natural 40:27 aspect, so only disp/(40/27)
     * remains to reach disp_num:disp_den (6/5 = 1.20x at 16:9). Never open
     * GTE FOV past that ceiling, or X becomes narrower than vertical scale. */
    if (crash2_crop_disabled()) {
        max_n = (int64_t)disp_num * 3;
        max_d = (int64_t)disp_den * 4;
    } else {
        max_n = (int64_t)disp_num * 27;
        max_d = (int64_t)disp_den * 40;
    }
    if (max_n < max_d) {
        max_n = 1;
        max_d = 1;
    }
    if ((int64_t)fov_n * max_d > max_n * (int64_t)fov_d) {
        crash2_reduce_ratio(&max_n, &max_d);
        fov_n = (int)max_n;
        fov_d = (int)max_d;
    }

    /* gte_set_display_aspect(eff_num, eff_den) computes (4*eff_den)/(3*eff_num)
     * = 1 / fov when eff = (4/3) * fov. For fov = 9/8, eff = 3:2 (squash 8/9). */
    eff_n = (int64_t)4 * fov_n;
    eff_d = (int64_t)3 * fov_d;
    crash2_reduce_ratio(&eff_n, &eff_d);
    *proj_num = (int)eff_n;
    *proj_den = (int)eff_d;
    return 1;
}

static void crash2_widescreen_activate(void) {
    crash2_refresh_fov_option();
    (void)psx_mod_set_fixed_display_aspect(16u, 9u);
}

static int crash2_widescreen_option_changed(const char *option_id,
                                            const char *value) {
    (void)option_id;
    (void)value;
    crash2_refresh_fov_option();
    psx_ws_refresh_projection_live();
    return 1;
}

PSX_MOD_CONSTRUCTOR(crash2_register_widescreen) {
    gpu_set_present_crop_callback(crash2_present_crop);
    gpu_set_widescreen_projection_aspect_callback(
        crash2_widescreen_projection_aspect);
    (void)psx_mod_register_activation_plugin(
        CRASH2_WS_PLUGIN_ID, crash2_widescreen_activate);
    (void)psx_mod_register_option_changed_plugin(
        CRASH2_WS_PLUGIN_ID, crash2_widescreen_option_changed);
}
