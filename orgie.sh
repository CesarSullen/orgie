#!/usr/bin/env bash

# orgie.sh — gestor de organizaciones de archivos. Ver README.md para uso e instalación.

set -uo pipefail

VERSION="0.3.0"
INSTALL_DIR="$HOME/.local/bin"
INSTALL_PATH="$INSTALL_DIR/orgie"
TMP_PREFIX=".orgie.tmp."
DEFAULT_EXTS="mp4,mkv,avi,mov,webm,m4v,ts,flv,wmv"

shopt -s nullglob

# ============================================================
#  Ayuda
# ============================================================

usage() {
    cat <<'EOF'
orgie — gestor de organizaciones de archivos

Uso: orgie <modo> [opciones] [carpeta]

Si no se indica carpeta, se usa el directorio actual (.).

Modos (hay que elegir uno):
  -g, --games      Descomprime y organiza archivos .rar/.zip de juegos de
                   Nintendo Switch en una carpeta por juego, y genera un
                   README.md con el tamaño de cada una.
  -s, --series     Renombra los videos con números (01, 02... o 001, 002...)
                   según su fecha de CREACIÓN en el disco, conservando la
                   extensión. Muestra vista previa y pide confirmación.
                   El renombrado no se puede deshacer.
  -t, --subs       Descarga subtítulos (por defecto en español) para un video
                   o para todos los de una carpeta, y los guarda junto al
                   video con el mismo nombre (Pelicula.es.srt) para que el
                   reproductor los cargue solo. No usa cuentas. Necesita
                   tener 'subliminal' instalado (solo para este modo).

  --install        Copia este script a ~/.local/bin/orgie para poder usar el
                   comando 'orgie' desde cualquier carpeta. No usa sudo.
  --uninstall      Quita ~/.local/bin/orgie (la copia instalada).

Opciones de --series:
  -n, --start N    Número con el que empieza (por defecto 1).
                   Ej: -n 36 -> 036, 037...

Opciones de --subs:
  -l, --lang COD   Idioma del subtítulo (por defecto es). Ej: en, pt-BR.

Opciones de --series y --subs:
  -e, --ext LISTA  Extensiones a procesar, separadas por comas y sin punto.
                   Por defecto: mp4,mkv,avi,mov,webm,m4v,ts,flv,wmv

Generales:
  -h, --help       Muestra esta ayuda.
  -V, --version    Muestra la versión.

Ejemplos:
  orgie -g ~/Games
  orgie -s .
  orgie -s -n 36 -e mkv ~/Series/Temporada1
  orgie -t ~/Peliculas/MiPelicula.mkv
  orgie -t ~/Peliculas
  bash orgie.sh --install
  orgie --uninstall

Ver más detalle en el README del repositorio.
EOF
}

# ============================================================
#  Funciones comunes
# ============================================================

banner() {
    echo ""
    echo "========================================"
    echo "  $1"
    echo "========================================"
    echo ""
}

# resolve_target: valida TARGET_ARG (o '.') y deja la ruta absoluta en TARGET_DIR.
resolve_target() {
    TARGET_DIR="${TARGET_ARG:-.}"

    if [[ ! -d "$TARGET_DIR" ]]; then
        echo "Error: '$TARGET_DIR' no es una carpeta válida." >&2
        exit 1
    fi

    TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

    echo "      Carpeta de trabajo: $TARGET_DIR"
    echo ""
}

# ============================================================
#  Modo --games
# ============================================================

# extract_archive <archivo> <carpeta_destino>
# Devuelve 0 si tuvo éxito, distinto de 0 si falló.
extract_archive() {
    local archive="$1"
    local dest="$2"
    local ext="${archive##*.}"
    ext="${ext,,}"

    case "$ext" in
        rar)
            if [[ $HAVE_UNRAR -eq 1 ]]; then
                unrar x -o+ "$archive" "$dest/" > /dev/null 2>&1
            elif [[ $HAVE_7Z -eq 1 ]]; then
                7z x "$archive" -o"$dest" -y > /dev/null 2>&1
            else
                return 2
            fi
            ;;
        zip)
            if [[ $HAVE_UNZIP -eq 1 ]]; then
                unzip -o "$archive" -d "$dest" > /dev/null 2>&1
            elif [[ $HAVE_7Z -eq 1 ]]; then
                7z x "$archive" -o"$dest" -y > /dev/null 2>&1
            else
                return 2
            fi
            ;;
        *)
            return 3
            ;;
    esac
}

# find_existing_folder <nombre_juego> <carpeta_destino>
# Busca, sin distinguir mayúsculas/minúsculas, si ya existe una carpeta para
# este juego. Si la encuentra, imprime su nombre exacto para reutilizarla.
find_existing_folder() {
    local name="$1"
    local target="$2"
    local lower_name="${name,,}"

    local d dname lower_dname
    for d in "$target"/*/; do
        [[ -d "$d" ]] || continue
        dname="$(basename "$d")"
        lower_dname="${dname,,}"
        if [[ "$lower_dname" == "$lower_name" ]]; then
            echo "$dname"
            return 0
        fi
    done
    return 1
}

mode_games() {
    banner "Organizador de juegos Nintendo Switch"

    # --- 1. Carpeta ---
    echo "[1/5] Comprobando carpeta de trabajo..."
    resolve_target

    # --- 2. Herramientas ---
    echo "[2/5] Comprobando herramientas de extracción..."

    HAVE_UNRAR=0
    HAVE_UNZIP=0
    HAVE_7Z=0

    command -v unrar >/dev/null 2>&1 && HAVE_UNRAR=1
    command -v unzip >/dev/null 2>&1 && HAVE_UNZIP=1
    command -v 7z    >/dev/null 2>&1 && HAVE_7Z=1

    if [[ $HAVE_UNRAR -eq 0 && $HAVE_UNZIP -eq 0 && $HAVE_7Z -eq 0 ]]; then
        echo "Error: no se encontró 'unrar', 'unzip' ni '7z' instalados." >&2
        echo "Instala al menos uno con:" >&2
        echo "  sudo apt install unrar" >&2
        echo "  sudo apt install unzip" >&2
        echo "  sudo apt install p7zip-full" >&2
        exit 1
    fi

    echo "      Disponibles: $( [[ $HAVE_UNRAR -eq 1 ]] && echo -n 'unrar ' )$( [[ $HAVE_UNZIP -eq 1 ]] && echo -n 'unzip ' )$( [[ $HAVE_7Z -eq 1 ]] && echo -n '7z' )"
    echo ""

    # --- 3. Procesar cada archivo ---
    echo "[3/5] Procesando archivos..."
    echo ""

    local archive_files=("$TARGET_DIR"/*.rar "$TARGET_DIR"/*.zip)
    local extracted_files=()
    local failed_files=()

    if [[ ${#archive_files[@]} -eq 0 ]]; then
        echo "      No se encontraron archivos .rar/.zip en '$TARGET_DIR'."
        echo "      Se omite la extracción."
        echo ""
    else
        local total_files=${#archive_files[@]}
        local current_file=0
        local archive_file filename filename_noext normalized game_name
        local existing_name dest_dir extracted_dirs inner_dir inner_entries inner_name

        for archive_file in "${archive_files[@]}"; do
            current_file=$((current_file + 1))

            filename="$(basename "$archive_file")"
            filename_noext="${filename%.*}"

            echo "----------------------------------------"
            echo "  [$current_file/$total_files] $filename_noext"
            echo "----------------------------------------"

            # Sustituir guiones por espacios
            normalized="${filename_noext//-/ }"

            # Cortar todo desde la palabra "Switch" en adelante
            game_name="$(echo "$normalized" | sed -E 's/[[:space:]]+[Ss][Ww][A-Za-z]{0,3}[Cc][Hh].*$//')"
            game_name="$(echo "$game_name" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"

            if [[ -z "$game_name" ]]; then
                echo "      Aviso: no se pudo determinar el nombre del juego."
                echo "      Se omite el archivo (no se toca)."
                echo ""
                failed_files+=("$filename (nombre no reconocido)")
                continue
            fi

            # Reutilizar carpeta existente aunque cambie la capitalización
            existing_name="$(find_existing_folder "$game_name" "$TARGET_DIR" || true)"
            if [[ -n "$existing_name" ]]; then
                game_name="$existing_name"
            fi

            dest_dir="$TARGET_DIR/$game_name"
            echo "      Juego: $game_name"

            mkdir -p "$dest_dir"

            echo "      Extrayendo archivo..."

            if extract_archive "$archive_file" "$dest_dir"; then
                echo "      Extracción completada."
            else
                echo "      Error: la extracción falló, se deja el archivo intacto." >&2
                failed_files+=("$filename (error al extraer)")
                if [[ -d "$dest_dir" && -z "$(ls -A "$dest_dir")" ]]; then
                    rmdir "$dest_dir"
                fi
                echo ""
                continue
            fi

            # Si la extracción dejó una única subcarpeta anidada, subir su contenido
            extracted_dirs=("$dest_dir"/*/)

            if [[ ${#extracted_dirs[@]} -eq 1 ]]; then
                inner_dir="${extracted_dirs[0]}"
                inner_entries=("$inner_dir"/*)

                if [[ ${#inner_entries[@]} -gt 0 ]]; then
                    inner_name="$(basename "$inner_dir")"
                    echo "      Normalizando estructura..."
                    echo "      Carpeta interna detectada: $inner_name"
                    echo "      Moviendo archivos a '$game_name/'..."

                    mv "$inner_dir"/* "$dest_dir/"
                    rmdir "$inner_dir"

                    echo "      Estructura normalizada."
                else
                    echo "      La carpeta interna está vacía."
                fi
            else
                echo "      Estructura normalizada."
            fi

            echo "      Archivo procesado correctamente."
            echo ""

            extracted_files+=("$archive_file")
        done
    fi

    # --- 4. README.md con tamaños ---
    echo "[4/5] Generando README.md..."

    local readme_path="$TARGET_DIR/README.md"

    {
        echo "# Juegos"
        echo ""
        echo "Actualizado: $(date '+%Y-%m-%d %H:%M')"
        echo ""
        echo "| Juego | Tamaño |"
        echo "|---|---|"
    } > "$readme_path"

    local game_dirs=("$TARGET_DIR"/*/)

    if [[ ${#game_dirs[@]} -eq 0 ]]; then
        echo "| (sin carpetas de juegos todavía) | - |" >> "$readme_path"
    else
        local size dir name total_size
        while IFS=$'\t' read -r size dir; do
            name="$(basename "$dir")"
            printf '| %s | %s |\n' "$name" "$size" >> "$readme_path"
        done < <(du -sh "${game_dirs[@]}" | sort -rh)

        total_size="$(du -shc "${game_dirs[@]}" 2>/dev/null | tail -1 | cut -f1)"
        {
            echo "|---|---|"
            echo "| **Total** | **$total_size** |"
        } >> "$readme_path"
    fi

    echo "      README.md generado correctamente."
    echo ""

    # --- 5. Resumen ---
    echo "[5/5] Resumen"
    banner "Proceso terminado"

    echo "  Archivos encontrados:  ${#archive_files[@]}"
    echo "  Extraídos con éxito:   ${#extracted_files[@]}"
    echo "  Fallidos:              ${#failed_files[@]}"

    if [[ ${#failed_files[@]} -gt 0 ]]; then
        echo ""
        echo "  Archivos con problemas:"
        local f
        for f in "${failed_files[@]}"; do
            echo "    - $f"
        done
    fi

    echo ""
    echo "  Revisa: $readme_path"
    echo ""

    # --- Preguntar si se borran los archivos ya extraídos con éxito ---
    if [[ ${#extracted_files[@]} -gt 0 ]]; then
        local confirm
        read -r -p "¿Eliminar los ${#extracted_files[@]} archivos ya extraídos con éxito? (s/n): " confirm

        if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
            echo ""
            echo "Eliminando archivos..."

            local archive_file
            for archive_file in "${extracted_files[@]}"; do
                rm -f "$archive_file"
                echo "      Eliminado: $(basename "$archive_file")"
            done

            echo ""
            echo "Listo. Solo quedan las carpetas de juegos organizadas."
        else
            echo ""
            echo "No se eliminó ningún archivo."
        fi
        echo ""
    fi
}

# ============================================================
#  Modo --series
# ============================================================

# apply_renames
# Usa los arrays globales SRC[] y DST[] (nombres, no rutas) y renombra SRC[i] -> DST[i].
# Lo hace en dos fases (primero a nombres temporales) para que nunca se pisen
# archivos entre sí. Si algo falla en la fase 1, revierte lo hecho.
# Devuelve 0 si todo salió bien.
apply_renames() {
    local n=${#SRC[@]} i j bad=0

    for ((i = 0; i < n; i++)); do
        if ! mv -- "$TARGET_DIR/${SRC[i]}" "$TARGET_DIR/${TMP_PREFIX}$i"; then
            echo "      Error al mover '${SRC[i]}'. Se revierte lo hecho..." >&2
            for ((j = i - 1; j >= 0; j--)); do
                mv -- "$TARGET_DIR/${TMP_PREFIX}$j" "$TARGET_DIR/${SRC[j]}"
            done
            return 1
        fi
    done

    for ((i = 0; i < n; i++)); do
        if ! mv -- "$TARGET_DIR/${TMP_PREFIX}$i" "$TARGET_DIR/${DST[i]}"; then
            echo "      Error: no se pudo crear '${DST[i]}' (quedó como '${TMP_PREFIX}$i')." >&2
            bad=1
        fi
    done

    return $bad
}

# print_series_line <índice>
print_series_line() {
    local i="$1" when
    when="$(date -d "@${BIRTH[i]%.*}" '+%d/%m %H:%M:%S')"
    printf '      %s  <-  %s   (creado %s)\n' "${DST[i]}" "${SRC[i]}" "$when"
}

mode_series() {
    banner "Organizador de series"

    if ! [[ "$START" =~ ^[0-9]+$ ]]; then
        echo "Error: -n/--start debe ser un número entero (ej: -n 36)." >&2
        exit 1
    fi
    START=$((10#$START))

    # --- 1. Carpeta ---
    echo "[1/5] Comprobando carpeta de trabajo..."
    resolve_target

    # --- 2. Herramientas ---
    echo "[2/5] Comprobando herramientas..."

    if ! stat -c '%W' / >/dev/null 2>&1; then
        echo "Error: 'stat' no soporta la fecha de creación (se necesita GNU stat, el de Linux)." >&2
        exit 1
    fi

    echo "      Todo disponible."
    echo ""

    # Si quedó algún temporal de una ejecución interrumpida, no se continúa.
    local leftovers=("$TARGET_DIR"/"$TMP_PREFIX"*) f
    if [[ ${#leftovers[@]} -gt 0 ]]; then
        echo "Error: hay archivos temporales de una ejecución interrumpida:" >&2
        for f in "${leftovers[@]}"; do echo "  - ${f##*/}" >&2; done
        echo "Revísalos a mano antes de volver a ejecutar (son tus videos con otro nombre)." >&2
        exit 1
    fi

    # --- 3. Buscar videos y ordenarlos ---
    echo "[3/5] Buscando videos y leyendo su fecha de creación..."

    local -A allowed=()
    local ext_list e
    IFS=',' read -r -a ext_list <<< "$EXTS"
    for e in "${ext_list[@]}"; do
        e="${e#.}"
        e="${e,,}"
        [[ -n "$e" ]] && allowed["$e"]=1
    done

    local lines=() skipped=0 name ext birth
    for f in "$TARGET_DIR"/*; do
        [[ -f "$f" && ! -L "$f" ]] || continue
        name="${f##*/}"
        [[ "$name" == *.* ]] || continue
        ext="${name##*.}"
        ext="${ext,,}"
        [[ -n "${allowed[$ext]:-}" ]] || continue

        if [[ "$name" == *$'\t'* || "$name" == *$'\n'* ]]; then
            echo "      Aviso: se omite '$name' (tiene tabulador o salto de línea en el nombre)."
            skipped=$((skipped + 1))
            continue
        fi

        birth="$(stat -c '%.9W' -- "$f")"
        if ! [[ "$birth" =~ ^[1-9][0-9]*(\.[0-9]+)?$ ]]; then
            echo "Error: no se pudo leer la fecha de creación de '$name'." >&2
            echo "Tu sistema de archivos quizá no la guarda, así que no es seguro ordenar con ella." >&2
            exit 1
        fi

        lines+=("$birth"$'\t'"$name")
    done

    local total=${#lines[@]}

    if [[ $total -eq 0 ]]; then
        echo "      No se encontraron videos (extensiones: $EXTS) en '$TARGET_DIR'."
        echo ""
        return 0
    fi

    # Orden: fecha de creación (con nanosegundos) y, si empatan, por nombre.
    local sorted
    mapfile -t sorted < <(printf '%s\n' "${lines[@]}" | LC_ALL=C sort -t $'\t' -k1,1 -k2,2)

    local last=$((START + total - 1))
    local width=${#last}
    [[ $width -lt 2 ]] && width=2

    SRC=()
    DST=()
    BIRTH=()
    local -A in_src=()
    local ties=0 prev_birth="" entry idx num

    for entry in "${sorted[@]}"; do
        birth="${entry%%$'\t'*}"
        name="${entry#*$'\t'}"
        ext="${name##*.}"
        idx=${#SRC[@]}
        num=$((START + idx))

        SRC+=("$name")
        DST+=("$(printf '%0*d.%s' "$width" "$num" "$ext")")
        BIRTH+=("$birth")
        in_src["$name"]=1

        [[ "$birth" == "$prev_birth" ]] && ties=$((ties + 1))
        prev_birth="$birth"
    done

    echo "      Videos encontrados: $total"
    echo "      Numeración: de ${DST[0]%.*} a ${DST[$((total - 1))]%.*} ($width cifras)"
    [[ $skipped -gt 0 ]] && echo "      Omitidos por nombre raro: $skipped"
    if [[ $ties -gt 0 ]]; then
        echo "      Aviso: $ties archivos tienen exactamente la misma fecha de creación que otro;"
        echo "             entre ellos el orden se decide por nombre."
    fi
    echo ""

    # Seguridad: ningún nombre nuevo puede pisar un archivo que no sea parte del lote.
    local conflicts=0 i
    for i in "${!DST[@]}"; do
        if [[ -e "$TARGET_DIR/${DST[i]}" && -z "${in_src[${DST[i]}]:-}" ]]; then
            echo "Error: ya existe '${DST[i]}' y no es uno de los videos a renombrar." >&2
            conflicts=$((conflicts + 1))
        fi
    done
    if [[ $conflicts -gt 0 ]]; then
        echo "No se cambió nada. Mueve o renombra esos archivos y vuelve a ejecutar." >&2
        exit 1
    fi

    # --- 4. Vista previa y confirmación ---
    echo "[4/5] Vista previa (nada se ha cambiado todavía)..."
    echo ""

    if [[ $total -le 10 ]]; then
        for ((i = 0; i < total; i++)); do print_series_line "$i"; done
    else
        for ((i = 0; i < 5; i++)); do print_series_line "$i"; done
        echo "      ..."
        for ((i = total - 3; i < total; i++)); do print_series_line "$i"; done
    fi
    echo ""

    local confirm
    read -r -p "¿Renombrar los $total archivos? Esto no se puede deshacer. (s/n): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        echo ""
        echo "No se cambió nada."
        return 0
    fi
    echo ""

    # --- 5. Renombrar y resumen ---
    echo "[5/5] Renombrando..."

    local status=0
    if apply_renames; then
        echo "      Renombrado completado."
    else
        echo "      Terminó con errores (ver mensajes arriba)." >&2
        status=1
    fi

    banner "Proceso terminado"
    echo "  Videos renombrados: $total"
    echo "  Primero: ${DST[0]}   Último: ${DST[$((total - 1))]}"
    echo ""

    return $status
}

# ============================================================
#  Modo --subs
# ============================================================

# subs_count <ruta_base_sin_extension>
# Cuenta los .srt que ya existen junto al video (cualquier idioma).
subs_count() {
    local found=("$1".*.srt)
    echo "${#found[@]}"
}

mode_subs() {
    banner "Descargador de subtítulos"

    if ! [[ "$SUB_LANG" =~ ^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,4})?$ ]]; then
        echo "Error: idioma no válido: '$SUB_LANG' (ejemplos: es, en, pt-BR)." >&2
        exit 1
    fi

    # --- 1. Ruta ---
    echo "[1/4] Comprobando ruta..."

    local input="${TARGET_ARG:-.}"
    local videos=() f

    if [[ -f "$input" ]]; then
        TARGET_DIR="$(cd "$(dirname "$input")" && pwd)"
        videos=("$TARGET_DIR/$(basename "$input")")
        echo "      Archivo: ${videos[0]}"
        echo ""
    else
        TARGET_ARG="$input"
        resolve_target
    fi

    # --- 2. Herramientas ---
    echo "[2/4] Comprobando herramientas..."

    if ! command -v subliminal >/dev/null 2>&1; then
        echo "Error: no se encontró 'subliminal' (solo hace falta para este modo)." >&2
        echo "Instálalo una vez, sin sudo, con:" >&2
        echo "  pipx install subliminal" >&2
        echo "Si no tienes pipx:" >&2
        echo "  sudo apt install pipx        (Debian/Ubuntu/Kubuntu)" >&2
        echo "  sudo pacman -S python-pipx   (Arch/Omarchy)" >&2
        exit 1
    fi

    local sub_help
    sub_help="$(subliminal download --help 2>/dev/null)"
    if [[ "$sub_help" != *"--subtitle-categories"* ]]; then
        echo "Error: tu 'subliminal' es muy antiguo. Actualízalo con: pipx upgrade subliminal" >&2
        exit 1
    fi

    echo "      Disponible: $(subliminal --version 2>/dev/null | head -n 1)"
    echo ""

    # --- 3. Buscar videos (si se indicó una carpeta) ---
    echo "[3/4] Buscando videos..."

    if [[ ${#videos[@]} -eq 0 ]]; then
        local -A allowed=()
        local ext_list e name ext
        IFS=',' read -r -a ext_list <<< "$EXTS"
        for e in "${ext_list[@]}"; do
            e="${e#.}"
            e="${e,,}"
            [[ -n "$e" ]] && allowed["$e"]=1
        done

        for f in "$TARGET_DIR"/*; do
            [[ -f "$f" && ! -L "$f" ]] || continue
            name="${f##*/}"
            [[ "$name" == *.* ]] || continue
            ext="${name##*.}"
            ext="${ext,,}"
            [[ -n "${allowed[$ext]:-}" ]] || continue
            videos+=("$f")
        done
    fi

    local total=${#videos[@]}

    if [[ $total -eq 0 ]]; then
        echo "      No se encontraron videos (extensiones: $EXTS) en '$TARGET_DIR'."
        echo ""
        return 0
    fi

    echo "      Videos encontrados: $total"
    echo ""

    # --- 4. Descargar ---
    echo "[4/4] Buscando subtítulos ($SUB_LANG)..."
    echo "      Sitios consultados (sin cuenta): podnapisi.net, subt.is, subtitulamos.tv"
    echo ""

    local got=0 skipped=0 notfound=0 failed=0 i=0
    local video base before after out rc

    for video in "${videos[@]}"; do
        i=$((i + 1))
        base="${video%.*}"

        echo "----------------------------------------"
        echo "  [$i/$total] ${video##*/}"
        echo "----------------------------------------"

        if [[ -e "$base.$SUB_LANG.srt" ]]; then
            echo "      Ya tiene subtítulo ($SUB_LANG), se omite."
            echo ""
            skipped=$((skipped + 1))
            continue
        fi

        before="$(subs_count "$base")"

        # -c /dev/null: no lee ninguna configuración (ni cuentas guardadas).
        # -p: solo estos tres sitios, ninguno exige cuenta.
        # -r: solo refinadores locales (no consultan servicios externos).
        # -C: prefiere subtítulos normales sobre los de sordos/solo-extranjero.
        out="$(subliminal -c /dev/null download -l "$SUB_LANG" \
            -p podnapisi -p subtis -p subtitulamos \
            -r hash -r metadata \
            -C n,hi,fo -- "$video" 2>&1)"
        rc=$?

        after="$(subs_count "$base")"

        if [[ $after -gt $before ]]; then
            echo "      Subtítulo descargado."
            got=$((got + 1))
        elif [[ $rc -ne 0 ]]; then
            echo "      Error al buscar (¿sin internet?). Detalle:" >&2
            echo "$out" | tail -n 3 | sed 's/^/        /' >&2
            failed=$((failed + 1))
        else
            echo "      No se descargó nada (no hay subtítulo disponible, el video ya trae uno incrustado, o no hubo conexión)."
            notfound=$((notfound + 1))
        fi
        echo ""
    done

    banner "Proceso terminado"
    echo "  Videos revisados:         $total"
    echo "  Subtítulos descargados:   $got"
    echo "  Ya tenían subtítulo:      $skipped"
    echo "  Sin resultado:            $notfound"
    echo "  Con error:                $failed"
    echo ""

    [[ $failed -eq 0 ]]
}

# ============================================================
#  Modos --install / --uninstall
# ============================================================

# is_orgie_file <ruta>: comprueba que el archivo realmente es este script.
is_orgie_file() {
    [[ -f "$1" ]] && grep -q '^# orgie.sh' "$1" 2>/dev/null
}

mode_install() {
    banner "Instalación de orgie"

    local src="${BASH_SOURCE[0]:-}"

    if ! is_orgie_file "$src"; then
        echo "Error: no puedo localizar el archivo del script para copiarlo." >&2
        echo "Descárgalo a un archivo y ejecútalo desde ahí:  bash orgie.sh --install" >&2
        exit 1
    fi

    src="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"

    if [[ "$src" == "$INSTALL_PATH" ]]; then
        echo "      Ya estás ejecutando la copia instalada ($INSTALL_PATH)."
        echo "      No hay nada que hacer."
        echo ""
        return 0
    fi

    if [[ -e "$INSTALL_PATH" || -L "$INSTALL_PATH" ]]; then
        if [[ -f "$INSTALL_PATH" && ! -L "$INSTALL_PATH" ]] && cmp -s "$src" "$INSTALL_PATH"; then
            echo "      Esta misma versión ya está instalada en $INSTALL_PATH."
            echo ""
            return 0
        fi

        echo "      Ya existe '$INSTALL_PATH' y es distinto de este script."
        local confirm
        read -r -p "¿Reemplazarlo? (s/n): " confirm
        if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
            echo ""
            echo "No se cambió nada."
            return 0
        fi
        echo ""
    fi

    if ! mkdir -p "$INSTALL_DIR"; then
        echo "Error: no se pudo crear '$INSTALL_DIR'." >&2
        exit 1
    fi

    if ! install -m 755 -- "$src" "$INSTALL_PATH"; then
        echo "Error: no se pudo copiar el script a '$INSTALL_PATH'." >&2
        exit 1
    fi

    echo "      Instalado en: $INSTALL_PATH"
    echo ""

    case ":$PATH:" in
        *":$INSTALL_DIR:"*)
            echo "      Ya puedes usarlo desde cualquier carpeta. Prueba:  orgie --help"
            ;;
        *)
            echo "      Aviso: '$INSTALL_DIR' no está en tu PATH, así que la terminal"
            echo "      todavía no encuentra el comando 'orgie'. Añade esta línea a"
            echo "      ~/.bashrc (o ~/.zshrc si usas zsh) y abre una terminal nueva:"
            echo ""
            echo "        export PATH=\"\$HOME/.local/bin:\$PATH\""
            ;;
    esac
    echo ""
}

mode_uninstall() {
    banner "Desinstalación de orgie"

    if [[ ! -e "$INSTALL_PATH" && ! -L "$INSTALL_PATH" ]]; then
        echo "      orgie no está instalado en '$INSTALL_PATH'. No hay nada que quitar."
        echo ""
        return 0
    fi

    if ! is_orgie_file "$INSTALL_PATH"; then
        echo "Error: '$INSTALL_PATH' no parece ser orgie, así que no se borra por seguridad." >&2
        echo "Revísalo a mano." >&2
        exit 1
    fi

    local confirm
    read -r -p "¿Eliminar $INSTALL_PATH? (s/n): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        echo ""
        echo "No se cambió nada."
        return 0
    fi

    rm -f -- "$INSTALL_PATH"

    echo ""
    echo "      Desinstalado. Solo se quitó '$INSTALL_PATH'; tu archivo orgie.sh"
    echo "      descargado (si lo conservas) y la línea de PATH (si la añadiste) no se tocan."
    echo ""
}

# ============================================================
#  Lectura de flags y selección de modo
# ============================================================

MODE=""
START=1
EXTS="$DEFAULT_EXTS"
TARGET_ARG=""
SUB_LANG="es"
START_SET=0
EXT_SET=0
LANG_SET=0

set_mode() {
    if [[ -n "$MODE" && "$MODE" != "$1" ]]; then
        echo "Error: elige un solo modo (--games, --series o --subs), no varios." >&2
        exit 1
    fi
    MODE="$1"
}

set_target() {
    if [[ -n "$TARGET_ARG" ]]; then
        echo "Error: solo se puede indicar una carpeta (recibí '$TARGET_ARG' y '$1')." >&2
        exit 1
    fi
    TARGET_ARG="$1"
}

need_value() {
    if [[ $2 -lt 2 ]]; then
        echo "Error: la opción $1 necesita un valor." >&2
        exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)    usage; exit 0 ;;
        -V|--version) echo "orgie $VERSION"; exit 0 ;;
        -g|--games)   set_mode games;  shift ;;
        -s|--series)  set_mode series; shift ;;
        -t|--subs)    set_mode subs;   shift ;;
        --install)    set_mode install;   shift ;;
        --uninstall)  set_mode uninstall; shift ;;
        -n|--start)   need_value "$1" $#; START="$2";    START_SET=1; shift 2 ;;
        -e|--ext)     need_value "$1" $#; EXTS="$2";     EXT_SET=1;   shift 2 ;;
        -l|--lang)    need_value "$1" $#; SUB_LANG="$2"; LANG_SET=1;  shift 2 ;;
        --)           shift; while [[ $# -gt 0 ]]; do set_target "$1"; shift; done ;;
        -*)           echo "Error: opción desconocida: $1 (usa -h para ver la ayuda)." >&2; exit 1 ;;
        *)            set_target "$1"; shift ;;
    esac
done

if [[ -z "$MODE" ]]; then
    echo "Error: falta indicar el modo (-g/--games, -s/--series o -t/--subs)." >&2
    echo "" >&2
    usage >&2
    exit 1
fi

case "$MODE" in
    install|uninstall)
        if [[ $START_SET -eq 1 || $EXT_SET -eq 1 || $LANG_SET -eq 1 || -n "$TARGET_ARG" ]]; then
            echo "Error: --install y --uninstall no aceptan carpeta ni otras opciones." >&2
            exit 1
        fi
        ;;
    games)
        if [[ $START_SET -eq 1 || $EXT_SET -eq 1 || $LANG_SET -eq 1 ]]; then
            echo "Error: -n, -e y -l no se usan con -g/--games." >&2
            exit 1
        fi
        ;;
    series)
        if [[ $LANG_SET -eq 1 ]]; then
            echo "Error: -l/--lang solo se usa con -t/--subs." >&2
            exit 1
        fi
        ;;
    subs)
        if [[ $START_SET -eq 1 ]]; then
            echo "Error: -n/--start solo se usa con -s/--series." >&2
            exit 1
        fi
        ;;
esac

case "$MODE" in
    games)  mode_games ;;
    series) mode_series ;;
    subs)   mode_subs ;;
    install)   mode_install ;;
    uninstall) mode_uninstall ;;
esac
