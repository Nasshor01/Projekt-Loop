# **PLÁN PŘIDÁVÁNÍ OBSAHU DO PROJEKT LOOP**

Tento dokument obsahuje komplexní plán pro rozšíření hry o nový obsah, vylepšení gameplaye a implementaci nových systémů.

---

## **1. LORE A KONCEPT SMYČKY**

### **1.1 Koncept "Projekt Loop"**
- **Název hry:** Projekt Loop odkazuje na časovou smyčku, ve které se hráč nachází
- **Lore:** Hráč je uvězněn v nekonečné časové smyčce, kde musí projít stejnou cestou znovu a znovu
- **Každý run = nová smyčka:** Každý pokus je nová iterace smyčky, ne "new game +"
- **Cíl:** Najít způsob, jak smyčku prolomit, nebo se naučit v ní přežít a vylepšovat se

### **1.2 Odstranění "Akt 1/2/3" a "New Game +"**
- **Odstranit:** Všechny reference na "Akt 1", "Akt 2", "Akt 3"
- **Odstranit:** Koncept "New Game +" (ng_plus_level)
- **Nahradit:** Systém "Loop Level" - číslo smyčky (Loop 1, Loop 2, Loop 3...)
- **Implementace:**
  - Přejmenovat `ng_plus_level` na `loop_level` v PlayerData
  - Upravit UI, aby zobrazovalo "Loop X" místo "New Game + X"
  - Scaling enemy a odměn bude založen na `loop_level`

---

## **2. VYLEPŠENÍ PALADINA**

### **2.1 Herní Styl Paladina**
Paladin je **defenzivní powerhouse** s těmito charakteristikami:
- **Blok:** Generuje velké množství bloku
- **Léčení:** Má přístup k léčení
- **Svaté poškození:** Trestá nepřátele svatým poškozením
- **Aura:** Pasivní schopnosti posilují obranu

### **2.2 Nové Karty pro Paladina (Cíl: 40-60 karet)**
Aktuálně má Paladin **22 karet** (11 základních + 11 upgradovaných). Potřebujeme přidat **18-38 nových karet**.

#### **Kategorie karet:**

**A) Obrana a Blok (8-10 karet)**
- **Opevnění** (Rare) - Získej 15 bloku. Tento blok nezmizí na konci tahu.
- **Svatá Zbroj** (Uncommon) - Získej 8 bloku. Pokud máš více než 20 bloku, získej +3 bloku navíc.
- **Ochranná Aura** (Common) - Získej 5 bloku. Všichni spojenci získají 2 bloku.
- **Neprůstřelný Štít** (Epic) - Získej 10 bloku. Odstraň všechny debuffy.
- **Posvěcená Bariéra** (Uncommon) - Získej 6 bloku. Pokud jsi v posledním tahu utrpěl poškození, získej +4 bloku.
- **Obranný Postoj** (Common) - Získej 4 bloku. Příští útok proti tobě způsobí o 50% méně poškození.
- **Svatý Štít** (Rare) - Získej 12 bloku. Pokud máš méně než 50% zdraví, získej +8 bloku.
- **Neprůstřelná Víra** (Epic) - Získej bloku rovný tvému maximálnímu zdraví. Tato karta se vyčerpá.

**B) Léčení (6-8 karet)**
- **Očista** (Uncommon) - Odstraň všechny debuffy a získej 5 bloku. (Odemčeno ve skill tree)
- **Léčivé Světlo** (Common) - Vyléč se za 8 HP.
- **Masivní Léčení** (Rare) - Vyléč se za 20 HP. Pokud máš méně než 30% zdraví, vyléč se za 30 HP.
- **Svaté Požehnání** (Uncommon) - Vyléč se za 12 HP. Získej 3 bloku.
- **Regenerace** (Common) - Získej status "Regenerace" (léčí 3 HP na konci každého tahu) na 3 kola.
- **Posvátné Vyléčení** (Rare) - Vyléč se za 15 HP. Odstraň všechny debuffy.
- **Božská Milost** (Epic) - Vyléč se na plné zdraví. Tato karta se vyčerpá.
- **Léčivá Aura** (Uncommon) - Vyléč se za 10 HP. Všichni spojenci se vyléčí za 5 HP.

**C) Svaté Poškození (8-10 karet)**
- **Svatý Úder** (Common) - Způsob 8 svatého poškození.
- **Boží Hněv** (Rare) - Způsob 15 svatého poškození. Pokud má nepřítel debuff, způsob +10 svatého poškození.
- **Exkomunikace** (Uncommon) - Způsob 10 svatého poškození. Nepřítel získá debuff "Zranitelný" na 2 kola.
- **Svatá Pomsta** (Common) - Způsob 6 svatého poškození. Za každý blok, který máš, způsob +1 poškození.
- **Božský Soud** (Epic) - Způsob 25 svatého poškození všem nepřátelům. Tato karta se vyčerpá.
- **Svatý Hněv** (Rare) - Způsob 12 svatého poškození. Pokud máš více než 15 bloku, způsob +8 svatého poškození.
- **Posvěcená Zbraň** (Uncommon) - Způsob 9 svatého poškození. Příští útok způsobí +5 svatého poškození.
- **Boží Blesk** (Rare) - Způsob 18 svatého poškození. Pokud zabiješ nepřítele, získej 2 energie.
- **Svatá Pomsta** (Common) - Způsob 7 svatého poškození. Za každé poškození, které jsi utrpěl v tomto kole, způsob +1 poškození.
- **Božská Spravedlnost** (Epic) - Způsob 20 svatého poškození. Pokud má nepřítel více než 50% zdraví, způsob +15 svatého poškození.

**D) Kombinované Efekty (4-6 karet)**
- **Štítový Úder** (Common) - Získej 5 bloku. Způsob 6 poškození.
- **Ochranná Ruka** (Uncommon) - Získej 8 bloku. Vyléč se za 5 HP.
- **Svatá Obrana** (Rare) - Získej 10 bloku. Způsob 10 svatého poškození.
- **Božská Ochrana** (Epic) - Získej 15 bloku. Vyléč se za 10 HP. Způsob 12 svatého poškození všem nepřátelům.
- **Svatý Rytíř** (Rare) - Získej 6 bloku. Způsob 8 svatého poškození. Vyléč se za 4 HP.
- **Neprůstřelná Víra** (Legendary) - Získej bloku rovný tvému maximálnímu zdraví. Vyléč se na plné zdraví. Způsob 30 svatého poškození všem nepřátelům. Tato karta se vyčerpá.

### **2.3 Úprava Pasivního Skill Tree**
- **Přidat uzly pro odemykání karet:**
  - "Očista" - Odemčeno na Tier 2
  - "Opevnění" - Odemčeno na Tier 3
  - "Božský Soud" - Odemčeno na Tier 4
  - "Neprůstřelná Víra" - Odemčeno na Tier 5 (finální schopnost)

---

## **3. SYSTÉM ODEMYKÁNÍ KARET**

### **3.1 Mechanika Odemykání**
- **Karty se odemykají ve Skill Tree:**
  - Některé uzly v skill tree mají vlastnost "unlocks_card: String" (card_id)
  - Když hráč alokuje takový uzel, karta se přidá do `PlayerData.unlocked_cards`
  - Odemčené karty se pak mohou objevit v reward scene a obchodě

### **3.2 Úprava CardPool**
- **Přidat metodu `get_available_cards()` do CardPool.gd:**
  ```gdscript
  func get_available_cards(player_class: ClassData, player_subclass: SubclassData, unlocked_cards: Array[String]) -> Array[CardData]:
      var available = []
      for card in cards:
          # Filtruj podle třídy
          if not card.can_be_used_by(player_class, player_subclass):
              continue
          # Filtruj podle rarity (BASIC karty se neobjevují)
          if card.rarity == CardData.CardRarity.BASIC:
              continue
          # Filtruj podle odemčených karet
          if card.required_subclass != null:
              # Karta je specifická pro subclassu - musí být odemčena
              if not unlocked_cards.has(card.card_id):
                  continue
          available.append(card)
      return available
  ```

### **3.3 Úprava Reward Scene a Shop**
- **RewardScene.gd:** Použít `get_available_cards()` místo přímého přístupu k poolu
- **ShopScene.gd:** Použít `get_available_cards()` místo přímého přístupu k poolu
- **GameManager.gd:** Použít `get_available_cards()` při generování odměn

### **3.4 Úprava PassiveSkillNode**
- **Přidat pole `unlocks_card: String = ""`** do PassiveSkillNode.gd
- **Přidat logiku:** Když se uzel alokuje, odemkne kartu (pokud je nastaveno)

---

## **4. ROZŠÍŘENÍ KARET PRO VŠECHNY TŘÍDY**

### **4.1 Cíl: 40-60 karet na třídu**
- **Paladin:** 22 → 50 karet (potřebujeme +28)
- **Berserker:** 0 → 50 karet (nová třída)
- **Ochránce:** 0 → 50 karet (nová třída)
- **Mistr Zbraní:** 0 → 50 karet (nová třída)
- **Duelant:** 0 → 50 karet (nová třída)
- **Elementalista:** 0 → 50 karet (nová třída)
- **Alchymista:** 0 → 50 karet (nová třída)
- **Nekromant:** 0 → 50 karet (nová třída)
- **Stínový Vrah:** 0 → 50 karet (nová třída)
- **Trapper:** 0 → 50 karet (nová třída)
- **Vrah Duší:** 0 → 50 karet (nová třída)

### **4.2 Prioritizace**
1. **Fáze 1:** Dokončit Paladina (28 nových karet)
2. **Fáze 2:** Implementovat 2-3 další třídy (Berserker, Elementalista, Stínový Vrah)
3. **Fáze 3:** Postupně přidávat zbývající třídy

---

## **5. ROZŠÍŘENÍ ARTEFAKTŮ**

### **5.1 Více Artefaktů**
- **Aktuální stav:** ~10-15 artefaktů
- **Cíl:** 50-80 artefaktů celkem
- **Kategorie:**
  - **Common (20-25):** Základní vylepšení
  - **Uncommon (15-20):** Střední vylepšení
  - **Rare (10-15):** Silná vylepšení
  - **Epic (5-8):** Velmi silná vylepšení
  - **Legendary (3-5):** Nejsilnější artefakty

### **5.2 Kombinace Artefaktů (Synergie)**
- **Systém kombinací:**
  - Některé artefakty mají "synergy_tags: Array[String]"
  - Když hráč má 2+ artefakty se stejnými tagy, aktivuje se bonus
  - **Příklad:**
    - "Svatý Amulet" + "Posvěcená Zbroj" = +5% k všem svatým poškozením
    - "Krvavý Meč" + "Berserkerova Zbroj" = +10% k poškození za každé chybějící HP

### **5.3 Implementace Synergií**
- **Přidat do ArtifactsData.gd:**
  ```gdscript
  @export var synergy_tags: Array[String] = []
  ```
- **Přidat do ArtifactManager.gd:**
  ```gdscript
  func get_synergy_bonuses() -> Dictionary:
      var tag_counts = {}
      for artifact in PlayerData.artifacts:
          for tag in artifact.synergy_tags:
              tag_counts[tag] = tag_counts.get(tag, 0) + 1
      # Vrátit bonusy pro tagy s 2+ artefakty
  ```

---

## **6. VÍCE NEPŘÁTEL**

### **6.1 Rozšíření Enemy Pool**
- **Aktuální stav:** ~5-10 typů nepřátel
- **Cíl:** 30-50 typů nepřátel
- **Kategorie:**
  - **Normální nepřátelé (20-30):** Základní typy
  - **Elite nepřátelé (8-12):** Silnější verze
  - **Boss nepřátelé (5-8):** Finální souboje

### **6.2 Nové Typy Nepřátel**
- **Melee nepřátelé:**
  - Goblin Warrior, Orc Berserker, Skeleton Knight, Zombie Brute
- **Ranged nepřátelé:**
  - Goblin Archer, Orc Shaman, Skeleton Archer, Dark Mage
- **Tank nepřátelé:**
  - Stone Golem, Iron Guardian, Bone Colossus
- **Support nepřátelé:**
  - Goblin Shaman, Necromancer, Dark Priest
- **Speciální nepřátelé:**
  - Exploder (vybuchuje), Cursed (proklíná), Regenerator (léčí se)

### **6.3 Implementace**
- Vytvořit nové UnitData soubory v `data/units/`
- Vytvořit nové EncounterData soubory v `data/encounters/`
- Přidat nové AI skripty pokud je potřeba

---

## **7. LEPŠÍ SCALING ENEMY A ODMĚN**

### **7.1 Systém Loop Level**
- **Nahradit ng_plus_level za loop_level:**
  ```gdscript
  var loop_level: int = 0  # Místo ng_plus_level
  ```

### **7.2 Scaling Enemy**
- **Zdraví:** `base_health * (1.0 + loop_level * 0.3)`
- **Poškození:** `base_damage * (1.0 + loop_level * 0.25)`
- **Speciální schopnosti:** Některé nepřátelé získávají nové schopnosti v vyšších loop levelech

### **7.3 Scaling Odměn**
- **Zlato:** `base_gold * (1.0 + loop_level * 0.2)`
- **XP:** `base_xp * (1.0 + loop_level * 0.15)`
- **Vzácnost karet:** Vyšší loop level = větší šance na Rare/Epic karty
- **Vzácnost artefaktů:** Vyšší loop level = větší šance na Rare/Epic artefakty

### **7.4 Implementace**
- **Unit.gd:** Upravit scaling v `_ready()`
- **GameManager.gd:** Upravit generování odměn
- **EncounterData.gd:** Přidat možnost nastavit scaling koeficienty

---

## **8. IMPLEMENTAČNÍ POŘADÍ**

### **Fáze 1: Základní Systémy (1-2 týdny)**
1. ✅ Odstranit "New Game +" a nahradit "Loop Level"
2. ✅ Implementovat systém odemykání karet
3. ✅ Upravit CardPool pro filtrování podle odemčených karet
4. ✅ Upravit Reward Scene a Shop pro použití filtrovaných poolů

### **Fáze 2: Vylepšení Paladina (1-2 týdny)**
1. ✅ Vytvořit 28 nových karet pro Paladina
2. ✅ Upravit skill tree pro odemykání karet
3. ✅ Otestovat gameplay Paladina

### **Fáze 3: Rozšíření Artefaktů (1 týden)**
1. ✅ Vytvořit 20-30 nových artefaktů
2. ✅ Implementovat systém synergií
3. ✅ Otestovat kombinace artefaktů

### **Fáze 4: Více Nepřátel (1-2 týdny)**
1. ✅ Vytvořit 20-30 nových typů nepřátel
2. ✅ Vytvořit nové encountery
3. ✅ Otestovat bojovou rozmanitost

### **Fáze 5: Scaling a Balance (1 týden)**
1. ✅ Implementovat loop level scaling
2. ✅ Vybalancovat odměny
3. ✅ Otestovat progresi

### **Fáze 6: Další Třídy (Postupně)**
1. ✅ Implementovat Berserker
2. ✅ Implementovat Elementalista
3. ✅ Implementovat další třídy podle priorit

---

## **9. TECHNICKÉ POZNÁMKY**

### **9.1 Migrace ng_plus_level → loop_level**
- **SaveManager:** Přidat migraci pro staré save soubory
- **PlayerData:** Přejmenovat proměnnou a signál
- **UI:** Aktualizovat všechny reference

### **9.2 Odemykání Karet**
- **SaveManager:** Uložit odemčené karty do meta_progress
- **PlayerData:** Udržovat seznam odemčených karet
- **Skill Tree UI:** Zobrazit, které karty se odemknou

### **9.3 Performance**
- **Card Pool filtrování:** Cache výsledky filtrování
- **Enemy scaling:** Předpočítat hodnoty při načtení
- **Synergie artefaktů:** Předpočítat při změně artefaktů

---

## **10. TESTING CHECKLIST**

### **10.1 Systém Odemykání Karet**
- [ ] Karty se odemykají při alokaci uzlu
- [ ] Odemčené karty se objevují v reward scene
- [ ] Odemčené karty se objevují v obchodě
- [ ] Neodemčené karty se neobjevují

### **10.2 Loop Level**
- [ ] Loop level se správně zvyšuje
- [ ] Enemy scaling funguje
- [ ] Odměny scaling funguje
- [ ] UI zobrazuje "Loop X" místo "New Game + X"

### **10.3 Paladin Karty**
- [ ] Všechny nové karty fungují správně
- [ ] Karty jsou vyvážené
- [ ] Skill tree odemykání funguje

### **10.4 Artefakty**
- [ ] Nové artefakty fungují
- [ ] Synergie fungují
- [ ] Kombinace jsou vyvážené

### **10.5 Nepřátelé**
- [ ] Noví nepřátelé fungují
- [ ] AI funguje správně
- [ ] Encountery jsou vyvážené

---

## **11. BUDOUCÍ ROZŠÍŘENÍ**

### **11.1 Eventy**
- Více eventů s odměnami
- Eventy specifické pro loop level

### **11.2 Map System**
- Více typů uzlů na mapě
- Speciální uzly pro vyšší loop levely

### **11.3 Achievements**
- Achievement systém
- Odměny za achievementy

### **11.4 Daily Challenges**
- Denní výzvy
- Speciální odměny

---

**Konec dokumentu**

