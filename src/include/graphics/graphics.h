#ifndef GRAPHICS_GRAPHICS_H
#define GRAPHICS_GRAPHICS_H

#include <kernel.h>

#include <dmaKit.h>
#include <gsKit.h>

#include <gsInline.h>
#include <gsToolkit.h>

#include <math3d.h>

#include <packet2.h>
#include <packet2_utils.h>

/// GSKit CLUT base struct. This should've been in gsKit from the start :)
typedef struct {
  uint8_t PSM;       ///< Pixel Storage Method (Color Format)
  uint8_t ClutPSM;   ///< CLUT Pixel Storage Method (Color Format)
  uint32_t *Clut;    ///< EE CLUT Memory Pointer
  uint32_t VramClut; ///< GS VRAM CLUT Memory Pointer
} GSCLUT;

typedef struct {
  float x, y;
  float u, v;
} rm_tx_coord_t;

typedef struct {
  rm_tx_coord_t ul;
  rm_tx_coord_t br;
  uint64_t color;
  GSTEXTURE *txt;
} rm_quad_t;

typedef struct {
  texel_t *stqr;
  color_t *rgba;
  vertex_f_t *xyzw;
  VECTOR *test;
} vData;

struct model {
  uint32_t facesCount;
  uint16_t *idxList;
  VECTOR *positions;
  VECTOR *texcoords;
  VECTOR *normals;
  VECTOR *colours;
  VECTOR *bounding_box;
  GSTEXTURE *texture;
};

typedef uint32_t Color;
#define A(color) ((uint8_t)(color >> 24 & 0xFF))
#define B(color) ((uint8_t)(color >> 16 & 0xFF))
#define G(color) ((uint8_t)(color >> 8 & 0xFF))
#define R(color) ((uint8_t)(color & 0xFF))

void initGraphics();

GSTEXTURE *load_png_from_memory(const void *data, size_t size, bool delayed);

void clearScreen(Color color);

void flipScreen();

void graphicWaitVblankStart();

void setVSync(bool vsync_flag);

void gsKit_clear_screens();

GSGLOBAL *getGSGLOBAL();

int GetInterlacedFrameMode();

int getFreeVRAM();

float FPSCounter(int interval);

void setVideoMode(s16 mode, int width, int height, int psm, s16 interlace, s16 field, bool zbuffering, int psmz);

GSTEXTURE *load_image(const char *path, bool delayed);

void drawImage(GSTEXTURE *source, float x, float y, float width, float height, float startx, float starty, float endx, float endy, Color color);
void drawImageRotate(GSTEXTURE *source, float x, float y, float width, float height, float startx, float starty, float endx, float endy, float angle,
                     Color color);

void drawPixel(float x, float y, Color color);
void drawLine(float x, float y, float x2, float y2, Color color);
void drawRect(float x, float y, int width, int height, Color color);
void drawCircle(float x, float y, float radius, uint64_t color, uint8_t filled);
void drawTriangle(float x, float y, float x2, float y2, float x3, float y3, Color color);
void drawTriangle_gouraud(float x, float y, float x2, float y2, float x3, float y3, Color color, Color color2, Color color3);
void drawQuad(float x, float y, float x2, float y2, float x3, float y3, float x4, float y4, Color color);
void drawQuad_gouraud(float x, float y, float x2, float y2, float x3, float y3, float x4, float y4, Color color, Color color2, Color color3,
                      Color color4);

void InvalidateTexture(GSTEXTURE *txt);

void UnloadTexture(GSTEXTURE *txt);

void fntDrawQuad(rm_quad_t *q);

GSFONT *loadFont(const char *path);

void printFontText(GSFONT *font, const char *text, float x, float y, float scale, Color color);

void unloadFont(GSFONT *font);

void init3D(float aspect);

void setCameraPosition(float x, float y, float z);

void setCameraRotation(float x, float y, float z);

void setLightQuantity(int quantity);

void createLight(int lightid, float dir_x, float dir_y, float dir_z, int type, float r, float g, float b);

model *loadOBJ(const char *path, GSTEXTURE *text);

void drawOBJ(model *m, float pos_x, float pos_y, float pos_z, float rot_x, float rot_y, float rot_z);

void draw_bbox(model *m, float pos_x, float pos_y, float pos_z, float rot_x, float rot_y, float rot_z, Color color);

#endif
