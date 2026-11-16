/*
 * Estructuras y direcciones confirmadas de Crash Bandicoot 2 (SCUS-94154, main).
 *
 * Clean-room: derivado exclusivamente de análisis propio sobre SCUS_941.54 en
 * Ghidra y verificación dinámica en PCSX-Redux (experimentos 001..008).
 *
 * Convención: los punteros del invitado PS1 de 32 bits se declaran como
 * uint32_t (no void*) para conservar los desplazamientos exactos en memoria
 * cuando este encabezado se compile en un host de 64 bits.
 */
#ifndef CRASH2_RE_STRUCTS_H
#define CRASH2_RE_STRUCTS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* --- Direcciones confirmadas en RAM principal (re/symbols.csv) ---------- */

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
#define CRASH2_ADDR_CAM_SHAKE_Y             0x8006CB78u /* fijo >> 8 */
#define CRASH2_ADDR_LETTERBOX_LEVEL         0x8006CC94u
#define CRASH2_ADDR_CAM_UPDATE              0x80017BC4u
#define CRASH2_ADDR_CAM_MODE_DISPATCH       0x80026CA0u
#define CRASH2_ADDR_CAM_MATRIX_ASPECT_SCALE 0x80017AF8u /* -5/8 Y en camara */
#define CRASH2_ADDR_MODEL_VIEW_MATRIX_BUILD 0x8003D3CCu /* -5/8 Y en texto 3D */
#define CRASH2_ADDR_MATRIX_ASPECT_SCALE_LOC 0x80043090u /* -5/8 Y en HUD 2D */
#define CRASH2_ADDR_HUD_TRANSFORM_2D        0x80044558u
#define CRASH2_ADDR_DRAW_TEXT_3D            0x8001BD84u
#define CRASH2_ADDR_ZONE_GFX_MODE_APPLY     0x80020A24u
#define CRASH2_ADDR_ZONE_GFX_FLAGS          0x80062AD8u

#define CRASH2_ADDR_GOOL_PLAYER_SLOT        0x8006CB10u /* ptr al slot 0x33c B */
#define CRASH2_ADDR_GOOL_OBJECT_POOL        0x8006CB14u /* ptr a 96 x 0x23c B */
#define CRASH2_ADDR_GOOL_ROOT_BUCKETS       0x8006CB18u /* 8 x GoolBucket */
#define CRASH2_ADDR_GOOL_FREE_BUCKET        0x8006CB58u /* GoolBucket libre */
#define CRASH2_ADDR_GOOL_PLAYER_PTR         0x8005F38Cu /* ptr GoolObject Crash */
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

/* --- Tipos PsyQ / GTE básicos ------------------------------------------ */

/* Equivalente a MATRIX de libgte (32 bytes = 0x20). Verificado en 006. */
typedef struct PsxMatrix {
    int16_t m[3][3];                    /* +0x00: matriz 3x3 (4.12 fijo) */
    int16_t _pad12;                     /* +0x12 */
    int32_t t[3];                       /* +0x14: traslación */
} PsxMatrix;

/* Equivalente a DISPENV de libgpu (20 bytes = 0x14). Verificado en 007. */
typedef struct PsxDispEnv {
    int16_t disp[4];                    /* +0x00: x, y, w=512, h=240 */
    int16_t screen[4];                  /* +0x08: x, y, w, h */
    uint8_t isinter;                    /* +0x10 */
    uint8_t isrgb24;                    /* +0x11 */
    uint8_t pad[2];                     /* +0x12 */
} PsxDispEnv;

/* Equivalente a DRAWENV de libgpu (92 bytes = 0x5c). Verificado en 007. */
typedef struct PsxDrawEnv {
    int16_t clip[4];                    /* +0x00: x, y=12, w=512, h=216 */
    int16_t ofs[2];                     /* +0x08: x, y=12 */
    int16_t tw[4];                      /* +0x0c: texture window */
    uint8_t _rest14[0x48];              /* +0x14..+0x5b: tpage/dtd/dfe/isbg/dr_env */
} PsxDrawEnv;

/* --- Estructuras del motor de Crash 2 ---------------------------------- */

/* Bloque contiguo de matrices/pose de cámara en 0x80060754..0x80060817. */
typedef struct CameraTransformBlock {
    PsxMatrix cam_rot_matrix;           /* 0x80060754 (+0x00): verificado 006 */
    PsxMatrix cam_view_matrix;          /* 0x80060774 (+0x20): fila Y -5/8, verificado 006 */
    PsxMatrix cam_view_matrix_copy;     /* 0x80060794 (+0x40): estático */
    PsxMatrix cam_alt_matrix_a;         /* 0x800607b4 (+0x60): estático (espejo) */
    PsxMatrix cam_alt_matrix_b;         /* 0x800607d4 (+0x80): estático (draw_text_3d) */
    int32_t   pos[3];                   /* 0x800607f4 (+0xa0): fijo >> 8 para GTE, verificado 006 */
    int32_t   rot[3];                   /* 0x80060800 (+0xac): 4096 = 360°, verificado 006 */
    int32_t   scale[3];                 /* 0x8006080c (+0xb8): estático (0x1000 = 1.0) */
} CameraTransformBlock;

/* Contexto gráfico y de cuadro (0x2094 bytes); pool de 2 en 0x8006345c. */
typedef struct DisplayContext {
    int32_t    id;                      /* +0x00: 0 o 1 (verificado 007) */
    uint32_t   ot_or_buf_base;          /* +0x04: estático */
    uint32_t   prim_ptr;                /* +0x08: estático */
    uint32_t   raw_ticks;               /* +0x0c: ticks RCnt2 (verificado 005/007) */
    uint32_t   draw_end_ticks;          /* +0x10: verificado 007 */
    int32_t    quant_ticks;             /* +0x14: dt cuantizado 0x11/0x22/0x33 (verificado 005/007) */
    uint32_t   ot[2048];                /* +0x18..+0x2017: ordering table */
    PsxDispEnv disp_env;                /* +0x2018: 512x240 (verificado 007) */
    PsxDrawEnv draw_env;                /* +0x202c: 512x216 y=12 (verificado 007) */
    uint32_t   render_queue_head;       /* +0x2088: cabeza cola render (verificado 007) */
    uint32_t   render_arena_base;       /* +0x208c: base arena frame (verificado 007) */
    uint32_t   render_arena_cur;        /* +0x2090: cursor arena frame (verificado 007) */
} DisplayContext;

/* Estado de mando procesado (0x4c bytes): Pad 1 en 0x80069920, Pad 2 en 0x8006996c. */
typedef struct PadState {
    uint8_t  raw[0x22];                 /* +0x00: +0x00 raw_stat, +0x01 pad_type (verificado 007/008) */
    uint16_t _pad22;                    /* +0x22 */
    uint32_t buttons_pressed;           /* +0x24: held & ~prev1 & 0xffff (verificado 008 Lua) */
    uint32_t buttons_held;              /* +0x28: activo-alto (verificado 008 Lua) */
    uint32_t buttons_prev1;             /* +0x2c: cuadro previo (verificado 008 Lua) */
    uint32_t buttons_pressed_prev;      /* +0x30: estático (pad_update) */
    uint32_t buttons_prev2;             /* +0x34: estático (pad_update) */
    int32_t  stick_angle;               /* +0x38: 0..4095 (verificado 008 Lua) */
    int32_t  stick_mag;                 /* +0x3c: <0x66 -> 0 (verificado 008 Lua) */
    int32_t  dir_index;                 /* +0x40: 0..7, 8=neutro (verificado 008 Lua) */
    uint32_t _unk44;                    /* +0x44 */
    uint32_t _unk48;                    /* +0x48 */
} PadState;

/* Cubeta cabecera de listas GOOL (8 bytes): 8 raíces en 0x8006cb18 + libre en 0x8006cb58. */
typedef struct GoolBucket {
    int32_t  type;                      /* +0x00: 2 para cubeta (verificado 007) */
    uint32_t first_child;               /* +0x04: ptr PS1 al primer GoolObject */
} GoolBucket;

/*
 * Objeto/entidad GOOL (0x23c bytes en gool_object_pool; jugador 0x33c bytes en
 * gool_player_slot compartiendo este prefijo de 0x23c bytes).
 *
 * REGLA OBLIGATORIA Fase 6 (verificada en 007):
 *   FUN_80019e08 devuelve objetos liberados a gool_free_bucket (0x8006cb58)
 *   SIN limpiar node_kind (+0x04 == 3). Para interpolar entidades activas hay
 *   que recorrer las 8 cubetas raíz (0x8006cb18..0x8006cb57) por first_child /
 *   next_sibling, NUNCA barrer gool_object_pool buscando node_kind == 3.
 */
typedef struct GoolObject {
    int32_t  handle;                    /* +0x00: 0 libre, 1 objeto, 2 cubeta (verificado 007) */
    int32_t  node_kind;                 /* +0x04: 3 activo (no se limpia al liberar! verificado 007) */
    uint32_t meta_ptr;                  /* +0x08: ptr PS1 subestructura metadatos (verificado 007) */
    uint32_t gool_entry;                /* +0x0c: ptr PS1 entrada tipo 11 (verificado 007) */
    uint8_t  _unk10[0x08];              /* +0x10..+0x17 */
    uint32_t zone_entry;                /* +0x18: ptr PS1 entrada ZDAT (verificado 007) */
    uint8_t  _unk1c[0x24];              /* +0x1c..+0x3f (+0x20..+0x3f color/tinte estático) */
    uint32_t self;                      /* +0x40: ptr PS1 (verificado 007) */
    uint32_t parent;                    /* +0x44: ptr PS1 (verificado 007) */
    uint32_t next_sibling;              /* +0x48: ptr PS1 (verificado 007) */
    uint32_t first_child;               /* +0x4c: ptr PS1 (verificado 007) */
    uint8_t  _unk50[0x08];              /* +0x50..+0x57 */
    uint32_t rider;                     /* +0x58: ptr PS1 (verificado 007) */
    uint32_t _unk5c;                    /* +0x5c */
    int32_t  pos[3];                    /* +0x60..+0x68: fijo << 8 (verificado 007/008) */
    int32_t  rot[3];                    /* +0x6c..+0x74: 4096 = vuelta (verificado 007) */
    int32_t  scale[3];                  /* +0x78..+0x80: 0x1000 = 1.0 (verificado 007) */
    int32_t  vel[3];                    /* +0x84..+0x8c: velocidad (verificado 007) */
    int32_t  target_rot[3];             /* +0x90..+0x98: estático */
    uint8_t  _unk9c[0x0c];              /* +0x9c..+0xa7 */
    uint32_t status_flags_a;            /* +0xa8: estático */
    uint32_t status_flags_b;            /* +0xac: estático */
    uint8_t  _unkb0[0x08];              /* +0xb0..+0xb7 */
    int32_t  entity_id;                 /* +0xb8: verificado 007 */
    uint32_t gool_sp;                   /* +0xbc: ptr PS1 pila GOOL (estático) */
    uint32_t gool_pc;                   /* +0xc0: ptr PS1 cursor GOOL $s5 (estático) */
    uint32_t _unkc4;                    /* +0xc4 */
    uint32_t pending_pc;                /* +0xc8: ptr PS1 (estático) */
    uint8_t  _unkcc[0x1c];              /* +0xcc..+0xe7 */
    uint32_t anim_seq;                  /* +0xe8: ptr PS1 (*anim_seq: 1 SVTX, 2 sprite, 4 texto3D, 5 frag; verificado 007) */
    int32_t  anim_frame;                /* +0xec: fijo << 8 (verificado 007) */
    uint8_t  _unkf0[0x28];              /* +0xf0..+0x117 (+0xf0 subentry, +0xfc floor_y estático) */
    int32_t  ot_depth_bias;             /* +0x118: estático */
    uint32_t _unk11c;                   /* +0x11c */
    uint8_t  render_mode;               /* +0x120: verificado 008 (rmode=6 en Pausa) */
    uint8_t  draw_type;                 /* +0x121: estático */
    uint8_t  light_mode;                /* +0x122: estático */
    uint8_t  _unk123[0x119];            /* +0x123..+0x23b */
} GoolObject;

#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
_Static_assert(sizeof(PsxMatrix) == 0x20, "PsxMatrix debe medir 0x20 bytes");
_Static_assert(sizeof(PsxDispEnv) == 0x14, "PsxDispEnv debe medir 0x14 bytes");
_Static_assert(sizeof(PsxDrawEnv) == 0x5C, "PsxDrawEnv debe medir 0x5C bytes");
_Static_assert(sizeof(CameraTransformBlock) == 0xC4, "CameraTransformBlock debe medir 0xC4 bytes");
_Static_assert(offsetof(CameraTransformBlock, pos) == 0xA0, "pos debe estar en 0x800607f4");
_Static_assert(offsetof(CameraTransformBlock, rot) == 0xAC, "rot debe estar en 0x80060800");
_Static_assert(sizeof(DisplayContext) == 0x2094, "DisplayContext debe medir 0x2094 bytes");
_Static_assert(offsetof(DisplayContext, quant_ticks) == 0x14, "quant_ticks debe estar en +0x14");
_Static_assert(offsetof(DisplayContext, disp_env) == 0x2018, "disp_env debe estar en +0x2018");
_Static_assert(offsetof(DisplayContext, draw_env) == 0x202C, "draw_env debe estar en +0x202C");
_Static_assert(offsetof(DisplayContext, render_queue_head) == 0x2088, "render_queue_head debe estar en +0x2088");
_Static_assert(sizeof(PadState) == 0x4C, "PadState debe medir 0x4C bytes");
_Static_assert(offsetof(PadState, buttons_pressed) == 0x24, "buttons_pressed debe estar en +0x24");
_Static_assert(offsetof(PadState, dir_index) == 0x40, "dir_index debe estar en +0x40");
_Static_assert(sizeof(GoolBucket) == 0x08, "GoolBucket debe medir 0x08 bytes");
_Static_assert(sizeof(GoolObject) == 0x23C, "GoolObject debe medir 0x23C bytes");
_Static_assert(offsetof(GoolObject, pos) == 0x60, "GoolObject.pos debe estar en +0x60");
_Static_assert(offsetof(GoolObject, rot) == 0x6C, "GoolObject.rot debe estar en +0x6C");
_Static_assert(offsetof(GoolObject, scale) == 0x78, "GoolObject.scale debe estar en +0x78");
_Static_assert(offsetof(GoolObject, vel) == 0x84, "GoolObject.vel debe estar en +0x84");
_Static_assert(offsetof(GoolObject, anim_seq) == 0xE8, "GoolObject.anim_seq debe estar en +0xE8");
_Static_assert(offsetof(GoolObject, anim_frame) == 0xEC, "GoolObject.anim_frame debe estar en +0xEC");
_Static_assert(offsetof(GoolObject, render_mode) == 0x120, "GoolObject.render_mode debe estar en +0x120");
#endif

#ifdef __cplusplus
}
#endif

#endif /* CRASH2_RE_STRUCTS_H */
