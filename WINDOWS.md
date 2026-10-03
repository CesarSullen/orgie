# orgie en Windows (con WSL)

orgie es un script de Bash y Windows no trae Bash, así que en Windows se usa a través de WSL. WSL es una función de Windows que instala Linux (Ubuntu) dentro de tu propio equipo, sin máquinas virtuales que tengas que manejar ni particiones. Desde ahí orgie funciona como en cualquier Linux, y puede trabajar directamente sobre tus carpetas de Windows.

## Qué vas a conseguir

Al terminar esta guía tendrás Ubuntu instalado dentro de Windows, el comando `orgie` funcionando y sabrás abrir una terminal en la carpeta de tus videos para usarlo. No se borra ni se cambia nada de lo que ya tienes en Windows.

Necesitas Windows 10 versión 2004 (compilación 19041) o superior, o Windows 11, permisos de administrador para el primer paso, conexión a internet y poder reiniciar el equipo una vez.

## Paso 1: instalar WSL

1. Pulsa la tecla de Windows, escribe `PowerShell`, haz clic derecho sobre "Windows PowerShell" y elige **Ejecutar como administrador**. Acepta el aviso que aparece.
2. En la ventana azul o negra que se abre, escribe esto y pulsa Enter:

```powershell
wsl --install
```

Qué hace: activa las funciones de Windows que necesita WSL, descarga Ubuntu y lo deja como Linux por defecto. Puede tardar unos minutos.

3. Cuando termine, **reinicia el equipo**.

Si algo sale mal: si el mensaje de error habla de virtualización, hay que activarla en la BIOS del equipo (suele llamarse Virtualization, Intel VT-x o SVM). Si más adelante quieres quitar Ubuntu, en PowerShell escribe `wsl --unregister Ubuntu`. Ojo: eso borra Ubuntu y todo lo que hayas guardado dentro de él, pero no toca tus archivos de Windows.

## Paso 2: crear tu usuario de Ubuntu

1. Después de reiniciar, Ubuntu se abre solo y termina su instalación. Si no se abre, pulsa la tecla de Windows, escribe `Ubuntu` y ábrelo.
2. Te pedirá un nombre de usuario (puedes poner el que quieras, en minúsculas y sin espacios) y una contraseña.

La contraseña no se ve mientras la escribes, ni siquiera con asteriscos. Es normal: escríbela igualmente y pulsa Enter, y repítela cuando la pida. Esta contraseña es solo de Ubuntu y se usará cuando un comando empiece por `sudo`. Anótala.

Desde aquí, todo lo que escribas va en esa ventana de Ubuntu, no en PowerShell.

## Paso 3: preparar Ubuntu

1. Actualiza la lista de programas disponibles:

```bash
sudo apt update
```

Qué hace: solo refresca el catálogo, no instala ni cambia nada. Te pedirá la contraseña del paso anterior.

2. Instala `curl`, que sirve para descargar orgie:

```bash
sudo apt install curl
```

Si te pregunta `¿Desea continuar? [S/n]`, escribe `s` y Enter. Si dice que ya está instalado, no pasa nada.

## Paso 4: instalar orgie

Copia y pega este comando en la ventana de Ubuntu (pegar en la terminal es clic derecho o Ctrl+Shift+V):

```bash
f=$(mktemp) && curl -fsSL -o "$f" https://raw.githubusercontent.com/CesarSullen/orgie/main/orgie.sh && bash "$f" --install; rm -f "$f"
```

Qué hace: descarga el script a un archivo temporal, ejecuta su instalador y borra el temporal. El instalador copia orgie a `~/.local/bin/orgie` (dentro de tu usuario de Ubuntu). No usa `sudo` ni toca nada de Windows.

Si prefieres leer el script antes de ejecutarlo, descárgalo y ábrelo primero:

```bash
curl -fsSL -o orgie.sh https://raw.githubusercontent.com/CesarSullen/orgie/main/orgie.sh
less orgie.sh
bash orgie.sh --install
```

`less` muestra el archivo página a página; sales con la tecla `q`.

Al terminar, **cierra la ventana de Ubuntu y ábrela otra vez**. Así Ubuntu reconoce el comando nuevo. Comprueba que funciona:

```bash
orgie --help
```

Debe mostrar la lista de modos. Si dice `orgie: command not found`, repite el cierre y apertura de la ventana; si sigue igual, ejecuta `bash orgie.sh --install` otra vez y lee el aviso final del instalador, que explica qué línea añadir.

Para quitar orgie cuando quieras: `orgie --uninstall`.

## Paso 5: abrir la terminal en la carpeta de tus videos

Los discos de Windows aparecen en Ubuntu dentro de `/mnt`. El disco `C:` es `/mnt/c`. Por ejemplo, `C:\Users\Ana\Downloads` es `/mnt/c/Users/Ana/Downloads`.

La forma fácil, sin escribir rutas:

1. Abre la carpeta en el Explorador de archivos de Windows.
2. Haz clic en la barra de direcciones de arriba (donde sale la ruta), escribe `wsl` y pulsa Enter.

Se abre una terminal de Ubuntu ya dentro de esa carpeta. Comprueba dónde estás con:

```bash
pwd
```

La otra forma es escribir la ruta con `cd`, siempre entre comillas si tiene espacios:

```bash
cd "/mnt/c/Users/Ana/Downloads/Telegram Desktop/MiSerie"
```

Y para abrir la carpeta actual en el Explorador de Windows desde Ubuntu:

```bash
explorer.exe .
```

## Paso 6: comprobar la fecha de creación (solo si vas a usar `-s`)

El modo `-s` numera los capítulos según la fecha en que cada archivo apareció en tu disco. No sé de antemano si Windows se la entrega a Ubuntu en tu equipo, así que hay que comprobarlo antes. Estando en la carpeta de los videos, cambia `mkv` por la extensión de los tuyos:

```bash
stat -c '%n | creado: %w' *.mkv | head -3
```

Muestra el nombre y la fecha de creación de los tres primeros archivos. No cambia nada.

- Si sale una fecha y hora (por ejemplo `2026-10-01 03:38:54`), `-s` va a funcionar.
- Si en `creado:` sale un guion (`-`), tu equipo no la entrega y `-s` por fecha no se puede usar en esa carpeta. No pasa nada grave: orgie lo detecta por sí solo y se detiene sin cambiar nada. Tienes dos salidas: `orgie -s --by-name .`, que ordena por nombre en vez de por fecha (sirve si los archivos ya tienen números o nombres que se ordenan bien), y el resto de modos, que funcionan igual.

Importante: para que la fecha sirva, ejecuta orgie con los archivos donde se descargaron. Si los copias a otra carpeta, o dentro del disco de Ubuntu, la copia recibe una fecha nueva y el orden original se pierde.

## Paso 7: usar orgie

Ya en la carpeta de los videos:

```bash
orgie -s .                  # numera los capítulos (01, 02...) según el orden de descarga
orgie -s -n 36 .            # igual, empezando en 036
orgie -s --by-name .        # renumera por nombre (si la fecha de creación no sirve)
orgie -p 24,12,13 .         # reparte en T1, T2 y T3 según los capítulos de cada temporada
orgie -d .                  # busca archivos duplicados
orgie -t .                  # descarga subtítulos
orgie -g .                  # organiza juegos de Switch (.rar y .zip)
```

Antes de cambiar nada, orgie enseña lo que va a hacer y pregunta `s/n`. Puedes escribir `n` para cancelar sin tocar nada. El detalle de cada modo está en el [README](./README.md).

## Programas extra para algunos modos

Solo si vas a usar estos modos. Se instalan dentro de Ubuntu.

**Juegos (`-g`)**: necesita una herramienta para descomprimir.

```bash
sudo apt install unzip p7zip-full
```

Instala `unzip` (para `.zip`) y 7-Zip (que abre `.zip` y `.rar`).

**Subtítulos (`-t`)**: necesita subliminal, que se instala con pipx.

```bash
sudo apt update
sudo apt install pipx
pipx ensurepath
pipx install subliminal
```

Qué hace cada línea: actualiza la lista de programas, instala pipx, le dice a Ubuntu dónde dejará los programas, y instala subliminal aislado en su propia carpeta. No hace falta instalar Python aparte: pipx lo trae como dependencia y apt lo instala solo si falta. Después **cierra y vuelve a abrir la ventana de Ubuntu**. La primera vez que uses `-t`, orgie te preguntará si quieres iniciar sesión con tu cuenta de OpenSubtitles; el README explica qué se guarda y dónde. Para quitar subliminal: `pipx uninstall subliminal`.

## Actualizar y desinstalar

```bash
orgie --update        # busca una versión nueva y pregunta antes de instalarla
orgie --uninstall     # quita orgie, y también la sesión y la caché si las hubiera
```

## Si algo falla

**`sudo apt install pipx` da error (por ejemplo `Unable to locate package pipx`).** Suele ser una de estas tres:

1. Falta actualizar la lista de programas. En una instalación nueva de Ubuntu está vacía, así que ejecuta `sudo apt update` y repite el comando.
2. El Ubuntu es demasiado viejo. Mira cuál tienes con `cat /etc/os-release`. pipx está disponible desde Ubuntu 22.04 y subliminal necesita Python 3.10 o más, así que con Ubuntu 20.04 no funciona. La solución es instalar uno nuevo desde PowerShell (no desde Ubuntu): `wsl --install -d Ubuntu-24.04`. Cada Linux de WSL es independiente, así que en el nuevo hay que repetir los pasos 2 a 4. Con `wsl -l -v` ves los que tienes instalados.
3. Ubuntu no tiene internet. Si `sudo apt update` termina con errores del tipo `Temporary failure resolving`, el problema es la red de WSL y no orgie. Reiniciar WSL (`wsl --shutdown` en PowerShell y abrir Ubuntu de nuevo) suele arreglarlo.

Si sigue sin funcionar, copia el texto completo del error (no hace falta captura) para poder verlo.

**`orgie -t` dice "límite diario de descargas alcanzado".** OpenSubtitles limita cuántos subtítulos se pueden bajar por día. No es un problema de tu contraseña ni de la instalación, y orgie sigue con las otras fuentes mientras tanto.

## Al terminar deberías tener

- Ubuntu instalado en Windows, que se abre desde el menú Inicio.
- El comando `orgie --help` funcionando en cualquier ventana de Ubuntu.
- La costumbre de abrir una terminal en una carpeta escribiendo `wsl` en la barra de direcciones del Explorador.
- Tus archivos de Windows exactamente donde estaban.
