# orgie

Un solo script de Bash para tres cosas que hago a mano todo el tiempo: ordenar descargas de juegos de Switch, numerar capítulos de series y bajar subtítulos. Se elige qué hacer con una flag.

```bash
orgie -g carpeta     # juegos de Switch
orgie -s carpeta     # numerar capítulos
orgie -t carpeta     # subtítulos
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

Para actualizar, vuelve a correr el comando de instalación; si la versión cambió, pregunta antes de reemplazar.

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
orgie -t .                     # subtítulos: para los videos de la carpeta actual
orgie -t ~/Peliculas/Mi.mkv    # subtítulos: para una sola película
orgie -t -l en .               # subtítulos: en inglés
orgie -v                       # versión
```

## Juegos (`-g`)

Pensado para juegos de Switch en `.rar` o `.zip` (base más update o DLC). Para cada archivo saca el nombre del juego, lo descomprime en su carpeta, y si el juego ya tiene carpeta mete ahí el update. Si la extracción deja una sola subcarpeta, sube el contenido un nivel. Al final genera un `README.md` con lo que pesa cada juego, de mayor a menor, y pregunta si quieres borrar los archivos que se extrajeron bien. Los que fallan se quedan como estaban.

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

Ordena los videos de una carpeta por su fecha de creación en el disco y los renombra `01.mp4`, `02.mp4`... o `001.mp4`, `002.mp4`... según cuántos sean (si el último número pasa de 99, usa tres cifras). Conserva la extensión y deja los demás archivos como están.

Antes de renombrar enseña los primeros y los últimos y pregunta. **No se puede deshacer**, así que mira esa vista previa.

La fecha de creación es el momento en que el archivo apareció en tu disco, o sea cuando empezó a descargarse, y no cambia después. Si descargas desde Telegram, dale a descargar en el orden correcto y el resultado respeta ese orden aunque las descargas terminen desordenadas. La fecha de modificación no sirve para esto porque cambia cuando termina cada descarga.

Ojo: si copias los archivos a otra carpeta o disco, la copia recibe una fecha de creación nueva y se pierde el orden. Ejecútalo donde se descargaron, o mueve en vez de copiar.

Opciones:

| Opción                    | Qué hace                                                   |
| ------------------------- | ---------------------------------------------------------- |
| `-n N`, `--start N`       | Número inicial (por defecto 1). `-n 36` da `036`, `037`... |
| `-e LISTA`, `--ext LISTA` | Extensiones a procesar, separadas por comas y sin punto    |

Por defecto procesa `mp4, mkv, avi, mov, webm, m4v, ts, flv, wmv`. Si dos archivos tienen exactamente la misma fecha, los ordena por nombre y te avisa. Si tu sistema de archivos no guarda la fecha de creación, se detiene sin cambiar nada.

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

Si no tienes pipx: `sudo apt install pipx` (Debian, Ubuntu) o `sudo pacman -S python-pipx` (Arch). Para quitarlo: `pipx uninstall subliminal`. orgie nunca lo instala por su cuenta.

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
- Las cuentas gratuitas tienen un límite diario de descargas. Si lo alcanzas, orgie lo dice y sigue con las otras fuentes.
- Si la contraseña guardada deja de funcionar, te ofrece escribirla de nuevo.
- Para cerrar sesión basta con borrar las carpetas de orgie: `rm -r ~/.config/orgie ~/.cache/orgie`. `orgie --uninstall` también las quita.

### Privacidad

Los sitios de arriba ven tu IP y lo que se busca (el nombre del archivo y una huella del video). El video no se sube. Aparte de eso, orgie no manda datos a ningún lado.

### Opciones

| Opción                       | Qué hace                                           |
| ---------------------------- | -------------------------------------------------- |
| `-l CÓDIGO`, `--lang CÓDIGO` | Idioma (por defecto `es`). Ejemplos: `en`, `pt-BR` |
| `-e LISTA`, `--ext LISTA`    | Extensiones a procesar cuando le pasas una carpeta |

## Requisitos

Bash y el `stat` de GNU, que ya vienen en cualquier distro Linux. Para `-g`, una herramienta de extracción (arriba). Para `-t`, subliminal.

## Seguridad

- Nunca renombra ni borra nada sin preguntar. `-t` es la excepción porque solo agrega archivos.
- `-s` no pisa archivos: si un nombre nuevo choca con uno que no es del lote, se detiene sin cambiar nada. Si se interrumpe a medias pueden quedar archivos `.orgie.tmp.N`; son tus videos con nombre temporal y orgie no seguirá hasta que los revises.
- `-g` solo borra los archivos que extrajo bien en esa ejecución y solo si lo confirmas.
- No usa `sudo` ni abre puertos. Solo `-t` entra a internet.

## Licencia

MIT. Ver [LICENSE](./LICENSE).
