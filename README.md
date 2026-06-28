![logo](https://raw.githubusercontent.com/saildot4k/R3CONFIGURATOR/refs/heads/main/res/title.png)

A PlayStation 2 GUI application for editing config files for:  
- FMCB, FHDB 
- OSDMenu, OSDMenu MBR, HOSDMenu  
- PS2BBL Extended and PSXBBL Extended.

**This application is based on [Enceladus](https://github.com/DanielSant0s/Enceladus)** by Daniel Santos.  
Enceladus provides the Lua bindings, graphics, system, and I/O APIs.  
See the [Enceladus repository](https://github.com/DanielSant0s/Enceladus) for the full project, documentation, and thanks.  
Forked from [OSDMenu Configurator](https://github.com/pcm720/OSDMenu-Configurator) by @pcm720 to add the other configurators and simpler UX

## Usage

Choose `Free McBoot`, `Free HDBoot`, `OSDMenu`, `HOSDMenu`, `OSDMenu MBR`, `PS2BBL`, `PSXBBL`, and open the corresponding config.

- [OSDMenu repository](https://github.com/pcm720/OSDMenu) for usage and installation.

- [PS2BBL Extended repository](https://github.com/saildot4k/PlayStation2-Basic-BootLoader-Extended) for usage and installation.

- Hold __SELECT__ while booting to force all devices/choices to be shown. Your configuration file is still applied for hiding/showing apps to configure.


<details>

<summary>Config Lookup order for each application</summary>

## Config lookup order for each application

These are the orders and files that each app looks for when loading. First found file is used by each app.  
R3CONFIGURATOR will let you search for and edit any of these config file paths.

### FreeMcBoot (`FREEMCB.CNF`)

-  `mass:/FREEMCB.CNF` -> `mc0:/SYS-CONF/FREEMCB.CNF` -> `mc1:/SYS-CONF/FREEMCB.CNF`

### Free HDBoot (`FREEHDB.CNF`)

- `mass:/FREEHDB.CNF` -> `hdd0:__sysconf/FMCB/FREEHDB.CNF` -> `mc0:/SYS-CONF/FREEHDB.CNF` -> `mc1:/SYS-CONF/FREEHDB.CNF`

### OSDMenu (`OSDMENU.CNF`, `OSDGSM.CSM`)

- `mc0:/SYS-CONF/OSDMENU.CNF` -> `mc1:/SYS-CONF/OSDMENU.CNF`
- `xfrom:/osdmenu/OSDMENU.CNF`

- `mc0:/SYS-CONF/OSDGSM.CNF` -> `mc1:/SYS-CONF/OSDGSM.CNF`

### HOSDMenu (`OSDMENU.CNF, OSDGSM.CNF`)

- `hdd0:__sysconf:pfs:/osdmenu/OSDMENU.CNF`

- `hdd0:__sysconf:pfs:/osdmenu/OSDGSM.CNF`

### OSDMenu MBR (`OSDMBR.CNF`, `OSDGSM.CNF`)

- `hdd0:__sysconf:pfs:osdmenu/OSDMBR.CNF`
- `xfrom:/osdmenu/OSDMBR.CNF` (PSX)

- `hdd0:__sysconf:pfs:osdmenu/OSDGSM.CNF`
- `xfrom:/osdmenu/OSDGSM.CNF` (PSX)

### PS2BBL/PSXBBL Extended (`PS2BBL.INI` / `CONFIG.INI`)

1. `CONFIG.INI` (CWD: Current Working Directory)
2. __device PS2BBL launched from__ `device:/PS2BBL/CONFIG.INI`
3. __if launched from HDD__ `hdd0:__sysconf:pfs:/PS2BBL/CONFIG.INI`, `hdd1:__sysconf:pfs:/PS2BBL/CONFIG.INI`
4. `mc?:/SYS-CONF/PSXBBL.INI` (PSX DESR only; skipped on PS2 hardware)
5. `mc?:/SYS-CONF/PS2BBL.INI`


## Config types

- FREEMCB.CNF -  Free McBoot global, autolaunch and hotkeys

- FREEHDB.CNF -  Free HDBoot global, autolaunch and hotkeys

- [`OSDMENU.CNF`](https://github.com/pcm720/OSDMenu/blob/main/patcher/README.md#osdmenucnf) — OSDMenu/HOSDMenu global options and menu entries (including names, paths and arguments).

- [`OSDMBR.CNF`](https://github.com/pcm720/OSDMenu/blob/main/mbr/README.md) — OSDMenu MBR options

- [`OSDGSM.CNF`](https://github.com/pcm720/OSDMenu/blob/main/utils/loader/README.md#eGSM) — eGSM options with default settings and per–title ID overrides

- [PS2BBL Extended repository](https://github.com/saildot4k/PlayStation2-Basic-BootLoader-Extended)

The config is saved to the same location the config was loaded from

</details>

<details>

<summary> Running and r3configurator.cnf</summary>

## Running

Run the ELF from your preferred method.  
The app’s working directory (CWD) is where the ELF is launched from (e.g. `mass0:/`, `mc0:/`, `mmce0:/`).

- With `EMBED_VFS`: the built-in script bundle is used; you can still override strings and font from CWD (see below).
- Without `EMBED_VFS`: place the `scripts/` directory (and optionally `res/` if not embedded) and the ELF so that paths like `scripts/ui.lua`, `scripts/lang/strings_en.lua`, and `scripts/font/font.ttf` are available from CWD

The automated build comes with `EMBED_VFS` flag set, so all scripts are already embedded.

## Startup Configuration (CWD)

R3Configurator can configure itself and apply changes immediatly. `r3configurator.cnf` will be saved in CWD of `r3configurator.elf`

### Supported keys

- `video_mode`:
  - `auto`, `ntsc`, `pal`, `480p`
- `swap_buttons`:
  - `0`/`1` (also accepts `false`/`true`, `no`/`yes`, `off`/`on`)
- `default_language`:
  - language code loaded from `scripts/lang/strings_<code>.lua` (example: `en`, `pt`, `es`)
- Main page visibility toggles (`0`/`1`):
  - `show_freemcboot`
  - `show_freehddboot`
  - `show_osdmenu`
  - `show_osdmenu_mbr`
  - `show_hosdmenu`
  - `show_ps2bbl`
  - `show_psxbbl`
- UI color keys (`RRGGBB` format only):
  - `cross`, `square`, `triangle`, `circle`
  - `selected`, `selected_dim`, `unselected`, `dim`, `background`

</details>

<details>

<summary> Language and font overrides</summary>

## Language and font overrides

You can override the built-in strings and font by placing files in the **current working directory** (the directory from which the ELF is run).

### strings.lua

- If a file named `strings.lua` exists in CWD, it is loaded **instead of** `scripts/lang/strings_XX.lua`
- It must return a table with the same structure as the lang files (see `scripts/lang/strings_en.lua` for keys and layout). This allows fully custom UI text without modifying the `scripts/lang/` tree
- When this override is active, **L1/R1 language cycling is disabled** (the app does not scan `scripts/lang/` for other languages)

### font.ttf

- If a file named **`font.ttf`** exists in CWD, it is used as the UI font
- If not, the app falls back to **`scripts/font/font.ttf`** (either on the filesystem or from the embedded VFS when using `EMBED_VFS=ON`)

## Translations

- UI strings are in **`scripts/lang/strings_XX.lua`** (e.g. `strings_en.lua`, `strings_fr.lua`)
- To add a language: copy `scripts/lang/strings_en.lua` to `scripts/lang/strings_<lang>.lua`, then translate the **values** and keep all **keys** unchanged
- If more than one `strings_*.lua` exists in `scripts/lang/` and you are *not* using a CWD `strings.lua` override, **L1 / R1** on the main menu cycle the language  
  When a CWD `strings.lua` override is used, language cycling is disabled

</details>

### Contributing

If you'd like to contribute your translation to the project:
1. Fork the project
2. Create a new branch (e.g. `translation_<language>`)
3. Place your translation to `scripts/lang/strings_<2-letter language code>.lua` 
4. Commit the change and push it
5. Open a pull request

## Building

Requires [PS2SDK](https://github.com/ps2dev/ps2sdk) installed.

```bash
cmake -B build
cmake --build build
```
### Build Configuration flags
- `-DOUTDIR=<dir>` for custom output directory
- `-DPOWERPC_UART=ON` for enabling stdout redirection on Deckard consoles
- `-DEMBED_VFS=ON` for embedding the contents of `scripts/` into the ELF so the app can run without external script files (e.g. from a single ELF on memory card)
- `-DAPP_VERSION_OVERRIDE=<value>` to override the app version shown in UI/splash and used by default for `SAS/title.cfg` `Version=`
- `-DSAS_TITLE_VERSION=<value>` to override only `Version=` in `SAS/title.cfg` (defaults to `APP_VERSION_OVERRIDE` when set, otherwise git describe)

## Lua syntax checks

The repository includes a VS Code task named `Lua: Syntax Check`:

- Windows: runs `tools/lua_syntax_check.ps1` (expects `luac.exe` in `PATH`, or `LUAC` env var set).
- Linux/WSL/macOS: runs `tools/lua_syntax_check.sh` (expects `luac` in `PATH`, or `LUAC` env var set).

Run it from VS Code with `Terminal -> Run Task... -> Lua: Syntax Check`.

## License

Distributed under the GNU GPL-3.0 License. See `LICENSE` for details.

## Translation contributors

- Spanish
  - VizoR
- Portuguese
  - nuno
