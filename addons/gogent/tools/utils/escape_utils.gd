@tool
class_name GoGentEscapeUtils
extends RefCounted
## 特殊字符转义标记工具
##
## 在 JSON 工具调用中使用特殊字符标记来避免转义问题。
## 参考 AlphaAgent 的设计：使用 {GOGENT_NEWLINE_CHAR} 等标记代替转义字符。
##
## 问题背景：
## AI 在生成 JSON 时，字符串中的换行符、引号、制表符等需要转义，
## 但 AI 经常忘记转义或转义错误，导致 JSON 解析失败。
## 使用特殊标记可以让 AI 直接插入标记，由系统在解析时替换为实际字符。

const NEWLINE_CHAR := "{GOGENT_NEWLINE_CHAR}"
const TAB_CHAR := "{GOGENT_TAB_CHAR}"
const QUOTE_CHAR := "{GOGENT_QUOTE_CHAR}"
const BACKSLASH_CHAR := "{GOGENT_BACKSLASH_CHAR}"
const CARRIAGE_RETURN_CHAR := "{GOGENT_CR_CHAR}"
const DOUBLE_QUOTE_CHAR := "{GOGENT_DQUOTE_CHAR}"

# 所有标记的列表，用于检测
const ALL_MARKERS := [
	NEWLINE_CHAR,
	TAB_CHAR,
	QUOTE_CHAR,
	BACKSLASH_CHAR,
	CARRIAGE_RETURN_CHAR,
	DOUBLE_QUOTE_CHAR
]

## 将字符串中的特殊字符替换为标记（编码）
## 用于在显示给 AI 之前，将文件内容中的特殊字符替换为标记
static func encode(text: String) -> String:
	var result := text
	result = result.replace("\\", BACKSLASH_CHAR)  # 反斜杠必须先处理
	result = result.replace("\r\n", NEWLINE_CHAR)
	result = result.replace("\r", CARRIAGE_RETURN_CHAR)
	result = result.replace("\n", NEWLINE_CHAR)
	result = result.replace("\t", TAB_CHAR)
	result = result.replace("\"", DOUBLE_QUOTE_CHAR)
	result = result.replace("'", QUOTE_CHAR)
	return result

## 将标记替换回实际字符（解码）
## 用于在解析 AI 返回的工具调用参数时，将标记替换为实际字符
static func decode(text: String) -> String:
	var result := text
	result = result.replace(NEWLINE_CHAR, "\n")
	result = result.replace(TAB_CHAR, "\t")
	result = result.replace(QUOTE_CHAR, "'")
	result = result.replace(BACKSLASH_CHAR, "\\")
	result = result.replace(CARRIAGE_RETURN_CHAR, "\r")
	result = result.replace(DOUBLE_QUOTE_CHAR, "\"")
	return result

## 解码 JSON 字符串中的标记
## 递归处理所有字符串值
static func decode_json(data) -> Variant:
	if data is String:
		return decode(data)
	elif data is Dictionary:
		var result: Dictionary = {}
		for key in data.keys():
			result[key] = decode_json(data[key])
		return result
	elif data is Array:
		var result: Array = []
		for item in data:
			result.append(decode_json(item))
		return result
	return data

## 检查字符串中是否包含标记
static func has_markers(text: String) -> bool:
	for marker in ALL_MARKERS:
		if text.contains(marker):
			return true
	return false

## 在系统提示词中添加特殊字符标记说明
static func get_marker_instruction() -> String:
	return """
## 特殊字符标记（重要）
在工具调用的参数中，使用以下标记代替特殊字符，避免 JSON 转义问题：
- {GOGENT_NEWLINE_CHAR} = 换行符 (\\n)
- {GOGENT_TAB_CHAR} = 制表符 (\\t)
- {GOGENT_DQUOTE_CHAR} = 双引号 (")
- {GOGENT_QUOTE_CHAR} = 单引号 (')
- {GOGENT_BACKSLASH_CHAR} = 反斜杠 (\\)
- {GOGENT_CR_CHAR} = 回车符 (\\r)

例如：写入包含多行文本时：
{"tool":"write_file","args":{"path":"res://script.gd","content":"extends Node{GOGENT_NEWLINE_CHAR}{GOGENT_NEWLINE_CHAR}func _ready():{GOGENT_NEWLINE_CHAR}    print({GOGENT_DQUOTE_CHAR}Hello{GOGENT_DQUOTE_CHAR})"}}
"""
