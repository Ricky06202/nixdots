---
name: web-design-pro
description: Diseña y construye páginas web modernas, memorables y de alta conversión — landing pages, sitios de negocios locales, portafolios y sitios corporativos. Use when designing or building web pages, landing pages, hero sections, UI aesthetics, landing pages for local businesses, or when the user wants a design that feels premium, innovative, award-worthy (Awwwards-level) and "wow". Covers visual hierarchy, color, typography, motion, micro-interactions, storytelling, and conversion-driven CTAs with Tailwind CSS, Astro, React, and responsive mobile-first layout.
license: MIT
metadata:
  author: opencode-ricky
  version: "2.0"
  domain: frontend
  role: specialist
  scope: design-and-implementation
  output-format: code
---

# Web Design Pro — Diseño que vende y sorprende

Experto en diseño UI/UX para web. Cada página debe cumplir dos metas simultáneas: **convertir** (vender, cotizar, contactar, llamar) y **sorprender** (dejar al visitante diciendo "wow, ¿esto se puede hacer en una web?"). No hay excusa para páginas genéricas: la estética por defecto es inaceptable.

## Cuándo usar esta skill

- Crear landing pages, sitios de negocios locales (veterinarias, clínicas, restaurantes, tiendas, estudios), portafolios, sitios corporativos.
- Diseñar el hero, secciones, tarjetas, CTAs, headers, footers o cualquier pieza visual de una web.
- Elegir paleta de colores, tipografías, spacing, sombras, animaciones o estilo visual general.
- Rediseñar una página existente que se ve genérica o no convierte.
- Cuando el usuario pida algo "innovador", "wow", "premium", "que llame la atención" o "que se vea caro".

## Regla de oro

> **Lo genérico es un bug.** Si la página podría confundirse con una plantilla de ThemeForest, está mal hecha. Cada diseño debe tener una identidad propia, un "gancho visual" que la haga inolvidable.

---

## Parte 1 — Fundamentos de conversión (nunca se sacrifican)

1. **Mobile-first siempre.** La mayoría del tráfico local es móvil. Los botones de contacto (llamar directo, WhatsApp) deben ser grandes, de alto contraste y **siempre accesibles** (header fijo, botón flotante, o ambos). Prueba todo diseño primero en 375px de ancho.
2. **Jerarquía visual clara.**
   - `h1` grande, llamativo, con la propuesta clara: qué ofrece el negocio + en qué ciudad (ej: "Clínica Veterinaria 24/7 en David, Chiriquí").
   - Una idea por sección, secciones bien delimitadas con contenedores/tarjetas limpias.
   - Un solo CTA principal por pantalla; los secundarios se atenúan visualmente.
3. **CTAs sin ambigüedad.** Texto que invite a la acción inmediata: "Llamar Ahora", "Cotizar Servicio", "Ver Ubicación", "Agenda tu cita". El botón primario debe contrastar contra todo lo demás.
4. **Confianza y prueba social.** Testimonios reales, resultados en números ("+500 mascotas atendidas"), garantías, insignias, fotos del negocio real. La prueba social va justo después del hero y cerca del CTA.
5. **Velocidad.** El diseño no justifica una web lenta. Optimiza imágenes, evita animaciones que bloqueen el LCP, usa `content-visibility` y lazy-loading. Core Web Vitals verdes.

## Parte 2 — El "gancho" visual (lo que te hace único)

Antes de escribir CSS, define **UNA idea de diseño rectora** (design hook). Pregunta: *¿qué hace que ESTA marca sea diferente y cómo lo vuelvo visual?* Elige una dirección de entre estos niveles de ambición:

### Nivel 1 — Identidad de marca fuerte (mínimo aceptable)
- Paleta de color **propia del negocio**, no azul corporativo genérico. Máximo 3 colores + neutros. Deriva la paleta de la marca (ej: una clínica veterinaria → verdes y tierra; una cafetería → tonos tostados cálidos; un estudio creativo → neón sobre oscuro).
- Tipografía con **personalidad**: una display (serif editorial, grotesca con carácter, mono técnico) + una legible para cuerpo. Evita Inter/Roboto por defecto: busca algo con carácter (Fraunces, Space Grotesk, Clash Display, Unbounded, Syne, Playfair).
- Bordes redondeados **sutiles y coherentes** (`rounded-xl`–`rounded-3xl`), sombras con profundidad (`shadow-md`), spacing generoso (`py-12`/`py-24`, `gap-6`).
- Texturas o detalles propios: ruido sutil (SVG `feTurbulence`), grano, gradientes orgánicos, motivos repetidos de la marca.

### Nivel 2 — Diseño que se siente vivo (motion como identidad)
- **Micro-interacciones en todo elemento interactivo**: hover que transforma (escala + rotación + color), foco de botón con `::after` que se despliega, links con subrayado animado.
- **Scroll experiences**: secciones que revelan con `IntersectionObserver` (fade + slide + stagger), progreso de scroll, parallax sutil, texto que se desvanece al hacer scroll.
- **Cursor con identidad**: botón magnético, cursor custom que cambia según el elemento, spotlight que sigue al mouse (radial-gradient en el hero).
- **Animaciones de entrada (page load)**: hero con stagger escalonado de título/línea de apoyo/CTA, números que cuentan al aparecer.
- Todo respetando `prefers-reduced-motion`.

### Nivel 3 — Experiencias que dejan con la boca abierta (solo cuando el cliente lo pide o el proyecto lo merece)
- **Storytelling scrollytelling**: la página cuenta una historia a medida que el usuario baja (escenas que cambian, texto que se reemplaza, imágenes que se transforman).
- **3D / WebGL** (Three.js / Spline / R3F): producto rotando, héroe tridimensional, geometrías abstractas interactivas de fondo.
- **Marca de agua gigante de fondo**: el nombre de la marca como tipografía enorme semi-transparente detrás del contenido.
- **Glassmorphism / neumorphism** bien ejecutados (no sobreusados), **gradientes animados (aurora)**, **botones con brillo que siguen al mouse**, **borde que se pinta solo** (conic-gradient en CSS).
- **Modo oscuro por defecto con acentos neón** para estudios creativos/tech.
- **Tipografía gigante editorial** (title de viewport completo), composiciones asimétricas tipo revista (grid de 12 con elementos que rompen la cuadrícula).

> **Regla de uso:** el Nivel 3 se aplica cuando el usuario pide innovación explícitamente o cuando la marca es de alto valor percibido (estudios creativos, productos premium, eventos, startups). Para un negocio local, Nivel 1–2 + conversión impecable suele ser la combinación ganadora. **La conversión nunca se sacrifica por el espectáculo.**

## Parte 3 — Proceso de trabajo (metodología)

1. **Entender el negocio** (si no se ha hecho): giro, ciudad, público, competencia, qué vende, cómo contacta. Pregunta si falta contexto.
2. **Definir el gancho y la dirección de diseño** en 1-2 frases. Ejemplo: *"Cafetería de especialidad → Nivel 2: crema cálida sobre fondo oscuro, tipografía editorial, grano de café animado en el hero, CTA 'Ordena ahora' fijo."*
3. **Diseñar el sistema**: paleta (definir tokens en `tailwind.config` o CSS variables), tipografías (2 máximo, con jerarquía), radios de borde, sombras, espaciados, breakpoints, estados (hover/active/disabled).
4. **Construir mobile-first** componente a componente con Tailwind: header → hero → prueba social → beneficios → cómo funciona → testimoniales → precios/servicios → FAQs → CTA final → footer.
5. **Añadir motion** (Nivel 2-3): primero la estructura, después la vida.
6. **Revisar conversión**: ¿el CTA principal es imposible de perder? ¿el teléfono/WhatsApp está a un toque en móvil? ¿el mensaje del h1 se entiende en 3 segundos?
7. **Verificar** en el navegador a 375px, 768px y desktop; validar contraste AA, `prefers-reduced-motion`, y que no se rompa nada al hacer zoom/rotar.

## Parte 4 — Patrones técnicos (Tailwind + Astro/React)

- **Tokens en vez de clases sueltas**: define colores, fuentes y radios en la config de Tailwind; el contenido usa solo tokens. Cambiar la marca = cambiar tokens.
- **Botón primario**: gradiente o color sólido de alto contraste + `hover:scale-[1.03]` + sombra con `transition`. Nunca un `<button>` sin estado hover/focus visible.
- **Contenedor**: `mx-auto max-w-6xl px-4 sm:px-6 lg:px-8`. Tarjetas: `rounded-2xl shadow-sm hover:shadow-md transition-shadow`.
- **Hero efectivo**: h1 grande (`text-4xl sm:text-5xl lg:text-6xl` + `font-bold tracking-tight`), línea de apoyo (máx. 2 líneas), CTA primario + secundario, y un **elemento visual** (imagen real, mockup, gráfico, efecto) — el hero sin imagen convierte peor.
- **Sticky CTA móvil**: botón de contacto fijo en la parte inferior en móvil (`fixed bottom-4`), o en el header.
- **Imágenes reales > ilustraciones genéricas** para negocios locales: fotos del local, del equipo, de resultados. Usa `loading="lazy"` excepto en el hero (`eager` + `fetchpriority="high"`).
- **Accesibilidad**: landmarks semánticos, `alt` descriptivo, contraste AA, `aria-label` en iconos, foco visible, `prefers-reduced-motion: reduce` para desactivar animaciones.
- **SEO local**: `LocalBusiness`/`MedicalBusiness` (JSON-LD), teléfono y dirección en `tel:` links, `og:` tags, meta description que menciona la ciudad.

## Parte 5 — Anti-patrones (prohibido)

- Fondos gris claro + botón azul + texto negro por defecto ("estética 2018").
- Más de 3 colores saturados compitiendo.
- Más de 2 tipografías por página.
- Párrafos interminables (nadie los lee); usa bullets, tarjetas, y 2 frases máximo por bloque.
- Animaciones lentas o infinitas que irritan; todo motion ≤ 400ms salvo casos justificados.
- Centrar todo (clásico de plantilla); mezcla alineaciones para crear tensión visual.
- Emojis como iconos de marca, imágenes con watermark de banco de imágenes, sliders que cambian solos sin control del usuario.

## Checklist final (antes de entregar)

- [ ] El h1 responde a "¿qué es esto, dónde está, y qué hago ahora?" en ≤3 segundos.
- [ ] CTA principal visible sin scroll y repetido al menos al final de la página.
- [ ] En móvil: contacto (tel/WhatsApp) accesible en todo momento.
- [ ] Paleta coherente, tipografías con carácter, "gancho visual" identificable.
- [ ] Micro-interacciones en todos los elementos interactivos.
- [ ] Contraste AA, `prefers-reduced-motion` respetado, HTML semántico.
- [ ] Lighthouse: Performance ≥ 90, Best Practices ≥ 95, Accessibility ≥ 95.
- [ ] Se siente único: nadie la confundiría con una plantilla.
