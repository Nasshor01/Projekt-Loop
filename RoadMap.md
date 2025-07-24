### **Roadmapa Vývoje: Projekt "Loop" (srpen – prosinec 2025)**

---

#### **Fáze 1: Dokončení Základního Zážitku (srpen – polovina října)**

**Cíl:** Mít plně hratelnou a uspokojivou verzi jednoho "runu" od začátku do konce. Soustředíme se na tvůj cíl: **"Bojiště 2.0"** a základní komfort pro hráče.

1.  **Priorita č. 1: Vylepšení Bojiště:**
    * **Implementovat vizualizaci AoE:** Klíčový úkol. Vytvořit v `BattleGrid.gd` funkci, která dočasně zvýrazní zasažená políčka, když hráč klikne myší na kartu s plošným efektem.
    * **Implementovat překážky:** Přidat na bojiště neprůchodné překážky (kameny, trosky), aby se zvýšila taktická hloubka. AI se je musí naučit obcházet.
    * **Zpětná vazba pro hráče:** Přidat "plovoucí" čísla pro poškození/léčení, aby byly dopady karet okamžitě vidět.

2.  **Systém Ukládání a Načítání:**
    * Umožnit hráči uložit hru na mapě a vrátit se později. Vytvořit `SaveManager.gd`, který bude ukládat klíčová data (HP, balíček, pozice na mapě, seed) do JSON souboru.

3.  **Základy Meta-progrese:**
    * Odměnit hráče za každý pokus. Po každém "runu" dej hráči permanentní měnu ("Střepy Věčnosti"). Zatím je jenom sbírej a zobrazuj v nějakém jednoduchém menu.

---

#### **Fáze 2: Obsahová exploze (polovina října – listopad)**

**Cíl:** Naplnit hotové systémy obsahem, aby byl každý průchod hrou unikátní a znovuhratelný.

1.  **Implementace Druhé Hratelné Třídy:**
    * Přidat další kompletní třídu s podtřídou dle tvého plánu. Například **Mág -> Elementalista** nebo **Fighter -> Mistr Zbraní**, protože přináší zcela nové herní styly.

2.  **Rozšíření Obsahu (Karty, Nepřátelé, Artefakty):**
    * **Karty:** Doplň počet karet k cíli ~50-60 unikátních kusů pro dvě hratelné třídy. Zaměř se na karty využívající status efekty (Poison, Weak, Vulnerable).
    * **Nepřátelé:** Vytvoř první tematickou skupinu nepřátel, např. **Zrezivělá Pevnost (Goblini a Orkové)**, s celkovým počtem 15-20 jednotek.
    * **Artefakty:** Vytvoř prvních ~15-20 artefaktů, které významně mění hru.

---

#### **Fáze 3: Leštění a Příprava na Veřejnost (prosinec)**

**Cíl:** Z funkčního prototypu udělat hru, která působí jako ucelený zážitek a je připravená na první oči veřejnosti.

1.  **UI/UX a Vizuální Lesk ("Juice"):**
    * **Zvuky a Hudba:** Přidej základní zvukové efekty (zahrání karty, útok, kliknutí) a hudbu pro boj a mapu.
    * **Animace:** Implementuj jednoduché animace karet, bliknutí jednotek při zásahu, třes obrazovky.
    * **Hlavní Menu:** Vytvoř základní hlavní menu s tlačítky "Nová Hra" a "Ukončit".

2.  **Marketing a Komunita (Průběžně, ale teď naplno):**
    * **Steam Stránka:** Pokud ještě není, teď je nejvyšší čas ji založit a začít sbírat wishlisty.
    * **Demo pro Steam Next Fest:** Tvůj plán vydat demo je skvělý. Prosinec je ideální čas na přípravu této ukázky (např. ořezaná verze s jedním hratelným aktem).
