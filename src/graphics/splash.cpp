#include "graphics/graphics.h"

extern unsigned char title_png[];
extern unsigned int size_title_png;
extern unsigned char loading_png[];
extern unsigned int size_loading_png;

static const uint64_t SPLASH_BG_RGBAQ = GS_SETREG_RGBAQ(0x14, 0x14, 0x14, 0x80, 0x00);

// Implemented in graphics.cpp
void showSplashScreen(void) {
  if (!getGSGLOBAL())
    return;

  clearScreen(SPLASH_BG_RGBAQ);
  const int w = getGSGLOBAL()->Width;
  const int h = getGSGLOBAL()->Height;

  GSTEXTURE *tex_title = load_png_from_memory(title_png, size_title_png, true);
  GSTEXTURE *tex_loading = load_png_from_memory(loading_png, size_loading_png, true);

  if (tex_title) {
    float tw = (float)tex_title->Width;
    float th = (float)tex_title->Height;
    float cx = (float)w * 0.5f;
    float cy = (float)h * 0.5f - 30.0f;
    drawImage(tex_title, cx - tw / 2, cy - th / 2, tw, th, 0.0f, 0.0f, tw, th, GS_SETREG_RGBA(0xFF, 0xFF, 0xFF, 0x80));
  }
  if (tex_loading) {
    float src_w = (float)tex_loading->Width;
    float src_h = (float)tex_loading->Height;
    float lw = src_w * 0.5f;
    float lh = src_h * 0.5f;
    float cx = (float)w * 0.5f;
    float cy = (float)(h - 100);
    drawImage(tex_loading, cx - lw / 2, cy - lh / 2, lw, lh, 0.0f, 0.0f, src_w, src_h,
              GS_SETREG_RGBA(0xFF, 0xFF, 0xFF, 0x80));
  }

  flipScreen();

  if (tex_title)
    UnloadTexture(tex_title);
  if (tex_loading)
    UnloadTexture(tex_loading);
}
