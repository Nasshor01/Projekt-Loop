# Jak nastavit překlady v Godot editoru

## ⚠️ DŮLEŽITÉ

CSV soubor `translations.csv` musí být importován v Godot editoru jako Translation CSV.

## 📋 Postup:

### Metoda 1: Přes Project Settings (DOPORUČENO)

1. **Otevři Godot editor**
2. **Project → Project Settings**
3. **V levém menu najdi "Localization"**
4. **Klikni na "Translations" v sekci "Translations"**
5. **Klikni na tlačítko "Add..." nebo "+"**
6. **Vyber soubor `translations.csv` z FileSystem panelu**
7. **Klikni "Open"**
8. **Soubor by se měl objevit v seznamu**

### Metoda 2: Přes Import tab

1. **Klikni pravým tlačítkem na `translations.csv` v FileSystem panelu**
2. **Vyber "Reimport"**
3. **V Import tabu (dole) zkontroluj:**
   - **Type:** Translation CSV
   - Pokud není, změň na "Translation CSV"
4. **Klikni "Reimport"**

## ✅ Ověření

Po importu:
1. **Project → Project Settings → Localization → Translations**
2. Měl by tam být `translations.csv` v seznamu

## 🔧 Pokud to stále nefunguje

1. **Zkontroluj, že `translations.csv` má správný formát:**
   ```
   keys,en,cs
   "key","English text","Czech text"
   ```

2. **Zkontroluj, že soubor není prázdný**

3. **Zkus smazat `.import` soubor** (pokud existuje) a znovu importovat

## 📝 Poznámka

Po importu můžeš změnit výchozí jazyk v:
**Project → Project Settings → Localization → Locale Filter**
Nastav na "en" pro angličtinu.
