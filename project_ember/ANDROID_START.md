# Android Start — Project Ember v0.17.0

1. Распакуй ZIP в отдельную папку. Не перезаписывай v0.16.0 и предыдущие версии.
2. В Godot Android Editor открой `project.godot` и дождись импорта двух атласов: `world_surface_atlas.png` и `world_detail_atlas.png`. На первом открытии импорт может занять больше времени из-за mipmap-уровней.
3. Запусти проект. Для проверки визуальных ресурсов можно использовать текущую кампанию: генератор и сохранения не менялись.
4. Проверь `zoom 0.900`: рисунок должен продолжаться через соседние гексы, а крупные детали ландшафта — появляться выборочно поверх поверхности.
5. Проверь `zoom 0.075`: foreground detail batch должен отключаться, а карта переходить в спокойный LOD.
6. Сними Performance Report на обоих масштабах. Нужны FPS, Draw Calls, Objects, Video Memory и число экземпляров карты.

## Что изменено
- 24 самостоятельные сцены поверхности: по четыре для каждого из шести биомов. Источники разделены из прежних коллажей; ни один контакт-лист не используется как единая текстура.
- 4×4 axial macro-region выбирает один художественный вариант на крупную область; текстура всё равно сэмплируется по общим мировым координатам.
- Соседние биомы и варианты мягко смешиваются у общей границы гексов.
- Период выборки уменьшен до 430 world units для более высокой детализации на близком масштабе.
- Добавлен второй пакетный слой из 24 крупных деталей: цветочные поля, кроны, горные гряды, берега, поля и болота.
- Гекс-сетка ослаблена; один MultiMesh рельефа и один MultiMesh деталей.
- Генераторы миров v1/v2/v3, ИИ, бои и формат сохранений не изменялись.

## Проверка
Это исходный Godot-проект, не APK. В этой среде не удалось запустить Godot Parser/Shader Compiler, поэтому обязательны импорт в Godot 4.7.2 и проверка на Android. Не удаляй подтверждённую рабочую версию до этого теста.


## QA pipeline (v0.17.1)

- Target engine is pinned to Godot 4.7.2 stable. The matching official Linux editor binary is checksum-verified by `.github/workflows/ember-qa.yml`.
- Every `tests/*_smoke_test.gd` test runs in its own temporary user-data directory.
- The visual capture runner saves strategic-map screenshots at zoom 0.075, 0.76, 0.90 and 1.25 and writes a JSON summary with tile/detail batch counts and RenderingServer metrics.
- GitHub Actions uploads the complete QA bundle even when a test fails, so logs and screenshots can be inspected.
- On Android, keep sending the in-game Performance Report together with a screenshot at zoom 0.900. CI uses Mesa software rendering and is not a substitute for measuring the physical Android GPU.
- To activate the workflow for the current v0.17.1 source, use `INSTALL_EMBER_QA_PIPELINE.sh` from the accompanying release package. It creates a dedicated `qa/godot-4.7.2-visual-pipeline-v0.17.1` branch and opens a PR; `main` and PR #4 remain untouched.
