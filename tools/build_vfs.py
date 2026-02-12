#!/usr/bin/env python3
"""
Build a virtual filesystem binary from all files under scripts/.

Binary format (all multi-byte values little-endian):

  Header (padded to 16 bytes):
    magic         4          "EVFS"
    num_files     4          number of file entries
    for each file:
      path_len    4          path storage size in bytes (multiple of 4), includes null terminator and padding
      path        [path_len] null-terminated UTF-8 path, zero-padded to path_len (C string)
      offset      4          file data offset relative to start of data section
      size        4          file size in bytes

  Data (starts at 16-byte-aligned offset after header):
    file contents, each file at a 16-byte-aligned offset

Usage: build_vfs.py <root_dir> <output.bin>
  root_dir   directory containing "scripts" (e.g. .)
  output.bin output VFS binary path
"""

import os
import struct
import sys

MAGIC = b"EVFS"
ALIGN = 16

def align_up(value):
    return (value + ALIGN - 1) & ~(ALIGN - 1)

def main():
    if len(sys.argv) != 3:
        sys.stderr.write("Usage: %s <root_dir> <output.bin>\n" % sys.argv[0])
        sys.exit(1)
    root = os.path.normpath(sys.argv[1])
    out_path = sys.argv[2]
    scripts_dir = os.path.join(root, "scripts")
    if not os.path.isdir(scripts_dir):
        sys.stderr.write("No scripts directory under %s\n" % root)
        sys.exit(1)

    entries = []  # (path_bytes, size)
    data_chunks = []

    for dirpath, _dirnames, filenames in os.walk(scripts_dir):
        for name in sorted(filenames):
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, root).replace("\\", "/")
            with open(path, "rb") as f:
                content = f.read()
            size = len(content)
            path_bytes = rel.encode("utf-8") + b"\0"
            if len(path_bytes) > 0x7FFFFFFF:
                sys.stderr.write("Path too long: %s\n" % rel)
                sys.exit(1)
            entries.append((path_bytes, size))
            data_chunks.append(content)

    # Header: path is null-terminated C string, path_len = storage size (multiple of 4)
    path_align = 4
    header_len = 4 + 4
    for path_bytes, size in entries:
        path_len = (len(path_bytes) + path_align - 1) & ~(path_align - 1)
        header_len += 4 + path_len + 4 + 4
    data_start = align_up(header_len)

    # Compute 16-byte-aligned offset for each file (absolute position in blob)
    offsets_abs = []
    pos = data_start
    for i, (_, size) in enumerate(entries):
        offsets_abs.append(pos)
        pos = align_up(pos + size)

    # VFS reader expects offsets relative to data_start (first byte of file data)
    with open(out_path, "wb") as out:
        out.write(MAGIC)
        out.write(struct.pack("<I", len(entries)))
        for (path_bytes, size), offset_abs in zip(entries, offsets_abs):
            offset_rel = offset_abs - data_start
            path_len = (len(path_bytes) + path_align - 1) & ~(path_align - 1)
            out.write(struct.pack("<I", path_len))
            out.write(path_bytes)
            out.write(b"\0" * (path_len - len(path_bytes)))
            out.write(struct.pack("<II", offset_rel, size))
        # Pad header to 16-byte boundary so first file starts aligned
        pad = data_start - header_len
        assert pad >= 0 and pad < ALIGN
        out.write(b"\0" * pad)
        # Write each file at its aligned offset (with padding between files)
        pos = data_start
        for i, (chunk, offset_abs) in enumerate(zip(data_chunks, offsets_abs)):
            assert pos == offset_abs, "offset mismatch at file %d" % i
            out.write(chunk)
            pos += len(chunk)
            # Pad to next 16-byte boundary for next file
            next_start = align_up(pos)
            out.write(b"\0" * (next_start - pos))
            pos = next_start

    sys.stderr.write("VFS: %u files -> %s (data aligned %u)\n" % (len(entries), out_path, ALIGN))

if __name__ == "__main__":
    main()
