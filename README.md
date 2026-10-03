# orgie

Un solo script de Bash para cosas que hago a mano todo el tiempo con descargas: ordenar juegos de Switch, numerar capítulos de series, repartirlos en temporadas, bajar subtítulos y quitar duplicados. Se elige qué hacer con una flag.

```bash
orgie -g carpeta          # juegos de Switch
orgie -s carpeta          # numerar capítulos
orgie -p 24,12 carpeta    # repartir en temporadas
orgie -t carpeta          # subtítulos
orgie -d carpeta          # duplicados
orgie --update            # actualizar orgie
```

Si no pones carpeta usa la actual. Si no pones ninguna flag, muestra la ayuda y no toca nada.

## Instalación

Se instala solo para tu usuario, en `~/.local/bin/orgie`. No usa `sudo` ni toca la configuración de tu terminal.

Descarga e instala de una vez:

```bash
f=$(mktemp) && curl -fsSL -o "$f" https://raw.githubusercontent.com/CesarSullen/orgie/main/orgie.sh && bash "$f" --install; rm -f "$f"
```

Si prefieres leerlo antes de ejecutarlo (no está de más):

```bash
curl -fsSL -o orgie.sh https://raw.githubusercontent.com/CesarSullen/orgie/main/orgie.sh
less orgie.sh
bash orgie.sh --install
```

O clonando el repo:

```bash
git clone https://github.com/CesarSullen/orgie.git
cd orgie
bash orgie.sh --install
```

Al terminar te dice si `~/.local/bin` está en tu `PATH`. Si no, te da la línea que tienes que añadir a `~/.bashrc` (o `~/.zshrc`) y luego abres una terminal nueva. Para comprobarlo:

```bash
orgie --help
```

Para actualizar:

```bash
orgie --update
```

Mira la versión publicada en GitHub, la compara con la que tienes instalada y, si hay una más nueva, te lo dice y pregunta antes de reemplazarla. Comprueba que lo descargado sea de verdad orgie y que no esté roto, y no ejecuta nada de lo que baja. Es lo único, además de `-t`, que entra a internet, y solo a GitHub.

Para desinstalar:

```bash
orgie --uninstall
```

Te enseña qué va a quitar (el script, tu sesión de OpenSubtitles si la guardaste y la caché) y pide confirmación. No toca tus videos ni tus juegos.

Sin instalar también funciona: `bash orgie.sh -s .`

## Ejemplos rápidos

```bash
orgie -g .                     # juegos: organiza los .rar/.zip de la carpeta actual
orgie -g ~/Downloads/Games     # juegos: en otra carpeta
orgie -s .                     # series: numera los videos de la carpeta actual
orgie -s -n 36 .               # series: empieza en 036
orgie -p 24,12,13 .            # temporadas: T1 con 24 capítulos, T2 con 12 y T3 con 13 (por nombre)
orgie -p 11,12 -s .            # temporadas y numeración por fecha de creación
orgie -p 11,12 -s --by-name .  # lo mismo, pero ordenando por nombre
orgie -s --by-name .           # renumera por nombre una carpeta ya numerada
orgie -d ~/Downloads           # duplicados: busca archivos idénticos en esa carpeta
orgie --update                 # actualizar orgie
orgie -t .                     # subtítulos: para los videos de la carpeta actual
orgie -t ~/Peliculas/Mi.mkv    # subtítulos: para una sola película
orgie -t -l en .               # subtítulos: en inglés
orgie -v                       # versión
```

## Juegos (`-g`)

Pensado para juegos de Switch en `.rar` o `.zip` (base más update o DLC). Primero enseña el plan: qué archivo va a qué carpeta, si la carpeta es nueva o ya existe, y cuáles se omiten porque no se reconoce el nombre. Hasta que no confirmas no toca nada.

Después, para cada archivo, lo descomprime en la carpeta de su juego (si ya existe, mete ahí el update) y, si la extracción deja una sola subcarpeta, sube el contenido un nivel. Al terminar pregunta si quieres generar un `README.md` con lo que pesa cada juego, de mayor a menor (si ya hay uno, avisa de que lo reemplazaría), y por último si quieres borrar los archivos que se extrajeron bien. Los que fallan se quedan como estaban.

El nombre del juego sale de lo que va antes de la palabra "Switch" en el archivo, con los guiones convertidos en espacios:

```
Kingdom Rush Frontiers Switch NSP BASE GAME.rar   ->  Kingdom Rush Frontiers/
Pokemon-HOME-Switch-NSP-Update-1.2.1.rar          ->  Pokemon HOME/
```

Si un archivo no tiene la palabra "Switch", lo avisa y no lo toca. Hace falta `unrar`, `unzip` o `7z`:

```bash
sudo apt install unrar         # .rar
sudo apt install unzip         # .zip
sudo apt install p7zip-full    # ambos
```

## Series (`-s`)

Ordena los videos de una carpeta por su fecha de creación en el disco y los renombra `01.mp4`, `02.mp4`... o `001.mp4`, `002.mp4`... según cuántos sean (si el último número pasa de 99, usa tres cifras). Conserva la extensión y deja los demás archivos como están, salvo los subtítulos (`.srt`, `.ass`, `.ssa`, `.sub`, `.vtt`) que tengan el mismo nombre que un video: esos cambian de nombre con él, para que el reproductor los siga encontrando solo. Por ejemplo, `video_xxx.mp4` y `video_xxx.es.srt` pasan a `036.mp4` y `036.es.srt`.

Antes de renombrar enseña los primeros y los últimos (y cuántos subtítulos se renombrarán con ellos) y pregunta. **No se puede deshacer**, así que mira esa vista previa.

La fecha de creación es el momento en que el archivo apareció en tu disco, o sea cuando empezó a descargarse, y no cambia después. Si descargas desde Telegram, dale a descargar en el orden correcto y el resultado respeta ese orden aunque las descargas terminen desordenadas. La fecha de modificación no sirve para esto porque cambia cuando termina cada descarga.

Ojo: si copias los archivos a otra carpeta o disco, la copia recibe una fecha de creación nueva y se pierde el orden. Ejecútalo donde se descargaron, o mueve en vez de copiar.

Opciones:

| Opción | Qué hace |
|---|---|
| `-n N`, `--start N` | Número inicial (por defecto 1). `-n 36` da `036`, `037`... |
| `-e LISTA`, `--ext LISTA` | Extensiones a procesar, separadas por comas y sin punto |
| `--by-name` | Ordena por nombre en vez de por fecha de creación (ver abajo) |

Por defecto procesa `mp4, mkv, avi, mov, webm, m4v, ts, flv, wmv`. Si dos archivos tienen exactamente la misma fecha, los ordena por nombre y te avisa. Si tu sistema de archivos no guarda la fecha de creación, se detiene sin cambiar nada.

### Ordenar por nombre (`--by-name`)

Si la fecha de creación no es fiable (copiaste los archivos y se desordenó, o tu sistema no la guarda), `-s --by-name` ordena por nombre. Usa el orden natural: `2` va antes que `10` y `99` antes que `100`, tengan las cifras que tengan.

Sirve sobre todo para carpetas que ya tienen números en el nombre y a las que quieres cambiar algo de la numeración:

- cerrar huecos: `001`, `002`, `005`, `007` pasan a `01`, `02`, `03`, `04`
- empezar en otro número (`-n 36`) o pasar de dos a tres cifras
- numerar archivos que no tienen número pero que ya quedan en el orden correcto al ordenarlos alfabéticamente

Renumera de forma consecutiva, así que si falta un capítulo los siguientes se corren y el número deja de coincidir con el del episodio. Si los archivos ya tienen exactamente los nombres que saldrían, lo dice y no cambia nada. Sigue enseñando la vista previa y pidiendo confirmación, y no se puede deshacer.

## Temporadas (`-p`)

Reparte los videos de una carpeta en subcarpetas `T1`, `T2`... según los capítulos que tiene cada temporada. Los videos se toman por orden de nombre (con orden natural: `2` va antes que `10`).

```bash
orgie -p 24,12,13 .
```

Con eso, los primeros 24 videos van a `T1`, los siguientes 12 a `T2` y los últimos 13 a `T3`. Los archivos no se renombran. Los subtítulos con el mismo nombre que un video (`03.mp4` y `03.es.srt`) se mueven con él.

### Temporadas y numeración a la vez (`-p` con `-s`)

Si usas las dos flags juntas, el orden deja de ser por nombre y pasa a ser por fecha de creación, igual que en `-s`:

```bash
orgie -p 11,12 -s .
```

Ordena todos los videos por el momento en que empezaron a descargarse, mete los primeros 11 en `T1` y los siguientes 12 en `T2`, y en cada carpeta los numera desde `01` (`01.mp4` a `11.mp4` en la primera, `01.mp4` a `12.mp4` en la segunda). Los nombres originales no influyen en nada. Cada temporada usa dos cifras, o tres si tiene 100 capítulos o más.

Con `-n` cambia el número con el que empieza la **primera** temporada (`-p 189,12 -s -n 36` da `036` a `224` en `T1` y `01` a `12` en `T2`). Los subtítulos con el mismo nombre que un video se mueven y renombran con él. Antes de tocar nada enseña, por temporada, los primeros y los últimos y pide confirmación; no se puede deshacer, aunque si algo falla a mitad de la operación devuelve todo a como estaba.

Todo lo de `-s` sobre la fecha de creación (descargar en orden, no copiar los archivos) sigue valiendo aquí. Si la fecha no es fiable, añade `--by-name` y el orden será por nombre:

```bash
orgie -p 11,12 -s --by-name .
```

Así, una carpeta ya numerada de corrido (`001` a `023`) se reparte en `T1` y `T2`, cada una desde `01`.

### Reglas de la lista

La suma de la lista tiene que coincidir con el número de videos de la carpeta; si no, se detiene sin tocar nada (con `-e` puedes limitar las extensiones). Tampoco sigue si ya existe alguna carpeta `T1`, `T2`... que vaya a crear. Enseña la vista previa y pide confirmación antes de mover.

## Duplicados (`-d`)

Busca archivos idénticos en la carpeta (sin entrar en subcarpetas), pensado para esos `video (2).mp4` que deja Telegram cuando descargas dos veces lo mismo. Compara primero el tamaño, luego el principio y el final de cada archivo y, solo si siguen coincidiendo, el contenido completo, así que dos archivos solo cuentan como duplicados si son iguales byte a byte. Con archivos grandes puede tardar un poco.

De cada grupo conserva el más antiguo (si empatan, el de nombre más corto) y te enseña qué se conserva y qué se borraría. Pide confirmación antes de borrar y **no se puede deshacer**.

## Subtítulos (`-t`)

Descarga el subtítulo y lo guarda al lado del video con el mismo nombre:

```
Pelicula.mkv
Pelicula.es.srt
```

VLC, mpv y casi cualquier reproductor lo cargan solos. Si le pasas una carpeta revisa todos sus videos (sin entrar en subcarpetas); si le pasas un archivo, solo ese. Si el video ya tiene su `.es.srt` lo salta. No pide confirmación porque solo agrega archivos, nunca cambia ni borra los que ya tienes.

Para buscar usa [subliminal](https://github.com/Diaoul/subliminal), que se instala una vez con pipx. Los otros modos no lo necesitan:

```bash
pipx install subliminal
```

Si no tienes pipx: `sudo apt update && sudo apt install pipx` (Ubuntu 22.04 o más nuevo, Debian) o `sudo pacman -S python-pipx` (Arch). El `apt update` es importante en una instalación nueva, porque sin él apt no encuentra el paquete. subliminal necesita Python 3.10 o más, que en Ubuntu significa 22.04 o posterior; pipx instala Python por su cuenta si falta. Para quitarlo: `pipx uninstall subliminal`. orgie nunca lo instala por su cuenta.

### Dónde busca

En este orden, y se queda con el primero que encuentre:

1. **OpenSubtitles**, solo si iniciaste sesión. Es el catálogo más grande.
2. **subt.is** y **subtitulamos.tv** (este último solo sirve para series).
3. **BSPlayer**. Este va último porque su conexión no es cifrada; solo se llega a él si los demás no tenían nada.

Sin cuenta de OpenSubtitles el catálogo queda muy limitado, y para películas poco comunes lo normal es que no haya resultado. Los subtítulos los suben usuarios, así que tampoco se puede asegurar que estén bien sincronizados; si uno sale mal, bórralo.

### La cuenta de OpenSubtitles

La primera vez que uses `-t`, orgie pregunta si quieres iniciar sesión. Si dices que sí, te pide usuario y contraseña (la contraseña no se ve al escribirla) y los guarda para las próximas veces. Si dices que no, usa solo las otras fuentes y volverá a preguntar la siguiente vez. Si todavía no tienes cuenta, créala gratis en [opensubtitles.com](https://www.opensubtitles.com), confirma el correo y vuelve a correr orgie.

- Tu usuario y contraseña solo los recibe OpenSubtitles, que los necesita para funcionar. orgie no los manda a ningún otro sitio y yo no recibo nada.
- Se guardan en texto normal en `~/.config/orgie/opensubtitles.toml`. La carpeta y el archivo solo los puede leer tu usuario, y la contraseña nunca se pasa por la línea de comandos. Aun así, no uses ahí una contraseña que repitas en otros sitios.
- OpenSubtitles pone un límite de descargas por día, también en las cuentas gratuitas. Si lo alcanzas, orgie lo dice ("límite diario de descargas alcanzado"), deja de usar OpenSubtitles en esa ejecución y sigue con las otras fuentes. No lo confundas con "usuario o contraseña rechazados", que solo sale cuando OpenSubtitles de verdad no acepta tus datos.
- Si la contraseña guardada deja de funcionar, te ofrece escribirla de nuevo.
- Para cerrar sesión basta con borrar las carpetas de orgie: `rm -r ~/.config/orgie ~/.cache/orgie`. `orgie --uninstall` también las quita.

### Privacidad

Los sitios de arriba ven tu IP y lo que se busca (el nombre del archivo y una huella del video). El video no se sube. Aparte de eso, orgie no manda datos a ningún lado.

### Opciones

| Opción | Qué hace |
|---|---|
| `-l CÓDIGO`, `--lang CÓDIGO` | Idioma (por defecto `es`). Ejemplos: `en`, `pt-BR` |
| `-e LISTA`, `--ext LISTA` | Extensiones a procesar cuando le pasas una carpeta |

## Requisitos

Bash y las herramientas de GNU (`stat`, `sha256sum`, `numfmt`), que ya vienen en cualquier distro Linux. Para `-g`, una herramienta de extracción (arriba). Para `-t`, subliminal. Para `--update`, `curl`.

## Windows

orgie es un script de Bash, así que en Windows se usa a través de WSL, que instala Ubuntu dentro de Windows y deja trabajar sobre tus carpetas de siempre. Los pasos, uno por uno, están en [WINDOWS.md](./WINDOWS.md).

## Seguridad

- Nunca renombra, mueve ni borra nada sin enseñar antes lo que va a hacer y preguntar. `-t` es la excepción porque solo agrega archivos.
- `-s` no pisa archivos: si un nombre nuevo choca con uno que no es del lote, se detiene sin cambiar nada. Si se interrumpe a medias pueden quedar archivos `.orgie.tmp.N`; son tus videos con nombre temporal y orgie no seguirá hasta que los revises.
- `-g` solo borra los archivos que extrajo bien en esa ejecución y solo si lo confirmas.
- No usa `sudo` ni abre puertos. Solo `-t` y `--update` entran a internet.

## Licencia

MIT. Ver [LICENSE](./LICENSE).
