tool
extends TextEdit

const KEYWORDS : Array = ["and", "break", "do", "end", "false", "function", "in", "local", "nil", "not", "or", "return", "true"]
const FLOW_CONTROL_KEYWORDS = ["until", "while", "else", "elseif", "for", "goto", "if", "repeat", "then"]
#const SYMBOLS : Array = ["+", "-", "*", "/", "%", "^", "#", "&", "~", "|", "<<", ">>", "//", "==", "~=", "<=", ">=", "<", ">", "=", "(", ")", "{", "}", "[", "]", "::", ";", ":", ",", ".", "..", "..."]

export var keyword_color : Color = Color(1, 0.439216, 0.521569, 1)
export var flow_control_keyword_color : Color = Color(1, 0.54902, 0.8, 1)
#export var symbol_color : Color = Color(1, 0.54902, 0.8, 1)

func _init():
	for word in KEYWORDS:
		add_keyword_color(word, keyword_color)
	for word in FLOW_CONTROL_KEYWORDS:
		add_keyword_color(word, flow_control_keyword_color)
#	for word in KEYWORDS:
#		add_keyword_color(word, keyword_color)
