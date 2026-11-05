# Recursos visuales de Mi Voz

Tres familias, cada una con un papel distinto:

| Familia | Para qué | Dónde | Origen y licencia |
|---|---|---|---|
| **Avatares** | Identidad de cada perfil (niños y adultos) | `assets/avatars/<id>.svg`, catálogo en `lib/core/visuals/avatar_catalog.dart` | Diseño propio de Mi Voz, generado con `tool/avatars/generate_avatars.dart` |
| **Pictogramas** | Comunicación: categorías, acciones, frases, ayuda urgente, solicitudes | `assets/pictograms/<id>.png` (256 px), catálogo en `lib/core/visuals/symbol_catalog.dart` | ARASAAC (Sergio Palao, Gobierno de Aragón), **CC BY-NC-SA 4.0**. Ver `assets/pictograms/ATRIBUCION.md` |
| **Iconos de interfaz** | Navegación, ajustes, historial, estados | Material Symbols *rounded* (`lib/core/theme/ui_icons.dart`) | Incluidos en Flutter (Apache 2.0) |

Todo va dentro de la app: funciona sin internet desde la primera ejecución.
Peso: 133 pictogramas ≈ 844 KB; 42 avatares SVG ≈ 100 KB.

## Identificadores estables

Los datos guardan **el identificador**, nunca la posición en una galería:

- `ChildProfile.avatar` / `AppUser.avatar` → `animal_lion`, `adult_curly_black`…
- `Pictogram.emoji`, `FrequentPhrase.emoji`, `CommunicationRequest.emoji` y
  `PictogramCategory.emoji` → `quiero_agua`, `cat_necesito`, `pal_pizza`…
  (el campo conserva el nombre `emoji` para no romper los datos ya
  guardados ni las reglas del servidor).

## Datos anteriores (emojis)

`AvatarCatalog.legacyEmoji` y `SymbolCatalog.legacyEmoji` traducen cada
emoji que usaban las versiones anteriores a su ilustración. La traducción
ocurre al mostrar (no hace falta reescribir la base de datos) y al guardar
(los formularios normalizan al identificador). El texto y la voz de una
frase nunca cambian: solo su imagen. Un emoji propio sin equivalente se
muestra tal cual, para no perder lo que el adulto eligió.

## Cambiar o agregar recursos

**Pictograma:** agrega `id: "consulta"` en `tool/pictograms/queries.json`,
ejecuta `dart run tool/pictograms/fetch_pictograms.dart candidates <carpeta>`
para ver candidatos, anota el número elegido en `selection.json`, ejecuta
`download` y regenera `lib/core/visuals/symbol_ids.g.dart` (lista de
identificadores). Para sustituir uno existente cambia solo el número: el
identificador se conserva.

**Avatar:** edita o agrega el dibujo en `tool/avatars/generate_avatars.dart`,
ejecuta `dart run tool/avatars/generate_avatars.dart` y registra el
identificador y su descripción accesible en `avatar_catalog.dart`. Revisa la
hoja de contacto con:

```
flutter test test/visuals_preview_test.dart --dart-define=PREVIEW=true --update-goldens
```

(escribe `build/preview/*.png`).

## Licencia de los pictogramas: lo que debes decidir

CC BY-NC-SA **no permite uso comercial**. Es compatible con una app gratuita
y sin publicidad. Si Mi Voz se vende, tiene compras o anuncios, hay que
reemplazar los pictogramas (la estructura de catálogo lo permite sin tocar
los datos) o pedir autorización a ARASAAC.

## Pendiente de revisión humana

- Los pictogramas se eligieron entre los primeros resultados de ARASAAC
  revisando hojas de contacto. Algunos conceptos solo existen en el estilo
  blanco y negro de ARASAAC (p. ej. `tengo_calor`, `me_molesta_ruido`,
  `cat_ayudame`): conviene que una terapeuta del lenguaje valide la
  comprensión con niños reales.
- `me_molesta_ruido` y `cat_me_molesta` usan el mismo pictograma (persona
  tapándose los oídos ante el ruido); `necesito_bano`, `quiero_ir_bano` y
  `ayudame_bano` comparten el inodoro.
- Los avatares son ilustraciones vectoriales simples generadas por código;
  un ilustrador puede refinarlos conservando los identificadores.
