#ifndef GRAPHICS_FNTSYS_H
#define GRAPHICS_FNTSYS_H

#include <gsToolkit.h>
#include <cstdint>

/// default (built-in) font id
#define FNT_DEFAULT (0)
/// Value returned on errors
#define FNT_ERROR (-1)

#define ALIGN_TOP (0 << 0)
#define ALIGN_BOTTOM (1 << 0)
#define ALIGN_VCENTER (2 << 0)
#define ALIGN_LEFT (0 << 2)
#define ALIGN_RIGHT (1 << 2)
#define ALIGN_HCENTER (2 << 2)
#define ALIGN_NONE (ALIGN_TOP | ALIGN_LEFT)
#define ALIGN_CENTER (ALIGN_VCENTER | ALIGN_HCENTER)

// Initializes the font subsystem
void fntInit();

// Terminates the font subsystem
void fntEnd();

// Loads a font from a file path. Returns font slot id (negative value means error happened).
int fntLoadFile(const char *path);

// Loads a font from a buffer (e.g. from VFS). Buffer must remain valid for the font lifetime. Returns font slot id (negative value means error happened).
int fntLoadFromMemory(const void *buf, int size);

// Reloads the default font
int fntLoadDefault(const char *path);

// Releases a font slot
void fntRelease(int id);

// Updates to the native display resolution and aspect ratio. Invalidates the whole glyph cache for all fonts!
void fntUpdateAspectRatio();

// Renders a text with specified window dimensions
int fntRenderString(int id, int x, int y, short aligned, size_t width, size_t height, const char *string, uint64_t colour);

// Replaces spaces with newlines so that the text fits into the specified width. Destructive - modifies the given string!
void fntFitString(int id, char *string, size_t width);

// Calculates the width of the given text string. We can't use the height for alignment, as the horizontal center would depend on the contained text itself.
int fntCalcDimensions(int id, const char *str);

void fntSetPixelSize(int fontid, int width, int height);

void fntSetCharSize(int fontid, int width, int height);

#endif
