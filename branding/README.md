# Imágenes originales de Mi Voz

Estas imágenes se conservan sin modificar. No se empaquetan en la app: los
recursos que usa la app se generan a partir de ellas.

| Archivo | Imagen | Se usa en |
|---|---|---|
| `imagen1_pantalla_de_carga.png` | Imagen 1: niño sonriendo con una tableta de pictogramas, globo "Mi Voz" y marco circular de colores | Pantalla de carga → `assets/images/splash_mi_voz.png` |
| `imagen2_icono_app.png` | Imagen 2: niño con audífonos azules, burbuja con barras de sonido, piezas de rompecabezas y "Mi Voz" | Icono de instalación → `assets/icon/` y logotipo → `assets/images/logo_mi_voz.png` |

Para reemplazar una imagen, guarda la nueva con el **mismo nombre** en esta
carpeta y ejecuta:

```bash
dart run tool/prepare_brand_assets.dart
dart run flutter_launcher_icons
```

Qué hace `tool/prepare_brand_assets.dart`:
- Imagen 1: convierte el fondo blanco exterior al marco circular en
  transparencia (sin tocar el dibujo) y la reduce a 1024 × 1024.
- Imagen 2: limpia los píxeles casi transparentes, recorta el margen vacío y
  genera el icono completo (fondo celeste suave), el primer plano adaptativo
  (zona segura) y el logotipo. Siempre conserva las proporciones.
