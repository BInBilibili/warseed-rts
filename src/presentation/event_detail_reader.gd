class_name EventDetailReader
extends RefCounted

static func first_value(detail: String, key: String) -> String:
	var prefix := key + "="
	var start := detail.find(prefix)
	while start >= 0:
		if start == 0 or detail.unicode_at(start-1) == 59:
			var value_start := start + prefix.length()
			var end := detail.find(";",value_start)
			return detail.substr(value_start) if end < 0 else detail.substr(value_start,end-value_start)
		start = detail.find(prefix,start+1)
	return ""
