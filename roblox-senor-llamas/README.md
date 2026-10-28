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
│   └── senor_llamas.py          → genera el monstruo (detallado) + ciudad en Blender
└── roblox/
    ├── CiudadArena.server.lua   → construye la ciudad-arena jugable en Roblox
    ├── DemonLordAI.server.lua   → cerebro del jefe: zona, fases, vida, melee (Luau)
    ├── Poderes.lua              → poderes brutales + zarpazo (ModuleScript)
    └── EspadaInfernal.server.lua→ arma del jugador para combatir al jefe
```

> 💡 Dos formas de tener la ciudad:
> - **Rápida y jugable:** usa `CiudadArena.server.lua` (la arma Roblox solito, sin Blender).
> - **Bonita y con detalle:** usa el modelo de `blender/senor_llamas.py` y la importas.
> Puedes usar la arena de Roblox para jugar y meter el demonio detallado de Blender encima.

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
Inserta cada archivo en el lugar correcto (nombres exactos):

| Archivo | Dónde va | Tipo | Nómbralo |
|---------|----------|------|----------|
| `Poderes.lua` | **ReplicatedStorage** | ModuleScript | `Poderes` |
| `CiudadArena.server.lua` | **ServerScriptService** | Script | (libre) |
| `DemonLordAI.server.lua` | **ServerScriptService** | Script | (libre) |
| `EspadaInfernal.server.lua` | **ServerScriptService** | Script | (libre) |

Luego **Play** ▶:
1. `CiudadArena` construye la ciudad, la muralla, la lava, el spawn y la `ZonaCiudad`.
2. Coloca tu Model **`SenorLlamas`** en el **centro (0, altura, 0)**.
3. Apareces en la **puerta**, agarras la **Espada Infernal** (tecla 1) y entras a pelear. ⚔️🔥

> El `DemonLordAI` carga `require(ReplicatedStorage.Poderes)`, así que el ModuleScript
> **tiene que llamarse `Poderes`** y estar en ReplicatedStorage.

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

---

## 🏙️ LA CIUDAD-ARENA + COMBATE

**`CiudadArena.server.lua`** arma todo el escenario jugable en Roblox:
- Suelo de piedra, **anillo de edificios** con plaza central (ahí va el jefe).
- **Charcos de lava** que queman al pisarlos (12 de daño/seg).
- **Fogatas y llamaradas** de ambiente con luz.
- **Muralla exterior con puerta** y torres.
- **SpawnLocation** en la puerta: los jugadores entran por ahí.
- Crea sola la **`ZonaCiudad`** que despierta al demonio.

### ⚔️ Rango de golpes (melee)
El jefe ahora combina distancia y cuerpo a cuerpo:
- **Lejos** → poderes a distancia (meteoros, rayo, etc.).
- **Cerca (≤ 24 studs)** → **ZARPAZO**: golpe de garra en arco frontal (120°) que
  hace daño y te empuja. Ajusta `RANGO_MELEE`, `DANO_MELEE` y `ESPERA_MELEE` en el AI.

### 🗡️ Cómo pelea el jugador
`EspadaInfernal.server.lua` le da a cada jugador una **Espada Infernal** al aparecer:
- Trae el atributo **`DanoArma = 60`** en la hoja.
- Equípala (tecla **1**) y golpea al demonio acercándote: le baja la vida.
- El jefe tiene **cooldown por arma** (`COOLDOWN_GOLPE`) para que no muera de un toque.

> ¿Quieres otra arma (arco, hacha, magia)? Solo ponle el atributo `DanoArma` a la
> parte que golpea y listo — el jefe ya sabe recibir daño de cualquier cosa con ese atributo.

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
