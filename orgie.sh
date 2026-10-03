#!/usr/bin/env bash

# orgie.sh: gestor de organizaciones de archivos. Uso e instalación en el README.

set -uo pipefail

VERSION="0.7.2"
INSTALL_DIR="$HOME/.local/bin"
INSTALL_PATH="$INSTALL_DIR/orgie"
REPO_RAW_URL="https://raw.githubusercontent.com/CesarSullen/orgie/main/orgie.sh"
SUB_EXTS="srt ass ssa sub vtt"

# Archivos que orgie guarda en el modo -t (sesión de OpenSubtitles y caché)
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/orgie"
CONF_FILE="$CONF_DIR/opensubtitles.toml"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/orgie"
TMP_PREFIX=".orgie.tmp."
DEFAULT_EXTS="mp4,mkv,avi,mov,webm,m4v,ts,flv,wmv"

shopt -s nullglob

# ============================================================
#  Ayuda
# ============================================================

usage() {
    cat <<'EOF'
orgie: gestor de organizaciones de archivos

Uso: orgie <modo> [opciones] [carpeta]

Si no indicas carpeta se usa la actual (.).

Modos (hay que elegir uno):
  -g, --games        Descomprime juegos de Nintendo Switch (.rar/.zip) en una
                     carpeta por juego. Enseña el plan y pide confirmación; el
                     README.md con los tamaños es opcional.
  -s, --series       Renombra los videos con números (01, 02... o 001, 002...)
                     según su fecha de creación en el disco, y conserva la
                     extensión. Los subtítulos con el mismo nombre que un video
                     se renombran con él. Enseña una vista previa y pide
                     confirmación. No se puede deshacer.
  -t, --subs         Descarga subtítulos (en español por defecto) de un video o
                     de todos los de una carpeta, y los guarda al lado con el
                     mismo nombre (Pelicula.es.srt). Necesita 'subliminal'.
  -p, --split LISTA  Reparte los videos, en orden de nombre, en carpetas T1, T2...
                     según los capítulos de cada temporada. Ej: -p 24,12,13.
                     Los subtítulos viajan con su video. Pide confirmación.
                     Si lo combinas con -s (orgie -p 11,12 -s), los videos se
                     ordenan por fecha de creación, se reparten y se numeran
                     desde 01 en cada temporada.
  -d, --dupes        Busca archivos idénticos en la carpeta y ofrece borrar las
                     copias, conservando el más antiguo. No se puede deshacer.
  --update           Mira si hay una versión nueva en GitHub y, si la hay, la
                     instala tras confirmar.
  --install          Copia orgie a ~/.local/bin/orgie para usarlo desde cualquier
                     carpeta. No usa sudo.
  --uninstall        Quita orgie y lo que haya guardado (sesión y caché).

Opciones de --series:
  -n, --start N      Número inicial (por defecto 1). Con -n 36 sale 036, 037...
                     Junto con -p, solo afecta a la primera temporada.
  --by-name          Ordena por nombre (orden natural: 2 va antes que 10) en
                     lugar de por fecha de creación. Sirve para carpetas ya
                     numeradas, o cuando la fecha de creación no es fiable.

Opciones de --subs:
  -l, --lang COD     Idioma (por defecto es). Ejemplos: en, pt-BR.

Opciones de --series, --subs y --split (con o sin --series):
  -e, --ext LISTA    Extensiones a procesar, separadas por comas y sin punto.
                     Por defecto: mp4,mkv,avi,mov,webm,m4v,ts,flv,wmv

Generales:
  -h, --help         Muestra esta ayuda.
  -v, --version      Muestra la versión.

Ejemplos:
  orgie -g ~/Games
  orgie -s .
  orgie -s -n 36 -e mkv ~/Series/Temporada1
  orgie -p 24,12,13 ~/Series/MiSerie
  orgie -p 11,12 -s ~/Series/MiSerie
  orgie -s --by-name ~/Series/MiSerie
  orgie -d ~/Downloads
  orgie -t ~/Peliculas/MiPelicula.mkv
  orgie --update
  bash orgie.sh --install
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

# game_name_from <archivo>: saca el nombre del juego del nombre del archivo.
# Devuelve vacío si no lo reconoce.
game_name_from() {
    local noext normalized name
    noext="${1%.*}"
    normalized="${noext//-/ }"
    name="$(printf '%s\n' "$normalized" | sed -E 's/[[:space:]]+[Ss][Ww][A-Za-z]{0,3}[Cc][Hh].*$//')"
    printf '%s\n' "$name" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
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

    local archive_files=("$TARGET_DIR"/*.rar "$TARGET_DIR"/*.zip)
    local extracted_files=()
    local failed_files=()
    local confirm

    # --- 3. Plan y confirmación ---
    echo "[3/5] Plan (todavía no se ha tocado nada)..."
    echo ""

    if [[ ${#archive_files[@]} -eq 0 ]]; then
        echo "      No se encontraron archivos .rar/.zip en '$TARGET_DIR'."
        echo "      Se omite la extracción."
        echo ""
    else
        local plan_file plan_name plan_game plan_existing
        local -A planned=()
        for plan_file in "${archive_files[@]}"; do
            plan_name="$(basename "$plan_file")"
            plan_game="$(game_name_from "$plan_name")"
            echo "      $plan_name"
            if [[ -z "$plan_game" ]]; then
                echo "        -> se omite (no se reconoce el nombre del juego)"
                continue
            fi
            plan_existing="$(find_existing_folder "$plan_game" "$TARGET_DIR" || true)"
            if [[ -n "$plan_existing" ]]; then
                echo "        -> $plan_existing/  (ya existe, se añade ahí)"
            elif [[ -n "${planned[${plan_game,,}]:-}" ]]; then
                echo "        -> ${planned[${plan_game,,}]}/  (misma carpeta que un archivo anterior)"
            else
                planned["${plan_game,,}"]="$plan_game"
                echo "        -> $plan_game/  (carpeta nueva)"
            fi
        done
        echo ""

        read -r -p "¿Descomprimir estos ${#archive_files[@]} archivos? (s/n): " confirm
        if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
            echo ""
            echo "No se cambió nada."
            return 0
        fi
        echo ""
    fi

    # --- 4. Procesar cada archivo ---
    echo "[4/5] Procesando archivos..."
    echo ""

    if [[ ${#archive_files[@]} -gt 0 ]]; then
        local total_files=${#archive_files[@]}
        local current_file=0
        local archive_file filename filename_noext game_name
        local existing_name dest_dir extracted_dirs inner_dir inner_entries inner_name

        for archive_file in "${archive_files[@]}"; do
            current_file=$((current_file + 1))

            filename="$(basename "$archive_file")"
            filename_noext="${filename%.*}"

            echo "----------------------------------------"
            echo "  [$current_file/$total_files] $filename_noext"
            echo "----------------------------------------"

            game_name="$(game_name_from "$filename")"

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

    # --- 5. README opcional y resumen ---
    echo "[5/5] README y resumen"
    echo ""

    local readme_path="$TARGET_DIR/README.md"
    local readme_state="omitido"
    local readme_note=""
    [[ -e "$readme_path" ]] && readme_note=" (ya existe uno y se reemplazaría)"

    read -r -p "¿Generar README.md con el tamaño de cada juego?$readme_note (s/n): " confirm
    echo ""

    if [[ "$confirm" == "s" || "$confirm" == "S" ]]; then
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
        readme_state="generado en $readme_path"
    fi

    banner "Proceso terminado"

    echo "  Archivos encontrados:  ${#archive_files[@]}"
    echo "  Extraídos con éxito:   ${#extracted_files[@]}"
    echo "  Fallidos:              ${#failed_files[@]}"
    echo "  README:                $readme_state"

    if [[ ${#failed_files[@]} -gt 0 ]]; then
        echo ""
        echo "  Archivos con problemas:"
        local f
        for f in "${failed_files[@]}"; do
            echo "    - $f"
        done
    fi
    echo ""

    # --- Preguntar si se borran los archivos ya extraídos con éxito ---
    if [[ ${#extracted_files[@]} -gt 0 ]]; then
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

# sort_entries: ordena líneas "fecha<TAB>nombre" por fecha de creación o, con
# --by-name, por nombre en orden natural (2 antes que 10).
sort_entries() {
    if [[ $BY_NAME -eq 1 ]]; then
        LC_ALL=C sort -t $'\t' -k2,2V
    else
        LC_ALL=C sort -t $'\t' -k1,1 -k2,2
    fi
}

# apply_renames: renombra SRC[i] a DST[i] (arrays globales, solo nombres).
# Pasa primero por nombres temporales para que ningún archivo pise a otro.
# Si algo falla en esa primera vuelta, deja todo como estaba.
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
    if [[ $BY_NAME -eq 1 ]]; then
        printf '      %s  <-  %s\n' "${DST[i]}" "${SRC[i]}"
        return
    fi
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

    if [[ $BY_NAME -eq 0 ]] && ! stat -c '%W' / >/dev/null 2>&1; then
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
    if [[ $BY_NAME -eq 1 ]]; then
        echo "[3/5] Buscando videos y ordenándolos por nombre..."
    else
        echo "[3/5] Buscando videos y leyendo su fecha de creación..."
    fi

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

        if [[ $BY_NAME -eq 1 ]]; then
            birth="-"
        else
            birth="$(stat -c '%.9W' -- "$f")"
            if ! [[ "$birth" =~ ^[1-9][0-9]*(\.[0-9]+)?$ ]]; then
                echo "Error: no se pudo leer la fecha de creación de '$name'." >&2
                echo "Tu sistema de archivos quizá no la guarda, así que no es seguro ordenar con ella." >&2
                echo "Puedes usar --by-name para ordenar por nombre en vez de por fecha." >&2
                exit 1
            fi
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
    # Con --by-name, por nombre en orden natural.
    local sorted
    mapfile -t sorted < <(printf '%s\n' "${lines[@]}" | sort_entries)

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

        [[ $BY_NAME -eq 0 && "$birth" == "$prev_birth" ]] && ties=$((ties + 1))
        prev_birth="$birth"
    done

    # Los subtítulos que acompañan a cada video (Nombre.es.srt) se renombran igual
    local SUB_SRC=() SUB_DST=() i new_base sub rest
    local -A sub_claimed=()
    for ((i = 0; i < total; i++)); do
        new_base="${DST[i]%.*}"
        while IFS= read -r sub; do
            [[ -n "$sub" ]] || continue
            sub="${sub##*/}"
            [[ -z "${sub_claimed[$sub]:-}" && -z "${in_src[$sub]:-}" ]] || continue
            rest="${sub#"${SRC[i]%.*}".}"
            sub_claimed["$sub"]=1
            in_src["$sub"]=1
            SUB_SRC+=("$sub")
            SUB_DST+=("$new_base.$rest")
        done < <(subtitle_companions "$TARGET_DIR/${SRC[i]%.*}")
    done

    local changes=0
    for ((i = 0; i < total; i++)); do
        [[ "${SRC[i]}" != "${DST[i]}" ]] && changes=$((changes + 1))
    done
    for ((i = 0; i < ${#SUB_SRC[@]}; i++)); do
        [[ "${SUB_SRC[i]}" != "${SUB_DST[i]}" ]] && changes=$((changes + 1))
    done
    if [[ $changes -eq 0 ]]; then
        echo "      Los $total videos ya tienen exactamente esos nombres. No hay nada que cambiar."
        echo ""
        return 0
    fi

    echo "      Videos encontrados: $total"
    echo "      Numeración: de ${DST[0]%.*} a ${DST[$((total - 1))]%.*} ($width cifras)"
    [[ ${#SUB_SRC[@]} -gt 0 ]] && echo "      Subtítulos que se renombrarán con sus videos: ${#SUB_SRC[@]}"
    [[ $skipped -gt 0 ]] && echo "      Omitidos por nombre raro: $skipped"
    if [[ $ties -gt 0 ]]; then
        echo "      Aviso: $ties archivos tienen exactamente la misma fecha de creación que otro;"
        echo "             entre ellos el orden se decide por nombre."
    fi
    echo ""

    # Un nombre nuevo no puede pisar un archivo que no sea del lote.
    local conflicts=0 dest
    for dest in "${DST[@]}" "${SUB_DST[@]}"; do
        if [[ -e "$TARGET_DIR/$dest" && -z "${in_src[$dest]:-}" ]]; then
            echo "Error: ya existe '$dest' y no es uno de los archivos a renombrar." >&2
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
    if [[ ${#SUB_SRC[@]} -gt 0 ]]; then
        echo ""
        echo "      Además, ${#SUB_SRC[@]} subtítulos cambian de nombre para seguir a su video, por ejemplo:"
        echo "      ${SUB_DST[0]}  <-  ${SUB_SRC[0]}"
    fi
    echo ""

    local confirm sub_text=""
    [[ ${#SUB_SRC[@]} -gt 0 ]] && sub_text=" y ${#SUB_SRC[@]} subtítulos"
    read -r -p "¿Renombrar los $total videos$sub_text? Esto no se puede deshacer. (s/n): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        echo ""
        echo "No se cambió nada."
        return 0
    fi
    echo ""

    # --- 5. Renombrar y resumen ---
    echo "[5/5] Renombrando..."

    local status=0
    if [[ ${#SUB_SRC[@]} -gt 0 ]]; then
        SRC+=("${SUB_SRC[@]}")
        DST+=("${SUB_DST[@]}")
    fi
    if apply_renames; then
        echo "      Renombrado completado."
    else
        echo "      Terminó con errores (ver mensajes arriba)." >&2
        status=1
    fi

    banner "Proceso terminado"
    echo "  Videos renombrados: $total"
    [[ ${#SUB_SRC[@]} -gt 0 ]] && echo "  Subtítulos renombrados: ${#SUB_SRC[@]}"
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

# Guarda usuario y contraseña de OpenSubtitles en un archivo que solo lee tu usuario.
save_login() {
    local u="$1" p="$2"

    # El archivo es TOML: hay que escapar barras y comillas
    u="${u//\\/\\\\}"
    u="${u//\"/\\\"}"
    p="${p//\\/\\\\}"
    p="${p//\"/\\\"}"

    mkdir -p -m 700 "$CONF_DIR" && chmod 700 "$CONF_DIR" || return 1

    (
        umask 077
        printf '[provider.opensubtitlescom]\nusername = "%s"\npassword = "%s"\n' "$u" "$p" > "$CONF_FILE"
    ) || return 1

    chmod 600 "$CONF_FILE"
}

# Pide usuario y contraseña (la contraseña no se ve al escribirla) y los guarda.
ask_login() {
    local user pass

    read -r -p "      Usuario de OpenSubtitles (vacío para cancelar): " user
    [[ -n "$user" ]] || return 1

    read -r -s -p "      Contraseña: " pass
    echo ""
    [[ -n "$pass" ]] || return 1

    if [[ "$user$pass" =~ [[:cntrl:]] ]]; then
        echo "      El usuario o la contraseña tienen caracteres no válidos." >&2
        return 1
    fi

    if ! save_login "$user" "$pass"; then
        echo "      No se pudo guardar la sesión en $CONF_DIR." >&2
        return 1
    fi

    SUB_CONF="$CONF_FILE"
    echo "      Sesión guardada en $CONF_DIR"
    return 0
}

# run_stage <sitios separados por espacio> <video>
# Deja la salida de subliminal en STAGE_OUT. Se usa --debug solo para poder leer
# los errores de cada sitio, porque si no subliminal los oculta.
run_stage() {
    local args=() site
    for site in $1; do
        args+=(-p "$site")
    done

    STAGE_OUT="$(subliminal --debug --cache-dir "$CACHE_DIR" -c "$SUB_CONF" \
        download -l "$SUB_LANG" "${args[@]}" \
        -r hash -r metadata -C n,hi,fo -- "$2" 2>&1)"
    STAGE_RC=$?
}

# try_stage <sitios> <video>
# Devuelve 0 si se descargó un subtítulo. En STAGE_NOTE queda el resultado.
try_stage() {
    local base="${2%.*}" before after bad_sites reason reset

    before="$(subs_count "$base")"
    run_stage "$1" "$2"
    after="$(subs_count "$base")"

    STAGE_AUTH_FAIL=0
    STAGE_LIMIT=0
    STAGE_AGENT=0

    if [[ $after -gt $before ]]; then
        STAGE_NOTE="descargado"
        return 0
    fi

    # Nombres de error tal como los muestra subliminal al hablar con OpenSubtitles.
    # Ojo: OpenSubtitles contesta "406" cuando se pasa el límite diario de
    # descargas, y subliminal lo llama NoSession aunque la contraseña esté bien.
    if [[ "$STAGE_OUT" == *UnknownUserAgent* || "$STAGE_OUT" == *DisabledUserAgent* ]]; then
        STAGE_NOTE="OpenSubtitles no acepta a subliminal (no es problema de tu cuenta)"
        STAGE_AGENT=1
    elif [[ "$STAGE_OUT" == *NoSession* || "$STAGE_OUT" == *DownloadLimitReached* || "$STAGE_OUT" == *DownloadLimitExceeded* ]]; then
        reset="$(printf '%s\n' "$STAGE_OUT" | sed -n 's/.*quota reset on \(.*\) UTC.*/\1/p' | tail -n 1)"
        STAGE_NOTE="límite diario de descargas alcanzado"
        [[ -n "$reset" ]] && STAGE_NOTE="$STAGE_NOTE (se renueva: $reset UTC)"
        STAGE_LIMIT=1
    elif [[ "$STAGE_OUT" == *Unauthorized* || "$STAGE_OUT" == *AuthenticationError* ]]; then
        STAGE_NOTE="usuario o contraseña rechazados"
        STAGE_AUTH_FAIL=1
    else
        bad_sites="$(printf '%s\n' "$STAGE_OUT" \
            | sed -n -E 's/^ERROR:subliminal\.utils:.*[Pp]rovider ([A-Za-z0-9_]+)$/\1/p' \
            | sort -u | tr '\n' ' ')"
        bad_sites="${bad_sites% }"
        if [[ -n "$bad_sites" ]]; then
            STAGE_NOTE="no se pudo consultar (${bad_sites// /, })"
            # Última línea de error que dejó subliminal, para saber el motivo real
            reason="$(printf '%s\n' "$STAGE_OUT" \
                | grep -E '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+: ' \
                | tail -n 1 | sed -E 's/^([A-Za-z0-9_]+\.)+//' | cut -c1-110)"
            [[ -n "$reason" ]] && STAGE_NOTE="$STAGE_NOTE: $reason"
        elif [[ $STAGE_RC -ne 0 ]]; then
            STAGE_NOTE="error de subliminal"
        else
            STAGE_NOTE="sin resultado"
        fi
    fi
    return 1
}

mode_subs() {
    banner "Descargador de subtítulos"

    if ! [[ "$SUB_LANG" =~ ^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,4})?$ ]]; then
        echo "Error: idioma no válido: '$SUB_LANG' (ejemplos: es, en, pt-BR)." >&2
        exit 1
    fi

    # --- 1. Ruta ---
    echo "[1/5] Comprobando ruta..."

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
    echo "[2/5] Comprobando herramientas..."

    if ! command -v subliminal >/dev/null 2>&1; then
        echo "Error: no se encontró 'subliminal' (solo hace falta para este modo)." >&2
        echo "Instálalo una vez, sin sudo, con:" >&2
        echo "  pipx install subliminal" >&2
        echo "Si no tienes pipx:" >&2
        echo "  sudo apt update && sudo apt install pipx   (Ubuntu 22.04 o más nuevo, Debian, Kubuntu)" >&2
        echo "  sudo pacman -S python-pipx                 (Arch/Omarchy)" >&2
        echo "Si apt sigue sin encontrar pipx, tu Ubuntu es demasiado viejo (hace falta 22.04 o más nuevo)." >&2
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

    # --- 3. Cuenta de OpenSubtitles ---
    echo "[3/5] Cuenta de OpenSubtitles..."

    SUB_CONF=/dev/null
    local logged=0 ans

    if [[ -f "$CONF_FILE" ]]; then
        SUB_CONF="$CONF_FILE"
        logged=1
        echo "      Hay una sesión guardada en $CONF_DIR"
    else
        cat <<EOF
      OpenSubtitles es la fuente de subtítulos más completa, pero necesita tu
      cuenta (es gratis). Sin ella orgie solo usa otras fuentes, con catálogos
      mucho más pequeños y que fallan más.

      Tu usuario y tu contraseña solo los recibe OpenSubtitles, que los necesita
      para funcionar. Se guardan en $CONF_DIR
      y no se envían a ningún otro sitio. El autor de orgie no recibe nada.

      Si no tienes cuenta, créala en https://www.opensubtitles.com, confirma el
      correo y vuelve a ejecutar orgie.

EOF
        read -r -p "      ¿Iniciar sesión con tu cuenta de OpenSubtitles? (s/n): " ans
        echo ""
        if [[ "$ans" == "s" || "$ans" == "S" ]]; then
            if ask_login; then
                logged=1
            else
                echo "      No se guardó ninguna sesión; se usarán solo las otras fuentes."
            fi
        else
            echo "      Sin cuenta: se usarán solo las otras fuentes."
        fi
    fi
    echo ""

    # --- 4. Buscar videos (si se indicó una carpeta) ---
    echo "[4/5] Buscando videos..."

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

    # --- 5. Descargar ---
    echo "[5/5] Buscando subtítulos ($SUB_LANG)..."
    local order="subt.is y subtitulamos.tv"
    [[ $logged -eq 1 ]] && order="OpenSubtitles, $order"
    echo "      Orden: $order, y al final BSPlayer."
    echo "      BSPlayer no usa conexión cifrada, por eso solo se prueba si los demás no tienen nada."
    echo ""

    # Primero los sitios con conexión cifrada, BSPlayer el último
    local stages=() labels=()
    if [[ $logged -eq 1 ]]; then
        stages+=("opensubtitlescom")
        labels+=("OpenSubtitles")
    fi
    stages+=("subtis subtitulamos")
    labels+=("subt.is / subtitulamos")
    stages+=("bsplayer")
    labels+=("BSPlayer")

    mkdir -p -m 700 "$CACHE_DIR" 2>/dev/null

    local got=0 skipped=0 notfound=0 i=0 s video found skip_os=0 relogin_done=0

    for video in "${videos[@]}"; do
        i=$((i + 1))

        echo "----------------------------------------"
        echo "  [$i/$total] ${video##*/}"
        echo "----------------------------------------"

        if [[ -e "${video%.*}.$SUB_LANG.srt" ]]; then
            echo "      Ya tiene subtítulo ($SUB_LANG), se omite."
            echo ""
            skipped=$((skipped + 1))
            continue
        fi

        found=0

        for ((s = 0; s < ${#stages[@]}; s++)); do
            if [[ "${stages[s]}" == "opensubtitlescom" && $skip_os -eq 1 ]]; then
                continue
            fi

            printf '      %-24s ' "${labels[s]}"

            if try_stage "${stages[s]}" "$video"; then
                echo "$STAGE_NOTE"
                found=1
                break
            fi
            echo "$STAGE_NOTE"

            if [[ "${stages[s]}" == "opensubtitlescom" ]]; then
                if [[ $STAGE_LIMIT -eq 1 || $STAGE_AGENT -eq 1 ]]; then
                    skip_os=1
                elif [[ $STAGE_AUTH_FAIL -eq 1 ]]; then
                    skip_os=1
                    if [[ $relogin_done -eq 0 ]]; then
                        relogin_done=1
                        read -r -p "      ¿Volver a escribir tus datos de OpenSubtitles? (s/n): " ans
                        if [[ "$ans" == "s" || "$ans" == "S" ]] && ask_login; then
                            skip_os=0
                            printf '      %-24s ' "${labels[s]}"
                            if try_stage "${stages[s]}" "$video"; then
                                echo "$STAGE_NOTE"
                                found=1
                                break
                            fi
                            echo "$STAGE_NOTE"
                            [[ $STAGE_AUTH_FAIL -eq 1 || $STAGE_LIMIT -eq 1 || $STAGE_AGENT -eq 1 ]] && skip_os=1
                        fi
                    fi
                fi
            fi
        done

        if [[ $found -eq 1 ]]; then
            got=$((got + 1))
        else
            notfound=$((notfound + 1))
        fi
        echo ""
    done

    banner "Proceso terminado"
    echo "  Videos revisados:         $total"
    echo "  Subtítulos descargados:   $got"
    echo "  Ya tenían subtítulo:      $skipped"
    echo "  Sin resultado:            $notfound"
    echo ""

    return 0
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

    local has_bin=0 has_conf=0 has_cache=0

    [[ -e "$INSTALL_PATH" || -L "$INSTALL_PATH" ]] && has_bin=1
    [[ -d "$CONF_DIR" && ! -L "$CONF_DIR" ]] && has_conf=1
    [[ -d "$CACHE_DIR" && ! -L "$CACHE_DIR" ]] && has_cache=1

    if [[ $((has_bin + has_conf + has_cache)) -eq 0 ]]; then
        echo "      No hay nada de orgie instalado ni guardado. No hay nada que quitar."
        echo ""
        return 0
    fi

    if [[ $has_bin -eq 1 ]] && ! is_orgie_file "$INSTALL_PATH"; then
        echo "Error: '$INSTALL_PATH' no parece ser orgie, así que no se borra por seguridad." >&2
        echo "Revísalo a mano." >&2
        exit 1
    fi

    # Las carpetas solo se borran si su ruta termina en /orgie
    if [[ $has_conf -eq 1 ]] && ! [[ "$CONF_DIR" == */orgie && "$CONF_DIR" != "/orgie" ]]; then
        echo "Error: la carpeta de configuración '$CONF_DIR' tiene una ruta rara; no se borra." >&2
        exit 1
    fi
    if [[ $has_cache -eq 1 ]] && ! [[ "$CACHE_DIR" == */orgie && "$CACHE_DIR" != "/orgie" ]]; then
        echo "Error: la carpeta de caché '$CACHE_DIR' tiene una ruta rara; no se borra." >&2
        exit 1
    fi

    echo "      Se va a quitar:"
    [[ $has_bin -eq 1 ]]   && echo "        $INSTALL_PATH"
    [[ $has_conf -eq 1 ]]  && echo "        $CONF_DIR   (incluye tu sesión de OpenSubtitles)"
    [[ $has_cache -eq 1 ]] && echo "        $CACHE_DIR"
    echo ""

    local confirm
    read -r -p "¿Continuar? (s/n): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        echo ""
        echo "No se cambió nada."
        return 0
    fi

    [[ $has_bin -eq 1 ]]   && rm -f -- "$INSTALL_PATH"
    [[ $has_conf -eq 1 ]]  && rm -rf -- "$CONF_DIR"
    [[ $has_cache -eq 1 ]] && rm -rf -- "$CACHE_DIR"

    echo ""
    echo "      Listo. Tu orgie.sh descargado (si lo conservas) y la línea de PATH"
    echo "      (si la añadiste) no se tocan."
    echo ""
}

# ============================================================
#  Modo --split
# ============================================================

# subtitle_companions <ruta sin extensión>: subtítulos que acompañan a un video
subtitle_companions() {
    local base="$1" f ext
    for f in "$base".*; do
        [[ -f "$f" ]] || continue
        ext="${f##*.}"
        ext="${ext,,}"
        case " $SUB_EXTS " in
            *" $ext "*) echo "$f" ;;
        esac
    done
}

mode_split() {
    banner "Partir en temporadas"

    if ! [[ "$SPLIT_LIST" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
        echo "Error: la lista debe ser números separados por comas, por ejemplo: -p 24,12,13" >&2
        exit 1
    fi

    local parts=() raw n sum=0
    IFS=',' read -r -a raw <<< "$SPLIT_LIST"
    for n in "${raw[@]}"; do
        n=$((10#$n))
        if [[ $n -lt 1 ]]; then
            echo "Error: cada temporada debe tener al menos 1 capítulo." >&2
            exit 1
        fi
        parts+=("$n")
        sum=$((sum + n))
    done

    # --- 1. Carpeta ---
    echo "[1/4] Comprobando carpeta de trabajo..."
    resolve_target

    # --- 2. Buscar videos ---
    echo "[2/4] Buscando videos..."

    local -A allowed=()
    local ext_list e f name ext
    IFS=',' read -r -a ext_list <<< "$EXTS"
    for e in "${ext_list[@]}"; do
        e="${e#.}"
        e="${e,,}"
        [[ -n "$e" ]] && allowed["$e"]=1
    done

    local found=()
    for f in "$TARGET_DIR"/*; do
        [[ -f "$f" && ! -L "$f" ]] || continue
        name="${f##*/}"
        [[ "$name" == *.* ]] || continue
        [[ "$name" == *$'\n'* ]] && continue
        ext="${name##*.}"
        ext="${ext,,}"
        [[ -n "${allowed[$ext]:-}" ]] || continue
        found+=("$name")
    done

    local total=${#found[@]}

    if [[ $total -eq 0 ]]; then
        echo "      No se encontraron videos (extensiones: $EXTS) en '$TARGET_DIR'."
        echo ""
        return 0
    fi

    local videos
    mapfile -t videos < <(printf '%s\n' "${found[@]}" | LC_ALL=C sort -V)

    echo "      Videos encontrados: $total"
    echo ""

    if [[ $total -ne $sum ]]; then
        echo "Error: la lista suma $sum capítulos pero hay $total videos en la carpeta." >&2
        echo "No se cambió nada. Revisa la lista o usa -e para limitar las extensiones." >&2
        exit 1
    fi

    local k
    for ((k = 1; k <= ${#parts[@]}; k++)); do
        if [[ -e "$TARGET_DIR/T$k" || -L "$TARGET_DIR/T$k" ]]; then
            echo "Error: ya existe '$TARGET_DIR/T$k'. Muévela o bórrala y vuelve a ejecutar." >&2
            exit 1
        fi
    done

    # --- 3. Vista previa ---
    echo "[3/4] Vista previa (todavía no se ha tocado nada)..."
    echo ""

    local start=0 count subs c i
    for ((k = 1; k <= ${#parts[@]}; k++)); do
        count="${parts[k-1]}"
        subs=0
        for ((i = start; i < start + count; i++)); do
            c="$(subtitle_companions "$TARGET_DIR/${videos[i]%.*}" | wc -l)"
            subs=$((subs + c))
        done
        printf '      T%s: %s videos (%s ... %s)' "$k" "$count" "${videos[start]}" "${videos[start+count-1]}"
        [[ $subs -gt 0 ]] && printf ', con %s subtítulos' "$subs"
        echo ""
        start=$((start + count))
    done
    echo ""

    local confirm
    read -r -p "¿Mover los videos a esas carpetas? (s/n): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        echo ""
        echo "No se cambió nada."
        return 0
    fi
    echo ""

    # --- 4. Mover ---
    echo "[4/4] Moviendo..."

    local moved=0 failed=0 base sub
    start=0
    for ((k = 1; k <= ${#parts[@]}; k++)); do
        count="${parts[k-1]}"
        if ! mkdir "$TARGET_DIR/T$k"; then
            echo "Error: no se pudo crear T$k." >&2
            exit 1
        fi
        for ((i = start; i < start + count; i++)); do
            base="$TARGET_DIR/${videos[i]%.*}"
            if mv -n -- "$TARGET_DIR/${videos[i]}" "$TARGET_DIR/T$k/"; then
                moved=$((moved + 1))
            else
                echo "      Error al mover '${videos[i]}'." >&2
                failed=$((failed + 1))
                continue
            fi
            while IFS= read -r sub; do
                [[ -n "$sub" ]] && mv -n -- "$sub" "$TARGET_DIR/T$k/"
            done < <(subtitle_companions "$base")
        done
        start=$((start + count))
    done

    banner "Proceso terminado"
    echo "  Temporadas creadas:  ${#parts[@]}"
    echo "  Videos movidos:      $moved"
    [[ $failed -gt 0 ]] && echo "  Con error:           $failed"
    echo ""

    [[ $failed -eq 0 ]]
}

# ============================================================
#  Modo --dupes
# ============================================================

# human_size <bytes>
human_size() {
    numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "$1 bytes"
}

mode_dupes() {
    banner "Buscar duplicados"

    echo "[1/4] Comprobando carpeta de trabajo..."
    resolve_target

    echo "[2/4] Agrupando archivos por tamaño..."

    local -A by_size=()
    local f size
    for f in "$TARGET_DIR"/*; do
        [[ -f "$f" && ! -L "$f" ]] || continue
        [[ "${f##*/}" == *$'\n'* ]] && continue
        size="$(stat -c %s -- "$f")"
        [[ "$size" -gt 0 ]] || continue
        by_size[$size]+="$f"$'\n'
    done

    # Primero una huella rápida (principio y final del archivo) y solo si
    # coincide se calcula la completa, para no leer gigas enteros sin necesidad.
    echo "[3/4] Comparando contenido (con archivos grandes puede tardar)..."

    local -A by_quick=() by_full=()
    local key members file quick full checked=0
    for key in "${!by_size[@]}"; do
        mapfile -t members <<< "${by_size[$key]%$'\n'}"
        [[ ${#members[@]} -ge 2 ]] || continue
        for file in "${members[@]}"; do
            quick="$({ head -c 1048576 -- "$file"; tail -c 1048576 -- "$file"; } | sha256sum | cut -d' ' -f1)"
            by_quick["$key:$quick"]+="$file"$'\n'
        done
    done

    for key in "${!by_quick[@]}"; do
        mapfile -t members <<< "${by_quick[$key]%$'\n'}"
        [[ ${#members[@]} -ge 2 ]] || continue
        for file in "${members[@]}"; do
            checked=$((checked + 1))
            printf '\r      Calculando huella completa... %s' "$checked"
            full="$(sha256sum -- "$file" | cut -d' ' -f1)"
            by_full["$key:$full"]+="$file"$'\n'
        done
    done
    [[ $checked -gt 0 ]] && echo ""
    echo ""

    # Para cada grupo idéntico se conserva el más antiguo (si empatan, el de
    # nombre más corto, que suele ser el original y no "video (2).mp4").
    local keep_list=() del_list=() del_bytes=0 groups=0
    local sorted entry g keep
    for key in "${!by_full[@]}"; do
        mapfile -t members <<< "${by_full[$key]%$'\n'}"
        [[ ${#members[@]} -ge 2 ]] || continue
        groups=$((groups + 1))

        mapfile -t sorted < <(
            for file in "${members[@]}"; do
                printf '%s\t%05d\t%s\n' "$(stat -c '%.9W' -- "$file")" "${#file}" "$file"
            done | LC_ALL=C sort -t $'\t' -k1,1 -k2,2 -k3,3
        )

        keep="${sorted[0]#*$'\t'}"
        keep="${keep#*$'\t'}"
        keep_list+=("$keep")

        for ((g = 1; g < ${#sorted[@]}; g++)); do
            entry="${sorted[g]#*$'\t'}"
            entry="${entry#*$'\t'}"
            del_list+=("$entry")
            del_bytes=$((del_bytes + $(stat -c %s -- "$entry")))
        done
    done

    echo "[4/4] Resultado..."
    echo ""

    if [[ $groups -eq 0 ]]; then
        echo "      No hay archivos duplicados en '$TARGET_DIR'."
        echo ""
        return 0
    fi

    echo "      Grupos de archivos idénticos: $groups"
    echo "      Copias que se pueden borrar:  ${#del_list[@]} ($(human_size "$del_bytes"))"
    echo ""

    # Mostrar cada grupo: qué se conserva y qué se borraría
    for key in "${!by_full[@]}"; do
        mapfile -t members <<< "${by_full[$key]%$'\n'}"
        [[ ${#members[@]} -ge 2 ]] || continue
        mapfile -t sorted < <(
            for file in "${members[@]}"; do
                printf '%s\t%05d\t%s\n' "$(stat -c '%.9W' -- "$file")" "${#file}" "$file"
            done | LC_ALL=C sort -t $'\t' -k1,1 -k2,2 -k3,3
        )
        keep="${sorted[0]#*$'\t'}"; keep="${keep#*$'\t'}"
        echo "      Se conserva: ${keep##*/}"
        for ((g = 1; g < ${#sorted[@]}; g++)); do
            entry="${sorted[g]#*$'\t'}"; entry="${entry#*$'\t'}"
            echo "      Se borraría: ${entry##*/}"
        done
        echo ""
    done

    local confirm
    read -r -p "¿Borrar las ${#del_list[@]} copias? Esto no se puede deshacer. (s/n): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        echo ""
        echo "No se borró nada."
        return 0
    fi
    echo ""

    local deleted=0
    for file in "${del_list[@]}"; do
        if rm -f -- "$file"; then
            deleted=$((deleted + 1))
        else
            echo "      No se pudo borrar '${file##*/}'." >&2
        fi
    done

    banner "Proceso terminado"
    echo "  Copias borradas:   $deleted"
    echo "  Espacio liberado:  $(human_size "$del_bytes")"
    echo ""
}

# ============================================================
#  Modo --update
# ============================================================

mode_update() {
    banner "Actualizar orgie"

    if ! command -v curl >/dev/null 2>&1; then
        echo "Error: hace falta 'curl' para buscar actualizaciones." >&2
        exit 1
    fi

    if ! is_orgie_file "$INSTALL_PATH"; then
        echo "Error: orgie no está instalado en '$INSTALL_PATH'." >&2
        echo "Instálalo primero con:  bash orgie.sh --install" >&2
        exit 1
    fi

    local current latest newest
    current="$(sed -n 's/^VERSION="\(.*\)"$/\1/p' "$INSTALL_PATH" | head -n 1)"

    echo "      Versión instalada: ${current:-desconocida}"
    echo "      Buscando en: $REPO_RAW_URL"
    echo ""

    UPDATE_TMP="$(mktemp)"
    trap 'rm -f "${UPDATE_TMP:-}"' EXIT

    if ! curl -fsSL --max-time 20 -o "$UPDATE_TMP" "$REPO_RAW_URL"; then
        echo "Error: no se pudo descargar la versión publicada (¿sin internet?)." >&2
        exit 1
    fi

    # Se comprueba que lo descargado sea de verdad este script y que no esté roto
    if ! is_orgie_file "$UPDATE_TMP" || ! bash -n "$UPDATE_TMP" 2>/dev/null; then
        echo "Error: lo descargado no parece un orgie válido. No se instala nada." >&2
        exit 1
    fi

    latest="$(sed -n 's/^VERSION="\(.*\)"$/\1/p' "$UPDATE_TMP" | head -n 1)"
    if [[ -z "$latest" || -z "$current" ]]; then
        echo "Error: no se pudo leer la versión. No se instala nada." >&2
        exit 1
    fi

    echo "      Versión publicada: $latest"
    echo ""

    if [[ "$latest" == "$current" ]]; then
        echo "      Ya tienes la última versión."
        echo ""
        return 0
    fi

    newest="$(printf '%s\n%s\n' "$current" "$latest" | sort -V | tail -n 1)"
    if [[ "$newest" == "$current" ]]; then
        echo "      Tu versión es más nueva que la publicada. No se cambia nada."
        echo ""
        return 0
    fi

    local confirm
    read -r -p "¿Instalar la versión $latest en lugar de la $current? (s/n): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        echo ""
        echo "No se cambió nada."
        return 0
    fi

    if ! install -m 755 -- "$UPDATE_TMP" "$INSTALL_PATH"; then
        echo "Error: no se pudo copiar la nueva versión a '$INSTALL_PATH'." >&2
        exit 1
    fi

    echo ""
    echo "      Actualizado a la versión $latest."
    echo ""
}

# ============================================================
#  Modo --split junto con --series
# ============================================================

mode_splitseries() {
    if [[ $BY_NAME -eq 1 ]]; then
        banner "Temporadas numeradas por nombre"
    else
        banner "Temporadas numeradas por fecha de creación"
    fi

    if ! [[ "$SPLIT_LIST" =~ ^[0-9]+(,[0-9]+)*$ ]]; then
        echo "Error: la lista debe ser números separados por comas, por ejemplo: -p 11,12" >&2
        exit 1
    fi
    if ! [[ "$START" =~ ^[0-9]+$ ]]; then
        echo "Error: -n/--start debe ser un número entero (ej: -n 36)." >&2
        exit 1
    fi
    START=$((10#$START))

    local parts=() raw n sum=0
    IFS=',' read -r -a raw <<< "$SPLIT_LIST"
    for n in "${raw[@]}"; do
        n=$((10#$n))
        if [[ $n -lt 1 ]]; then
            echo "Error: cada temporada debe tener al menos 1 capítulo." >&2
            exit 1
        fi
        parts+=("$n")
        sum=$((sum + n))
    done

    # --- 1. Carpeta ---
    echo "[1/4] Comprobando carpeta de trabajo..."
    resolve_target

    if [[ $BY_NAME -eq 0 ]] && ! stat -c '%W' / >/dev/null 2>&1; then
        echo "Error: 'stat' no soporta la fecha de creación (se necesita GNU stat, el de Linux)." >&2
        exit 1
    fi

    # --- 2. Videos y fechas de creación ---
    if [[ $BY_NAME -eq 1 ]]; then
        echo "[2/4] Buscando videos y ordenándolos por nombre..."
    else
        echo "[2/4] Buscando videos y leyendo su fecha de creación..."
    fi

    local -A allowed=()
    local ext_list e f name ext birth lines=() skipped=0
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

        if [[ "$name" == *$'\t'* || "$name" == *$'\n'* ]]; then
            echo "      Aviso: se omite '$name' (tiene tabulador o salto de línea en el nombre)."
            skipped=$((skipped + 1))
            continue
        fi

        if [[ $BY_NAME -eq 1 ]]; then
            birth="-"
        else
            birth="$(stat -c '%.9W' -- "$f")"
            if ! [[ "$birth" =~ ^[1-9][0-9]*(\.[0-9]+)?$ ]]; then
                echo "Error: no se pudo leer la fecha de creación de '$name'." >&2
                echo "Tu sistema de archivos quizá no la guarda, así que no es seguro ordenar con ella." >&2
                echo "Puedes usar --by-name para ordenar por nombre en vez de por fecha." >&2
                exit 1
            fi
        fi
        lines+=("$birth"$'\t'"$name")
    done

    local total=${#lines[@]}

    if [[ $total -eq 0 ]]; then
        echo "      No se encontraron videos (extensiones: $EXTS) en '$TARGET_DIR'."
        echo ""
        return 0
    fi

    local sorted
    mapfile -t sorted < <(printf '%s\n' "${lines[@]}" | sort_entries)

    echo "      Videos encontrados: $total"
    [[ $skipped -gt 0 ]] && echo "      Omitidos por nombre raro: $skipped"
    echo ""

    if [[ $total -ne $sum ]]; then
        echo "Error: la lista suma $sum capítulos pero hay $total videos en la carpeta." >&2
        echo "No se cambió nada. Revisa la lista o usa -e para limitar las extensiones." >&2
        exit 1
    fi

    local k
    for ((k = 1; k <= ${#parts[@]}; k++)); do
        if [[ -e "$TARGET_DIR/T$k" || -L "$TARGET_DIR/T$k" ]]; then
            echo "Error: ya existe '$TARGET_DIR/T$k'. Muévela o bórrala y vuelve a ejecutar." >&2
            exit 1
        fi
    done

    # Cada temporada empieza en 01 (la primera, en el -n que indiques) y usa
    # 2 cifras, o 3 si llega a 100 capítulos o más.
    local V_SRC=() V_DST=() V_BIRTH=() V_SEASON=()
    local idx=0 i count first_num last_num width num newbase entry
    local ties=0 prev_birth=""
    for ((k = 1; k <= ${#parts[@]}; k++)); do
        count="${parts[k-1]}"
        first_num=1
        [[ $k -eq 1 ]] && first_num=$START
        last_num=$((first_num + count - 1))
        width=${#last_num}
        [[ $width -lt 2 ]] && width=2

        for ((i = 0; i < count; i++)); do
            entry="${sorted[idx]}"
            birth="${entry%%$'\t'*}"
            name="${entry#*$'\t'}"
            ext="${name##*.}"
            num=$((first_num + i))
            newbase="$(printf '%0*d' "$width" "$num")"

            V_SRC+=("$name")
            V_DST+=("T$k/$newbase.$ext")
            V_BIRTH+=("$birth")
            V_SEASON+=("$k")

            [[ $BY_NAME -eq 0 && "$birth" == "$prev_birth" ]] && ties=$((ties + 1))
            prev_birth="$birth"
            idx=$((idx + 1))
        done
    done

    # Los subtítulos con el mismo nombre que un video se mueven y renombran con él
    local S_SRC=() S_DST=() sub rest dest_rel
    local -A is_video=() claimed=()
    for name in "${V_SRC[@]}"; do is_video["$name"]=1; done

    for ((i = 0; i < total; i++)); do
        dest_rel="${V_DST[i]}"
        newbase="${dest_rel#*/}"
        newbase="${newbase%.*}"
        while IFS= read -r sub; do
            [[ -n "$sub" ]] || continue
            sub="${sub##*/}"
            [[ -z "${claimed[$sub]:-}" && -z "${is_video[$sub]:-}" ]] || continue
            rest="${sub#"${V_SRC[i]%.*}".}"
            claimed["$sub"]=1
            S_SRC+=("$sub")
            S_DST+=("${dest_rel%%/*}/$newbase.$rest")
        done < <(subtitle_companions "$TARGET_DIR/${V_SRC[i]%.*}")
    done

    # --- 3. Vista previa ---
    echo "[3/4] Vista previa (todavía no se ha tocado nada)..."
    echo ""

    if [[ $ties -gt 0 ]]; then
        echo "      Aviso: $ties archivos tienen exactamente la misma fecha de creación que otro;"
        echo "             entre ellos el orden se decide por nombre."
        echo ""
    fi

    local start=0 when
    for ((k = 1; k <= ${#parts[@]}; k++)); do
        count="${parts[k-1]}"
        echo "      T$k: $count videos"
        for ((i = start; i < start + count; i++)); do
            if [[ $count -gt 6 && $i -eq $((start + 3)) ]]; then
                echo "        ..."
            fi
            if [[ $count -gt 6 && $i -ge $((start + 3)) && $i -lt $((start + count - 2)) ]]; then
                continue
            fi
            if [[ $BY_NAME -eq 1 ]]; then
                printf '        %s  <-  %s\n' "${V_DST[i]}" "${V_SRC[i]}"
            else
                when="$(date -d "@${V_BIRTH[i]%.*}" '+%d/%m %H:%M:%S')"
                printf '        %s  <-  %s   (creado %s)\n' "${V_DST[i]}" "${V_SRC[i]}" "$when"
            fi
        done
        start=$((start + count))
        echo ""
    done

    local sub_text=""
    if [[ ${#S_SRC[@]} -gt 0 ]]; then
        echo "      Además, ${#S_SRC[@]} subtítulos se mueven y renombran con su video, por ejemplo:"
        echo "        ${S_DST[0]}  <-  ${S_SRC[0]}"
        echo ""
        sub_text=" y ${#S_SRC[@]} subtítulos"
    fi

    local confirm
    read -r -p "¿Mover y renombrar los $total videos$sub_text? Esto no se puede deshacer. (s/n): " confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        echo ""
        echo "No se cambió nada."
        return 0
    fi
    echo ""

    # --- 4. Mover y renombrar ---
    echo "[4/4] Moviendo y renombrando..."

    local made=() j
    for ((k = 1; k <= ${#parts[@]}; k++)); do
        if ! mkdir "$TARGET_DIR/T$k"; then
            echo "Error: no se pudo crear T$k. Se deshace lo hecho." >&2
            for j in "${made[@]}"; do rmdir "$TARGET_DIR/$j" 2>/dev/null; done
            exit 1
        fi
        made+=("T$k")
    done

    local all_src=("${V_SRC[@]}") all_dst=("${V_DST[@]}")
    if [[ ${#S_SRC[@]} -gt 0 ]]; then
        all_src+=("${S_SRC[@]}")
        all_dst+=("${S_DST[@]}")
    fi

    for ((i = 0; i < ${#all_src[@]}; i++)); do
        if mv -n -- "$TARGET_DIR/${all_src[i]}" "$TARGET_DIR/${all_dst[i]}" \
            && [[ -e "$TARGET_DIR/${all_dst[i]}" && ! -e "$TARGET_DIR/${all_src[i]}" ]]; then
            :
        else
            echo "Error al mover '${all_src[i]}'. Se devuelve todo a como estaba..." >&2
            for ((j = i - 1; j >= 0; j--)); do
                mv -n -- "$TARGET_DIR/${all_dst[j]}" "$TARGET_DIR/${all_src[j]}"
            done
            for j in "${made[@]}"; do rmdir "$TARGET_DIR/$j" 2>/dev/null; done
            exit 1
        fi
    done

    banner "Proceso terminado"
    echo "  Temporadas creadas:  ${#parts[@]}"
    echo "  Videos movidos:      $total"
    [[ ${#S_SRC[@]} -gt 0 ]] && echo "  Subtítulos movidos:  ${#S_SRC[@]}"
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
SPLIT_LIST=""
START_SET=0
EXT_SET=0
LANG_SET=0
BY_NAME=0

set_mode() {
    local new="$1"
    if [[ -z "$MODE" || "$MODE" == "$new" ]]; then
        MODE="$new"
        return
    fi
    case "$MODE:$new" in
        split:series|series:split|splitseries:series|splitseries:split)
            MODE="splitseries" ;;
        *)
            echo "Error: elige un solo modo, no varios (usa -h para ver la lista)." >&2
            exit 1 ;;
    esac
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
        -v|--version) echo "orgie $VERSION"; exit 0 ;;
        -g|--games)   set_mode games;  shift ;;
        -s|--series)  set_mode series; shift ;;
        -t|--subs)    set_mode subs;   shift ;;
        -d|--dupes)   set_mode dupes;  shift ;;
        -p|--split)   need_value "$1" $#; SPLIT_LIST="$2"; set_mode split; shift 2 ;;
        --update)     set_mode update;    shift ;;
        --install)    set_mode install;   shift ;;
        --uninstall)  set_mode uninstall; shift ;;
        -n|--start)   need_value "$1" $#; START="$2";    START_SET=1; shift 2 ;;
        -e|--ext)     need_value "$1" $#; EXTS="$2";     EXT_SET=1;   shift 2 ;;
        -l|--lang)    need_value "$1" $#; SUB_LANG="$2"; LANG_SET=1;  shift 2 ;;
        --by-name)    BY_NAME=1; shift ;;
        --)           shift; while [[ $# -gt 0 ]]; do set_target "$1"; shift; done ;;
        -*)           echo "Error: opción desconocida: $1 (usa -h para ver la ayuda)." >&2; exit 1 ;;
        *)            set_target "$1"; shift ;;
    esac
done

if [[ -z "$MODE" ]]; then
    echo "Error: falta indicar el modo (por ejemplo -g, -s o -t)." >&2
    echo "" >&2
    usage >&2
    exit 1
fi

if [[ $BY_NAME -eq 1 && "$MODE" != "series" && "$MODE" != "splitseries" ]]; then
    echo "Error: --by-name solo se usa con -s (o con -p y -s juntos)." >&2
    exit 1
fi

# Cada modo solo acepta sus propias opciones
bad_opts=0
case "$MODE" in
    install|uninstall|update)
        [[ $((START_SET + EXT_SET + LANG_SET)) -gt 0 || -n "$TARGET_ARG" ]] && bad_opts=1 ;;
    games|dupes)
        [[ $((START_SET + EXT_SET + LANG_SET)) -gt 0 ]] && bad_opts=1 ;;
    series)
        [[ $LANG_SET -eq 1 ]] && bad_opts=1 ;;
    subs)
        [[ $START_SET -eq 1 ]] && bad_opts=1 ;;
    split)
        [[ $START_SET -eq 1 || $LANG_SET -eq 1 ]] && bad_opts=1 ;;
    splitseries)
        [[ $LANG_SET -eq 1 ]] && bad_opts=1 ;;
esac
if [[ $bad_opts -eq 1 ]]; then
    echo "Error: alguna de las opciones o la carpeta indicada no se usa con este modo (mira -h)." >&2
    exit 1
fi

case "$MODE" in
    games)     mode_games ;;
    series)    mode_series ;;
    subs)      mode_subs ;;
    split)     mode_split ;;
    splitseries) mode_splitseries ;;
    dupes)     mode_dupes ;;
    update)    mode_update ;;
    install)   mode_install ;;
    uninstall) mode_uninstall ;;
esac
