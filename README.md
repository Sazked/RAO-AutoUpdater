# RAO AutoUpdater

Repositorio de distribución del cliente de Rhember Argentum Online. Conserva
manifests, scripts de publicación y paquetes históricos utilizados por
RAO-Launcher.

## Estado actual

Este repositorio es público y es el canal de actualizaciones activo
(Sazked/RAO-AutoUpdater). Tanto el cliente como el launcher leen:

~~~text
https://raw.githubusercontent.com/Sazked/RAO-AutoUpdater/main/manifest.json
~~~

- El cliente compara rao/public_version de project.godot con la versión del
  manifest antes de conectar; si no coinciden, pide abrir el launcher.
- El launcher compara la versión del manifest con launcher-state.json,
  descarga el ZIP del release, verifica su SHA-256 y reemplaza game/.

El repositorio debe seguir siendo público: si pasa a privado, ningún jugador
podrá conectarse (el cliente no podrá verificar su versión). No se debe
incorporar un token personal al launcher.

## Contenido

- manifest.schema.json: contrato del manifest.
- manifest.example.json: ejemplo sin datos operativos.
- manifest.json: publicación vigente que leen el cliente y el launcher.
- Version.txt: referencia de versión utilizada por el flujo anterior.
- scripts/Publish-RAOClientRelease.ps1: validador y publicador.
- patch-notes.json: lista de parches que muestran las Noticias del launcher y del login.

Los paquetes Parche*.zip del cliente legacy (VB6) se retiraron del repositorio;
siguen disponibles en el historial de git.

## Formato del manifest

~~~json
{
  "version": "0.1.0-test.1",
  "download_url": "https://updates.example.com/RAO-Client-0.1.0-test.1-windows-x86_64.zip",
  "sha256": "64 caracteres hexadecimales en minúscula",
  "executable": "rao-client.exe"
}
~~~

El ZIP debe contener rao-client.exe en su raíz. El launcher compara el SHA-256
antes de extraer e instalar.

## Requisitos para administrar publicaciones

- PowerShell.
- Git.
- GitHub CLI autenticado con permisos sobre el repositorio.
- Un ZIP de Windows generado desde el cliente actual.

## Previsualizar una publicación

La previsualización valida el archivo y genera el manifest sin modificar
GitHub:

~~~powershell
.\scripts\Publish-RAOClientRelease.ps1 -ArchivePath C:\ruta\RAO-Client-0.1.0-test.1-windows-x86_64.zip -Version 0.1.0-test.1
~~~

## Publicar

La versión debe ser exactamente la misma que rao/public_version del
project.godot con el que se exportó el cliente; si no, el cliente publicado
nunca podrá conectar.

~~~powershell
.\scripts\Publish-RAOClientRelease.ps1 -ArchivePath C:\ruta\RAO-Client-0.1.0-test.1-windows-x86_64.zip -Version 0.1.0-test.1 -Publish
~~~

El script:

1. verifica que rao-client.exe esté en la raíz del ZIP;
2. calcula SHA-256;
3. crea un GitHub Release;
4. sube el ZIP;
5. actualiza manifest.json;
6. crea un commit y lo publica en main.

Desde ese momento los clientes con otra versión verán "Actualización
requerida" al conectar y el launcher instalará la nueva.

## Publicar el launcher

El launcher se actualiza solo con `launcher-manifest.json`, que tiene el mismo
formato que `manifest.json` pero apunta al `.exe` del launcher. Publicar un
parche del juego nunca lo toca, ni al revés.

```powershell
.\scripts\Publish-RAOLauncherRelease.ps1 -LauncherPath ..\RAO-Launcher\build\RAO-Launcher.exe -Version 1.0.0
.\scripts\Publish-RAOLauncherRelease.ps1 -LauncherPath ..\RAO-Launcher\build\RAO-Launcher.exe -Version 1.0.0 -Publish
```

El script verifica que el `.exe` informe esa misma versión (`--version`), crea
el release `launcher-v<versión>` con `RAO-Launcher.exe` sin marcarlo como
último release, y actualiza `launcher-manifest.json` en `main`.

## Noticias (patch-notes.json)

El launcher y la pantalla de login del cliente descargan `patch-notes.json`
(junto a `manifest.json`) y lo muestran en Noticias: cada parche aparece por
su título y se despliega con un clic para leer sus notas. Si no hay conexión
se muestra la última copia descargada.

Con cada publicación se agrega una entrada **al principio** de `patches`:

```json
{
  "title": "Parche 0.1.0-prealpha.26",
  "date": "2026-11-20",
  "notes": ["Primera novedad.", "Segunda novedad."]
}
```

La fecha va en formato `AAAA-MM-DD` y se muestra como `20/11/2026`.

## Probar el contrato sin publicar

~~~powershell
Get-Content manifest.example.json | ConvertFrom-Json | Out-Null
Get-Content manifest.schema.json | ConvertFrom-Json | Out-Null
~~~

La validación completa del publicador puede hacerse con un ZIP temporal que
contenga rao-client.exe y sin utilizar -Publish.

## Relación con el proyecto

El juego está en pre-alpha y actualmente prioriza PvP: targeting, combate,
hechizos, duelos, inventario, comercio, parties, guilds, facciones y
BattleServer. PvE cuenta con NPC, loot, mascotas, interacción y pathfinding,
pero es el área menos madura en contenido, balance y progresión.

## Repositorios relacionados

- AutoUpdater: https://github.com/Sazked/RAO-AutoUpdater
- Launcher: https://github.com/Sazked/RAO-Launcher
- Cliente: https://github.com/Sazked/RAO-Godot-Client
- Servidor: https://github.com/Sazked/RAO-Go-Server

## Seguridad

- No almacenar tokens, credenciales o claves en manifests o scripts.
- No publicar IPs reales de servidores.
- Verificar siempre el SHA-256 antes de instalar.
- No reutilizar un ZIP si las fuentes cambiaron después de exportarlo.
