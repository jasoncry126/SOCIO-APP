# De dónde salió esta skill y qué se le tocó

Esta carpeta **no la escribimos nosotros**. Es una copia de la skill `ui-ux-pro-max` del
repositorio público <https://github.com/nextlevelbuilder/ui-ux-pro-max-skill>,
con licencia MIT (ver `LICENSE`), tomada del commit `dcc40ff` (21 de septiembre de 2026).

## Qué es

Son instrucciones y tablas de consulta que Claude lee cuando el trabajo toca cómo se ve o
cómo se usa una pantalla: contraste, tamaño de los botones para el dedo, formularios,
navegación, tipografías, paletas, animación. No es una librería: no entra en el sitio que ve
el cliente ni en lo que se sube a Netlify. Solo cambia lo que Claude tiene en cuenta al
trabajar en este repositorio.

## Qué se revisó antes de traerla

- **No pide nada por internet.** Los scripts no importan `urllib.request`, `requests` ni
  ningún cliente de red. Las direcciones que aparecen en los CSV son referencias a
  documentación, en una columna de datos; nadie las abre.
- **No instala ni ejecuta nada.** Sin `subprocess`, `os.system`, `eval` ni `exec`.
- **Solo lee.** La única escritura posible es la opción `--persist`, que crea una carpeta
  `design-system/` y hay que pedirla a propósito.
- **Sin instrucciones escondidas** en los datos que intenten redirigir a Claude.
- Corre con Python 3 pelado, sin dependencias.

## Qué se cambió respecto al original

1. `SKILL.md` invocaba el script con `${CLAUDE_PLUGIN_ROOT}/...`, una variable que solo
   existe si la skill se instala como plugin. Aquí vive dentro del repositorio, así que esa
   variable queda vacía y el comando se rompe. Se reemplazó por la ruta relativa
   `.claude/skills/ui-ux-pro-max/scripts/search.py`, que funciona desde la raíz del repositorio.
2. Se quitó `scripts/tests/`, que son las pruebas de la propia skill (26 archivos, ~500 KB).
   No hacen falta para usarla y este repositorio no tiene CI.

Nada más. El resto es idéntico al original.

## Para actualizarla más adelante

Clonar el repositorio de arriba, copiar `.claude/skills/ui-ux-pro-max` encima de esta
carpeta, borrar otra vez `scripts/tests/`, y volver a aplicar el cambio de rutas del punto 1.
