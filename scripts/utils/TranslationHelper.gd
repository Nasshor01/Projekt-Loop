# Translation Helper
# Pomocná třída pro práci s překlady
class_name TranslationHelper
extends RefCounted

# Statická funkce pro překlad s parametry
static func tr_format(key: String, params: Dictionary = {}) -> String:
	var text = TranslationServer.translate(key)
	
	# Nahradíme parametry ve formátu {key}
	for param_key in params:
		var placeholder = "{" + param_key + "}"
		text = text.replace(placeholder, str(params[param_key]))
	
	return text

# Statická funkce pro překlad s jednoduchým parametrem
static func tr_single(key: String, value) -> String:
	return tr_format(key, {"value": value})
