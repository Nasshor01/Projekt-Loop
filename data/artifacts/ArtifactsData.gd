# Soubor: data/artifacts/ArtifactsData.gd
class_name ArtifactsData
extends Resource

## Název artefaktu, který se zobrazí ve hře.
@export var artifact_name: String = "Neznámý artefakt"

## Popis toho, co artefakt dělá.
@export_multiline var description: String = "Dělá něco tajemného."

## Ikona artefaktu.
@export var texture: Texture2D

## Unikátní ID pro identifikaci efektu v kódu.
@export var effect_id: String = ""

## Číselná hodnota spojená s efektem.
@export var value: int = 0
