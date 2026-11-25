# Android Start — Project Ember v0.29.0

1. Распакуй ZIP в отдельную новую папку. Не перезаписывай v0.28.0 и предыдущие рабочие сборки.
2. В Godot 4.7.2 Android Editor открой `project.godot` из папки v0.29.0.
3. Дождись завершения импорта ресурсов и проверь панель ошибок редактора.
4. Сначала создай новую кампанию или загрузи КОПИЮ сохранения v0.28.0. Не проверяй миграцию на единственном оригинале.
5. Открой «Ещё → Королевства», выбери разведанную державу и открой «Дипломатия».
6. Сверь характер, отношение, договор и описание доступных действий. Неизвестные державы не должны раскрывать разведывательные сведения.
7. Предложи торговлю. Если ИИ примет её, проверь срок в 6 ходов и начисление +2 золота за ход обеим сторонам.
8. Проверь союз после торгового договора: срок 8 ходов, доход +2 золота за ход каждой стороне.
9. Объяви войну или атакуй армию мирной державы. Проверь причину войны, движение вражеской армии и рост усталости на 5 за ход.
10. Во время войны проверь предложение мира от ИИ после порога усталости 35. После заключения мира должно действовать перемирие 4 хода.
11. На достаточно слабой державе проверь требование дани и вассалитета. Выплата не должна опустить казну плательщика ниже нуля.
12. Сохрани кампанию, перезапусти проект и проверь загрузку отношений, договоров, срока, усталости и входящих предложений.
13. Для миграции скопии v0.28.0 убедись, что старый сейв без дипломатических полей получает детерминированные отношения и пустую очередь предложений без изменения номера схемы.

## Что важно

- Это исходный Godot-проект, не APK.
- Используются только золото, еда и накопленное производство; четвёртый ресурс не добавлен.
- Версия схемы сохранений остаётся 1. Новые корневые поля: `diplomacy_relations`, `pending_diplomacy_offers`.
- Статические проверки 162/162 пройдены. Они не заменяют Godot parser/import, запуск сцен, реальные сохранение/загрузку и проверку на Android.
- `tests/diplomacy_smoke_test.gd` включён как тестовый исходник, но в среде сборки не исполнялся.


## v0.30.0 — Campaign victory verification

1. Import the project with Godot 4.7.2 Android Editor. Keep the v0.29.0 project and save as a separate backup.
2. Load a COPY of a v0.29.0 campaign. Confirm that it opens with empty victory progress and that the original cities, armies, diplomacy and neutral locations remain unchanged.
3. Open «Ещё → Цели победы». Before turn 25, the three paths must show progress but cannot unlock.
4. For the military path, win battles against six different AI kingdoms. Repeat battles against the same kingdom and confirm the counter does not increase. Keep at least eight living player troops for the sixth distinct win.
5. For the economic path, reach two cities with population 14+, keep at least 600 combined gold and a projected net gold income of +12/turn or more for five consecutive turns. Drop below any condition and confirm the hold counter resets.
6. For the diplomatic path, maintain relation +55 with five living kingdoms, three active positive agreements and at least two alliances or player-led vassal agreements for three consecutive turns.
7. Select an unlocked path and choose «Продолжить игру». Save, restart and confirm the victory choice and turn persist while the campaign continues.
8. Select an unlocked path and choose «Завершить кампанию» in a separate test save. Confirm turn advancement, map actions, army selection and city actions are disabled after reload.
9. Check the victory panel on the phone in landscape orientation: scroll all three rows, verify the safe area and confirm every interactive button is at least 48 dp high.
10. Run `tests/campaign_victory_smoke_test.gd` plus the existing campaign, diplomacy, faction, city, world and combat smoke tests.

The victory rules intentionally do not introduce mana, new building IDs, new unit IDs or a fourth resource. The project ZIP is source code, not an APK.
