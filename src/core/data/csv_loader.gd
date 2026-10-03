class_name CsvLoader
extends RefCounted
## Minimal, robust CSV reader (handles quoted fields with commas/newlines).
## Returns an Array of Dictionaries: { header: Array[String], rows: Array[Dictionary] }.
## Each row Dictionary maps column name -> String value.

static func parse(text: String) -> Dictionary:
	var lines := _split_lines(text)
	if lines.is_empty():
		return { "header": [], "rows": [] }
	var header: Array = _split_csv_line(lines[0])
	var rows: Array = []
	for i in range(1, lines.size()):
		var cells: Array = _split_csv_line(lines[i])
		if cells.is_empty():
			continue
		var row: Dictionary = {}
		for j in range(header.size()):
			row[header[j]] = cells[j] if j < cells.size() else ""
		rows.append(row)
	return { "header": header, "rows": rows }

# Split a CSV file into logical lines, honoring quoted fields that contain newlines.
static func _split_lines(text: String) -> Array:
	var lines: Array = []
	var cur := ""
	var in_quotes := false
	var i := 0
	while i < text.length():
		var c := text[i]
		if c == '"':
			in_quotes = not in_quotes
			cur += c
		elif c == "\n" and not in_quotes:
			lines.append(cur)
			cur = ""
		else:
			cur += c
		i += 1
	if cur != "":
		lines.append(cur)
	return lines

# Split one CSV line into cells, honoring double-quoted fields.
static func _split_csv_line(line: String) -> Array:
	var cells: Array = []
	var cur := ""
	var in_quotes := false
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == '"':
			in_quotes = not in_quotes
		elif c == "," and not in_quotes:
			cells.append(cur)
			cur = ""
		else:
			cur += c
		i += 1
	cells.append(cur)
	return cells
