# orgie

Gestor de organizaciones de archivos en Bash. Un solo comando con varios **modos**, que se eligen con una flag:

| Modo | Flag | Para qué sirve |
|---|---|---|
| Juegos | `-g`, `--games` | Descomprime y organiza juegos de Nintendo Switch (`.rar`/`.zip`) en una carpeta por juego |
| Series | `-s`, `--series` | Numera videos (`01`, `02`... o `001`, `002`...) según su fecha de creación en el disco |
| Subtítulos | `-t`, `--subs` | Descarga subtítulos (por defecto en español) y los nombra igual que el video, sin cuentas |

Se pueden añadir más modos en el futuro sin cambiar la forma de usarlo.

Además: `--install` y `--uninstall` para instalar/quitar el comando (ver [Instalación](#instalación)).

## Instalación

Instala `orgie` como comando propio de tu usuario (se copia a `~/.local/bin/orgie`). No usa `sudo` y no modifica ningún archivo de configuración de tu terminal.

### Instalar (descarga + instala en un paso)

Copia y pega este bloque en la terminal:

```bash
f=$(mktemp) && curl -fsSL -o "$f" https://raw.githubusercontent.com/CesarSullen/orgie/main/orgie.sh && bash "$f" --install; rm -f "$f"
```

Qué hace: descarga `orgie.sh` a un archivo temporal, ejecuta su instalador (`--install`) y borra el temporal. Si prefieres leer el script antes de ejecutarlo (buena costumbre), usa la versión en pasos:

```bash
curl -fsSL -o orgie.sh https://raw.githubusercontent.com/CesarSullen/orgie/main/orgie.sh
less orgie.sh              # léelo; sal con la tecla q
bash orgie.sh --install
```

También puedes clonar el repositorio:

```bash
git clone https://github.com/CesarSullen/orgie.git
cd orgie
bash orgie.sh --install
```

Al terminar, el instalador te dice si `~/.local/bin` ya está en tu `PATH`. Si no lo está, te indica la línea a añadir a `~/.bashrc` (o `~/.zshrc`) y debes abrir una terminal nueva. Comprueba que funciona con:

```bash
orgie --help
```

### Actualizar

Vuelve a ejecutar el bloque de instalación. Si la versión instalada es distinta, pregunta antes de reemplazarla.

### Desinstalar

```bash
orgie --uninstall
```

Pide confirmación y solo borra `~/.local/bin/orgie` (y únicamente si ese archivo es realmente orgie). No toca tus videos, tus juegos ni ningún otro archivo. Si prefieres hacerlo a mano: `rm ~/.local/bin/orgie`.

### Uso sin instalar

```bash
bash orgie.sh -s .
```

## Uso

```bash
orgie <modo> [opciones] [carpeta]
orgie --help
orgie --version
```

Si no se indica carpeta, usa el directorio actual (`.`). Hay que elegir **un** modo.

Si lo ejecutas sin modo (`orgie .` o solo `orgie`), no hace nada: muestra un error y la misma ayuda que `--help`, y termina.

### Ejemplos rápidos

```bash
orgie -g .                      # juegos: organiza los .rar/.zip de la carpeta actual
orgie -g ~/Downloads/Games      # juegos: en otra carpeta, sin entrar en ella
orgie -s .                      # series: numera los videos de la carpeta actual
orgie -s ~/Series/Temp1         # series: en otra carpeta
orgie -s -n 36 .                # series: empieza en 036 en vez de 01
orgie -t .                     # subtítulos: para los videos de la carpeta actual
orgie -t ~/Peliculas/Mi.mkv     # subtítulos: para una película
orgie -t ~/Peliculas            # subtítulos: para todos los videos de la carpeta
orgie -t -l en .                # subtítulos: en inglés en vez de español
bash orgie.sh --install          # instalar el comando (desde el orgie.sh descargado)
orgie --uninstall               # quitar el comando instalado
orgie --help                    # ver la ayuda
```

## Modo `--games`

Pensado para descargas de juegos de Switch en formato `.rar` o `.zip` (base + update/DLC).

1. Busca todos los `.rar` y `.zip` de la carpeta.
2. A partir del nombre de archivo, deduce el nombre del juego y descarta la parte de "Switch NSP Base Game" / "Switch NSP Update X.Y.Z" / etc.
3. Descomprime cada archivo dentro de `NombreDelJuego/` (si el juego ya tiene carpeta, añade ahí el update o DLC, aunque cambie la capitalización).
4. Si la extracción deja una única subcarpeta anidada, mueve su contenido un nivel arriba.
5. Si un archivo falla (corrupto, formato no reconocido...), lo deja intacto, avisa y sigue con el resto.
6. Genera `README.md` en esa carpeta con el tamaño de cada juego (de mayor a menor) y un total.
7. Muestra un resumen y pregunta si quieres borrar los archivos ya extraídos **con éxito** (los que fallaron nunca se tocan).

Ejemplo:

```
$ ls
'Kingdom Rush Frontiers Switch NSP BASE GAME.rar'
'Kingdom Rush Frontiers Switch NSP Update 3.2.23.rar'
'Pokemon-HOME-Switch-NSP-Base-Game.rar'
'Pokemon-HOME-Switch-NSP-Update-1.2.1.rar'

$ orgie -g .      # y confirmar el borrado
$ ls
'Kingdom Rush Frontiers'/
'Pokemon HOME'/
README.md
```

Convención de nombres que espera (con espacios o guiones, da igual):

```
NombreDelJuego Switch NSP Base Game.rar
NombreDelJuego Switch NSP Update 1.2.3.zip
```

Todo lo que va **después** de la palabra "Switch" se descarta, y los guiones se convierten en espacios. Si un archivo no contiene la palabra "Switch", se avisa y se deja intacto.

## Modo `--series`

Pensado para capítulos descargados (por ejemplo desde Telegram).

1. Busca los videos de la carpeta (`mp4`, `mkv`, `avi`, `mov`, `webm`, `m4v`, `ts`, `flv`, `wmv`; los demás archivos no se tocan).
2. Lee la fecha de creación de cada uno (precisión de nanosegundos) y los ordena del más antiguo al más reciente.
3. Calcula cuántas cifras usar: si el último número tiene 1 o 2 cifras usa 2 (`05`); si tiene 3, usa 3 (`005`); y así sucesivamente.
4. Muestra una **vista previa** y pide confirmación (`s`/`n`). Hasta ese momento no cambia nada.
5. Renombra en dos fases (primero a nombres temporales) para que ningún archivo pise a otro.

El renombrado **no se puede deshacer**: revisa la vista previa antes de confirmar.

Opciones:

| Opción | Qué hace |
|---|---|
| `-n N`, `--start N` | Número con el que empieza (por defecto 1). `-n 36` genera `036`, `037`... |
| `-e LISTA`, `--ext LISTA` | Extensiones a procesar, separadas por comas y sin punto. Ej: `-e mp4,mkv` |

Ejemplos:

```bash
orgie -s .                       # numera desde 01 (o 001 si son 100 o más)
orgie -s -n 36 .                 # numera desde 036
orgie -s -e mkv ~/Series/Temp1   # solo archivos .mkv de esa carpeta
```

### Cómo decide el orden

Se usa la fecha de **creación**: el instante en que el archivo apareció en tu disco al empezar a descargarse, y no cambia después. **Haz clic en descargar en el orden correcto** (capítulo 1, luego 2, luego 3...) y el script respetará ese orden aunque Telegram termine las descargas en otro orden. La fecha de *modificación* no se usa porque cambia cuando termina la descarga.

Cosas que pueden estropear la fecha de creación:

- Copiar los archivos (con `cp` o con el administrador de archivos) a otra carpeta o disco: la copia recibe una fecha nueva. Ejecuta orgie en la carpeta donde se descargaron, o mueve (no copies) dentro del mismo disco.
- Si dos archivos tienen exactamente la misma fecha, se avisa y entre ellos se ordena por nombre.
- Si el sistema de archivos no guarda la fecha de creación, orgie lo detecta y se detiene sin cambiar nada.

## Modo `--subs`

Descarga subtítulos para una película (o para todos los videos de una carpeta) y los guarda **junto al video, con el mismo nombre**:

```
Pelicula.mkv
Pelicula.es.srt     <- lo crea orgie
```

Reproductores como VLC o mpv cargan ese archivo solos al abrir la película, sin configurar nada.

1. Si le pasas un archivo, trabaja con ese video; si le pasas una carpeta, con todos sus videos (misma lista de extensiones que `--series`, no entra en subcarpetas).
2. Si el video ya tiene `Pelicula.es.srt`, lo omite. Si trae un subtítulo incrustado en ese idioma, tampoco descarga.
3. Busca en tres sitios que **no piden cuenta**: podnapisi.net, subt.is y subtitulamos.tv. Elige el subtítulo que mejor coincide con el nombre/versión del video, prefiriendo los normales sobre los de sordos.
4. Guarda el resultado y al final muestra cuántos se descargaron, cuántos ya existían y cuántos no tuvieron resultado.

No pide confirmación porque solo **agrega** archivos `.srt`; no cambia ni borra nada existente. Para quitar uno, bórralo a mano.

Opciones:

| Opción | Qué hace |
|---|---|
| `-l CÓDIGO`, `--lang CÓDIGO` | Idioma del subtítulo (por defecto `es`). Ej: `-l en`, `-l pt-BR` |
| `-e LISTA`, `--ext LISTA` | Extensiones a procesar (solo al pasar una carpeta) |

Honestidad sobre la calidad: los subtítulos los suben usuarios, así que no se puede garantizar que sean buenos ni que exista uno para cada película. Si el resultado sale desincronizado o malo, bórralo y prueba otro.

### Privacidad

- No usa cuentas, claves de API ni archivos de configuración (ignora cualquier configuración de subliminal que tengas).
- Solo se contactan los tres sitios de arriba. Esos sitios ven tu IP y lo que se pregunta (título/año deducidos del nombre del archivo y una huella del video). **No se sube el video.**
- Orgie no envía nada a ningún otro lugar. Si quieres más privacidad frente a esos sitios, usa una VPN.

### Qué necesita (solo este modo)

Los modos `--games` y `--series` no necesitan nada de esto. Para `--subs` hace falta **subliminal**, un programa en Python que hace la búsqueda y descarga. Se instala una vez, sin `sudo`, con `pipx`, que lo guarda aislado en su propia carpeta sin mezclarlo con el resto del sistema (ocupa unos 50 MB):

```bash
pipx install subliminal
```

Si no tienes `pipx`: `sudo apt install pipx` (Debian/Ubuntu/Kubuntu) o `sudo pacman -S python-pipx` (Arch/Omarchy). Para quitarlo del todo: `pipx uninstall subliminal`. Orgie nunca lo instala por su cuenta: si falta, te lo dice y se detiene.

## Requisitos

- Bash y `stat` de GNU (incluidos en cualquier distro Linux).
- Solo para `--subs`: `subliminal` (ver arriba).
- Solo para `--games`, al menos una herramienta de extracción:
  ```bash
  sudo apt install unrar        # para .rar
  sudo apt install unzip        # para .zip
  sudo apt install p7zip-full   # alternativa que cubre ambos formatos
  ```

## Notas de seguridad

- Nunca renombra ni borra nada sin pedir confirmación explícita (`s`/`n`).
- `--games` solo borra los archivos que se extrajeron correctamente en esa ejecución, y solo si lo confirmas. Es seguro ejecutarlo varias veces sobre la misma carpeta.
- `--series` no pisa archivos existentes: si un nombre nuevo choca con un archivo que no es del lote, se detiene sin cambiar nada.
- `--install` solo copia un archivo a `~/.local/bin` y `--uninstall` solo borra ese mismo archivo; ninguno usa `sudo` ni edita tu configuración.
- No usa `sudo` ni abre puertos. Solo `--subs` accede a internet, y únicamente a los tres sitios indicados.
- Si `--series` se interrumpe a medias, pueden quedar archivos `.orgie.tmp.N` (son tus videos); orgie se niega a continuar hasta que los revises.

## Resultado esperado

- `--games`: una carpeta por juego con base y updates juntos, más un `README.md` con los tamaños.
- `--series`: los videos numerados en el orden en que empezaron a descargarse, sin ningún otro archivo modificado ni creado.
- `--subs`: un `Nombre.es.srt` junto a cada película que tuvo resultado, listo para que el reproductor lo cargue solo.

## Licencia

MIT — ver [LICENSE](./LICENSE).
