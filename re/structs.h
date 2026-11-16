/*
 * Confirmed structures and addresses for Crash Bandicoot 2 (SCUS-94154, main).
 *
 * Clean-room: derived exclusively from original analysis of SCUS_941.54 in
 * Ghidra and dynamic verification in PCSX-Redux (experiments 001..008).
 *
 * Convention: 32-bit PS1 guest pointers are declared as uint32_t (not void*)
 * to preserve exact memory layouts when this header is compiled on a 64-bit
 * host.
 */
#ifndef CRASH2_RE_STRUCTS_H
#define CRASH2_RE_STRUCTS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* --- Confirmed addresses in main RAM (re/symbols.csv) -------------------- */

#define CRASH2_ADDR_RCNT2_TICK_ISR          0x8003BE88u
#define CRASH2_ADDR_RCNT2_TICK_COUNT        0x8003BEA4u
#define CRASH2_ADDR_FRAME_END_SYNC          0x8001645Cu
#define CRASH2_ADDR_QUANTIZE_FRAME_TICKS    0x80016F04u
#define CRASH2_ADDR_FRAME_COUNTER           0x8006CCF0u

#define CRASH2_ADDR_DISC_FILE_TABLE         0x80069034u
#define CRASH2_ADDR_NSD_PAGING_STATE        0x80067588u
#define CRASH2_ADDR_CURRENT_LEVEL_ID        0x8005F3ECu
#define CRASH2_ADDR_NEXT_LEVEL_ID           0x8005F3F0u
#define CRASH2_ADDR_LEVEL_FLAGS             0x8006CB94u

#define CRASH2_ADDR_GOOL_INTERPRET          0x8003A014u
#define CRASH2_ADDR_GOOL_OP49_EXEC_MIPS     0x8003AAD4u
#define CRASH2_ADDR_GOOL_OPCODE_TABLE       0x8005C514u

#define CRASH2_ADDR_DISPLAY_CTX_POOL        0x8006345Cu /* 2 x DisplayContext */
#define CRASH2_ADDR_DISP_CTX_FRONT          0x80063450u
#define CRASH2_ADDR_DISP_CTX_DRAW           0x80063454u
#define CRASH2_ADDR_DISP_CTX_WORK           0x80063458u
#define CRASH2_ADDR_DRAW_LETTERBOX_AND_FOV  0x80016C58u
#define CRASH2_ADDR_DRAW_BG_TILE            0x80016A60u

#define CRASH2_ADDR_CAM_ROT_MATRIX          0x80060754u /* PsxMatrix */
#define CRASH2_ADDR_CAM_VIEW_MATRIX         0x80060774u /* PsxMatrix (-5/8 Y) */
#define CRASH2_ADDR_CAM_POS                 0x800607F4u /* int32_t[3] */
#define CRASH2_ADDR_CAM_ROT                 0x80060800u /* int32_t[3] */
#define CRASH2_ADDR_GEOM_SCREEN             0x80060884u /* int32_t (H, nom. 288) */
#define CRASH2_ADDR_CURRENT_ZONE_ENTRY      0x800608CCu /* ptr ZDAT */
#define CRASH2_ADDR_CURRENT_CAM_PATH        0x800608D4u
#define CRASH2_ADDR_CAM_PATH_PROGRESS       0x800608E0u
#define CRASH2_ADDR_CAM_SUBMODE             0x800608F0u
#define CRASH2_ADDR_CAM_TRANS_STATE         0x8005B994u
#define CRASH2_ADDR_GEOM_OFFSET_X           0x8006CC20u /* +0x100 */
#define CRASH2_ADDR_GEOM_OFFSET_Y           0x8006CC24u /* +0x6c + shake */
#define CRASH2_ADDR_CAM_SHAKE_Y             0x8006CB78u /* fixed >> 8 */
#define CRASH2_ADDR_LETTERBOX_LEVEL         0x8006CC94u
#define CRASH2_ADDR_CAM_UPDATE              0x80017BC4u
#define CRASH2_ADDR_CAM_MODE_DISPATCH       0x80026CA0u
#define CRASH2_ADDR_CAM_MATRIX_ASPECT_SCALE 0x80017AF8u /* -5/8 Y in camera */
#define CRASH2_ADDR_MODEL_VIEW_MATRIX_BUILD 0x8003D3CCu /* -5/8 Y in 3D text */
#define CRASH2_ADDR_MATRIX_ASPECT_SCALE_LOC 0x80043090u /* -5/8 Y in 2D HUD */
#define CRASH2_ADDR_HUD_TRANSFORM_2D        0x80044558u
#define CRASH2_ADDR_DRAW_TEXT_3D            0x8001BD84u
#define CRASH2_ADDR_ZONE_GFX_MODE_APPLY     0x80020A24u
#define CRASH2_ADDR_ZONE_GFX_FLAGS          0x80062AD8u

#define CRASH2_ADDR_GOOL_PLAYER_SLOT        0x8006CB10u /* ptr to 0x33c B slot */
#define CRASH2_ADDR_GOOL_OBJECT_POOL        0x8006CB14u /* ptr to 96 x 0x23c B */
#define CRASH2_ADDR_GOOL_ROOT_BUCKETS       0x8006CB18u /* 8 x GoolBucket */
#define CRASH2_ADDR_GOOL_FREE_BUCKET        0x8006CB58u /* free GoolBucket */
#define CRASH2_ADDR_GOOL_PLAYER_PTR         0x8005F38Cu /* ptr Crash GoolObject */
#define CRASH2_ADDR_PLAYER_POS_COPY         0x8005F494u /* int32_t[3] */
#define CRASH2_ADDR_GOOL_OBJECT_TICK        0x8001C718u
#define CRASH2_ADDR_GOOL_PHYSICS_STEP       0x8001D63Cu
#define CRASH2_ADDR_RENDER_QUEUE_FLUSH      0x8003DB94u
#define CRASH2_ADDR_CTRL_SCALE              0x8006CBB4u

#define CRASH2_ADDR_RNG_B_SEED              0x8005F224u
#define CRASH2_ADDR_PAD_STATES              0x80069920u /* 2 x PadState */
#define CRASH2_ADDR_PAD_COUNT               0x8006991Cu
#define CRASH2_ADDR_DEMO_MODE               0x8006CD14u

#define CRASH2_GOOL_POOL_SLOTS              96u
#define CRASH2_GOOL_ROOT_BUCKET_COUNT       8u
#define CRASH2_DISPLAY_CTX_COUNT            2u
#define CRASH2_PAD_COUNT                    2u

/* --- Basic PsyQ / GTE types ---------------------------------------------- */

/* Equivalent to libgte MATRIX (32 bytes = 0x20). Verified in 006. */
typedef struct PsxMatrix {
    int16_t m[3][3];                    /* +0x00: 3x3 matrix (4.12 fixed) */
    int16_t _pad12;                     /* +0x12 */
    int32_t t[3];                       /* +0x14: translation */
} PsxMatrix;

/* Equivalent to libgpu DISPENV (20 bytes = 0x14). Verified in 007. */
typedef struct PsxDispEnv {
    int16_t disp[4];                    /* +0x00: x, y, w=512, h=240 */
    int16_t screen[4];                  /* +0x08: x, y, w, h */
    uint8_t isinter;                    /* +0x10 */
    uint8_t isrgb24;                    /* +0x11 */
    uint8_t pad[2];                     /* +0x12 */
} PsxDispEnv;

/* Equivalent to libgpu DRAWENV (92 bytes = 0x5c). Verified in 007. */
typedef struct PsxDrawEnv {
    int16_t clip[4];                    /* +0x00: x, y=12, w=512, h=216 */
    int16_t ofs[2];                     /* +0x08: x, y=12 */
    int16_t tw[4];                      /* +0x0c: texture window */
    uint8_t _rest14[0x48];              /* +0x14..+0x5b: tpage/dtd/dfe/isbg/dr_env */
} PsxDrawEnv;

/* --- Crash 2 engine structures ------------------------------------------- */

/* Contiguous camera matrix/pose block at 0x80060754..0x80060817. */
typedef struct CameraTransformBlock {
    PsxMatrix cam_rot_matrix;           /* 0x80060754 (+0x00): verified 006 */
    PsxMatrix cam_view_matrix;          /* 0x80060774 (+0x20): Y row -5/8, verified 006 */
    PsxMatrix cam_view_matrix_copy;     /* 0x80060794 (+0x40): static */
    PsxMatrix cam_alt_matrix_a;         /* 0x800607b4 (+0x60): static (mirror) */
    PsxMatrix cam_alt_matrix_b;         /* 0x800607d4 (+0x80): static (draw_text_3d) */
    int32_t   pos[3];                   /* 0x800607f4 (+0xa0): fixed >> 8 for GTE, verified 006 */
    int32_t   rot[3];                   /* 0x80060800 (+0xac): 4096 = 360 deg, verified 006 */
    int32_t   scale[3];                 /* 0x8006080c (+0xb8): static (0x1000 = 1.0) */
} CameraTransformBlock;

/* Graphics and frame context (0x2094 bytes); pool of 2 at 0x8006345c. */
typedef struct DisplayContext {
    int32_t    id;                      /* +0x00: 0 or 1 (verified 007) */
    uint32_t   ot_or_buf_base;          /* +0x04: static */
    uint32_t   prim_ptr;                /* +0x08: static */
    uint32_t   raw_ticks;               /* +0x0c: RCnt2 ticks (verified 005/007) */
    uint32_t   draw_end_ticks;          /* +0x10: verified 007 */
    int32_t    quant_ticks;             /* +0x14: quantized dt 0x11/0x22/0x33 (verified 005/007) */
    uint32_t   ot[2048];                /* +0x18..+0x2017: ordering table */
    PsxDispEnv disp_env;                /* +0x2018: 512x240 (verified 007) */
    PsxDrawEnv draw_env;                /* +0x202c: 512x216 y=12 (verified 007) */
    uint32_t   render_queue_head;       /* +0x2088: render queue head (verified 007) */
    uint32_t   render_arena_base;       /* +0x208c: frame arena base (verified 007) */
    uint32_t   render_arena_cur;        /* +0x2090: frame arena cursor (verified 007) */
} DisplayContext;

/* Processed controller state (0x4c bytes): Pad 1 at 0x80069920, Pad 2 at 0x8006996c. */
typedef struct PadState {
    uint8_t  raw[0x22];                 /* +0x00: +0x00 raw_stat, +0x01 pad_type (verified 007/008) */
    uint16_t _pad22;                    /* +0x22 */
    uint32_t buttons_pressed;           /* +0x24: held & ~prev1 & 0xffff (verified 008 Lua) */
    uint32_t buttons_held;              /* +0x28: active-high (verified 008 Lua) */
    uint32_t buttons_prev1;             /* +0x2c: previous frame (verified 008 Lua) */
    uint32_t buttons_pressed_prev;      /* +0x30: static (pad_update) */
    uint32_t buttons_prev2;             /* +0x34: static (pad_update) */
    int32_t  stick_angle;               /* +0x38: 0..4095 (verified 008 Lua) */
    int32_t  stick_mag;                 /* +0x3c: <0x66 -> 0 (verified 008 Lua) */
    int32_t  dir_index;                 /* +0x40: 0..7, 8=neutral (verified 008 Lua) */
    uint32_t _unk44;                    /* +0x44 */
    uint32_t _unk48;                    /* +0x48 */
} PadState;

/* Header bucket for GOOL lists (8 bytes): 8 roots at 0x8006cb18 + free at 0x8006cb58. */
typedef struct GoolBucket {
    int32_t  type;                      /* +0x00: 2 for bucket (verified 007) */
    uint32_t first_child;               /* +0x04: PS1 ptr to first GoolObject */
} GoolBucket;

/*
 * GOOL object/entity (0x23c bytes in gool_object_pool; player 0x33c bytes in
 * gool_player_slot sharing this 0x23c-byte prefix).
 *
 * MANDATORY RULE Phase 6 (verified in 007):
 *   FUN_80019e08 returns freed objects to gool_free_bucket (0x8006cb58)
 *   WITHOUT clearing node_kind (+0x04 == 3). To interpolate active entities,
 *   walk the 8 root buckets (0x8006cb18..0x8006cb57) via first_child /
 *   next_sibling; NEVER scan gool_object_pool looking for node_kind == 3.
 */
typedef struct GoolObject {
    int32_t  handle;                    /* +0x00: 0 free, 1 object, 2 bucket (verified 007) */
    int32_t  node_kind;                 /* +0x04: 3 active (not cleared on free! verified 007) */
    uint32_t meta_ptr;                  /* +0x08: PS1 ptr metadata sub-struct (verified 007) */
    uint32_t gool_entry;                /* +0x0c: PS1 ptr type-11 entry (verified 007) */
    uint8_t  _unk10[0x08];              /* +0x10..+0x17 */
    uint32_t zone_entry;                /* +0x18: PS1 ptr ZDAT entry (verified 007) */
    uint8_t  _unk1c[0x24];              /* +0x1c..+0x3f (+0x20..+0x3f static color/tint) */
    uint32_t self;                      /* +0x40: PS1 ptr (verified 007) */
    uint32_t parent;                    /* +0x44: PS1 ptr (verified 007) */
    uint32_t next_sibling;              /* +0x48: PS1 ptr (verified 007) */
    uint32_t first_child;               /* +0x4c: PS1 ptr (verified 007) */
    uint8_t  _unk50[0x08];              /* +0x50..+0x57 */
    uint32_t rider;                     /* +0x58: PS1 ptr (verified 007) */
    uint32_t _unk5c;                    /* +0x5c */
    int32_t  pos[3];                    /* +0x60..+0x68: fixed << 8 (verified 007/008) */
    int32_t  rot[3];                    /* +0x6c..+0x74: 4096 = full turn (verified 007) */
    int32_t  scale[3];                  /* +0x78..+0x80: 0x1000 = 1.0 (verified 007) */
    int32_t  vel[3];                    /* +0x84..+0x8c: velocity (verified 007) */
    int32_t  target_rot[3];             /* +0x90..+0x98: static */
    uint8_t  _unk9c[0x0c];              /* +0x9c..+0xa7 */
    uint32_t status_flags_a;            /* +0xa8: static */
    uint32_t status_flags_b;            /* +0xac: static */
    uint8_t  _unkb0[0x08];              /* +0xb0..+0xb7 */
    int32_t  entity_id;                 /* +0xb8: verified 007 */
    uint32_t gool_sp;                   /* +0xbc: PS1 ptr GOOL stack (static) */
    uint32_t gool_pc;                   /* +0xc0: PS1 ptr GOOL cursor $s5 (static) */
    uint32_t _unkc4;                    /* +0xc4 */
    uint32_t pending_pc;                /* +0xc8: PS1 ptr (static) */
    uint8_t  _unkcc[0x1c];              /* +0xcc..+0xe7 */
    uint32_t anim_seq;                  /* +0xe8: PS1 ptr (*anim_seq: 1 SVTX, 2 sprite, 4 3D text, 5 frag; verified 007) */
    int32_t  anim_frame;                /* +0xec: fixed << 8 (verified 007) */
    uint8_t  _unkf0[0x28];              /* +0xf0..+0x117 (+0xf0 subentry, +0xfc static floor_y) */
    int32_t  ot_depth_bias;             /* +0x118: static */
    uint32_t _unk11c;                   /* +0x11c */
    uint8_t  render_mode;               /* +0x120: verified 008 (rmode=6 in Pause) */
    uint8_t  draw_type;                 /* +0x121: static */
    uint8_t  light_mode;                /* +0x122: static */
    uint8_t  _unk123[0x119];            /* +0x123..+0x23b */
} GoolObject;

#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
_Static_assert(sizeof(PsxMatrix) == 0x20, "PsxMatrix must be 0x20 bytes");
_Static_assert(sizeof(PsxDispEnv) == 0x14, "PsxDispEnv must be 0x14 bytes");
_Static_assert(sizeof(PsxDrawEnv) == 0x5C, "PsxDrawEnv must be 0x5C bytes");
_Static_assert(sizeof(CameraTransformBlock) == 0xC4, "CameraTransformBlock must be 0xC4 bytes");
_Static_assert(offsetof(CameraTransformBlock, pos) == 0xA0, "pos must be at 0x800607f4");
_Static_assert(offsetof(CameraTransformBlock, rot) == 0xAC, "rot must be at 0x80060800");
_Static_assert(sizeof(DisplayContext) == 0x2094, "DisplayContext must be 0x2094 bytes");
_Static_assert(offsetof(DisplayContext, quant_ticks) == 0x14, "quant_ticks must be at +0x14");
_Static_assert(offsetof(DisplayContext, disp_env) == 0x2018, "disp_env must be at +0x2018");
_Static_assert(offsetof(DisplayContext, draw_env) == 0x202C, "draw_env must be at +0x202C");
_Static_assert(offsetof(DisplayContext, render_queue_head) == 0x2088, "render_queue_head must be at +0x2088");
_Static_assert(sizeof(PadState) == 0x4C, "PadState must be 0x4C bytes");
_Static_assert(offsetof(PadState, buttons_pressed) == 0x24, "buttons_pressed must be at +0x24");
_Static_assert(offsetof(PadState, dir_index) == 0x40, "dir_index must be at +0x40");
_Static_assert(sizeof(GoolBucket) == 0x08, "GoolBucket must be 0x08 bytes");
_Static_assert(sizeof(GoolObject) == 0x23C, "GoolObject must be 0x23C bytes");
_Static_assert(offsetof(GoolObject, pos) == 0x60, "GoolObject.pos must be at +0x60");
_Static_assert(offsetof(GoolObject, rot) == 0x6C, "GoolObject.rot must be at +0x6C");
_Static_assert(offsetof(GoolObject, scale) == 0x78, "GoolObject.scale must be at +0x78");
_Static_assert(offsetof(GoolObject, vel) == 0x84, "GoolObject.vel must be at +0x84");
_Static_assert(offsetof(GoolObject, anim_seq) == 0xE8, "GoolObject.anim_seq must be at +0xE8");
_Static_assert(offsetof(GoolObject, anim_frame) == 0xEC, "GoolObject.anim_frame must be at +0xEC");
_Static_assert(offsetof(GoolObject, render_mode) == 0x120, "GoolObject.render_mode must be at +0x120");
#endif

#ifdef __cplusplus
}
#endif

#endif /* CRASH2_RE_STRUCTS_H */
