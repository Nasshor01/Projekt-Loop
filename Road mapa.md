### **Rozšíření Světa a Nepřátel**

**Hlavní cíl:** Nahradit dočasný systém "New Game+" za strukturovanější postup hrou a naplnit svět zajímavějšími a chytřejšími nepřáteli.

Předělat smyčku po bossovi. Místo NG+ se hráč přesune do Fáze 2 (Akt 2).

**Akt 1:** Základní nepřátelé, první boss.  
**Akt 2:** Noví, silnější nepřátelé, nové eventy, druhý boss.  
**Akt 3:** Elitní verze nepřátel, finální boss.

—------------------------------------------------------------------------------------------------------------------------  
vývoj pokročilé AI a tříd enemy

fighter- obyčejný bojovník nic speciálního nemá, vyžaduje útok na blízko

assassin- umí se pohybovat rychleji na gridu, šance na double útok 25% (když dá double útok jeho útoky způsobují 75%dmg, šance na dodge 35%

berserk- malý pohyb po gridu ale silný dmg, pokud se k tobě nestihne dostat během prvních 5 kol tak když jste na stejným lince nebo sloupci tak k tobě rushne a dá masivní dmg (300% dmg)

archer- bojují z dálky, vždy když jste u nich na dosah tak se pokouší se dostat od vás pryč, využívají terén aby se schovali a měli větší přesnost, když jedno kolo neútočí tak zaměřují (250%dmg)

mage- bojují z dálky a dávají elementální požkození, pokud neumře za prvních 10 kol tak hodí na grid obří meteorit který ale dává požkození uplně všem a zapálí celý grid

druid- dokážou spawnout spirity kteří bojují po boku druidů, 5% šance na spawn ochránce

monk- nedává žádný dmg ale bufuje ostatní jednotky

healer/cleric- dává holy dmg (větší dmg do undead unitů a postav) a healuje spojence

Implementování elementárních vlastností 

Fire  
Hlavní mechanika: Poškození v čase (Damage over Time \- DoT).   
Statusový efekt: Hoření (Burning) Na začátku tvého tahu ti udělí X poškození.   
Každé kolo se doba trvání (nebo síla) snižuje.

Ice   
Hlavní mechanika: Omezení pohybu a akcí.

Statusový efekt: Zchlazení (Chilled)

Sníží tvůj pohyb na mřížce o 1\. Pokud máš více Zchlazení, můžeš být Zmrazen (Frozen).

Zmrazení: Na jedno kolo nemůžeš hrát žádné karty nebo se hýbat.

Lightning   
Hlavní mechanika: Zranitelnost, nárazové poškození.

Statusový efekt: Šok (Shocked)

Příští poškození, které utrpíš (z jakéhokoliv zdroje), bude o 50 % vyšší. Po zásahu efekt zmizí.

Rock & Iron(Kámen a Železo \- Trpaslíci