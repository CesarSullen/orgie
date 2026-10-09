# orgie

Un solo script de Bash para cosas que hago a mano todo el tiempo con descargas: ordenar juegos de Switch, numerar capítulos de series, repartirlos en temporadas, bajar subtítulos y quitar duplicados. Se elige qué hacer con una flag.

```bash
orgie -g carpeta          # juegos de Switch
orgie -s carpeta          # numerar capítulos
orgie -p 24,12 carpeta    # repartir en temporadas
orgie -p auto carpeta     # repartir en temporadas leyendo S05E03, 5x03...
orgie -t carpeta          # subtítulos
orgie -d carpeta          # duplicados
orgie -c carpeta          # limpiar nombres
orgie -a "nombre" carpeta  # agrupar en una carpeta por nombre
orgie -o carpeta          # ordenar por tipo
orgie --update            # actualizar orgie
```

Si no pones carpeta usa la actual. Si no pones ninguna flag, muestra la ayuda y no toca nada.

## Demo

[Ver demo: organiza una serie en carpetas y renumera los capítulos](demo.mp4)

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

Te enseña qué va a quitar (el script, tus cuentas de OpenSubtitles si las guardaste y restos de caché de versiones anteriores) y pide confirmación. No toca tus videos ni tus juegos.

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
orgie -p auto -s .             # temporadas por etiqueta (T5, T6...) y capítulos con su número
orgie -s --by-episode .        # renumera una temporada con el número real de cada capítulo
orgie -s --by-name .           # renumera por nombre una carpeta ya numerada
orgie -d ~/Downloads           # duplicados: busca archivos idénticos en esa carpeta
orgie -c ~/Downloads           # limpiar: quita basura de los nombres de los videos
orgie -a "the big bang" .      # agrupar: mete en una carpeta los videos que coinciden
orgie -a "the big bang" -p 12,24 -s .   # agrupar, repartir en temporadas y numerar
orgie -o ~/Downloads           # ordenar: reparte los archivos en Videos, Musica, Imagenes...
orgie --update                 # actualizar orgie
orgie -t .                     # subtítulos: para los videos de la carpeta actual
orgie -t ~/Peliculas/Mi.mkv    # subtítulos: para una sola película
orgie -t -l en .               # subtítulos: en inglés
orgie -t --youtube .           # subtítulos de videos de YouTube (busca solo en YouTube)
orgie -v                       # versión
```

## Juegos (`-g`)

Pensado para juegos de Switch en `.rar` o `.zip` (base más update o DLC). Primero enseña el plan: qué archivo va a qué carpeta, si la carpeta es nueva o ya existe, y cuáles se omiten porque no se reconoce el nombre. Hasta que no confirmas no toca nada.

Después, para cada archivo, lo descomprime en la carpeta de su juego (si ya existe, mete ahí el update) y, si la extracción deja una sola subcarpeta, sube el contenido un nivel. Al terminar pregunta si quieres generar un `README.md` con lo que pesa cada juego, de mayor a menor (si ya hay uno, avisa de que lo reemplazaría), y por último si quieres mandar a la papelera los archivos que se extrajeron bien. Los que fallan se quedan como estaban.

Antes de extraer, y ya al enseñar el plan, hace una comprobación rápida de cada `.zip` o `.rar`: lee solo su índice (segundos, aunque pese gigas) y no descomprime nada. Así detecta las descargas cortadas o dañadas, las marca como "dañado o incompleto" y las omite sin dejar una carpeta a medias. Un error en mitad de los datos, que esa lectura rápida no ve, sale igualmente al extraer.

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
| `--by-episode` | Ordena por la etiqueta de episodio del nombre y usa el número real (ver abajo) |

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

### Leer la temporada y el capítulo del nombre (`-p auto`, `--by-episode`)

Si los nombres traen la etiqueta del episodio, no hace falta contar nada ni fiarse de la fecha de creación:

```bash
orgie -p auto .            # reparte en T5, T6... según la temporada de cada nombre
orgie -p auto -s .         # además renombra cada video con el número de su capítulo
orgie -s --by-episode .    # renumera una carpeta de una sola temporada
```

orgie reconoce, sin distinguir mayúsculas y en cualquier mezcla: `S05E03`, `s5e3`, `S5E03`, `5x03`, `Season 5 Episode 3` y `Temporada 5 Episodio 3`. También `Episodio 3`, `Episode 3`, `Capitulo 3`, `Cap 3` y `Ep 3`, que no dicen la temporada: si **ningún** video la indica, lo toma todo como temporada 1. Resoluciones y códecs como `1920x1080` o `x264` no se confunden con una etiqueta.

- **Carpetas:** la carpeta de cada temporada usa el número de la etiqueta, así que con las temporadas 5 y 6 salen `T5` y `T6`, no `T1` y `T2`. Si una carpeta `T5` ya existe, la usa sin tocar lo que hay dentro y no pisa ningún archivo que tenga el mismo nombre.
- **Números:** con `-s`, cada video pasa a llamarse con el **número real del capítulo** de su etiqueta (`S03E05` queda `05.mkv`), con dos cifras o tres si la temporada llega a 100 capítulos. No renumera de forma consecutiva: si falta un capítulo, el hueco se queda.
- **Capítulos que faltan:** el plan avisa de los huecos entre el primero y el último que tienes (`Faltan los capítulos: 3, 4`) y de si la temporada empieza más tarde del 1. Es solo un aviso, porque orgie no consulta nada en internet.
- **Subtítulos:** los que tienen el mismo nombre que un video lo siguen y cambian con él.
- **Si algo no cuadra, no hace nada:** un video sin etiqueta reconocible, dos videos con el mismo capítulo, o una mezcla de nombres con temporada y nombres sin ella, detienen el proceso y te los lista.
- **`--by-episode` sin `-p auto`** necesita que haya una sola temporada en la carpeta; si hay varias, te pide `-p auto`.
- **Opciones:** no se combinan con `-n` (los números salen de las etiquetas) ni con `--by-name`. Enseña una vista previa y pide confirmación, y no se puede deshacer.

Con `-a` se encadena igual que lo demás: `orgie -a "the big bang theory" -p auto -s .` agrupa, y después reparte por temporada y renombra, cada paso con su confirmación.

### Reglas de la lista

La suma de la lista tiene que coincidir con el número de videos de la carpeta; si no, se detiene sin tocar nada (con `-e` puedes limitar las extensiones). Tampoco sigue si ya existe alguna carpeta `T1`, `T2`... que vaya a crear. Enseña la vista previa y pide confirmación antes de mover.

## Duplicados (`-d`)

Busca archivos idénticos en la carpeta (sin entrar en subcarpetas), pensado para esos `video (2).mp4` que deja Telegram cuando descargas dos veces lo mismo. Compara primero el tamaño, luego el principio y el final de cada archivo y, solo si siguen coincidiendo, el contenido completo, así que dos archivos solo cuentan como duplicados si son iguales byte a byte. Con archivos grandes puede tardar un poco.

De cada grupo conserva el más antiguo (si empatan, el de nombre más corto) y te enseña qué se conserva y qué se quitaría. Pide confirmación y manda las copias a la **papelera**, no las borra para siempre (ver más abajo).

## Agrupar por nombre (`-a`)

Mete en una carpeta los videos de una carpeta mezclada que coinciden por nombre, por ejemplo los capítulos de una serie o las partes de una saga. Los subtítulos con el mismo nombre que un video viajan con él. Solo mira archivos sueltos, no entra en subcarpetas, y siempre enseña un plan y pide confirmación.

```bash
orgie -a "the big bang theory" ~/Downloads
orgie -a "star trek,-discovery" .
```

**Criterios.** Se comparan con el nombre del archivo sin distinguir mayúsculas, acentos, puntos ni guiones, y solo con palabras completas (`bang` no coincide con `Bangkok`):

- Palabras separadas por comas: deben aparecer **todas**, en cualquier posición. `-a "the,bang"`.
- Varias palabras entre comillas, sin comas: deben aparecer **juntas y en ese orden**. `-a "the big bang"`.
- Un criterio con `-` delante **excluye**: `-a "star trek,-discovery"` deja fuera `Star Trek Discovery`. Ponlo siempre después de una palabra positiva.

Si el criterio coincide con el nombre de una carpeta que ya existe, escríbelo como `--group=Nombre`, para que no se confunda con la carpeta a procesar.

**Nombre de la carpeta.** Sale de las palabras con las que empiezan todos los videos que coinciden, quitando antes etiquetas de calidad, de temporada y episodio (`S05E03`, `5x03`, `Episodio 3`...) y el año. Con `The Big Bang Theory S05E03` y `the.big.bang.theory.s5e4` sale `The Big Bang Theory`. El plan lo muestra y, al confirmar, puedes responder `s`, `n`, o escribir otro nombre para la carpeta. Si ya existe una carpeta con ese nombre (aunque cambien las mayúsculas), la usa tal cual y solo añade archivos; nunca pisa uno que ya esté dentro.

El plan también enseña los videos que **no** entran pero tienen alguna de tus palabras, por si falta alguno (por ejemplo `The Big Bang Theory UK`).

**Sin criterios** (`orgie -a .`), propone grupos por las dos primeras palabras del nombre, sin contar `the`, `a`, `el`, `la`... ni las etiquetas de temporada, y solo grupos de dos videos o más. No hace magia: enseña cada grupo numerado, cuántos videos quedan sin grupo y un ejemplo de cómo ser más específico, y pregunta qué aplicar: `s` todos, `n` ninguno, o los números de los grupos que quieras (`1,3`). Los nombres de Telegram y de cámaras no se agrupan, y tampoco los que son solo números. Un caso como `86 2nd Season...` y `86 - Eighty Six 10` no se agrupa solo, porque la segunda palabra cambia; ahí usa `orgie -a 86 .`.

**Combinar con `-p` y `-s`.** Con criterios, después de agrupar orgie sigue dentro de la carpeta nueva con `-p`, con `-s`, o con los dos, cada paso con su propia vista previa y confirmación:

```bash
orgie -a "the big bang theory" -p 12,24 -s .
```

Sin criterios no se encadena, porque pueden salir varias carpetas. Con `-p auto` y `--by-episode` también funciona, y con ellos las cantidades salen de las etiquetas de los nombres.

## Limpiar nombres (`-c`)

Quita la basura típica de las descargas de los nombres de los videos (no entra en subcarpetas). Enseña cada cambio como `nombre viejo -> nombre nuevo` y pide confirmación; como `-s`, no se puede deshacer. Los subtítulos con el mismo nombre que un video cambian con él.

```bash
orgie -c ~/Downloads
```

Reglas, para que sepas qué toca y qué no:

- Quita etiquetas de sitios (`at Streamtape.com`, `www.sitio.com`, `AnimeFLV`, `Streamtape`), `Sub Español`, usuarios de canales (`@canal`), y la extensión repetida dentro del nombre (`3461_9.mp4 at Streamtape.com.mp4` pasa a `3461_9.mp4`).
- Quita calidad, códec y fuente, sueltos o entre corchetes y paréntesis: `1080p`, `720p`, `2160p`, `4K`, `BluRay`, `WEB-DL`, `WEBRip`, `HDRip`, `x264`, `x265`, `HEVC`, `AAC`, `DTS`, `10bit` y similares.
- Si el nombre no tiene espacios y lleva alguna palabra de letras (`Scarface.1983.720p.BluRay`), cambia los puntos y guiones bajos por espacios y queda `Scarface 1983`.
- No toca los nombres de Telegram (`video_2026-10-03_03-59-17`), los de cámaras (`VID_...`, `IMG_...`) ni nombres que no tengan nada que limpiar. Tampoco inventa nada: solo quita lo de arriba.
- Si dos videos acabarían con el mismo nombre, o el nombre nuevo ya existe, se omiten y te lo dice.

Por defecto procesa los videos (`-e` cambia las extensiones). Es un limpiador conservador, no perfecto: un nombre como `Blade_Runner_2049_2017_720p_10bit_BluRay_x265_HEVC_Org_M` queda en `Blade Runner 2049 2017 Org M`, porque el nombre del grupo que lo publicó no se puede distinguir del título. Mira siempre la vista previa.

## Ordenar por tipo (`-o`)

Reparte los archivos sueltos de una carpeta (típicamente la de descargas) en carpetas por tipo, según la extensión. No entra en subcarpetas ni toca los archivos ocultos.

```bash
orgie -o ~/Downloads
```

| Carpeta | Extensiones |
|---|---|
| `Videos` | mp4, mkv, avi, mov, webm, m4v, ts, flv, wmv, mpg, mpeg, 3gp |
| `Musica` | mp3, flac, wav, ogg, m4a, aac, opus, wma |
| `Imagenes` | jpg, jpeg, png, gif, webp, bmp, svg, heic, tiff |
| `Documentos` | pdf, doc, docx, xls, xlsx, ppt, pptx, odt, ods, odp, txt, rtf, epub, csv |
| `Comprimidos` | zip, rar, 7z, tar, gz, bz2, xz, tgz, iso |
| `Instaladores` | deb, rpm, appimage, exe, msi, apk, dmg |

- **Carpetas que ya existen:** si ya tienes una carpeta de ese tipo, orgie la usa tal cual y solo añade archivos; no la vuelve a crear ni toca lo que había dentro. Reconoce también `Music`, `Pictures`, `Images`, `Documents`, `Archives` y variantes con acentos, sin distinguir mayúsculas.
- **Nada se pisa:** si en la carpeta de destino ya hay un archivo con el mismo nombre, ese archivo se queda donde está y te lo dice.
- **Subtítulos:** los que tienen el mismo nombre que un video viajan con él.
- **Lo demás:** los archivos de otros tipos (`.nsp`, `.md`, lo que no esté en la tabla) se quedan donde están.

Enseña un plan por carpeta, con cuáles son nuevas y cuáles ya existen, y pide confirmación antes de mover nada.

## Papelera

`-d` y `-g` no borran nada para siempre: mandan los archivos a la papelera, así que puedes recuperarlos. Usan `gio` o `trash-put`, el que haya. Si no hay ninguno, orgie ofrece instalar `gio` como con las demás herramientas. Si un archivo no se puede mandar a la papelera (por ejemplo, en algunos discos montados), no se borra y te lo dice. El espacio se libera cuando vacías la papelera.

## Subtítulos (`-t`)

Descarga el subtítulo y lo guarda al lado del video con el mismo nombre:

```
Pelicula.mkv
Pelicula.es.srt
```

VLC, mpv y casi cualquier reproductor lo cargan solos. Si le pasas una carpeta revisa todos sus videos (sin entrar en subcarpetas); si le pasas un archivo, solo ese. Si el video ya tiene su `.es.srt` lo salta. No pide confirmación porque solo agrega archivos, nunca cambia ni borra los que ya tienes.

Para buscar usa [subliminal](https://github.com/Diaoul/subliminal). Los otros modos no lo necesitan. Si no lo tienes, la primera vez que uses `-t` orgie te dice qué falta, te enseña los comandos exactos que ejecutaría y pregunta si quieres instalarlo (`s/n`). Hasta que no dices que sí, no instala nada.

- **Programas de Python** (subliminal, yt-dlp): se instalan con `pipx`, solo para tu usuario y sin `sudo`.
- **Paquetes del sistema** (`pipx` y `ffmpeg`, que trae `ffprobe`): se instalan con el gestor de tu distro (apt, pacman o dnf, según lo que detecte). Esos sí piden tu contraseña. Si no reconoce tu distro, te dice qué paquetes instalar a mano.

Si prefieres hacerlo tú, es esto: `pipx install subliminal`, y si no tienes pipx, `sudo apt update && sudo apt install pipx` (Ubuntu 22.04 o más nuevo, Debian) o `sudo pacman -S python-pipx` (Arch). El `apt update` es importante en una instalación nueva, porque sin él apt no encuentra el paquete. subliminal necesita Python 3.10 o más, que en Ubuntu significa 22.04 o posterior. Para quitarlo: `pipx uninstall subliminal`.

### Dónde busca

En este orden, y se queda con el primero que encuentre:

1. **OpenSubtitles**, solo si iniciaste sesión. Es el catálogo más grande.
2. **subt.is** y **subtitulamos.tv** (este último solo sirve para series).
3. **BSPlayer**. Este va último porque su conexión no es cifrada; solo se llega a él si los demás no tenían nada.

Sin cuenta de OpenSubtitles el catálogo queda muy limitado, y para películas poco comunes lo normal es que no haya resultado. Los subtítulos los suben usuarios, así que tampoco se puede asegurar que estén bien sincronizados; si uno sale mal, bórralo.

### Las cuentas de OpenSubtitles

La primera vez que uses `-t`, orgie pregunta si quieres iniciar sesión. Si dices que sí, te pide usuario y contraseña (la contraseña no se ve al escribirla) y los guarda para las próximas veces. Si dices que no, usa solo las otras fuentes y volverá a preguntar la siguiente vez. Si todavía no tienes cuenta, créala gratis en [opensubtitles.com](https://www.opensubtitles.com), confirma el correo y vuelve a correr orgie.

- Tu usuario y contraseña solo los recibe OpenSubtitles, que los necesita para funcionar. orgie no los manda a ningún otro sitio y yo no recibo nada.
- Se guardan en texto normal en `~/.config/orgie/`, un archivo por cuenta (`opensubtitles.toml`, `opensubtitles-2.toml`...). La carpeta y los archivos solo los puede leer tu usuario, y la contraseña nunca se pasa por la línea de comandos. Aun así, no uses ahí una contraseña que repitas en otros sitios.
- Si la contraseña de una cuenta deja de funcionar, orgie pasa a la siguiente que tengas guardada, o te ofrece escribirla de nuevo.
- Para cerrar sesión basta con borrar la carpeta de orgie: `rm -r ~/.config/orgie`. `orgie --uninstall` también la quita.

**Límite diario y más de una cuenta.** OpenSubtitles pone un límite de descargas por día a cada cuenta. Cuando se agota, orgie lo dice ("límite diario de descargas alcanzado") y pasa a la siguiente cuenta que tengas guardada, reintentando ese mismo video. Si no queda ninguna, pregunta si quieres iniciar sesión con otra cuenta y, si dices que no, sigue con las otras fuentes el resto de la ejecución. En la siguiente ejecución vuelve a empezar por la primera cuenta y cambia cuando falle. No lo confundas con "usuario o contraseña rechazados", que solo sale cuando OpenSubtitles de verdad no acepta tus datos. Cada uno decide cuántas cuentas guarda y de quién son; conviene revisar las condiciones de uso de OpenSubtitles.

**Sin caché que borrar.** Para no repetir el inicio de sesión en cada video, subliminal guarda en una caché el pase temporal que le da OpenSubtitles, y ese pase no distingue de qué cuenta es. orgie usa una carpeta temporal solo para cada ejecución, la vacía cada vez que cambia de cuenta y la borra al terminar, así que no queda nada en `~/.cache`. Una vez por ejecución se pide un pase nuevo, sin preguntarte nada.

### YouTube (`--youtube`)

Para videos de YouTube que tienes en local. Con `--youtube`, orgie busca **solo en YouTube** y no consulta OpenSubtitles ni las otras fuentes de películas, para que un video sobre una película no acabe con el subtítulo de la película que se llama igual. Sin la flag, nunca entra en YouTube.

```bash
orgie -t --youtube .
orgie -t --youtube -l en ~/Videos
```

Para cada video:

1. Busca en YouTube con el nombre del archivo (sin guiones bajos, puntos, emojis ni signos) y mira los primeros 8 resultados.
2. Descarta los que no tengan **la duración de tu archivo** (3 segundos de margen, que mide con `ffprobe`) y se queda solo con el primero que coincide. Si ninguno coincide, no descarga nada, para no ponerte el subtítulo de otro video.
3. Baja el subtítulo de ese único video en el idioma de `-l` (por defecto `es`): el manual si lo tiene y, si no, el automático. Si el video no está en ese idioma pero YouTube ofrece su traducción automática, usa esa y lo avisa.
4. Lo guarda como `TuVideo.es.srt` y muestra el título del video de YouTube del que lo sacó, para que compruebes que es el correcto.

Los subtítulos automáticos de YouTube repiten cada línea en el cuadro siguiente y traen cuadros de 10 milisegundos. orgie los limpia antes de guardarlos, y los manuales los deja tal cual. Aun así, un subtítulo automático puede tener errores de reconocimiento de voz, y muchos videos no tienen subtítulo en tu idioma.

Este modo necesita `yt-dlp` y `ffprobe`, y no necesita subliminal ni cuenta de OpenSubtitles. Si faltan, orgie ofrece instalarlos como se explicó antes. Para buscar, YouTube recibe el título del video y tu IP, y el video no se sube.

### Privacidad

Los sitios de arriba ven tu IP y lo que se busca (el nombre del archivo y una huella del video). El video no se sube. Aparte de eso, orgie no manda datos a ningún lado.

### Opciones

| Opción | Qué hace |
|---|---|
| `-l CÓDIGO`, `--lang CÓDIGO` | Idioma (por defecto `es`). Ejemplos: `en`, `pt-BR` |
| `-e LISTA`, `--ext LISTA` | Extensiones a procesar cuando le pasas una carpeta |
| `--youtube` | Busca solo en YouTube (por título y duración), para videos de YouTube |

## Requisitos

Bash y las herramientas de GNU (`stat`, `sha256sum`, `numfmt`), que ya vienen en cualquier distro Linux. Para `-g`, una herramienta de extracción (arriba). Para `-t`, subliminal; con `--youtube`, en su lugar, yt-dlp y ffprobe. Para `--update`, `curl`. Para mandar a la papelera, `gio` o `trash-put`.

## Windows

orgie es un script de Bash, así que en Windows se usa a través de WSL, que instala Ubuntu dentro de Windows y deja trabajar sobre tus carpetas de siempre. Los pasos, uno por uno, están en [WINDOWS.md](./WINDOWS.md).

## Seguridad

- Nunca renombra, mueve ni quita nada sin enseñar antes lo que va a hacer y preguntar. `-t` es la excepción porque solo agrega archivos.
- `-s` no pisa archivos: si un nombre nuevo choca con uno que no es del lote, se detiene sin cambiar nada. Si se interrumpe a medias pueden quedar archivos `.orgie.tmp.N`; son tus videos con nombre temporal y orgie no seguirá hasta que los revises.
- `-g` y `-d` nunca borran para siempre: lo que quitan va a la papelera, y solo si lo confirmas. `-g` solo propone los archivos que extrajo bien en esa ejecución.
- `-o` y `-c` no pisan nada: si un nombre de destino ya existe, ese archivo se omite.
- No abre puertos. Solo `-t` y `--update` entran a internet. `sudo` solo lo usa `-t` para instalar paquetes del sistema (`ffmpeg`, `pipx`) cuando faltan, y únicamente después de enseñarte los comandos y de que digas que sí; instalar orgie, actualizarlo y desinstalarlo no usan `sudo`.

## Licencia

MIT. Ver [LICENSE](./LICENSE).
