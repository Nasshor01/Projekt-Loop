class_name EncounterPool
extends Resource

## Pool encounterů jedné úrovně (lehké / těžké rané / těžké pozdní / elitní / boss).
@export var tier: EncounterData.Tier = EncounterData.Tier.EASY
@export var encounters: Array[EncounterData] = []
