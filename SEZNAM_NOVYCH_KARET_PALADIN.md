# Seznam nových karet pro Paladina

Vytvořeno celkem **30 nových karet** pro Paladina podle plánu.

## Karty Obrana a Blok (8 karet)

1. **fortification.tres** - Opevnění (Rare) - Získej 15 bloku. Tento blok nezmizí na konci tahu.
2. **holy_armor.tres** - Svatá Zbroj (Uncommon) - Získej 8 bloku. Pokud máš více než 20 bloku, získej +3 bloku navíc.
3. **protective_aura.tres** - Ochranná Aura (Common) - Získej 5 bloku. Všichni spojenci získají 2 bloku.
4. **impregnable_shield.tres** - Neprůstřelný Štít (Epic) - Získej 10 bloku. Odstraň všechny debuffy.
5. **consecrated_barrier.tres** - Posvěcená Bariéra (Uncommon) - Získej 6 bloku. Pokud jsi v posledním tahu utrpěl poškození, získej +4 bloku.
6. **defensive_stance.tres** - Obranný Postoj (Common) - Získej 4 bloku. Příští útok proti tobě způsobí o 50% méně poškození.
7. **holy_shield.tres** - Svatý Štít (Rare) - Získej 12 bloku. Pokud máš méně než 50% zdraví, získej +8 bloku.
8. **unbreakable_faith.tres** - Neprůstřelná Víra (Epic) - Získej bloku rovný tvému maximálnímu zdraví. Tato karta se vyčerpá.

## Karty Léčení (8 karet)

1. **purification.tres** - Očista (Uncommon) - Odstraň všechny debuffy a získej 5 bloku. (Odemčeno ve skill tree)
2. **healing_light.tres** - Léčivé Světlo (Common) - Vyléč se za 8 HP.
3. **massive_healing.tres** - Masivní Léčení (Rare) - Vyléč se za 20 HP. Pokud máš méně než 30% zdraví, vyléč se za 30 HP.
4. **holy_blessing.tres** - Svaté Požehnání (Uncommon) - Vyléč se za 12 HP. Získej 3 bloku.
5. **regeneration.tres** - Regenerace (Common) - Získej status "Regenerace" (léčí 3 HP na konci každého tahu) na 3 kola.
6. **sacred_healing.tres** - Posvátné Vyléčení (Rare) - Vyléč se za 15 HP. Odstraň všechny debuffy.
7. **divine_grace.tres** - Božská Milost (Epic) - Vyléč se na plné zdraví. Tato karta se vyčerpá.
8. **healing_aura.tres** - Léčivá Aura (Uncommon) - Vyléč se za 10 HP. Všichni spojenci se vyléčí za 5 HP.

## Karty Svaté Poškození (9 karet)

1. **holy_strike.tres** - Svatý Úder (Common) - Způsob 8 svatého poškození.
2. **gods_wrath.tres** - Boží Hněv (Rare) - Způsob 15 svatého poškození. Pokud má nepřítel debuff, způsob +10 svatého poškození.
3. **excommunication.tres** - Exkomunikace (Uncommon) - Způsob 10 svatého poškození. Nepřítel získá debuff "Zranitelný" na 2 kola.
4. **holy_vengeance.tres** - Svatá Pomsta (Common) - Způsob 6 svatého poškození. Za každý blok, který máš, způsob +1 poškození.
5. **divine_judgment.tres** - Božský Soud (Epic) - Způsob 25 svatého poškození všem nepřátelům. Tato karta se vyčerpá.
6. **holy_wrath.tres** - Svatý Hněv (Rare) - Způsob 12 svatého poškození. Pokud máš více než 15 bloku, způsob +8 svatého poškození.
7. **consecrated_weapon.tres** - Posvěcená Zbraň (Uncommon) - Způsob 9 svatého poškození. Příští útok způsobí +5 svatého poškození.
8. **gods_lightning.tres** - Boží Blesk (Rare) - Způsob 18 svatého poškození. Pokud zabiješ nepřítele, získej 2 energie.
9. **divine_justice.tres** - Božská Spravedlnost (Epic) - Způsob 20 svatého poškození. Pokud má nepřítel více než 50% zdraví, způsob +15 svatého poškození.

## Karty Kombinované Efekty (5 karet)

1. **shield_strike.tres** - Štítový Úder (Common) - Získej 5 bloku. Způsob 6 poškození.
2. **protective_hand.tres** - Ochranná Ruka (Uncommon) - Získej 8 bloku. Vyléč se za 5 HP.
3. **holy_defense.tres** - Svatá Obrana (Rare) - Získej 10 bloku. Způsob 10 svatého poškození.
4. **divine_protection.tres** - Božská Ochrana (Epic) - Získej 15 bloku. Vyléč se za 10 HP. Způsob 12 svatého poškození všem nepřátelům.
5. **holy_knight.tres** - Svatý Rytíř (Rare) - Získej 6 bloku. Způsob 8 svatého poškození. Vyléč se za 4 HP.

## Instrukce pro přidání do poolů

Všechny karty jsou uloženy v `data/cards/paladin/`. Pro přidání do poolů:

1. Otevři `data/cards/reward_card_pool.tres` v Godot editoru
2. Otevři `data/cards/shop_card_pool.tres` v Godot editoru
3. Přidej všechny nové karty do pole `cards` v obou souborech
4. Ulož soubory

**POZNÁMKA:** Některé karty mají podmíněné efekty (např. "pokud máš více než X bloku"), které budou vyžadovat implementaci v battle systému. Základní efekty (blok, léčení, poškození) by měly fungovat okamžitě.

