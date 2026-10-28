# 🔥 El Señor de las Llamas — Monstruo + Ciudad para Roblox

Diseño **original inspirado** en el demonio de las imágenes (estilo anime tipo *Black Clover*):
silueta oscura, cara con ojos brillantes, **corona de picos**, **halo de esferas de fuego**,
**varios brazos con garras**, **alas rasgadas**, parado sobre una **ciudad medieval en llamas**.
Cuando un jugador entra a la ciudad, **el demonio despierta y lo ataca**.

> ⚠️ El de las fotos es un personaje de anime con derechos de autor. Este es un diseño
> *inspirado* en ese estilo, no una copia exacta — tuyo para tu juego.

---

## 📁 Qué hay en esta carpeta

```
roblox-senor-llamas/
├── blender/
│   └── senor_llamas.py        → genera el monstruo (detallado) + ciudad en Blender
└── roblox/
    ├── DemonLordAI.server.lua → cerebro del jefe: zona, fases, vida (Luau)
    └── Poderes.lua            → poderes brutales con efectos (ModuleScript)
```

---

## 🧱 PASO 1 — Crear el modelo 3D (Blender)

1. Abre **Blender** (3.x o 4.x).
2. Pestaña **Scripting** → **Text → Open** → elige `blender/senor_llamas.py`.
3. Presiona **Run Script** (▶).
   - Aparecen dos colecciones: `SEÑOR_DE_LAS_LLAMAS` y `CIUDAD_EN_LLAMAS`.
4. (Opcional) Pule a mano: esculpir, texturas, más detalle en cara/alas.

> 💡 Es una **base procedural** sólida y estilizada. El detalle fino tipo escultura
> se hace a mano — el script te ahorra el 80% del bloque inicial.

### Exportar para Roblox
- Selecciona solo la colección del monstruo (si quieres el demonio aparte).
- **File → Export → FBX (.fbx)**.
- En las opciones marca **Selected Objects** y escala **1.0**.

---

## 🎮 PASO 2 — Montarlo en Roblox Studio

### a) Importar el modelo
1. En Studio: **Avatar → Import 3D** (o **Three Dots → Insert from File**) y sube el `.fbx`.
2. Agrupa todas las partes en un **Model** y renómbralo **`SenorLlamas`**.
3. Dale un **PrimaryPart**: crea/elige una Part central (por ejemplo una llamada
   `HumanoidRootPart`) y en las propiedades del Model pon **PrimaryPart = esa Part**.
   - (Opcional) si creas una Part llamada **`ManoDerecha`**, las bolas de fuego saldrán de ahí.

### b) Crear la zona de la ciudad
1. Inserta una **Part** grande que cubra toda la ciudad.
2. Renómbrala **`ZonaCiudad`**.
3. Propiedades: **Anchored = true**, **CanCollide = false**, **Transparency = 1**
   (invisible, solo es el "disparador" de la zona).

### c) Poner los scripts
1. En **ReplicatedStorage** inserta un **ModuleScript**, renómbralo **`Poderes`**
   y pega TODO el contenido de `roblox/Poderes.lua`.
2. En **ServerScriptService** inserta un **Script** (no LocalScript) y pega
   TODO el contenido de `roblox/DemonLordAI.server.lua`.
3. **Play** ▶ y camina hacia la ciudad: el demonio despierta y te ataca. 🔥

> El Script carga el ModuleScript con `require(ReplicatedStorage.Poderes)`, así que
> **ambos** tienen que existir con esos nombres exactos.

---

## 🔥 PODERES BRUTALES (ya incluidos)

El jefe tiene **vida (5000)**, **barra de jefe** y **3 fases** que se vuelven más
salvajes mientras le bajas la vida:

| Poder | Qué hace |
|-------|----------|
| 🌠 **Lluvia de meteoros** | Meteoros caen del cielo sobre los jugadores (marca de aviso + explosión) |
| 🔥 **Pilares de fuego** | Columnas de fuego erupcionan bajo tus pies |
| 💥 **Nova de fuego** | Onda expansiva gigante desde el demonio (daño + empuje) |
| 👁️ **Rayo ocular** | Láser de los ojos que te persigue y quema |
| ☄️ **Bolas infernales** | Bolas de fuego teledirigidas que te cazan |
| 🌋 **Erupción de lava** | Géiseres de lava por todo el mapa |
| ☠️ **METEORO COLOSAL** | Ataque final (fase 3): meteoro de 40 studs, devastador |

**Fases:**
- **Fase 1** (100–66% vida): bolas, rayo, nova.
- **Fase 2** (66–33%): agrega meteoros y pilares, más rápido.
- **Fase 3** (33–0%): modo furia — lava, meteoro colosal, ataca casi sin parar.
- **Al morir:** nova + erupción final y se desvanece.

### ¿Cómo le hago daño al jefe?
En tus armas/proyectiles del jugador, ponle un **Attribute numérico llamado `DanoArma`**
a la Part que golpea (p.ej. `espada:SetAttribute("DanoArma", 50)`). Cuando toque al
demonio, le resta esa cantidad de vida automáticamente.

---

## ⚙️ Ajustes rápidos (arriba del script, tabla `CONFIG`)

| Opción | Qué controla |
|--------|--------------|
| `DANIO_BOLA` | daño de cada bola de fuego |
| `DANIO_AOE` / `RADIO_AOE` | daño y alcance del golpe de área |
| `COOLDOWN_BOLA` / `COOLDOWN_AOE` | cada cuánto ataca |
| `VEL_BOLA` | velocidad de las bolas |
| `GIRO_SUAVE` | qué tan rápido voltea a verte |

---

## ✅ Resumen de lo que hace el ataque
- Detecta cuándo entras a `ZonaCiudad` (caja orientada, funciona aunque la gires).
- Elige al jugador **más cercano dentro de la ciudad**.
- Voltea a mirarte, lanza **bolas de fuego** y cada tanto un **golpe de área**.
- Si la ciudad queda vacía, **vuelve a dormir**.

---

## 🚀 Siguientes pasos (si quieres, te los armo)
- **Rig (esqueleto)** del monstruo en Blender para animar brazos y alas (Rigify).
- **Animaciones** de ataque (alzar brazos al lanzar meteoros, batir alas).
- **Sonidos** épicos (rugidos, impactos, música de jefe).
- **Recompensa** al derrotarlo (ítem, badge, puntos).
- Afinar **daño/vida** para que la pelea quede justa.

Dime cuál sigue y lo agrego. 💪
