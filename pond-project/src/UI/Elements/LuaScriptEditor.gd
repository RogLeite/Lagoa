tool
extends TextEdit

signal lua_script_changed(p_self)

const KEYWORDS : Array = ["and", "break", "do", "end", "false", "function", "in", "local", "nil", "not", "or", "return", "true"]
const FLOW_CONTROL_KEYWORDS = ["until", "while", "else", "elseif", "for", "goto", "if", "repeat", "then"]
#const SYMBOLS : Array = ["+", "-", "*", "/", "%", "^", "#", "&", "~", "|", "<<", ">>", "//", "==", "~=", "<=", ">=", "<", ">", "=", "(", ")", "{", "}", "[", "]", "::", ";", ":", ",", ".", "..", "..."]

export var keyword_color : Color = Color(1, 0.439216, 0.521569, 1)
export var flow_control_keyword_color : Color = Color(1, 0.54902, 0.8, 1)
export var string_color : Color = Color(1, 0.92549, 0.631373)
export var comment_color : Color = Color(0.462745, 0.47451, 0.509804)
#export var symbol_color : Color = Color(1, 0.54902, 0.8, 1)

func _init():
	for word in KEYWORDS:
		add_keyword_color(word, keyword_color)
	for word in FLOW_CONTROL_KEYWORDS:
		add_keyword_color(word, flow_control_keyword_color)
#	for word in KEYWORDS:
#		add_keyword_color(word, keyword_color)

	# Colours strings
	add_color_region("\"", "\"", string_color)
	add_color_region("\'", "\'", string_color)
	
	# Colours comments
	for i in range(0,50):
		var s : String = "=".repeat(i)
		add_color_region("--[%s["%s, "]%s]"%s, comment_color)
	add_color_region("--", "", comment_color, true)

	


func _on_PlayerScriptTemplate_text_changed():
	emit_signal("lua_script_changed", self)
