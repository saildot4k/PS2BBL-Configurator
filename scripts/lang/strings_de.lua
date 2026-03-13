--[[
  Deutsche UI-Texte fuer den Konfigurator.
  Nach strings_XX.lua (z. B. strings_fr.lua) kopieren und die Werte uebersetzen; die Schluessel unveraendert lassen.
  Hint _items: jeder Eintrag ist { pad = "cross", label = "Oeffnen" }. Optional row = 1 (unten) oder 2 (oben); wenn ein Element row=2 hat, kommt die Zeilenaufteilung aus der Sprachdatei, sonst sind die ersten 4 unten und der Rest oben.
]]

local strings = {}
strings.language_name = "Deutsch"

-- Hauptablauf (main, choose_mc, select_config, initHdd, open, choose_load)
strings.main = {
  main_title = "R3CONFIGURATOR",
  main_sub = "Waehle eine der folgenden Optionen",
  version_unknown = "unbekannt",
  main_hint_items = { { pad = "up", label = "Hoch" }, { pad = "cross", label = "Oeffnen" }, { pad = "down", label = "Runter" }, { pad = "start", label = "Beenden", row = 2 } },
  main_hint_items_with_lang = { { pad = "up", label = "Hoch", layoutLabel = "Sprache -", row = 1 }, { pad = "cross", label = "Oeffnen", layoutLabel = "Beenden", row = 1 }, { pad = "down", label = "Runter", layoutLabel = "Sprache +", row = 1 }, { pad = "L1", label = "Sprache -", layoutLabel = "Sprache -", row = 2 }, { pad = "start", label = "Beenden", layoutLabel = "Beenden", row = 2 }, { pad = "R1", label = "Sprache +", layoutLabel = "Sprache +", row = 2 } },
  main_ps2bbl_mc = "PS2BBL",
  main_psxbbl_mc = "PSXBBL",
  main_osdmenu = "OSDMenu",
  main_osdmenu_mbr = "OSDMenu MBR",
  main_hosdmenu = "HOSDMenu",
  main_egsm = "eGSM",
  main_freemcboot = "FreeMCBoot",
  main_freehddboot = "FreeHDBoot",
  main_exit = "Zum Browser beenden",
  main_exit_prompt = "Zum Browser beenden?",
  main_exit_hint_items = { { pad = "cross", label = "Ja" }, { pad = "circle", label = "Nein" } },
  no_memory_card = "Keine Speicherkarte gefunden",
  insert_mc = "Lege eine Speicherkarte ein und versuche es erneut",
  circle_back_items = { { pad = "circle", label = "Zurueck" } },
  select_memory_card = "Waehle die Speicherkarte zum Laden der Konfiguration",
  config_card_hint = "Die Konfigurationsdatei wird erstellt, falls sie nicht existiert",
  cross_select_circle_back_items = { { pad = "cross", label = "Oeffnen" }, { pad = "circle", label = "Zurueck" } },
  memory_card_1_slot = "Speicherkarte 1",
  memory_card_2_slot = "Speicherkarte 2",
  which_file = "Welche Datei?",
  init_hdd_title = "HDD-Module werden initialisiert...",
  init_hdd_sub = "HDD-Treiber werden geladen und __sysconf wird eingehaengt",
  no_location = "Kein Speicherort fuer diesen Dateityp",
  hdd_not_found = "Stelle sicher, dass die HDD angeschlossen und formatiert ist",
  cross_back_items = { { pad = "cross", label = "Zurueck" } },
  failed_to_load = "Laden fehlgeschlagen: ",
  cross_load_circle_back_items = { { pad = "cross", label = "Laden" }, { pad = "circle", label = "Zurueck" } },
  select_config_ps2bbl_ini = "PS2BBL.INI",
  select_config_psxbbl_ini = "PSXBBL.INI",
  select_config_browse_ini = "CONFIG.INI durchsuchen (CWD)",
  select_config_osdmenu_cnf = "OSDMENU.CNF",
  select_config_osdmbr_cnf = "OSDMBR.CNF",
  select_config_osdgsm_cnf = "OSDGSM.CNF",
}

-- Editor
strings.editor = {
  saved = "Gespeichert",
  cross_open_circle_back_items = { { pad = "cross", label = "Oeffnen" }, { pad = "start", label = "Speichern" }, { pad = "circle", label = "Zurueck" } },
  start_save_circle_back_items = { { pad = "start", label = "Speichern" }, { pad = "circle", label = "Zurueck" } },
  hint_edit_items = { { pad = "cross", label = "Bearbeiten", row = 1 }, { pad = "triangle", label = "Reset", row = 1 }, { pad = "start", label = "Speichern", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 }, { pad = "left", label = "-1", row = 2 }, { pad = "L1", label = "-10", row = 2 }, { pad = "L2", label = "-50", row = 2 }, { pad = "R2", label = "+50", row = 2 }, { pad = "R1", label = "+10", row = 2 }, { pad = "right", label = "+1", row = 2 } },
  no_option_list = "Keine Optionsliste fuer diesen Dateityp",
  save_config_to = "Konfiguration speichern nach",
  save_failed = "Speichern fehlgeschlagen",
  no_save_location = "Kein Speicherort",
  error_write_failed = "Schreiben fehlgeschlagen",
  error_read_failed = "Lesen fehlgeschlagen",
  error_cannot_get_size = "Dateigroesse kann nicht ermittelt werden",
  error_cannot_open = "Kann nicht oeffnen ",
  error_cannot_open_for_write = "Kann nicht zum Schreiben oeffnen ",
  cross_save_circle_cancel_items = { { pad = "cross", label = "Speichern" }, { pad = "circle", label = "Abbrechen" } },
  leave_save_prompt = "Aenderungen vor dem Verlassen speichern?",
  leave_save_hint_items = { { pad = "cross", label = "Speichern" }, { pad = "triangle", label = "Verwerfen" }, { pad = "circle", label = "Abbrechen" } },
  edit_color_suffix = " - Farbe bearbeiten",
  red = "Rot",
  green = "Gruen",
  blue = "Blau",
  alpha = "Alpha",
  color_edit_hint_items = { { pad = "cross", label = "Anwenden", row = 1 }, { pad = "up", label = "Hoch", row = 1 }, { pad = "down", label = "Runter", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 }, { pad = "left", label = "-1", row = 2 }, { pad = "L1", label = "-10", row = 2 }, { pad = "L2", label = "-50", row = 2 }, { pad = "R2", label = "+50", row = 2 }, { pad = "R1", label = "+10", row = 2 }, { pad = "right", label = "+1", row = 2 } },
}

-- Menueintraege
strings.menu_entries = {
  edit_menu_entries = "Menueeintraege bearbeiten",
  edit_irx_entries = "IRX-Eintraege bearbeiten",
  item = "Element ",
  hint_items = { { pad = "cross", label = "Oeffnen", row = 1 }, { pad = "select", label = "Einfuegen", row = 1 }, { pad = "square", label = "Loeschen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 }, { pad = "left", label = "Vorher", row = 2 }, { pad = "L1", label = "Hoch", row = 2 }, { pad = "start", label = "Speichern", row = 2 }, { pad = "R1", label = "Runter", row = 2 }, { pad = "right", label = "Weiter", row = 2 } },
  hint_items_with_enable = { { pad = "cross", label = "Oeffnen", row = 1 }, { pad = "triangle", label = "Aktivieren", layoutLabel = "Deaktivieren", row = 1 }, { pad = "select", label = "Einfuegen", row = 1 }, { pad = "square", label = "Loeschen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 }, { pad = "left", label = "Vorher", row = 2 }, { pad = "L1", label = "Hoch", row = 2 }, { pad = "start", label = "Speichern", row = 2 }, { pad = "R1", label = "Runter", row = 2 }, { pad = "right", label = "Weiter", row = 2 } },
  hint_items_with_disable = { { pad = "cross", label = "Oeffnen", row = 1 }, { pad = "triangle", label = "Deaktivieren", layoutLabel = "Deaktivieren", row = 1 }, { pad = "select", label = "Einfuegen", row = 1 }, { pad = "square", label = "Loeschen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 }, { pad = "left", label = "Vorher", row = 2 }, { pad = "L1", label = "Hoch", row = 2 }, { pad = "start", label = "Speichern", row = 2 }, { pad = "R1", label = "Runter", row = 2 }, { pad = "right", label = "Weiter", row = 2 } },
  irx_hint_items = { { pad = "", label = "", row = 2 }, { pad = "L1", label = "Hoch", row = 2 }, { pad = "start", label = "Speichern", row = 2 }, { pad = "R1", label = "Runter", row = 2 }, { pad = "", label = "", row = 2 }, { pad = "cross", label = "Oeffnen", row = 1 }, { pad = "triangle", label = "Deaktivieren", row = 1 }, { pad = "select", label = "Einfuegen", row = 1 }, { pad = "square", label = "Loeschen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 } },
  irx_hint_items_with_enable = { { pad = "", label = "", row = 2 }, { pad = "L1", label = "Hoch", row = 2 }, { pad = "start", label = "Speichern", row = 2 }, { pad = "R1", label = "Runter", row = 2 }, { pad = "", label = "", row = 2 }, { pad = "cross", label = "Oeffnen", row = 1 }, { pad = "triangle", label = "Aktivieren", layoutLabel = "Deaktivieren", row = 1 }, { pad = "select", label = "Einfuegen", row = 1 }, { pad = "square", label = "Loeschen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 } },
  irx_hint_items_with_disable = { { pad = "", label = "", row = 2 }, { pad = "L1", label = "Hoch", row = 2 }, { pad = "start", label = "Speichern", row = 2 }, { pad = "R1", label = "Runter", row = 2 }, { pad = "", label = "", row = 2 }, { pad = "cross", label = "Oeffnen", row = 1 }, { pad = "triangle", label = "Deaktivieren", layoutLabel = "Deaktivieren", row = 1 }, { pad = "select", label = "Einfuegen", row = 1 }, { pad = "square", label = "Loeschen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 } },
  entry_index = "Eintrag ",
  name = "Name: ",
  paths = "Pfade: ",
  args = "args: ",
  none = "keine",
  path_s = " Pfad(e)",
  arg_s = " Arg(s)",
  cross_select_circle_back_items = { { pad = "cross", label = "Oeffnen" }, { pad = "circle", label = "Zurueck" } },
  edit_name = "Name bearbeiten",
  paths_label = "Pfade",
  launch_disc_options = "Optionen zum Disc-Start",
  arguments = "Argumente",
  entry_name_prompt = "Name des Eintrags",
  add_entry_label = "Neuer Eintrag",
  launch_disc_options_title = "Optionen zum Disc-Start",
  launch_disc_options_sub = "Diese Optionen ueberschreiben das Standardverhalten beim Disc-Start",
  paths_for_entry_title = "Pfade fuer %s (Eintrag %s)",
  paths_hint_items = { { pad = "cross", label = "Bearbeiten", row = 1 }, { pad = "square", label = "Entfernen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 }, { pad = "L1", label = "Hoch", row = 2 }, { pad = "select", label = "Hinzufuegen", row = 2 }, { pad = "R1", label = "Runter", row = 2 } },
  paths_hint_items_with_enable = { { pad = "cross", label = "Bearbeiten", row = 1 }, { pad = "triangle", label = "Aktivieren", layoutLabel = "Deaktivieren", row = 1 }, { pad = "square", label = "Entfernen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 }, { pad = "L1", label = "Hoch", row = 2 }, { pad = "select", label = "Hinzufuegen", row = 2 }, { pad = "R1", label = "Runter", row = 2 } },
  paths_hint_items_with_disable = { { pad = "cross", label = "Bearbeiten", row = 1 }, { pad = "triangle", label = "Deaktivieren", layoutLabel = "Deaktivieren", row = 1 }, { pad = "square", label = "Entfernen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 }, { pad = "L1", label = "Hoch", row = 2 }, { pad = "select", label = "Hinzufuegen", row = 2 }, { pad = "R1", label = "Runter", row = 2 } },
  args_for_entry_title = "Argumente fuer %s (Eintrag %s)",
  args_hint_items = { { pad = "cross", label = "Bearbeiten", row = 1 }, { pad = "square", label = "Entfernen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 }, { pad = "L1", label = "Hoch", row = 2 }, { pad = "select", label = "Hinzufuegen", row = 2 }, { pad = "R1", label = "Runter", row = 2 } },
  args_hint_items_with_enable = { { pad = "cross", label = "Bearbeiten", row = 1 }, { pad = "triangle", label = "Aktivieren", layoutLabel = "Deaktivieren", row = 1 }, { pad = "square", label = "Entfernen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 }, { pad = "L1", label = "Hoch", row = 2 }, { pad = "select", label = "Hinzufuegen", row = 2 }, { pad = "R1", label = "Runter", row = 2 } },
  args_hint_items_with_disable = { { pad = "cross", label = "Bearbeiten", row = 1 }, { pad = "triangle", label = "Deaktivieren", layoutLabel = "Deaktivieren", row = 1 }, { pad = "square", label = "Entfernen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 }, { pad = "L1", label = "Hoch", row = 2 }, { pad = "select", label = "Hinzufuegen", row = 2 }, { pad = "R1", label = "Runter", row = 2 } },
  cdrom_hint = "Disc-Starteintrag: Verwende die Optionen zum Disc-Start fuer Flags",
  cdrom_toggle_hint_items = { { pad = "cross", label = "Umschalten", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 }, { pad = "left", label = "Vorher", row = 2 }, { pad = "right", label = "Weiter", row = 2 } },
  new_argument_prompt = "Neues Argument",
  edit_argument_prompt = "Argument bearbeiten",
}

-- Pfad-Auswahl
strings.path_picker = {
  choose_device = "Geraet waehlen",
  add_path_choose_device = "Pfad hinzufuegen: Geraet waehlen",
  bbl_build_device_hint = "Waehle nur Geraete, die von deinem PS?BBL-Build unterstuetzt werden.",
  enter_path_manually = "Pfad manuell eingeben",
  bbl_cmd_cdvd = "$CDVD (Disc starten)",
  bbl_cmd_cdvd_no_logo = "$CDVD_NO_PS2LOGO (Disc ohne Logo starten)",
  bbl_cmd_osdsys = "$OSDSYS (Browser starten)",
  fmcb_cmd_osdsys = "OSDSYS (Browser starten)",
  bbl_cmd_credits = "$CREDITS",
  bbl_cmd_hddchecker = "$HDDCHECKER (HDD-Build)",
  bbl_cmd_runkelf = "$RUNKELF:<pfad>",
  bbl_cmd_runkelf_prompt = "KELF-Pfad fuer $RUNKELF eingeben:",
  enter_path_prompt = "Pfad eingeben",
  cross_select_circle_back_items = { { pad = "cross", label = "Oeffnen" }, { pad = "circle", label = "Zurueck" } },
  select_hdd_partition = "HDD-Partition waehlen",
  no_partitions = "Keine Partitionen (ist die HDD angeschlossen?)",
  cross_open_circle_back_items = { { pad = "cross", label = "Oeffnen" }, { pad = "circle", label = "Zurueck" } },
  cross_open_square_patinfo_circle_back_items = { { pad = "cross", label = "Oeffnen" }, { pad = "square", label = "PATINFO" }, { pad = "circle", label = "Zurueck" } },
  no_elf_files = "Keine ELF-Dateien oder Ordner",
  no_ini_files = "Keine INI-Dateien oder Ordner",
  cross_select_file_items = { { pad = "cross", label = "Waehlen" }, { pad = "circle", label = "Zurueck" } },
  cross_select_create_circle_back_items = { { pad = "cross", label = "Waehlen" }, { pad = "select", label = "CONFIG.INI erstellen" }, { pad = "circle", label = "Zurueck" } },
  no_devices = "Keine Geraete",
  waiting_for_device_drivers = "Warte auf Geraet...",
  circle_back_items = { { pad = "circle", label = "Zurueck" } },
  device_timeout = "%DEVICE% nicht gefunden",
  irx_extension_required = "Pfad muss auf .irx enden",
  wildcard_confirm_title = "Pfad als Platzhalter verwenden?",
  wildcard_confirm_hint = { { pad = "cross", label = "Ja" }, { pad = "circle", label = "Nein" } },
}

-- Geraete- und Spezialeintragsnamen
strings.devices = {
  memory_card_1 = "Speicherkarte 1",
  memory_card_2 = "Speicherkarte 2",
  launch_disc = "Disc mit Ueberschreibung starten",
  dvd_player = "DVD-Player",
  osd = "OSDSYS",
  shutdown = "Ausschalten",
  hosdsys = "Browser 2.0 / HOSDMenu",
  psbbn = "PlayStation Broadband Navigator",
  usb_storage_0 = "USB-Massenspeicher 1",
  usb_storage_1 = "USB-Massenspeicher 2",
  mmce_0 = "MMCE in Slot 1",
  mmce_1 = "MMCE in Slot 2",
  mx4sio_sd = "MX4SIO",
  exfat_hdd_mass0 = "exFAT-formatierte HDD",
  hdd = "APA-formatierte HDD",
}

-- Gemeinsame Texte
strings.common = {
  on = "Ein",
  off = "Aus",
  not_set = "(nicht gesetzt)",
  empty = "(leer)",
  second = "Sekunde",
  seconds = "Sekunden",
  enter_text = "Text eingeben",
  hint_prev = "Vorher",
  hint_next = "Weiter",
}

-- Kategorienamen
strings.categories = {
  [1] = "OSD-Verhaltensmodifikatoren",
  [2] = "Benutzerdefinierte OSD-Menueoptionen",
  [3] = "Disc- und Anwendungsstart-Modifikatoren",
  [4] = "Menueeintraege bearbeiten",
}

strings.categories_freemcboot = {
  [1] = "OSD-Verhaltensmodifikatoren",
  [2] = "Benutzerdefinierte OSD-Menueoptionen",
  [3] = "Disc-Optionen",
  [4] = "AUTOBOOT",
  [5] = "START-TASTEN",
  [6] = "Menueeintraege bearbeiten",
}

-- OSDMENU.CNF Optionsbezeichnungen und Beschreibungen
strings.options_osdmenu = {
  OSDSYS_video_mode = { label = "Videomodus erzwingen", desc = "OSD-Videomodus erzwingen" },
  OSDSYS_region = { label = "Region erzwingen", desc = "OSD-Region erzwingen" },
  OSDSYS_Skip_Disc = { label = "Disc ueberspringen", desc = "Automatischen Disc-Start ueberspringen" },
  OSDSYS_Skip_Logo = { label = "Intro ueberspringen", desc = "SCE-Introanimation ueberspringen" },
  OSDSYS_Inner_Browser = { label = "Interner Browser", desc = "Im Speicherkarten-Browser starten" },
  OSDSYS_Skip_MC = { label = "MC ueberspringen", desc = "Speicherkartenpruefung im Browser ueberspringen" },
  OSDSYS_Skip_HDD = { label = "HDD ueberspringen", desc = "HDD-Pruefung im Browser ueberspringen" },
  Debug_Screen = { label = "Debug-Bildschirm", desc = "Debug-Ausgabe auf dem Bildschirm aktivieren" },
  hacked_OSDSYS = { label = "Gepatchtes OSD", desc = "FHDB-gepatchten OSD-Menue-Modus aktivieren" },
  OSDSYS_custom_menu = { label = "Benutzerdefiniertes Menue", desc = "Benutzerdefiniertes Menue aktivieren" },
  OSDSYS_scroll_menu = { label = "Endloses Scrollen", desc = "Endloses Scrollen aktivieren" },
  OSDSYS_menu_x = { label = "Menue X", desc = "X-Position des benutzerdefinierten Menues" },
  OSDSYS_menu_y = { label = "Menue Y", desc = "Y-Position des benutzerdefinierten Menues" },
  OSDSYS_enter_x = { label = "Enter X", desc = "X-Position der Enter-Taste" },
  OSDSYS_enter_y = { label = "Enter Y", desc = "Y-Position der Enter-Taste" },
  OSDSYS_version_x = { label = "Version X", desc = "X-Position der Versionsanzeige" },
  OSDSYS_version_y = { label = "Version Y", desc = "Y-Position der Versionsanzeige" },
  OSDSYS_cursor_max_velocity = { label = "Cursor-Geschwindigkeit", desc = "Maximale Cursor-Geschwindigkeit" },
  OSDSYS_cursor_acceleration = { label = "Cursor-Beschleunigung", desc = "Cursor-Beschleunigung" },
  OSDSYS_left_cursor = { label = "Text linker Cursor", desc = "Max. 19 Zeichen" },
  OSDSYS_right_cursor = { label = "Text rechter Cursor", desc = "Max. 19 Zeichen" },
  OSDSYS_menu_top_delimiter = { label = "Oberer Menue-Trenner", desc = "Max. 79 Zeichen" },
  OSDSYS_menu_bottom_delimiter = { label = "Unterer Menue-Trenner", desc = "Max. 79 Zeichen" },
  OSDSYS_num_displayed_items = { label = "Angezeigte Elemente", desc = "Anzahl sichtbarer Menueeintraege" },
  OSDSYS_selected_color = { label = "Ausgewaehlte Farbe", desc = "Hervorhebungsfarbe des Menueeintrags" },
  OSDSYS_unselected_color = { label = "Nicht ausgewaehlte Farbe", desc = "Farbe des Menueeintrags" },
  cdrom_skip_ps2logo = { label = "PS2LOGO ueberspringen", desc = "PlayStation-2-Logo beim Disc-Start ueberspringen" },
  cdrom_disable_gameid = { label = "Visuelle Spiel-ID deaktivieren", desc = "Visuelle Spiel-ID deaktivieren" },
  cdrom_use_dkwdrv = { label = "DKWDRV verwenden", desc = "DKWDRV fuer PS1-Discs verwenden" },
  ps1drv_enable_fast = { label = "PS1-Schnellladen", desc = "Schnelle PS1-Disc-Geschwindigkeit erzwingen" },
  ps1drv_enable_smooth = { label = "PS1-Texturglaettung", desc = "PS1-Texturglaettung erzwingen" },
  ps1drv_use_ps1vn = { label = "PS1VN verwenden", desc = "PS1 Video Mode Negator verwenden" },
  app_gameid = { label = "Anwendungs-Spiel-ID", desc = "Visuelle Spiel-ID fuer ELF-Dateien aktivieren" },
  path_DKWDRV_ELF = { label = "DKWDRV-Pfad", desc = "Benutzerdefinierter Pfad zu DKWDRV.ELF" },
  pad_delay = { label = "Pad-Verzoegerung", desc = "Verzoegerung vor der Auswahl der AUTOBOOT-Starttaste" },
  FastBoot = { label = "Schnellstart", desc = "Schnelle Disc-Startbehandlung aktivieren" },
  ESR_Path_E1 = { label = "ESR-Pfad E1", desc = "Primaerer ESR-Pfad" },
  ESR_Path_E2 = { label = "ESR-Pfad E2", desc = "Sekundaerer ESR-Pfad" },
  ESR_Path_E3 = { label = "ESR-Pfad E3", desc = "Tertiaerer ESR-Pfad" },
  _menu_entries = { label = "Menueeintraege bearbeiten", desc = "Benutzerdefinierte Menueeintraege bearbeiten: Name, Pfade, Argumente" },
}

-- OSDMBR.CNF Optionsbezeichnungen / Beschreibungen
strings.options_osdmbr = {
  boot_auto = { label = "Boot Auto", desc = "Standardpfade und -argumente" },
  boot_start = { label = "Boot START", desc = "Pfade und Argumente fuer die Start-Taste" },
  boot_triangle = { label = "Boot TRIANGLE", desc = "Pfade und Argumente fuer die Dreieck-Taste" },
  boot_circle = { label = "Boot CIRCLE", desc = "Pfade und Argumente fuer die Kreis-Taste" },
  boot_cross = { label = "Boot CROSS", desc = "Pfade und Argumente fuer die Kreuz-Taste" },
  boot_square = { label = "Boot SQUARE", desc = "Pfade und Argumente fuer die Quadrat-Taste" },
  cdrom_skip_ps2logo = { label = "PS2LOGO ueberspringen", desc = "PlayStation-2-Logo beim Disc-Start ueberspringen" },
  cdrom_disable_gameid = { label = "Visuelle Spiel-ID deaktivieren", desc = "Visuelle Spiel-ID deaktivieren" },
  cdrom_use_dkwdrv = { label = "DKWDRV verwenden", desc = "DKWDRV fuer PS1-Discs verwenden" },
  ps1drv_enable_fast = { label = "PS1-Schnellladen", desc = "Schnelle PS1-Disc-Geschwindigkeit erzwingen" },
  ps1drv_enable_smooth = { label = "PS1-Texturglaettung", desc = "PS1-Texturglaettung erzwingen" },
  ps1drv_use_ps1vn = { label = "PS1VN verwenden", desc = "PS1 Video Mode Negator verwenden" },
  prefer_bbn = { label = "BBN bevorzugen", desc = "PSBBN beim Neustart laden" },
  app_gameid = { label = "Anwendungs-Spiel-ID", desc = "Visuelle Spiel-ID fuer ELF-Dateien anzeigen" },
  osd_screentype = { label = "OSD-Bildschirmtyp", desc = "OSD-Bildschirmtyp erzwingen (4:3, 16:9, Vollbild)" },
  osd_language = { label = "OSD-Sprache", desc = "OSD-Sprache erzwingen (abhaengig vom Konsolenmodell)" },
}

strings.options_bbl = {
  _bbl_irx_entries = { label = "IRX-Eintraege bearbeiten", desc = "LOAD_IRX_E#-Modulpfade bearbeiten" },
}

-- eGSM-Editor
strings.egsm = {
  default_label = "Standard",
  title_id_prompt = "Titel-ID (z. B. SCES12345)",
  hint_items = { { pad = "cross", label = "Bearbeiten", row = 1 }, { pad = "select", label = "Einfuegen", row = 1 }, { pad = "square", label = "Loeschen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 }, { pad = "start", label = "Speichern", row = 2 } },
  hint_items_with_enable = { { pad = "left", label = "Vorher", row = 2 }, { pad = "", label = "", row = 2 }, { pad = "start", label = "Speichern", row = 2 }, { pad = "", label = "", row = 2 }, { pad = "right", label = "Weiter", row = 2 }, { pad = "cross", label = "Bearbeiten", row = 1 }, { pad = "triangle", label = "Aktivieren", layoutLabel = "Deaktivieren", row = 1 }, { pad = "select", label = "Einfuegen", row = 1 }, { pad = "square", label = "Loeschen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 } },
  hint_items_with_disable = { { pad = "left", label = "Vorher", row = 2 }, { pad = "", label = "", row = 2 }, { pad = "start", label = "Speichern", row = 2 }, { pad = "", label = "", row = 2 }, { pad = "right", label = "Weiter", row = 2 }, { pad = "cross", label = "Bearbeiten", row = 1 }, { pad = "triangle", label = "Deaktivieren", layoutLabel = "Deaktivieren", row = 1 }, { pad = "select", label = "Einfuegen", row = 1 }, { pad = "square", label = "Loeschen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 } },
  value_edit_title = "eGSM-Wert",
  result_prefix = "Wert: ",
  video_header = "Videomodus",
  video_240p = "240/288p erzwingen",
  video_480p = "480/576p erzwingen",
  video_1080i_1x = "1080i erzwingen (1x Skalierung)",
  video_1080i_2x = "1080i erzwingen (2x Skalierung)",
  video_1080i_3x = "1080i erzwingen (3x Skalierung)",
  compat_header = "Kompatibilitaet",
  compat_none = "Keine",
  compat_1 = "Field Flipping Typ 1 (wie OPL)",
  compat_2 = "Field Flipping Typ 2",
  compat_3 = "Field Flipping Typ 3",
  value_edit_hint = { { pad = "cross", label = "Waehlen", row = 1 }, { pad = "circle", label = "Zurueck", row = 1 } },
}

-- Gemeinsame Tabelle fuer alle Konfigurationstypen
strings.options = {}
for k, v in pairs(strings.options_osdmenu or {}) do strings.options[k] = v end
for k, v in pairs(strings.options_osdmbr or {}) do strings.options[k] = v end
for k, v in pairs(strings.options_bbl or {}) do strings.options[k] = v end
for k, v in pairs(strings.options_osdgsm or {}) do strings.options[k] = v end

-- CDROM-Optionen
strings.cdrom_options = {
  nologo = { label = "PS2LOGO ueberspringen", desc = "PlayStation-2-Logo beim Disc-Start ueberspringen" },
  nogameid = { label = "Visuelle Spiel-ID deaktivieren", desc = "Visuelle Spiel-ID deaktivieren" },
  dkwdrv = { label = "DKWDRV verwenden", desc = "DKWDRV fuer PS1-Discs verwenden" },
  ps1fast = { label = "PS1-Schnellladen", desc = "Schnelle PS1-Disc-Geschwindigkeit erzwingen" },
  ps1smooth = { label = "PS1-Texturglaettung", desc = "PS1-Texturglaettung erzwingen" },
  ps1vneg = { label = "PS1VN verwenden", desc = "PS1 Video Mode Negator verwenden" },
}

-- Texteingabe
strings.text_input = {
  hint_items = { { pad = "cross", label = "Bestaet.", row = 1 }, { pad = "triangle", label = "Grossschr.", row = 1 }, { pad = "square", label = "Loeschen", row = 1 }, { pad = "circle", label = "Abbrechen", row = 1 }, { pad = "L1", label = "Links", row = 2 }, { pad = "start", label = "Fertig", row = 2 }, { pad = "R1", label = "Rechts", row = 2 } },
  hint_items_title_id = { { pad = "cross", label = "Bestaet.", row = 1 }, { pad = "square", label = "Loeschen", row = 1 }, { pad = "circle", label = "Abbrechen", row = 1 }, { pad = "L1", label = "Links", row = 2 }, { pad = "start", label = "Fertig", row = 2 }, { pad = "R1", label = "Rechts", row = 2 } },
}

return strings
