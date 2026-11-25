# Project Ember — Art Bible

## Направление

**Stylized Low-Poly Fantasy**: тёплая, картинная эстетика настольной миниатюры на старинном игровом столе. Геометрия простая и выразительная, материалы матовые, силуэты различимы на экране телефона. Деталь вторична по отношению к композиции и читаемости.

## Палитра

Основные цвета собраны в `scripts/art_palette.gd` (`ArtPalette`). Рельеф и окружение используют землю, траву, лес, холмы, воду, камень и дерево. Металл — холодный серо-стальной, золото — приглушённое тёплое.

Игрок: синий текстиль с серебряным металлом и золотыми мелкими акцентами. Враг: багрово-красный текстиль с тёмным металлом. Команды должны различаться не только цветом: в дальнейших этапах игроку соответствует прямоугольное знамя и округлый щит, врагу — раздвоенный вымпел и угловатый щит.

## Силуэты юнитов

- Мечник: щит и короткий меч; тяжёлые плечи и устойчивый силуэт.
- Лучник: лёгкая фигура, лук и колчан, без щита.
- Копейщик: длинное древко, выступающее выше головы.
- Кавалерия: заметно более крупная форма коня и всадника.
- Командир: плащ, поднятое знамя и золотая отделка.

Силуэт должен считываться до мелких декоративных деталей. Боевой интерфейс не должен закрывать центр поля.

## Свет и материалы

Целевой свет — тёплый направленный утренний/закатный источник и прохладный заполняющий ambient. Тени мягкие, длинные и ограниченные одним направленным источником. Depth fog допустим только в дешёвой конфигурации GL Compatibility. Основные поверхности матовые; металл использует умеренную metallic-значимость, ткань и дерево — высокую roughness.

## UI

Тёмная бронза задаёт основу панелей, тонкая кромка бронзы и золота связывает экраны. Золото — для важных действий и наград, красно-терракотовый — для предупреждений, зелёный — для восстановления. Минимальный размер нажимаемой цели — 48 px на базовом viewport; базовый шрифт — 16 px.

## Правило пяти секунд

За первые пять секунд боя игрок должен определить стороны, расположение отрядов, выбранную цель и состояние здоровья. Для этого используются цвет команды, форма отрядов, селекционное кольцо, маркер цели и полоска здоровья. Не добавлять детали, которые мешают чтению этих сигналов.

## Бюджет Android

Предпочтение MultiMesh для повторяющегося окружения и общим материалам. Качество Низкое отключает динамические тени и сокращает количество декора; Среднее — целевой профиль; Высокое увеличивает детализацию умеренно. Тяжёлые пост-эффекты и рендер-функции Forward+/Mobile не использовать: целевой рендерер — Godot 4.3 GL Compatibility.

## Стратегическая карта — иллюстрированный рельеф

- Поверхность гексов должна напоминать матовую раскрашенную миниатюрную карту: мягкий внутренний рельеф, тонкая светлая кромка и читаемый силуэт на телефоне.
- Тип местности получает собственный небольшой мотив: травяные пучки, кроны леса, линии горных склонов или водные ряби.
- Мотивы создаются в одном компактном атласе и выбираются через alpha-диапазон цвета экземпляра одного MultiMesh. Не создавать отдельные Sprite2D/CanvasItem на клетки; не использовать неподдерживаемые custom shader built-ins для CanvasItem в GL Compatibility.
- Ориентация декоративного мотива детерминирована координатами гекса и меняется шагами по 60°, чтобы избежать механического повтора.
- На континентальном масштабе отдельные символы заменяются спокойными топографическими контурами LOD-чанка.
- Туман войны продолжает управлять яркостью экземпляра; неизвестная местность не должна раскрывать сведения о типе рельефа.
- Декоративная фактура не должна конкурировать с городами, армиями, границами и селекционными маркерами.


## Стратегическая карта — дороги, города и ориентиры

- Столицы читаются крупнее поселений: укреплённый периметр, башни, центральная постройка и знамя фракции. Города игрока используют синий цвет, столицы AI — собственный цвет державы.
- Дороги связывают столицу с основанными городами. Трасса строится по осевой линии гексов; участки над водой, чужими владениями и неразведанными клетками не рисуются.
- Контуры владений проходят по границам разведанных гексов с разными владельцами. Неизведанные клетки не участвуют в построении отображаемых границ.
- Природные ориентиры (горные пики, древние деревья, островки и менгиры) выбираются по координатам гекса и seed мира. Они не требуют новых полей сохранения или постоянных объектов сцены.
- Дороги и границы собираются в пакетные массивы линий на существующем CanvasItem. Не создавать отдельные Node2D, Line2D или Sprite2D на каждый сегмент или ориентир.
- Маркеры городов, армий и перемещения остаются визуально выше инфраструктуры. На малом масштабе природные ориентиры отключаются, чтобы не перегружать континентальный LOD.


## Стратегическая карта — атлас ориентиров и подписи

- Природные ориентиры не создают самостоятельных CanvasItem-примитивов: пик, древнее дерево, островок и менгир являются вариантами существующего гекс-атласа.
- Атлас сохраняет один MultiMesh и один terrain draw batch. Ориентир выбирает специальную колонку с тем же базовым биомом, а цвет экземпляра продолжает управлять владением и туманом войны.
- Специальные варианты используют ту же ориентацию и геометрию гекса, чтобы не менять размер экземпляра и не создавать отдельные объекты на клетку.
- Подписи названий разведанных городов показываются только при zoom >= 0.58; на малом масштабе остаются компактные символы, не создающие текстовый шум.
- Атлас генерируется один раз при создании рендерера. Никакой генерации текстуры или новых узлов во время движения камеры не выполняется.


## Стратегическая карта — читаемость и иерархия

- Основные цвета карты должны быть светлее и различаться по биому: равнины — оливково-золотые, лес — насыщенно-зелёный, холмы — тёплый камень, вода — спокойный сине-бирюзовый.
- Кромка гекса — мягкая светлая грань и короткая тень, а не толстая тёмная рамка. Повторяющиеся штрихи внутри гекса не должны превращаться в шумовую сетку.
- Мотивы биомов широкие и редкие. Природный ориентир должен быть заметнее фоновой фактуры.
- Столица должна быть крупнее поселения и сразу распознаваться по крепостному силуэту и высокому знамени.
- Табличка названия города читается на телефоне и не перекрывает сам маркер.
- Побережье подчёркивается одним общим набором линий только на разведанной местности.


## Map readability correction (v0.12.1)

- The alpha silhouette of an atlas tile must match the strategic axial grid pitch. Avoid undersized hex textures that expose wide dark gaps between neighbouring cells.
- Use six 60-degree motif orientations so repeated forest and meadow patterns do not form vertical stripes.
- Prefer broad low-contrast terrain motifs. Avoid dense high-contrast trunks, scratch-like contours and per-cell decorative linework.
- Remembered terrain remains dimmer than current vision, but must remain readable; a mild luminance reduction is preferred over heavy darkening.
- Capital and settlement markers must remain the strongest landmarks on the strategic map. Their names should be legible at the standard mobile zoom.


## Painted strategic map atlas (v0.13.0)

- The strategic map's primary visual language is now hand-painted overhead fantasy terrain, not monochrome procedural symbols. Meadows, forests, highlands and water use full-colour art with broad organic shapes.
- Natural landmark variants are part of the same hex atlas: a snow-cut peak, an ancient canopy, a sandy islet and a standing-stone circle.
- Each atlas cell is 304x336 pixels with a 248x286 pointy-top painted hex centered inside a 28x25 transparent gutter. The gutter prevents neighbouring atlas cells bleeding through mipmaps. The visible hex is scaled to the exact strategic grid footprint. Tile borders are kept soft and restrained; do not add heavy dark seams or exterior cast shadows.
- The 7x7 atlas contains six rotated variants of each of eight motifs and one low-detail LOD tile. It is sampled by one MultiMesh shader, with mipmaps for distant map scales.
- Per-instance color remains white for unowned visible terrain. Ownership adds a mild faction tint; remembered territory is dimmed gently, not multiplied by the base terrain palette.
- Capitals and settlements use painted sprite assets. Banner colour and label content remain dynamic per faction/city.


## v0.14 — связные биомы и крупные игровые формы

- Основная карта строится из крупных пространственно связанных зон: равнины, лесные массивы, горные хребты, водные бассейны, болота и сельскохозяйственные поля.
- Гекс-атлас содержит восемь полноцветных семейств по шесть ориентаций. Варианты имеют крупные читаемые формы, а не частую микрофактуру.
- Городские маркеры увеличены: столица становится главным визуальным якорем, поселения остаются чуть компактнее.
- Старые кампании используют генератор мира версии 1. Новые кампании используют версию 2. Версия генератора записывается в сохранение и не меняет ландшафт старого мира.
- Основной Terrain MultiMesh по-прежнему один; биомы не создают дополнительные узлы на каждый гекс.



## Strategic terrain art system v0.15

- Six biomes have four distinct visual compositions each: meadow, forest, highland, water, farmland and marsh.
- The 24 art compositions are sourced from 12 distinct painted hex scenes with mirrored compositions for additional variation; each composition has six 60-degree rotations.
- Atlas layout is family-major: 24 variants per biome (four compositions × six rotations). Direct indices are 0–143; index 144 is continent LOD.
- The flat painted tile surface must not show thick extruded side walls or heavy cast shadows. Hex boundaries are supplied by one batched strategic grid overlay.
- The per-cell source composition and orientation are deterministic from axial coordinates, preventing the same exact image from being stamped across a whole biome.
- Ownership tint and remembered fog remain subtle multipliers over the full-colour source image.
- New campaigns use world-generation v3. Save versions 1 and 2 keep their exact previous terrain generation so that previously explored worlds do not change.


## v0.16 — Continuous world surfaces

- Do not draw a full independent landscape illustration inside every hex. This creates a board of miniature repeated stamps when 200–300 cells are visible.
- The six painterly terrain surfaces are sampled in global axial world coordinates. Adjacent cells in the same biome use identical UVs at shared edges; texture detail flows continuously across the map.
- The hex shape is only a procedural alpha mask. Keep tile side walls, per-hex bevels and heavy tile borders out of the surface artwork.
- The strategic hex grid is drawn separately, once as a batched multiline overlay, using thin low-contrast strokes.
- Distinguish landforms through the large-scale texture itself: forest canopy clusters, broad meadow clearings, mountain ridges, fields, open water and marsh channels. Avoid high-frequency noise and tiny repeated symbols.
- Continue to use one MultiMesh terrain instance and one atlas texture. The additional memory is spent on six large terrain surfaces, not on per-cell nodes.


## v0.17 — Biome transitions and foreground detail

- Terrain families must not switch as hard, isolated hex stamps. The base surface is global in axial world coordinates; a narrow symmetric blend joins different neighboring biomes at shared edges.
- Close-zoom surface sampling targets near one source texel per screen pixel. Use a 430-world-unit surface period in v0.17; validate mipmap sharpness and repetition on Android before tuning further.
- Large visual details are sparse foreground patches drawn from a dedicated atlas in one MultiMesh. They are deterministic per axial cell and seed; never create a Node2D or Sprite2D per patch.
- Forest canopies, alpine ridges, meadow/rock patches, fields, shoreline details and marsh reeds should be used sparingly and must respect fog-of-war brightness.
- At distant zoom, foreground patches are culled and the calm LOD surface remains.


## v0.17 — независимые сцены биомов

- Не использовать 2x2 контактный лист как одну текстуру биома: каждый из четырёх исходных фрагментов остаётся самостоятельной сценой.
- Луга, леса, горы, вода, поля и болота имеют по четыре крупных варианта. Выбор варианта стабилен в пределах 4x4 axial-региона и вычисляется из seed мира.
- Переходы между вариантами и биомами смешиваются по общей мировой координате на границах гексов; у тройных стыков учитывается второе ближайшее ребро.
- Декоративные кроны, горные гряды, поля и болотные группы накладываются отдельным общим MultiMesh, оставаясь под дорогами, сеткой и городами.


## v0.17 — 24 independent painted scenes and landscape details
- Each biome owns four independent artwork crops. A deterministic 4x4 axial macro-region selects the variant, so the map no longer repeats one contact-sheet collage.
- Surface sampling uses shared world coordinates; transitions between biome/scene variants blend at common hex edges.
- Close-zoom sampling period is 430 world units; mipmaps remain enabled.
- The 24-sprite foreground sheet adds larger meadow, canopy, alpine ridge, shore, farmland and marsh forms through one selective MultiMesh.
- Hex-grid lines are subdued; terrain remains the dominant image.
