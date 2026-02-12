#include "graphics/graphics.h"
#include "devices/vfs.h"
#include <fcntl.h>
#include <malloc.h>
#include <math.h>
#include <png.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define DEG2RAD(x) ((x) * 0.01745329251)

static const uint64_t BLACK_RGBAQ = GS_SETREG_RGBAQ(0x00, 0x00, 0x00, 0x80, 0x00);
static const uint64_t TEXTURE_RGBAQ = GS_SETREG_RGBAQ(0x80, 0x80, 0x80, 0x80, 0x00);

GSGLOBAL *gsGlobal = NULL;
GSFONTM *gsFontM = NULL;

static bool vsync = true;
static int vsync_sema_id = 0;
static clock_t curtime = 0;
static float fps = 0.0f;

static int frames = 0;
static int frame_interval = -1;

// 2D drawing functions
GSTEXTURE *loadpng(FILE *File, bool delayed) {
  GSTEXTURE *tex = (GSTEXTURE *)malloc(sizeof(GSTEXTURE));
  tex->Delayed = delayed;

  if (File == NULL) {
    printf("graphics: png: failed to load PNG file\n");
    return NULL;
  }

  png_structp png_ptr;
  png_infop info_ptr;
  png_uint_32 width, height;
  png_bytep *row_pointers;

  uint32_t sig_read = 0;
  int row, i, k = 0, j, bit_depth, color_type, interlace_type;

  png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, (png_voidp)NULL, NULL, NULL);

  if (!png_ptr) {
    printf("graphics: png: read struct init failed\n");
    fclose(File);
    return NULL;
  }

  info_ptr = png_create_info_struct(png_ptr);

  if (!info_ptr) {
    printf("graphics: png: info struct init failed\n");
    fclose(File);
    png_destroy_read_struct(&png_ptr, (png_infopp)NULL, (png_infopp)NULL);
    return NULL;
  }

  if (setjmp(png_jmpbuf(png_ptr))) {
    printf("graphics: png: got PNG error!\n");
    png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
    fclose(File);
    return NULL;
  }

  png_init_io(png_ptr, File);

  png_set_sig_bytes(png_ptr, sig_read);

  png_read_info(png_ptr, info_ptr);

  png_get_IHDR(png_ptr, info_ptr, &width, &height, &bit_depth, &color_type, &interlace_type, NULL, NULL);

  if (bit_depth == 16)
    png_set_strip_16(png_ptr);
  if (color_type == PNG_COLOR_TYPE_GRAY || bit_depth < 4)
    png_set_expand(png_ptr);
  if (png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS))
    png_set_tRNS_to_alpha(png_ptr);

  png_set_filler(png_ptr, 0xff, PNG_FILLER_AFTER);

  png_read_update_info(png_ptr, info_ptr);

  tex->Width = width;
  tex->Height = height;

  tex->VramClut = 0;
  tex->Clut = NULL;
  tex->ClutStorageMode = GS_CLUT_STORAGE_CSM1;

  if (png_get_color_type(png_ptr, info_ptr) == PNG_COLOR_TYPE_RGB_ALPHA) {
    int row_bytes = png_get_rowbytes(png_ptr, info_ptr);
    tex->PSM = GS_PSM_CT32;
    tex->Mem = (u32 *)memalign(128, gsKit_texture_size_ee(tex->Width, tex->Height, tex->PSM));

    row_pointers = (png_byte **)calloc(height, sizeof(png_bytep));

    for (row = 0; row < height; row++)
      row_pointers[row] = (png_bytep)malloc(row_bytes);

    png_read_image(png_ptr, row_pointers);

    struct pixel {
      uint8_t r, g, b, a;
    };
    struct pixel *Pixels = (struct pixel *)tex->Mem;

    for (i = 0; i < tex->Height; i++) {
      for (j = 0; j < tex->Width; j++) {
        memcpy(&Pixels[k], &row_pointers[i][4 * j], 3);
        Pixels[k++].a = row_pointers[i][4 * j + 3] >> 1;
      }
    }

    for (row = 0; row < height; row++)
      free(row_pointers[row]);

    free(row_pointers);
  } else if (png_get_color_type(png_ptr, info_ptr) == PNG_COLOR_TYPE_RGB) {
    int row_bytes = png_get_rowbytes(png_ptr, info_ptr);
    tex->PSM = GS_PSM_CT24;
    tex->Mem = (u32 *)memalign(128, gsKit_texture_size_ee(tex->Width, tex->Height, tex->PSM));

    row_pointers = (png_byte **)calloc(height, sizeof(png_bytep));

    for (row = 0; row < height; row++)
      row_pointers[row] = (png_bytep)malloc(row_bytes);

    png_read_image(png_ptr, row_pointers);

    struct pixel3 {
      uint8_t r, g, b;
    };
    struct pixel3 *Pixels = (struct pixel3 *)tex->Mem;

    for (i = 0; i < tex->Height; i++) {
      for (j = 0; j < tex->Width; j++) {
        memcpy(&Pixels[k++], &row_pointers[i][4 * j], 3);
      }
    }

    for (row = 0; row < height; row++)
      free(row_pointers[row]);

    free(row_pointers);
  } else if (png_get_color_type(png_ptr, info_ptr) == PNG_COLOR_TYPE_PALETTE) {

    struct png_clut {
      uint8_t r, g, b, a;
    };

    png_colorp palette = NULL;
    int num_pallete = 0;
    png_bytep trans = NULL;
    int num_trans = 0;

    png_get_PLTE(png_ptr, info_ptr, &palette, &num_pallete);
    png_get_tRNS(png_ptr, info_ptr, &trans, &num_trans, NULL);
    tex->ClutPSM = GS_PSM_CT32;

    if (bit_depth == 4) {

      int row_bytes = png_get_rowbytes(png_ptr, info_ptr);
      tex->PSM = GS_PSM_T4;
      tex->Mem = (u32 *)memalign(128, gsKit_texture_size_ee(tex->Width, tex->Height, tex->PSM));

      row_pointers = (png_byte **)calloc(height, sizeof(png_bytep));

      for (row = 0; row < height; row++)
        row_pointers[row] = (png_bytep)malloc(row_bytes);

      png_read_image(png_ptr, row_pointers);

      tex->Clut = (u32 *)memalign(128, gsKit_texture_size_ee(8, 2, GS_PSM_CT32));
      memset(tex->Clut, 0, gsKit_texture_size_ee(8, 2, GS_PSM_CT32));

      unsigned char *pixel = (unsigned char *)tex->Mem;
      struct png_clut *clut = (struct png_clut *)tex->Clut;

      int i, j, k = 0;

      for (i = num_pallete; i < 16; i++) {
        memset(&clut[i], 0, sizeof(clut[i]));
      }

      for (i = 0; i < num_pallete; i++) {
        clut[i].r = palette[i].red;
        clut[i].g = palette[i].green;
        clut[i].b = palette[i].blue;
        clut[i].a = 0x80;
      }

      for (i = 0; i < num_trans; i++)
        clut[i].a = trans[i] >> 1;

      for (i = 0; i < tex->Height; i++) {
        for (j = 0; j < tex->Width / 2; j++)
          memcpy(&pixel[k++], &row_pointers[i][1 * j], 1);
      }

      int byte;
      unsigned char *tmpdst = (unsigned char *)tex->Mem;
      unsigned char *tmpsrc = (unsigned char *)pixel;

      for (byte = 0; byte < gsKit_texture_size_ee(tex->Width, tex->Height, tex->PSM); byte++)
        tmpdst[byte] = (tmpsrc[byte] << 4) | (tmpsrc[byte] >> 4);

      for (row = 0; row < height; row++)
        free(row_pointers[row]);

      free(row_pointers);
    } else if (bit_depth == 8) {
      int row_bytes = png_get_rowbytes(png_ptr, info_ptr);
      tex->PSM = GS_PSM_T8;
      tex->Mem = (u32 *)memalign(128, gsKit_texture_size_ee(tex->Width, tex->Height, tex->PSM));

      row_pointers = (png_byte **)calloc(height, sizeof(png_bytep));

      for (row = 0; row < height; row++)
        row_pointers[row] = (png_bytep)malloc(row_bytes);

      png_read_image(png_ptr, row_pointers);

      tex->Clut = (u32 *)memalign(128, gsKit_texture_size_ee(16, 16, GS_PSM_CT32));
      memset(tex->Clut, 0, gsKit_texture_size_ee(16, 16, GS_PSM_CT32));

      unsigned char *pixel = (unsigned char *)tex->Mem;
      struct png_clut *clut = (struct png_clut *)tex->Clut;

      int i, j, k = 0;

      for (i = num_pallete; i < 256; i++) {
        memset(&clut[i], 0, sizeof(clut[i]));
      }

      for (i = 0; i < num_pallete; i++) {
        clut[i].r = palette[i].red;
        clut[i].g = palette[i].green;
        clut[i].b = palette[i].blue;
        clut[i].a = 0x80;
      }

      for (i = 0; i < num_trans; i++)
        clut[i].a = trans[i] >> 1;

      // rotate clut
      for (i = 0; i < num_pallete; i++) {
        if ((i & 0x18) == 8) {
          struct png_clut tmp = clut[i];
          clut[i] = clut[i + 8];
          clut[i + 8] = tmp;
        }
      }

      for (i = 0; i < tex->Height; i++) {
        for (j = 0; j < tex->Width; j++) {
          memcpy(&pixel[k++], &row_pointers[i][1 * j], 1);
        }
      }

      for (row = 0; row < height; row++)
        free(row_pointers[row]);

      free(row_pointers);
    }
  } else {
    printf("graphics: png: this texture depth (%d) is not supported yet!\n", bit_depth);
    return NULL;
  }

  tex->Filter = GS_FILTER_NEAREST;
  png_read_end(png_ptr, NULL);
  png_destroy_read_struct(&png_ptr, &info_ptr, (png_infopp)NULL);
  fclose(File);

  if (!tex->Delayed) {
    tex->Vram = gsKit_vram_alloc(gsGlobal, gsKit_texture_size(tex->Width, tex->Height, tex->PSM), GSKIT_ALLOC_USERBUFFER);
    if (tex->Vram == GSKIT_ALLOC_ERROR) {
      printf("graphics: png: VRAM Allocation Failed. Will not upload texture.\n");
      return NULL;
    }

    if (tex->Clut != NULL) {
      if (tex->PSM == GS_PSM_T4)
        tex->VramClut = gsKit_vram_alloc(gsGlobal, gsKit_texture_size(8, 2, GS_PSM_CT32), GSKIT_ALLOC_USERBUFFER);
      else
        tex->VramClut = gsKit_vram_alloc(gsGlobal, gsKit_texture_size(16, 16, GS_PSM_CT32), GSKIT_ALLOC_USERBUFFER);

      if (tex->VramClut == GSKIT_ALLOC_ERROR) {
        printf("graphics: png: VRAM CLUT Allocation Failed. Will not upload texture.\n");
        return NULL;
      }
    }

    // Upload texture
    gsKit_texture_upload(gsGlobal, tex);
    // Free texture
    free(tex->Mem);
    tex->Mem = NULL;
    // Free texture CLUT
    if (tex->Clut != NULL) {
      free(tex->Clut);
      tex->Clut = NULL;
    }
  } else {
    gsKit_setup_tbw(tex);
  }

  return tex;
}

GSTEXTURE *load_image(const char *path, bool delayed) {
  FILE *file = NULL;
  if (vfs_available()) {
    size_t sz = 0;
    const void *buf = vfs_get(path, &sz);
    if (buf && sz >= 8)
      file = fmemopen((void *)buf, sz, "rb");
  }
  if (!file)
    file = fopen(path, "rb");
  if (!file) {
    printf("graphics: failed to load image %s", path);
    return NULL;
  }

  uint16_t magic;
  fread(&magic, 1, 2, file);
  fseek(file, 0, SEEK_SET);
  GSTEXTURE *image = NULL;
  if (magic == 0x5089)
    image = loadpng(file, delayed);
  else
    fclose(file);
  if (image == NULL)
    printf("graphics: failed to load image %s", path);
  return image;
}

void gsKit_clear_screens() {
  int i;

  for (i = 0; i < 2; i++) {
    gsKit_clear(gsGlobal, BLACK_RGBAQ);
    gsKit_queue_exec(gsGlobal);
    gsKit_sync_flip(gsGlobal);
  }
}

void clearScreen(Color color) { gsKit_clear(gsGlobal, color); }

GSTEXTURE *load_png_from_memory(const void *data, size_t size, bool delayed) {
  if (!data || size < 8)
    return NULL;
  FILE *f = fmemopen((void *)data, size, "rb");
  if (!f)
    return NULL;
  GSTEXTURE *tex = loadpng(f, delayed);
  // loadpng closes f on success
  if (!tex)
    fclose(f);
  return tex;
}

float FPSCounter(int interval) {
  frame_interval = interval;
  return fps;
}

GSFONT *loadFont(const char *path) {
  int file = open(path, O_RDONLY, 0777);
  uint16_t magic;
  read(file, &magic, 2);
  close(file);
  GSFONT *font = NULL;
  if (magic == 0x4D42) {
    font = gsKit_init_font(GSKIT_FTYPE_BMP_DAT, (char *)path);
    gsKit_font_upload(gsGlobal, font);
  } else if (magic == 0x4246) {
    font = gsKit_init_font(GSKIT_FTYPE_FNT, (char *)path);
    gsKit_font_upload(gsGlobal, font);
  } else if (magic == 0x5089) {
    font = gsKit_init_font(GSKIT_FTYPE_PNG_DAT, (char *)path);
    gsKit_font_upload(gsGlobal, font);
  }

  return font;
}

void printFontText(GSFONT *font, const char *text, float x, float y, float scale, Color color) {
  gsKit_set_test(gsGlobal, GS_ATEST_ON);
  gsKit_font_print_scaled(gsGlobal, font, x - 0.5f, y - 0.5f, 1, scale, color, text);
}

void unloadFont(GSFONT *font) {
  gsKit_TexManager_free(gsGlobal, font->Texture);
  // clut was pointing to static memory, so do not free
  font->Texture->Clut = NULL;
  // mem was pointing to 'TexBase', so do not free
  font->Texture->Mem = NULL;
  // free texture
  free(font->Texture);
  font->Texture = NULL;

  if (font->RawData != NULL)
    free(font->RawData);

  free(font);
}

int getFreeVRAM() { return (4096 - (gsGlobal->CurrentPointer / 1024)); }

void drawImageCentered(GSTEXTURE *source, float x, float y, float width, float height, float startx, float starty, float endx, float endy,
                       Color color) {
  if (source->Delayed == true) {
    gsKit_TexManager_bind(gsGlobal, source);
  }
  gsKit_set_texfilter(gsGlobal, source->Filter);
  gsKit_prim_sprite_texture(gsGlobal, source,
                            x - width / 2,    // X1
                            y - height / 2,   // Y1
                            startx,           // U1
                            starty,           // V1
                            (width / 2 + x),  // X2
                            (height / 2 + y), // Y2
                            endx,             // U2
                            endy,             // V2
                            1, color);
}

void drawImage(GSTEXTURE *source, float x, float y, float width, float height, float startx, float starty, float endx, float endy, Color color) {
  if (source->Delayed == true) {
    gsKit_TexManager_bind(gsGlobal, source);
  }
  gsKit_set_texfilter(gsGlobal, source->Filter);
  gsKit_prim_sprite_texture(gsGlobal, source,
                            x - 0.5f,            // X1
                            y - 0.5f,            // Y1
                            startx,              // U1
                            starty,              // V1
                            (width + x) - 0.5f,  // X2
                            (height + y) - 0.5f, // Y2
                            endx,                // U2
                            endy,                // V2
                            1, color);
}

void drawImageRotate(GSTEXTURE *source, float x, float y, float width, float height, float startx, float starty, float endx, float endy, float angle,
                     Color color) {

  float c = cosf(angle);
  float s = sinf(angle);

  if (source->Delayed == true) {
    gsKit_TexManager_bind(gsGlobal, source);
  }
  gsKit_set_texfilter(gsGlobal, source->Filter);
  gsKit_prim_quad_texture(gsGlobal, source, (-width / 2) * c - (-height / 2) * s + x, (-height / 2) * c + (-width / 2) * s + y, startx, starty,
                          (-width / 2) * c - height / 2 * s + x, height / 2 * c + (-width / 2) * s + y, startx, endy,
                          width / 2 * c - (-height / 2) * s + x, (-height / 2) * c + width / 2 * s + y, endx, starty,
                          width / 2 * c - height / 2 * s + x, height / 2 * c + width / 2 * s + y, endx, endy, 1, color);
}

void drawPixel(float x, float y, Color color) { gsKit_prim_point(gsGlobal, x, y, 1, color); }

void drawLine(float x, float y, float x2, float y2, Color color) { gsKit_prim_line(gsGlobal, x, y, x2, y2, 1, color); }

void drawRect(float x, float y, int width, int height, Color color) {
  gsKit_prim_sprite(gsGlobal, x - 0.5f, y - 0.5f, (x + width) - 0.5f, (y + height) - 0.5f, 1, color);
}

void drawRectCentered(float x, float y, int width, int height, Color color) {
  gsKit_prim_sprite(gsGlobal, x - width / 2, y - height / 2, (x + width) - width / 2, (y + height) - height / 2, 1, color);
}

void drawTriangle(float x, float y, float x2, float y2, float x3, float y3, Color color) {
  gsKit_prim_triangle(gsGlobal, x, y, x2, y2, x3, y3, 1, color);
}

void drawTriangle_gouraud(float x, float y, float x2, float y2, float x3, float y3, Color color, Color color2, Color color3) {
  gsKit_prim_triangle_gouraud(gsGlobal, x, y, x2, y2, x3, y3, 1, color, color2, color3);
}

void drawQuad(float x, float y, float x2, float y2, float x3, float y3, float x4, float y4, Color color) {
  gsKit_prim_quad(gsGlobal, x, y, x2, y2, x3, y3, x4, y4, 1, color);
}

void drawQuad_gouraud(float x, float y, float x2, float y2, float x3, float y3, float x4, float y4, Color color, Color color2, Color color3,
                      Color color4) {
  gsKit_prim_quad_gouraud(gsGlobal, x, y, x2, y2, x3, y3, x4, y4, 1, color, color2, color3, color4);
}

void drawCircle(float x, float y, float radius, uint64_t color, uint8_t filled) {
  float v[37 * 2];
  int a;
  float ra;

  for (a = 0; a < 36; a++) {
    ra = DEG2RAD(a * 10);
    v[a * 2] = cos(ra) * radius + x;
    v[a * 2 + 1] = sin(ra) * radius + y;
  }

  if (!filled) {
    v[36 * 2] = radius + x;
    v[36 * 2 + 1] = y;
  }

  if (filled)
    gsKit_prim_triangle_fan(gsGlobal, v, 36, 1, color);
  else
    gsKit_prim_line_strip(gsGlobal, v, 37, 1, color);
}

void InvalidateTexture(GSTEXTURE *txt) { gsKit_TexManager_invalidate(gsGlobal, txt); }

void UnloadTexture(GSTEXTURE *txt) { gsKit_TexManager_free(gsGlobal, txt); }

int GetInterlacedFrameMode() {
  if ((gsGlobal->Interlace == GS_INTERLACED) && (gsGlobal->Field == GS_FRAME))
    return 1;

  return 0;
}

GSGLOBAL *getGSGLOBAL() { return gsGlobal; }

void setVideoMode(s16 mode, int width, int height, int psm, s16 interlace, s16 field, bool zbuffering, int psmz) {
  gsGlobal->Mode = mode;
  gsGlobal->Width = width;
  if ((interlace == GS_INTERLACED) && (field == GS_FRAME))
    gsGlobal->Height = height / 2;
  else
    gsGlobal->Height = height;

  gsGlobal->PSM = psm;
  gsGlobal->PSMZ = psmz;

  gsGlobal->ZBuffering = zbuffering;
  gsGlobal->DoubleBuffering = GS_SETTING_ON;
  gsGlobal->PrimAlphaEnable = GS_SETTING_ON;
  gsGlobal->Dithering = GS_SETTING_OFF;

  gsGlobal->Interlace = interlace;
  gsGlobal->Field = field;

  gsKit_set_primalpha(gsGlobal, GS_SETREG_ALPHA(0, 1, 0, 1, 0), 0);

  printf("graphics: created video surface (%d, %d)\n", gsGlobal->Width, gsGlobal->Height);

  gsKit_set_clamp(gsGlobal, GS_CMODE_REPEAT);
  gsKit_vram_clear(gsGlobal);
  gsKit_init_screen(gsGlobal);
  gsKit_set_display_offset(gsGlobal, -0.5f, -0.5f);
  gsKit_sync_flip(gsGlobal);

  gsKit_mode_switch(gsGlobal, GS_ONESHOT);
  gsKit_clear(gsGlobal, BLACK_RGBAQ);
}

void fntDrawQuad(rm_quad_t *q) {
  if (!q || !q->txt)
    return;
  if (!q->txt->Mem)
    return;  // atlas alloc failed or texture invalid - avoid gsKit NULL deref (TLB Miss)
  gsKit_TexManager_bind(gsGlobal, q->txt);
  gsKit_prim_sprite_texture(gsGlobal, q->txt, q->ul.x - 0.5f, q->ul.y - 0.5f, q->ul.u, q->ul.v, q->br.x - 0.5f, q->br.y - 0.5f, q->br.u, q->br.v, 1,
                            q->color);
}

// PRIVATE METHODS
static int vsync_handler(int unknown) {
  iSignalSema(vsync_sema_id);

  ExitHandler();
  return 0;
}

void setVSync(bool vsync_flag) { vsync = vsync_flag; }

// Copy of gsKit_sync_flip, but without the 'flip'
static void gsKit_sync(GSGLOBAL *gsGlobal) {
  if (!gsGlobal->FirstFrame)
    WaitSema(vsync_sema_id);
  while (PollSema(vsync_sema_id) >= 0)
    ;
}

// Copy of gsKit_sync_flip, but without the 'sync'
static void gsKit_flip(GSGLOBAL *gsGlobal) {
  if (!gsGlobal->FirstFrame) {
    if (gsGlobal->DoubleBuffering == GS_SETTING_ON) {
      GS_SET_DISPFB2(gsGlobal->ScreenBuffer[gsGlobal->ActiveBuffer & 1] / 8192, gsGlobal->Width / 64, gsGlobal->PSM, 0, 0);

      gsGlobal->ActiveBuffer ^= 1;
    }
  }

  gsKit_setactive(gsGlobal);
}

void initGraphics() {
  ee_sema_t sema;
  sema.init_count = 0;
  sema.max_count = 1;
  sema.option = 0;
  vsync_sema_id = CreateSema(&sema);

  gsGlobal = gsKit_init_global();

  gsGlobal->Mode = gsKit_check_rom();
  if (gsGlobal->Mode == GS_MODE_PAL) {
    gsGlobal->Height = 512;
  } else {
    gsGlobal->Height = 448;
  }

  gsGlobal->PSM = GS_PSM_CT24;
  gsGlobal->PSMZ = GS_PSMZ_16S;
  gsGlobal->ZBuffering = GS_SETTING_OFF;
  gsGlobal->DoubleBuffering = GS_SETTING_ON;
  gsGlobal->PrimAlphaEnable = GS_SETTING_ON;
  gsGlobal->Dithering = GS_SETTING_OFF;

  gsKit_set_primalpha(gsGlobal, GS_SETREG_ALPHA(0, 1, 0, 1, 0), 0);

  dmaKit_init(D_CTRL_RELE_OFF, D_CTRL_MFD_OFF, D_CTRL_STS_UNSPEC, D_CTRL_STD_OFF, D_CTRL_RCYC_8, 1 << DMA_CHANNEL_GIF);
  dmaKit_chan_init(DMA_CHANNEL_GIF);

  printf("graphics: created %ix%i video surface\n", gsGlobal->Width, gsGlobal->Height);

  gsKit_set_clamp(gsGlobal, GS_CMODE_REPEAT);

  gsKit_vram_clear(gsGlobal);

  gsKit_init_screen(gsGlobal);

  gsKit_TexManager_init(gsGlobal);

  gsKit_add_vsync_handler(vsync_handler);

  gsKit_mode_switch(gsGlobal, GS_ONESHOT);

  gsKit_clear(gsGlobal, BLACK_RGBAQ);
  gsKit_vsync_wait();
  flipScreen();
  gsKit_clear(gsGlobal, BLACK_RGBAQ);
  gsKit_vsync_wait();
  flipScreen();
}

void flipScreen() {
  // gsKit_set_finish(gsGlobal);
  if (gsGlobal->DoubleBuffering == GS_SETTING_OFF) {
    if (vsync)
      gsKit_sync(gsGlobal);
    gsKit_queue_exec(gsGlobal);
  } else {
    gsKit_queue_exec(gsGlobal);
    gsKit_finish();
    if (vsync)
      gsKit_sync(gsGlobal);
    gsKit_flip(gsGlobal);
  }
  gsKit_TexManager_nextFrame(gsGlobal);
  if (frames > frame_interval && frame_interval != -1) {
    clock_t prevtime = curtime;
    curtime = clock();

    fps = ((float)(frame_interval)) / (((float)(curtime - prevtime)) / ((float)CLOCKS_PER_SEC));

    frames = 0;
  }
  frames++;
}

void graphicWaitVblankStart() { gsKit_vsync_wait(); }
