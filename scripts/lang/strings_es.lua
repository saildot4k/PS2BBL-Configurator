--[[
  Cadenas de interfaz de usuario en español para el configurador.
  Copiar a strings_XX.lua (ej. strings_fr.lua) y traducir los valores; mantener las claves sin cambios.
  Sugerencia _items: cada entrada es { pad = "cross", label = "Enter" }. Fila opcional = 1 (abajo) o 2 (arriba); si algún elemento tiene row=2, la asignación de fila es desde el idioma, de lo contrario, los primeros 4 van abajo, el resto arriba.
]]

local strings = {}

-- Flujo principal (main, choose_mc, select_config, initHdd, open, choose_load)
strings.main = {
  main_title = "Configurador OSDMenu",
  main_sub = "Elige una de las opciones a continuación",
  version_unknown = "desconocido",
  main_hint_items = { { pad = "up", label = "Arriba" }, { pad = "cross", label = "Entrar" }, { pad = "down", label = "Abajo" }, { pad = "start", label = "Salir", row = 2 } },
  main_hint_items_with_lang = { { pad = "up", label = "Arriba" }, { pad = "cross", label = "Entrar" }, { pad = "down", label = "Abajo" }, { pad = "L1", label = "Idioma", row = 2 }, { pad = "start", label = "Guardar", row = 2 }, { pad = "R1", label = "Idioma", row = 2 } },
  main_osdmenu_mc = "OSDMenu",
  main_hosdmenu_hdd = "HOSDMenu",
  main_osdmenu_mbr = "OSDMenu MBR",
  main_exit = "Salir al navegador",
  main_exit_prompt = "¿Salir al navegador?",
  main_exit_hint_items = { { pad = "cross", label = "Sí" }, { pad = "circle", label = "No" } },
  no_memory_card = "No se encontró tarjeta de memoria",
  insert_mc = "Inserta una tarjeta de memoria e inténtalo de nuevo",
  circle_back_items = { { pad = "circle", label = "Atrás" } },
  select_memory_card = "Selecciona la tarjeta de memoria para cargar la configuración",
  config_card_hint = "El archivo de configuración se creará si no existe",
  cross_select_circle_back_items = { { pad = "cross", label = "Entrar" }, { pad = "circle", label = "Atrás" } },
  memory_card_1_slot = "Tarjeta de Memoria 1",
  memory_card_2_slot = "Tarjeta de Memoria 2",
  which_file = "¿Qué archivo?",
  init_hdd_title = "Inicializando módulos HDD...",
  init_hdd_sub = "Cargando controladores HDD y montando __sysconf",
  no_location = "No hay ubicación para este tipo de archivo",
  hdd_not_found = "Asegúrate de que el HDD esté conectado y formateado",
  cross_back_items = { { pad = "cross", label = "Atrás" } },
  failed_to_load = "Error al cargar: ",
  cross_load_circle_back_items = { { pad = "cross", label = "Cargar" }, { pad = "circle", label = "Atrás" } },
  select_config_osdmenu_cnf = "OSDMENU.CNF",
  select_config_osdmbr_cnf = "OSDMBR.CNF",
  select_config_osdgsm_cnf = "OSDGSM.CNF",
}

-- Editor
strings.editor = {
  saved = "Guardado",
  cross_open_circle_back_items = { { pad = "cross", label = "Entrar" }, { pad = "start", label = "Guardar" }, { pad = "circle", label = "Atrás" } },
  start_save_circle_back_items = { { pad = "start", label = "Guardar" }, { pad = "circle", label = "Atrás" } },
  hint_edit_items = { { pad = "cross", label = "Editar", row = 1 }, { pad = "triangle", label = "Restablecer", row = 1 }, { pad = "start", label = "Guardar", row = 1 }, { pad = "circle", label = "Atrás", row = 1 }, { pad = "left", label = "-1", row = 2 }, { pad = "L1", label = "-10", row = 2 }, { pad = "L2", label = "-50", row = 2 }, { pad = "R2", label = "+50", row = 2 }, { pad = "R1", label = "+10", row = 2 }, { pad = "right", label = "+1", row = 2 } },
  no_option_list = "No hay lista de opciones para este tipo de archivo",
  save_config_to = "Guardar configuración en",
  save_failed = "Error al guardar",
  no_save_location = "No hay ubicación para guardar",
  error_write_failed = "Error de escritura",
  error_read_failed = "Error de lectura",
  error_cannot_get_size = "No se puede obtener el tamaño del archivo",
  error_cannot_open = "No se puede abrir ",
  error_cannot_open_for_write = "No se puede abrir para escribir ",
  cross_save_circle_cancel_items = { { pad = "cross", label = "Guardar" }, { pad = "circle", label = "Cancelar" } },
  leave_save_prompt = "¿Guardar cambios antes de salir?",
  leave_save_hint_items = { { pad = "cross", label = "Guardar" }, { pad = "triangle", label = "Descartar" }, { pad = "circle", label = "Cancelar" } },
  edit_color_suffix = " — Editar color",
  red = "Rojo",
  green = "Verde",
  blue = "Azul",
  alpha = "Alfa",
  color_edit_hint_items = { { pad = "cross", label = "Aplicar", row = 1 }, { pad = "up", label = "Arriba", row = 1 }, { pad = "down", label = "Abajo", row = 1 }, { pad = "circle", label = "Atrás", row = 1 }, { pad = "left", label = "-1", row = 2 }, { pad = "L1", label = "-10", row = 2 }, { pad = "L2", label = "-50", row = 2 }, { pad = "R2", label = "+50", row = 2 }, { pad = "R1", label = "+10", row = 2 }, { pad = "right", label = "+1", row = 2 } },
}

-- Entradas del menú
strings.menu_entries = {
  edit_menu_entries = "Editar entradas del menú",
  item = "Elemento ",
  hint_items = { { pad = "cross", label = "Entrar", row = 1 }, { pad = "select", label = "Insertar", row = 1 }, { pad = "square", label = "Eliminar", row = 1 }, { pad = "circle", label = "Atrás", row = 1 }, { pad = "left", label = "Izquierda", row = 2 }, { pad = "L1", label = "Arriba", row = 2 }, { pad = "start", label = "Guardar", row = 2 }, { pad = "R1", label = "Abajo", row = 2 }, { pad = "right", label = "Derecha", row = 2 } },
  hint_items_with_enable = { { pad = "cross", label = "Entrar", row = 1 }, { pad = "triangle", label = "Habilitar", row = 1 }, { pad = "select", label = "Insertar", row = 1 }, { pad = "square", label = "Eliminar", row = 1 }, { pad = "circle", label = "Atrás", row = 1 }, { pad = "left", label = "Izquierda", row = 2 }, { pad = "L1", label = "Arriba", row = 2 }, { pad = "start", label = "Guardar", row = 2 }, { pad = "R1", label = "Abajo", row = 2 }, { pad = "right", label = "Derecha", row = 2 } },
  hint_items_with_disable = { { pad = "cross", label = "Entrar", row = 1 }, { pad = "triangle", label = "Deshab.", row = 1 }, { pad = "select", label = "Insertar", row = 1 }, { pad = "square", label = "Eliminar", row = 1 }, { pad = "circle", label = "Atrás", row = 1 }, { pad = "left", label = "Izquierda", row = 2 }, { pad = "L1", label = "Arriba", row = 2 }, { pad = "start", label = "Guardar", row = 2 }, { pad = "R1", label = "Abajo", row = 2 }, { pad = "right", label = "Derecha", row = 2 } },
  entry_index = "Entrada ",
  name = "Nombre: ",
  paths = "Rutas: ",
  args = "args: ",
  none = "ninguno",
  path_s = " ruta(s)",
  arg_s = " arg(s)",
  cross_select_circle_back_items = { { pad = "cross", label = "Entrar" }, { pad = "circle", label = "Atrás" } },
  edit_name = "Editar nombre",
  paths_label = "Rutas",
  launch_disc_options = "Opciones de lanzamiento de disco",
  arguments = "Argumentos",
  entry_name_prompt = "Nombre de la entrada",
  add_entry_label = "Nueva entrada",
  launch_disc_options_title = "Opciones de lanzamiento de disco",
  launch_disc_options_sub = "Estas opciones anulan el comportamiento predeterminado",
  paths_for_entry_title = "Rutas para %s (entrada %s)",
  paths_hint_items = { { pad = "cross", label = "Editar", row = 1 }, { pad = "square", label = "Eliminar", row = 1 }, { pad = "circle", label = "Atrás", row = 1 }, { pad = "L1", label = "Arriba", row = 2 }, { pad = "select", label = "Añadir", row = 2 }, { pad = "R1", label = "Abajo", row = 2 } },
  paths_hint_items_with_enable = { { pad = "cross", label = "Editar", row = 1 }, { pad = "triangle", label = "Habilitar", row = 1 }, { pad = "square", label = "Eliminar", row = 1 }, { pad = "circle", label = "Atrás", row = 1 }, { pad = "L1", label = "Arriba", row = 2 }, { pad = "select", label = "Añadir", row = 2 }, { pad = "R1", label = "Abajo", row = 2 } },
  paths_hint_items_with_disable = { { pad = "cross", label = "Editar", row = 1 }, { pad = "triangle", label = "Deshab.", row = 1 }, { pad = "square", label = "Eliminar", row = 1 }, { pad = "circle", label = "Atrás", row = 1 }, { pad = "L1", label = "Arriba", row = 2 }, { pad = "select", label = "Añadir", row = 2 }, { pad = "R1", label = "Abajo", row = 2 } },
  args_for_entry_title = "Argumentos para %s (entrada %s)",
  args_hint_items = { { pad = "cross", label = "Editar", row = 1 }, { pad = "square", label = "Eliminar", row = 1 }, { pad = "circle", label = "Atrás", row = 1 }, { pad = "L1", label = "Arriba", row = 2 }, { pad = "select", label = "Añadir", row = 2 }, { pad = "R1", label = "Abajo", row = 2 } },
  args_hint_items_with_enable = { { pad = "cross", label = "Editar", row = 1 }, { pad = "triangle", label = "Habilitar", row = 1 }, { pad = "square", label = "Eliminar", row = 1 }, { pad = "circle", label = "Atrás", row = 1 }, { pad = "L1", label = "Arriba", row = 2 }, { pad = "select", label = "Añadir", row = 2 }, { pad = "R1", label = "Abajo", row = 2 } },
  args_hint_items_with_disable = { { pad = "cross", label = "Editar", row = 1 }, { pad = "triangle", label = "Deshab.", row = 1 }, { pad = "square", label = "Eliminar", row = 1 }, { pad = "circle", label = "Atrás", row = 1 }, { pad = "L1", label = "Arriba", row = 2 }, { pad = "select", label = "Añadir", row = 2 }, { pad = "R1", label = "Abajo", row = 2 } },
  cdrom_hint = "Entrada de lanzamiento de disco: usa las opciones de lanzamiento de disco para las banderas",
  cdrom_toggle_hint_items = { { pad = "cross", label = "Alternar" }, { pad = "circle", label = "Atrás" } },
  new_argument_prompt = "Nuevo argumento",
  edit_argument_prompt = "Editar argumento",
}

-- Selector de rutas
strings.path_picker = {
  choose_device = "Elegir dispositivo",
  add_path_choose_device = "Añadir ruta: elegir dispositivo",
  enter_path_manually = "Introducir ruta manualmente",
  enter_path_prompt = "Introducir ruta",
  cross_select_circle_back_items = { { pad = "cross", label = "Entrar" }, { pad = "circle", label = "Atrás" } },
  select_hdd_partition = "Seleccionar partición HDD",
  no_partitions = "No hay particiones (¿está el HDD conectado?)",
  cross_open_circle_back_items = { { pad = "cross", label = "Entrar" }, { pad = "circle", label = "Atrás" } },
  cross_open_square_patinfo_circle_back_items = { { pad = "cross", label = "Entrar" }, { pad = "square", label = "PATINFO" }, { pad = "circle", label = "Atrás" } },
  no_elf_files = "No hay archivos ELF o carpetas",
  cross_select_file_items = { { pad = "cross", label = "Seleccionar" }, { pad = "circle", label = "Atrás" } },
  no_devices = "No hay dispositivos",
  waiting_for_device_drivers = "Esperando dispositivo...",
  circle_back_items = { { pad = "circle", label = "Atrás" } },
  device_timeout = "Tiempo de espera del dispositivo agotado",
  wildcard_confirm_title = "¿Usar ruta como comodín?",
  wildcard_confirm_hint = { { pad = "cross", label = "Sí" }, { pad = "circle", label = "No" } },
}

-- Nombres de dispositivos y entradas especiales. Usados tanto por OSDMenu como por el selector de archivos / selector de rutas MBR (cadenas comunes).
strings.devices = {
  memory_card_1 = "Tarjeta de Memoria 1",
  memory_card_2 = "Tarjeta de Memoria 2",
  launch_disc = "Lanzar disco con anulación",
  dvd_player = "Reproductor de DVD",
  osd = "OSDSYS",
  shutdown = "Apagar",
  hosdsys = "Navegador 2.0 / HOSDMenu",
  psbbn = "PlayStation Broadband Navigator",
  usb_storage_0 = "Almacenamiento Masivo USB 1",
  usb_storage_1 = "Almacenamiento Masivo USB 2",
  mmce_0 = "MMCE en ranura 1",
  mmce_1 = "MMCE en ranura 2",
  mx4sio_sd = "MX4SIO",
  exfat_hdd_mass0 = "HDD formateado en exFAT",
  hdd = "HDD formateado en APA",
}

-- Tokens comunes
strings.common = {
  on = "Activado",
  off = "Desactivado",
  not_set = "(no establecido)",
  empty = "(vacío)",
  enter_text = "Introducir texto",
  hint_prev = "Anterior",
  hint_next = "Siguiente",
}

-- Nombres de categorías (para el editor OSDMENU, por índice basado en 1)
strings.categories = {
  [1] = "Modificadores de comportamiento de OSD",
  [2] = "Opciones de menú personalizadas de OSD",
  [3] = "Modificadores de lanzamiento de disco y aplicación",
  [4] = "Editar entradas del menú",
}

-- Etiquetas y descripciones de opciones de OSDMENU.CNF (por clave de opción)
strings.options_osdmenu = {
  OSDSYS_video_mode = { label = "Forzar modo de video", desc = "Forzar modo de video de OSD" },
  OSDSYS_region = { label = "Forzar región", desc = "Forzar región de OSD" },
  OSDSYS_Skip_Disc = { label = "Saltar disco", desc = "Saltar lanzamiento automático de disco" },
  OSDSYS_Skip_Logo = { label = "Saltar intro", desc = "Saltar animación de introducción de SCE" },
  OSDSYS_Inner_Browser = { label = "Navegador interno", desc = "Arrancar en el navegador de la tarjeta de memoria" },
  OSDSYS_custom_menu = { label = "Menú personalizado", desc = "Habilitar menú personalizado" },
  OSDSYS_scroll_menu = { label = "Desplazamiento infinito", desc = "Habilitar desplazamiento infinito" },
  OSDSYS_menu_x = { label = "Menú X", desc = "Posición X del menú personalizado" },
  OSDSYS_menu_y = { label = "Menú Y", desc = "Posición Y del menú personalizado" },
  OSDSYS_enter_x = { label = "Entrar X", desc = "Posición X del botón Entrar" },
  OSDSYS_enter_y = { label = "Entrar Y", desc = "Posición Y del botón Entrar" },
  OSDSYS_version_x = { label = "Versión X", desc = "Posición X del botón Versión" },
  OSDSYS_version_y = { label = "Versión Y", desc = "Posición Y del botón Versión" },
  OSDSYS_cursor_max_velocity = { label = "Velocidad del cursor", desc = "Velocidad máxima del cursor" },
  OSDSYS_cursor_acceleration = { label = "Aceleración del cursor", desc = "Aceleración del cursor" },
  OSDSYS_left_cursor = { label = "Texto del cursor izquierdo", desc = "Máx. 19 caracteres" },
  OSDSYS_right_cursor = { label = "Texto del cursor derecho", desc = "Máx. 19 caracteres" },
  OSDSYS_menu_top_delimiter = { label = "Delimitador superior del menú", desc = "Máx. 79 caracteres" },
  OSDSYS_menu_bottom_delimiter = { label = "Delimitador inferior del menú", desc = "Máx. 79 caracteres" },
  OSDSYS_num_displayed_items = { label = "Elementos mostrados", desc = "Número de elementos del menú visibles" },
  OSDSYS_selected_color = { label = "Color seleccionado", desc = "Color de resaltado de la entrada del menú" },
  OSDSYS_unselected_color = { label = "Color no seleccionado", desc = "Color de resaltado de la entrada del menú" },
  cdrom_skip_ps2logo = { label = "Saltar PS2LOGO", desc = "Saltar el logo de PlayStation 2 al iniciar el disco" },
  cdrom_disable_gameid = { label = "Deshabilitar ID de juego visual", desc = "Deshabilitar ID de juego visual" },
  cdrom_use_dkwdrv = { label = "Usar DKWDRV", desc = "Usar DKWDRV para discos de PS1" },
  ps1drv_enable_fast = { label = "Carga rápida de PS1", desc = "Forzar velocidad de disco rápida de PS1" },
  ps1drv_enable_smooth = { label = "Suavizado de texturas de PS1", desc = "Forzar suavizado de texturas de PS1" },
  ps1drv_use_ps1vn = { label = "Usar PS1VN", desc = "Usar Negador de Modo de Video de PS1" },
  app_gameid = { label = "ID de juego de aplicación", desc = "Habilitar ID de juego visual para archivos ELF" },
  path_DKWDRV_ELF = { label = "Ruta DKWDRV", desc = "Ruta personalizada a DKWDRV.ELF" },
  _menu_entries = { label = "Editar entradas del menú", desc = "Editar entradas de menú personalizadas: nombre, rutas, argumentos" },
}

-- Etiquetas y descripciones de opciones de OSDMBR.CNF (por clave de opción)
strings.options_osdmbr = {
  boot_auto = { label = "Inicio automático", desc = "Rutas y argumentos predeterminados" },
  boot_start = { label = "Inicio START", desc = "Rutas y argumentos para el botón START" },
  boot_triangle = { label = "Inicio TRIÁNGULO", desc = "Rutas y argumentos para el botón TRIÁNGULO" },
  boot_circle = { label = "Inicio CÍRCULO", desc = "Rutas y argumentos para el botón CÍRCULO" },
  boot_cross = { label = "Inicio CRUZ", desc = "Rutas y argumentos para el botón CRUZ" },
  boot_square = { label = "Inicio CUADRADO", desc = "Rutas y argumentos para el botón CUADRADO" },
  cdrom_skip_ps2logo = { label = "Saltar PS2LOGO", desc = "Saltar el logo de PlayStation 2 al iniciar el disco" },
  cdrom_disable_gameid = { label = "Deshabilitar ID de juego visual", desc = "Deshabilitar ID de juego visual" },
  cdrom_use_dkwdrv = { label = "Usar DKWDRV", desc = "Usar DKWDRV para discos de PS1" },
  ps1drv_enable_fast = { label = "Carga rápida de PS1", desc = "Forzar velocidad de disco rápida de PS1" },
  ps1drv_enable_smooth = { label = "Suavizado de texturas de PS1", desc = "Forzar suavizado de texturas de PS1" },
  ps1drv_use_ps1vn = { label = "Usar PS1VN", desc = "Usar Negador de Modo de Video de PS1" },
  prefer_bbn = { label = "Preferir BBN", desc = "Cargar PSBBN al reiniciar" },
  app_gameid = { label = "ID de juego de aplicación", desc = "Mostrar ID de juego visual para archivos ELF" },
  osd_screentype = { label = "Tipo de pantalla OSD", desc = "Forzar tipo de pantalla OSD (4:3, 16:9, completo)" },
  osd_language = { label = "Idioma OSD", desc = "Forzar idioma OSD (depende del modelo de consola)" },
}

-- Editor eGSM (pantalla única: valores predeterminados + anulaciones de título)
strings.egsm = {
  default_label = "Predeterminado",
  title_id_prompt = "ID de título (ej. SCES12345)",
  hint_items = { { pad = "cross", label = "Editar", row = 1 }, { pad = "select", label = "Insertar", row = 1 }, { pad = "square", label = "Eliminar", row = 1 }, { pad = "circle", label = "Atrás", row = 1 }, { pad = "start", label = "Guardar", row = 2 } },
  hint_items_with_enable = { { pad = "cross", label = "Editar", row = 1 }, { pad = "triangle", label = "Habilitar", row = 1 }, { pad = "select", label = "Insertar", row = 1 }, { pad = "square", label = "Eliminar", row = 1 }, { pad = "circle", label = "Atrás", row = 1 }, { pad = "start", label = "Guardar", row = 2 } },
  hint_items_with_disable = { { pad = "cross", label = "Editar", row = 1 }, { pad = "triangle", label = "Deshab.", row = 1 }, { pad = "select", label = "Insertar", row = 1 }, { pad = "square", label = "Eliminar", row = 1 }, { pad = "circle", label = "Atrás", row = 1 }, { pad = "start", label = "Guardar", row = 2 } },
  -- Pantalla de edición de valor (por README del cargador: fp1/fp2/1080ix1..3, compat 1/2/3)
  value_edit_title = "Valor eGSM",
  result_prefix = "Valor: ",
  video_header = "Modo de video",
  video_240p = "Forzar 240/288p",
  video_480p = "Forzar 480/576p",
  video_1080i_1x = "Forzar 1080i (escala 1x)",
  video_1080i_2x = "Forzar 1080i (escala 2x)",
  video_1080i_3x = "Forzar 1080i (escala 3x)",
  compat_header = "Compatibilidad",
  compat_none = "Ninguno",
  compat_1 = "Tipo de volteo de campo 1 (similar a OPL)",
  compat_2 = "Tipo de volteo de campo 2",
  compat_3 = "Tipo de volteo de campo 3",
  value_edit_hint = { { pad = "cross", label = "Seleccionar", row = 1 }, { pad = "circle", label = "Atrás", row = 1 } },
}

-- Tabla de búsqueda única para todos los tipos de configuración (construida a partir de los tres anteriores)
strings.options = {}
for k, v in pairs(strings.options_osdmenu or {}) do strings.options[k] = v end
for k, v in pairs(strings.options_osdmbr or {}) do strings.options[k] = v end
for k, v in pairs(strings.options_osdgsm or {}) do strings.options[k] = v end

-- Etiquetas/descripciones de opciones de CDROM (subpantalla de opciones de lanzamiento de disco). Las claves son simbólicas (sin argumentos brutos).
strings.cdrom_options = {
  nologo = { label = "Saltar PS2LOGO", desc = "Saltar el logo de PlayStation 2 al iniciar el disco" },
  nogameid = { label = "Deshabilitar ID de juego visual", desc = "Deshabilitar ID de juego visual" },
  dkwdrv = { label = "Usar DKWDRV", desc = "Usar DKWDRV para discos de PS1" },
  ps1fast = { label = "Carga rápida de PS1", desc = "Forzar velocidad de disco rápida de PS1" },
  ps1smooth = { label = "Suavizado de texturas de PS1", desc = "Forzar suavizado de texturas de PS1" },
  ps1vneg = { label = "Usar PS1VN", desc = "Usar Negador de Modo de Video de PS1" },
}

-- Sugerencia de entrada de texto (teclado). hint_items_title_id = igual pero sin mayúsculas (usado para ID de título GSM).
strings.text_input = {
  hint_items = { { pad = "cross", label = "Entrar", row = 1 }, { pad = "triangle", label = "Mayúsculas", row = 1 }, { pad = "square", label = "Retroceso", row = 1 }, { pad = "circle", label = "Cancelar", row = 1 }, { pad = "L1", label = "Izquierda", row = 2 }, { pad = "start", label = "Hecho", row = 2 }, { pad = "R1", label = "Derecha", row = 2 } },
  hint_items_title_id = { { pad = "cross", label = "Entrar", row = 1 }, { pad = "square", label = "Retroceso", row = 1 }, { pad = "circle", label = "Cancelar", row = 1 }, { pad = "L1", label = "Izquierda", row = 2 }, { pad = "start", label = "Hecho", row = 2 }, { pad = "R1", label = "Derecha", row = 2 } },
}

return strings
