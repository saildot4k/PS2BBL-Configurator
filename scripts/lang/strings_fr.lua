--[[
  Chaînes d'interface françaises pour le configurateur.
  Copier vers strings_XX.lua (par ex. strings_de.lua) et traduire les valeurs; garder les clés inchangées.
  Hint _items: chaque entrée est { pad = "cross", label = "Entrer" }. row optionnel = 1 (bas) ou 2 (haut); si un élément a row=2, l'affectation des lignes vient du fichier de langue, sinon les 4 premiers vont en bas et le reste en haut.
]]

local strings = {}
strings.language_name = "Francais"

-- Flux principal (main, choose_mc, select_config, initHdd, open, choose_load)
strings.main = {
  main_title = "R3CONFIGURATOR",
  main_sub = "Choisissez l'une des options ci-dessous",
  version_unknown = "inconnue",
  main_hint_items = { { pad = "up", label = "Haut" }, { pad = "cross", label = "Entrer" }, { pad = "down", label = "Bas" }, { pad = "start", label = "Quitter", row = 2 } },
  main_hint_items_with_lang = { { pad = "up", label = "Haut", layoutLabel = "Langue -", row = 1 }, { pad = "cross", label = "Entrer", layoutLabel = "Entrer", row = 1 }, { pad = "down", label = "Bas", layoutLabel = "Langue +", row = 1 }, { pad = "L1", label = "Langue -", layoutLabel = "Langue -", row = 2 }, { pad = "start", label = "Quitter", layoutLabel = "Entrer", row = 2 }, { pad = "R1", label = "Langue +", layoutLabel = "Langue +", row = 2 } },
  main_ps2bbl_mc = "PS2BBL",
  main_psxbbl_mc = "PSXBBL",
  main_osdmenu = "OSDMenu",
  main_osdmenu_mbr = "OSDMenu MBR",
  main_hosdmenu = "HOSDMenu",
  main_egsm = "eGSM",
  main_freemcboot = "FreeMCBoot",
  main_freehddboot = "FreeHDBoot",
  main_exit = "Quitter vers le navigateur",
  main_exit_prompt = "Quitter vers le navigateur ?",
  main_exit_hint_items = { { pad = "cross", label = "Oui" }, { pad = "circle", label = "Non" } },
  no_memory_card = "Aucune carte memoire detectee",
  insert_mc = "Inserez une carte memoire et reessayez",
  circle_back_items = { { pad = "circle", label = "Retour" } },
  select_memory_card = "Selectionnez la carte memoire pour charger la config",
  config_card_hint = "Le fichier de configuration sera cree s'il n'existe pas",
  cross_select_circle_back_items = { { pad = "cross", label = "Entrer" }, { pad = "circle", label = "Retour" } },
  memory_card_1_slot = "Carte memoire 1",
  memory_card_2_slot = "Carte memoire 2",
  which_file = "Quel fichier ?",
  init_hdd_title = "Initialisation des modules HDD...",
  init_hdd_sub = "Chargement des pilotes HDD et montage de __sysconf",
  no_location = "Aucun emplacement pour ce type de fichier",
  hdd_not_found = "Assurez-vous que le HDD est connecte et formate",
  cross_back_items = { { pad = "cross", label = "Retour" } },
  failed_to_load = "Echec du chargement : ",
  cross_load_circle_back_items = { { pad = "cross", label = "Charger" }, { pad = "circle", label = "Retour" } },
  select_config_ps2bbl_ini = "PS2BBL.INI",
  select_config_psxbbl_ini = "PSXBBL.INI",
  select_config_browse_ini = "Parcourir CONFIG.INI (CWD)",
  select_config_osdmenu_cnf = "OSDMENU.CNF",
  select_config_osdmbr_cnf = "OSDMBR.CNF",
  select_config_osdgsm_cnf = "OSDGSM.CNF",
}

-- Editeur
strings.editor = {
  saved = "Enregistre",
  cross_open_circle_back_items = { { pad = "cross", label = "Entrer" }, { pad = "start", label = "Sauver" }, { pad = "circle", label = "Retour" } },
  start_save_circle_back_items = { { pad = "start", label = "Sauver" }, { pad = "circle", label = "Retour" } },
  hint_edit_items = { { pad = "cross", label = "Modifier", row = 1 }, { pad = "triangle", label = "Reinit.", row = 1 }, { pad = "start", label = "Sauver", row = 1 }, { pad = "circle", label = "Retour", row = 1 }, { pad = "left", label = "-1", row = 2 }, { pad = "L1", label = "-10", row = 2 }, { pad = "L2", label = "-50", row = 2 }, { pad = "R2", label = "+50", row = 2 }, { pad = "R1", label = "+10", row = 2 }, { pad = "right", label = "+1", row = 2 } },
  no_option_list = "Aucune liste d'options pour ce type de fichier",
  save_config_to = "Enregistrer la config dans",
  save_failed = "Echec de l'enregistrement",
  no_save_location = "Aucun emplacement de sauvegarde",
  error_write_failed = "Echec d'ecriture",
  error_read_failed = "Echec de lecture",
  error_cannot_get_size = "Impossible d'obtenir la taille du fichier",
  error_cannot_open = "Impossible d'ouvrir ",
  error_cannot_open_for_write = "Impossible d'ouvrir en ecriture ",
  cross_save_circle_cancel_items = { { pad = "cross", label = "Sauver" }, { pad = "circle", label = "Annuler" } },
  leave_save_prompt = "Enregistrer les modifications avant de quitter ?",
  leave_save_hint_items = { { pad = "cross", label = "Sauver" }, { pad = "triangle", label = "Ignorer" }, { pad = "circle", label = "Annuler" } },
  edit_color_suffix = " - Modifier la couleur",
  red = "Rouge",
  green = "Vert",
  blue = "Bleu",
  alpha = "Alpha",
  color_edit_hint_items = { { pad = "cross", label = "Appliquer", row = 1 }, { pad = "up", label = "Haut", row = 1 }, { pad = "down", label = "Bas", row = 1 }, { pad = "circle", label = "Retour", row = 1 }, { pad = "left", label = "-1", row = 2 }, { pad = "L1", label = "-10", row = 2 }, { pad = "L2", label = "-50", row = 2 }, { pad = "R2", label = "+50", row = 2 }, { pad = "R1", label = "+10", row = 2 }, { pad = "right", label = "+1", row = 2 } },
}

-- Entrees du menu
strings.menu_entries = {
  edit_menu_entries = "Modifier les entrees du menu",
  edit_irx_entries = "Modifier les entrees IRX",
  item = "Element ",
  hint_items = { { pad = "cross", label = "Entrer", row = 1 }, { pad = "select", label = "Inserer", row = 1 }, { pad = "square", label = "Supprimer", row = 1 }, { pad = "circle", label = "Retour", row = 1 }, { pad = "left", label = "Precedent", row = 2 }, { pad = "L1", label = "Haut", row = 2 }, { pad = "start", label = "Sauver", row = 2 }, { pad = "R1", label = "Bas", row = 2 }, { pad = "right", label = "Suivant", row = 2 } },
  hint_items_with_enable = { { pad = "cross", label = "Entrer", row = 1 }, { pad = "triangle", label = "Activer", layoutLabel = "Desactiver", row = 1 }, { pad = "select", label = "Inserer", row = 1 }, { pad = "square", label = "Supprimer", row = 1 }, { pad = "circle", label = "Retour", row = 1 }, { pad = "left", label = "Precedent", row = 2 }, { pad = "L1", label = "Haut", row = 2 }, { pad = "start", label = "Sauver", row = 2 }, { pad = "R1", label = "Bas", row = 2 }, { pad = "right", label = "Suivant", row = 2 } },
  hint_items_with_disable = { { pad = "cross", label = "Entrer", row = 1 }, { pad = "triangle", label = "Desactiver", layoutLabel = "Desactiver", row = 1 }, { pad = "select", label = "Inserer", row = 1 }, { pad = "square", label = "Supprimer", row = 1 }, { pad = "circle", label = "Retour", row = 1 }, { pad = "left", label = "Precedent", row = 2 }, { pad = "L1", label = "Haut", row = 2 }, { pad = "start", label = "Sauver", row = 2 }, { pad = "R1", label = "Bas", row = 2 }, { pad = "right", label = "Suivant", row = 2 } },
  irx_hint_items = { { pad = "", label = "", row = 2 }, { pad = "L1", label = "Haut", row = 2 }, { pad = "start", label = "Sauver", row = 2 }, { pad = "R1", label = "Bas", row = 2 }, { pad = "", label = "", row = 2 }, { pad = "cross", label = "Entrer", row = 1 }, { pad = "triangle", label = "Desactiver", row = 1 }, { pad = "select", label = "Inserer", row = 1 }, { pad = "square", label = "Supprimer", row = 1 }, { pad = "circle", label = "Retour", row = 1 } },
  irx_hint_items_with_enable = { { pad = "", label = "", row = 2 }, { pad = "L1", label = "Haut", row = 2 }, { pad = "start", label = "Sauver", row = 2 }, { pad = "R1", label = "Bas", row = 2 }, { pad = "", label = "", row = 2 }, { pad = "cross", label = "Entrer", row = 1 }, { pad = "triangle", label = "Activer", layoutLabel = "Desactiver", row = 1 }, { pad = "select", label = "Inserer", row = 1 }, { pad = "square", label = "Supprimer", row = 1 }, { pad = "circle", label = "Retour", row = 1 } },
  irx_hint_items_with_disable = { { pad = "", label = "", row = 2 }, { pad = "L1", label = "Haut", row = 2 }, { pad = "start", label = "Sauver", row = 2 }, { pad = "R1", label = "Bas", row = 2 }, { pad = "", label = "", row = 2 }, { pad = "cross", label = "Entrer", row = 1 }, { pad = "triangle", label = "Desactiver", layoutLabel = "Desactiver", row = 1 }, { pad = "select", label = "Inserer", row = 1 }, { pad = "square", label = "Supprimer", row = 1 }, { pad = "circle", label = "Retour", row = 1 } },
  entry_index = "Entree ",
  name = "Nom : ",
  paths = "Chemins : ",
  args = "args : ",
  none = "aucun",
  path_s = " chemin(s)",
  arg_s = " arg(s)",
  cross_select_circle_back_items = { { pad = "cross", label = "Entrer" }, { pad = "circle", label = "Retour" } },
  edit_name = "Modifier le nom",
  paths_label = "Chemins",
  launch_disc_options = "Options de lancement du disque",
  arguments = "Arguments",
  entry_name_prompt = "Nom de l'entree",
  add_entry_label = "Nouvelle entree",
  launch_disc_options_title = "Options de lancement du disque",
  launch_disc_options_sub = "Ces options remplacent le comportement de lancement du disque par defaut",
  paths_for_entry_title = "Chemins pour %s (entree %s)",
  paths_hint_items = { { pad = "cross", label = "Modifier", row = 1 }, { pad = "square", label = "Supprimer", row = 1 }, { pad = "circle", label = "Retour", row = 1 }, { pad = "L1", label = "Haut", row = 2 }, { pad = "select", label = "Ajouter", row = 2 }, { pad = "R1", label = "Bas", row = 2 } },
  paths_hint_items_with_enable = { { pad = "cross", label = "Modifier", row = 1 }, { pad = "triangle", label = "Activer", layoutLabel = "Desactiver", row = 1 }, { pad = "square", label = "Supprimer", row = 1 }, { pad = "circle", label = "Retour", row = 1 }, { pad = "L1", label = "Haut", row = 2 }, { pad = "select", label = "Ajouter", row = 2 }, { pad = "R1", label = "Bas", row = 2 } },
  paths_hint_items_with_disable = { { pad = "cross", label = "Modifier", row = 1 }, { pad = "triangle", label = "Desactiver", layoutLabel = "Desactiver", row = 1 }, { pad = "square", label = "Supprimer", row = 1 }, { pad = "circle", label = "Retour", row = 1 }, { pad = "L1", label = "Haut", row = 2 }, { pad = "select", label = "Ajouter", row = 2 }, { pad = "R1", label = "Bas", row = 2 } },
  args_for_entry_title = "Arguments pour %s (entree %s)",
  args_hint_items = { { pad = "cross", label = "Modifier", row = 1 }, { pad = "square", label = "Supprimer", row = 1 }, { pad = "circle", label = "Retour", row = 1 }, { pad = "L1", label = "Haut", row = 2 }, { pad = "select", label = "Ajouter", row = 2 }, { pad = "R1", label = "Bas", row = 2 } },
  args_hint_items_with_enable = { { pad = "cross", label = "Modifier", row = 1 }, { pad = "triangle", label = "Activer", layoutLabel = "Desactiver", row = 1 }, { pad = "square", label = "Supprimer", row = 1 }, { pad = "circle", label = "Retour", row = 1 }, { pad = "L1", label = "Haut", row = 2 }, { pad = "select", label = "Ajouter", row = 2 }, { pad = "R1", label = "Bas", row = 2 } },
  args_hint_items_with_disable = { { pad = "cross", label = "Modifier", row = 1 }, { pad = "triangle", label = "Desactiver", layoutLabel = "Desactiver", row = 1 }, { pad = "square", label = "Supprimer", row = 1 }, { pad = "circle", label = "Retour", row = 1 }, { pad = "L1", label = "Haut", row = 2 }, { pad = "select", label = "Ajouter", row = 2 }, { pad = "R1", label = "Bas", row = 2 } },
  cdrom_hint = "Entree de lancement du disque : utilisez les options de lancement du disque pour les drapeaux",
  cdrom_toggle_hint_items = { { pad = "cross", label = "Basculer", row = 1 }, { pad = "circle", label = "Retour", row = 1 }, { pad = "left", label = "Precedent", row = 2 }, { pad = "right", label = "Suivant", row = 2 } },
  new_argument_prompt = "Nouvel argument",
  edit_argument_prompt = "Modifier l'argument",
}

-- Selecteur de chemin
strings.path_picker = {
  choose_device = "Choisir le peripherique",
  add_path_choose_device = "Ajouter un chemin : choisir le peripherique",
  bbl_build_device_hint = "Selectionnez uniquement les peripheriques pris en charge par votre build PS?BBL.",
  enter_path_manually = "Saisir le chemin manuellement",
  bbl_cmd_cdvd = "$CDVD (Lancer le disque)",
  bbl_cmd_cdvd_no_logo = "$CDVD_NO_PS2LOGO (Lancer le disque sans logo)",
  bbl_cmd_osdsys = "$OSDSYS (Lancer le navigateur)",
  fmcb_cmd_osdsys = "OSDSYS (Lancer le navigateur)",
  bbl_cmd_credits = "$CREDITS",
  bbl_cmd_hddchecker = "$HDDCHECKER (build HDD)",
  bbl_cmd_runkelf = "$RUNKELF:<chemin>",
  bbl_cmd_runkelf_prompt = "Saisissez le chemin KELF pour $RUNKELF :",
  enter_path_prompt = "Saisir le chemin",
  cross_select_circle_back_items = { { pad = "cross", label = "Entrer" }, { pad = "circle", label = "Retour" } },
  select_hdd_partition = "Selectionner la partition HDD",
  no_partitions = "Aucune partition (HDD connecte ?)",
  cross_open_circle_back_items = { { pad = "cross", label = "Entrer" }, { pad = "circle", label = "Retour" } },
  cross_open_square_patinfo_circle_back_items = { { pad = "cross", label = "Entrer" }, { pad = "square", label = "PATINFO" }, { pad = "circle", label = "Retour" } },
  no_elf_files = "Aucun fichier ELF ni dossier",
  no_ini_files = "Aucun fichier INI ni dossier",
  cross_select_file_items = { { pad = "cross", label = "Selectionner" }, { pad = "circle", label = "Retour" } },
  cross_select_create_circle_back_items = { { pad = "cross", label = "Selectionner" }, { pad = "select", label = "Creer CONFIG.INI" }, { pad = "circle", label = "Retour" } },
  no_devices = "Aucun peripherique",
  waiting_for_device_drivers = "En attente du peripherique...",
  circle_back_items = { { pad = "circle", label = "Retour" } },
  device_timeout = "%DEVICE% introuvable",
  irx_extension_required = "Le chemin doit se terminer par .irx",
  wildcard_confirm_title = "Utiliser le chemin comme joker ?",
  wildcard_confirm_hint = { { pad = "cross", label = "Oui" }, { pad = "circle", label = "Non" } },
}

-- Noms des peripheriques et entrees speciales. Utilises par OSDMenu et le selecteur MBR / chemin.
strings.devices = {
  memory_card_1 = "Carte memoire 1",
  memory_card_2 = "Carte memoire 2",
  launch_disc = "Lancer le disque avec remplacement",
  dvd_player = "Lecteur DVD",
  osd = "OSDSYS",
  shutdown = "Eteindre",
  hosdsys = "Navigateur 2.0 / HOSDMenu",
  psbbn = "PlayStation Broadband Navigator",
  usb_storage_0 = "Stockage de masse USB 1",
  usb_storage_1 = "Stockage de masse USB 2",
  mmce_0 = "MMCE dans l'emplacement 1",
  mmce_1 = "MMCE dans l'emplacement 2",
  mx4sio_sd = "MX4SIO",
  exfat_hdd_mass0 = "Disque dur formate exFAT",
  hdd = "Disque dur formate APA",
}

-- Jetons communs
strings.common = {
  on = "Active",
  off = "Desactive",
  not_set = "(non defini)",
  empty = "(vide)",
  second = "seconde",
  seconds = "secondes",
  enter_text = "Saisir du texte",
  hint_prev = "Precedent",
  hint_next = "Suivant",
}

-- Noms des categories (pour l'editeur OSDMENU, index base 1)
strings.categories = {
  [1] = "Modificateurs du comportement OSD",
  [2] = "Options du menu OSD personnalise",
  [3] = "Modificateurs de lancement disque et application",
  [4] = "Modifier les entrees du menu",
}

strings.categories_freemcboot = {
  [1] = "Modificateurs du comportement OSD",
  [2] = "Options du menu OSD personnalise",
  [3] = "Options du disque",
  [4] = "AUTOBOOT",
  [5] = "TOUCHES DE LANCEMENT",
  [6] = "Modifier les entrees du menu",
}

-- Libelles et descriptions des options OSDMENU.CNF (par cle d'option)
strings.options_osdmenu = {
  OSDSYS_video_mode = { label = "Forcer le mode video", desc = "Forcer le mode video OSD" },
  OSDSYS_region = { label = "Forcer la region", desc = "Forcer la region OSD" },
  OSDSYS_Skip_Disc = { label = "Ignorer le disque", desc = "Ignorer le lancement automatique du disque" },
  OSDSYS_Skip_Logo = { label = "Ignorer l'intro", desc = "Ignorer l'animation d'introduction SCE" },
  OSDSYS_Inner_Browser = { label = "Navigateur interne", desc = "Demarrer dans le navigateur de carte memoire" },
  OSDSYS_Skip_MC = { label = "Ignorer la MC", desc = "Ignorer la verification de la carte memoire dans le navigateur" },
  OSDSYS_Skip_HDD = { label = "Ignorer le HDD", desc = "Ignorer la verification du HDD dans le navigateur" },
  Debug_Screen = { label = "Ecran de debogage", desc = "Activer la sortie de debogage a l'ecran" },
  hacked_OSDSYS = { label = "OSD modifie", desc = "Activer le mode de menu OSD patche FHDB" },
  OSDSYS_custom_menu = { label = "Menu personnalise", desc = "Activer le menu personnalise" },
  OSDSYS_scroll_menu = { label = "Defilement infini", desc = "Activer le defilement infini" },
  OSDSYS_menu_x = { label = "Menu X", desc = "Position X du menu personnalise" },
  OSDSYS_menu_y = { label = "Menu Y", desc = "Position Y du menu personnalise" },
  OSDSYS_enter_x = { label = "Entrer X", desc = "Position X du bouton Entrer" },
  OSDSYS_enter_y = { label = "Entrer Y", desc = "Position Y du bouton Entrer" },
  OSDSYS_version_x = { label = "Version X", desc = "Position X du bouton Version" },
  OSDSYS_version_y = { label = "Version Y", desc = "Position Y du bouton Version" },
  OSDSYS_cursor_max_velocity = { label = "Vitesse du curseur", desc = "Vitesse maximale du curseur" },
  OSDSYS_cursor_acceleration = { label = "Acceleration du curseur", desc = "Acceleration du curseur" },
  OSDSYS_left_cursor = { label = "Texte du curseur gauche", desc = "Max 19 caracteres" },
  OSDSYS_right_cursor = { label = "Texte du curseur droit", desc = "Max 19 caracteres" },
  OSDSYS_menu_top_delimiter = { label = "Delimiteur haut du menu", desc = "Max 79 caracteres" },
  OSDSYS_menu_bottom_delimiter = { label = "Delimiteur bas du menu", desc = "Max 79 caracteres" },
  OSDSYS_num_displayed_items = { label = "Elements affiches", desc = "Nombre d'elements du menu visibles" },
  OSDSYS_selected_color = { label = "Couleur selectionnee", desc = "Couleur de surbrillance de l'entree du menu" },
  OSDSYS_unselected_color = { label = "Couleur non selectionnee", desc = "Couleur de l'entree du menu" },
  cdrom_skip_ps2logo = { label = "Ignorer PS2LOGO", desc = "Ignorer le logo PlayStation 2 au demarrage du disque" },
  cdrom_disable_gameid = { label = "Desactiver l'ID visuel du jeu", desc = "Desactiver l'ID visuel du jeu" },
  cdrom_use_dkwdrv = { label = "Utiliser DKWDRV", desc = "Utiliser DKWDRV pour les disques PS1" },
  ps1drv_enable_fast = { label = "Chargement rapide PS1", desc = "Forcer la vitesse rapide du disque PS1" },
  ps1drv_enable_smooth = { label = "Lissage des textures PS1", desc = "Forcer le lissage des textures PS1" },
  ps1drv_use_ps1vn = { label = "Utiliser PS1VN", desc = "Utiliser le neutraliseur de mode video PS1" },
  app_gameid = { label = "ID jeu application", desc = "Activer l'ID visuel du jeu pour les fichiers ELF" },
  path_DKWDRV_ELF = { label = "Chemin DKWDRV", desc = "Chemin personnalise vers DKWDRV.ELF" },
  pad_delay = { label = "Delai manette", desc = "Delai avant la selection de la touche de lancement AUTOBOOT" },
  FastBoot = { label = "Demarrage rapide", desc = "Activer la gestion rapide du demarrage du disque" },
  ESR_Path_E1 = { label = "Chemin ESR E1", desc = "Chemin ESR principal" },
  ESR_Path_E2 = { label = "Chemin ESR E2", desc = "Chemin ESR secondaire" },
  ESR_Path_E3 = { label = "Chemin ESR E3", desc = "Chemin ESR tertiaire" },
  _menu_entries = { label = "Modifier les entrees du menu", desc = "Modifier les entrees du menu personnalise : nom, chemins, arguments" },
}

-- Libelles / descriptions des options OSDMBR.CNF
strings.options_osdmbr = {
  boot_auto = { label = "Demarrage auto", desc = "Chemins et arguments par defaut" },
  boot_start = { label = "Demarrage START", desc = "Chemins et arguments pour le bouton start" },
  boot_triangle = { label = "Demarrage TRIANGLE", desc = "Chemins et arguments pour le bouton triangle" },
  boot_circle = { label = "Demarrage CIRCLE", desc = "Chemins et arguments pour le bouton circle" },
  boot_cross = { label = "Demarrage CROSS", desc = "Chemins et arguments pour le bouton cross" },
  boot_square = { label = "Demarrage SQUARE", desc = "Chemins et arguments pour le bouton square" },
  cdrom_skip_ps2logo = { label = "Ignorer PS2LOGO", desc = "Ignorer le logo PlayStation 2 au demarrage du disque" },
  cdrom_disable_gameid = { label = "Desactiver l'ID visuel du jeu", desc = "Desactiver l'ID visuel du jeu" },
  cdrom_use_dkwdrv = { label = "Utiliser DKWDRV", desc = "Utiliser DKWDRV pour les disques PS1" },
  ps1drv_enable_fast = { label = "Chargement rapide PS1", desc = "Forcer la vitesse rapide du disque PS1" },
  ps1drv_enable_smooth = { label = "Lissage des textures PS1", desc = "Forcer le lissage des textures PS1" },
  ps1drv_use_ps1vn = { label = "Utiliser PS1VN", desc = "Utiliser le neutraliseur de mode video PS1" },
  prefer_bbn = { label = "Preferer BBN", desc = "Charger PSBBN lors du redemarrage" },
  app_gameid = { label = "ID jeu application", desc = "Afficher l'ID visuel du jeu pour les fichiers ELF" },
  osd_screentype = { label = "Type d'ecran OSD", desc = "Forcer le type d'ecran OSD (4:3, 16:9, plein ecran)" },
  osd_language = { label = "Langue OSD", desc = "Forcer la langue OSD (depend du modele de console)" },
}

strings.options_bbl = {
  _bbl_irx_entries = { label = "Modifier les entrees IRX", desc = "Modifier les chemins des modules LOAD_IRX_E#" },
}

-- Editeur eGSM (ecran unique : valeurs par defaut + remplacements par titre)
strings.egsm = {
  default_label = "Par defaut",
  title_id_prompt = "ID de titre (ex. SCES12345)",
  hint_items = { { pad = "cross", label = "Modifier", row = 1 }, { pad = "select", label = "Inserer", row = 1 }, { pad = "square", label = "Supprimer", row = 1 }, { pad = "circle", label = "Retour", row = 1 }, { pad = "start", label = "Sauver", row = 2 } },
  hint_items_with_enable = { { pad = "left", label = "Precedent", row = 2 }, { pad = "", label = "", row = 2 }, { pad = "start", label = "Sauver", row = 2 }, { pad = "", label = "", row = 2 }, { pad = "right", label = "Suivant", row = 2 }, { pad = "cross", label = "Modifier", row = 1 }, { pad = "triangle", label = "Activer", layoutLabel = "Desactiver", row = 1 }, { pad = "select", label = "Inserer", row = 1 }, { pad = "square", label = "Supprimer", row = 1 }, { pad = "circle", label = "Retour", row = 1 } },
  hint_items_with_disable = { { pad = "left", label = "Precedent", row = 2 }, { pad = "", label = "", row = 2 }, { pad = "start", label = "Sauver", row = 2 }, { pad = "", label = "", row = 2 }, { pad = "right", label = "Suivant", row = 2 }, { pad = "cross", label = "Modifier", row = 1 }, { pad = "triangle", label = "Desactiver", layoutLabel = "Desactiver", row = 1 }, { pad = "select", label = "Inserer", row = 1 }, { pad = "square", label = "Supprimer", row = 1 }, { pad = "circle", label = "Retour", row = 1 } },
  value_edit_title = "Valeur eGSM",
  result_prefix = "Valeur : ",
  video_header = "Mode video",
  video_240p = "Forcer 240/288p",
  video_480p = "Forcer 480/576p",
  video_1080i_1x = "Forcer 1080i (echelle 1x)",
  video_1080i_2x = "Forcer 1080i (echelle 2x)",
  video_1080i_3x = "Forcer 1080i (echelle 3x)",
  compat_header = "Compatibilite",
  compat_none = "Aucune",
  compat_1 = "Inversion de champ type 1 (comme OPL)",
  compat_2 = "Inversion de champ type 2",
  compat_3 = "Inversion de champ type 3",
  value_edit_hint = { { pad = "cross", label = "Selectionner", row = 1 }, { pad = "circle", label = "Retour", row = 1 } },
}

-- Table de recherche unique pour tous les types de configuration
strings.options = {}
for k, v in pairs(strings.options_osdmenu or {}) do strings.options[k] = v end
for k, v in pairs(strings.options_osdmbr or {}) do strings.options[k] = v end
for k, v in pairs(strings.options_bbl or {}) do strings.options[k] = v end
for k, v in pairs(strings.options_osdgsm or {}) do strings.options[k] = v end

-- Libelles / descriptions des options CDROM
strings.cdrom_options = {
  nologo = { label = "Ignorer PS2LOGO", desc = "Ignorer le logo PlayStation 2 au demarrage du disque" },
  nogameid = { label = "Desactiver l'ID visuel du jeu", desc = "Desactiver l'ID visuel du jeu" },
  dkwdrv = { label = "Utiliser DKWDRV", desc = "Utiliser DKWDRV pour les disques PS1" },
  ps1fast = { label = "Chargement rapide PS1", desc = "Forcer la vitesse rapide du disque PS1" },
  ps1smooth = { label = "Lissage des textures PS1", desc = "Forcer le lissage des textures PS1" },
  ps1vneg = { label = "Utiliser PS1VN", desc = "Utiliser le neutraliseur de mode video PS1" },
}

-- Saisie de texte (clavier)
strings.text_input = {
  hint_items = { { pad = "cross", label = "Entrer", row = 1 }, { pad = "triangle", label = "Majusc.", row = 1 }, { pad = "square", label = "Effacer", row = 1 }, { pad = "circle", label = "Annuler", row = 1 }, { pad = "L1", label = "Gauche", row = 2 }, { pad = "start", label = "Termine", row = 2 }, { pad = "R1", label = "Droite", row = 2 } },
  hint_items_title_id = { { pad = "cross", label = "Entrer", row = 1 }, { pad = "square", label = "Effacer", row = 1 }, { pad = "circle", label = "Annuler", row = 1 }, { pad = "L1", label = "Gauche", row = 2 }, { pad = "start", label = "Termine", row = 2 }, { pad = "R1", label = "Droite", row = 2 } },
}

return strings
