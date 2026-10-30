class_name DialogueParser

static func parse_text(text: String) -> Dictionary:
	var parsed_data := {"characters": {}}
	var current_branch := ""
	var current_node := ""
	var in_choice := false
	
	for raw_line in text.split("\n"):
		var stripped = raw_line.strip_edges()
		if stripped == "" or stripped.begins_with("|"):
			continue
			
		if stripped.begins_with("char "):
			var parts = stripped.split(" ", false)
			if parts.size() >= 3:
				parsed_data["characters"][parts[1]] = " ".join(parts.slice(2))
			continue
			
		if stripped.begins_with("branch "):
			current_branch = stripped.replace("branch ", "").strip_edges()
			parsed_data[current_branch] = {}
			in_choice = false
			continue
		elif stripped.begins_with("node "):
			current_node = stripped.replace("node ", "").strip_edges()
			parsed_data[current_branch][current_node] = []
			in_choice = false
			continue
			
		if current_branch == "" or current_node == "": continue
		
		var cmd_list: Array = parsed_data[current_branch][current_node]
		
		if in_choice:
			var regex = RegEx.new()
			regex.compile("^(\\d+):\\s*(.*)$")
			var m = regex.search(stripped)
			if m:
				var opt_idx = int(m.get_string(1))
				var opt_text = m.get_string(2).strip_edges()
				# 【P3】choice 节点必须存在，否则说明剧本结构错乱
				if cmd_list.is_empty() or cmd_list[-1]["type"] != "choice":
					push_error("⚠️ [VN_Parser] 选项行没有前置 choice 指令: %s" % stripped)
					continue
				cmd_list[-1]["options"].append({"id": str(opt_idx), "text": opt_text, "goto": {"b": "", "n": ""}})
				continue
			elif stripped.begins_with("goto "):
				# 【P3】三重保护：无前置 choice / options 为空 / goto 参数不足
				if cmd_list.is_empty() or cmd_list[-1]["type"] != "choice":
					push_error("⚠️ [VN_Parser] goto 没有前置 choice 指令，已忽略: %s" % stripped)
					continue
				if cmd_list[-1]["options"].is_empty():
					push_error("⚠️ [VN_Parser] goto 没有前置选项，已忽略: %s" % stripped)
					continue
				var goto_params = stripped.replace("goto ", "").strip_edges().split(" ", false)
				if goto_params.size() < 2:
					push_error("⚠️ [VN_Parser] goto 参数不足（需要 branch node）: %s" % stripped)
					continue
				cmd_list[-1]["options"][-1]["goto"] = {"b": goto_params[0], "n": goto_params[1]}
				continue
			else:
				in_choice = false
				
		if stripped == "choice":
			in_choice = true
			cmd_list.append({"type": "choice", "options": []})
			continue
			
		if stripped == "end":
			cmd_list.append({"type": "end"})
			continue
			
		if stripped.begins_with("narrate "):
			cmd_list.append({"type": "narrate", "text": stripped.replace("narrate ", "")})
			continue
			
		if stripped.begins_with("title "):
			cmd_list.append({"type": "title", "text": stripped.replace("title ", "")})
			continue
			
		if stripped.begins_with("tip "):
			cmd_list.append({"type": "tip", "text": stripped.replace("tip ", "")})
			continue
			
		if stripped.begins_with("hide "):
			cmd_list.append({"type": "hide", "val": int(stripped.replace("hide ", ""))})
			continue
			
		if stripped.begins_with("whiteout "):
			cmd_list.append({"type": "whiteout", "val": stripped.replace("whiteout ", "").strip_edges()}) 
			continue
			
		if stripped.begins_with("pause "):
			cmd_list.append({"type": "pause", "val": float(stripped.replace("pause ", ""))})
			continue
			
		# 核心：角色演出极简语法解析
		var first_space = stripped.find(" ")
		var char_id = stripped if first_space == -1 else stripped.substr(0, first_space)
		
		if parsed_data["characters"].has(char_id):
			var action_str = "" if first_space == -1 else stripped.substr(first_space).strip_edges()
			var dialogue_text = ""
			
			var quote_idx = action_str.find("「")
			if quote_idx != -1:
				dialogue_text = action_str.substr(quote_idx)
				action_str = action_str.substr(0, quote_idx).strip_edges()
				
			var pos_target = -1
			var is_move = false
			var emotion = ""
			var is_remove = false
			
			if action_str != "":
				var tokens = action_str.split(" ", false)
				for t in tokens:
					if t == "_":
						is_remove = true
					elif t.is_valid_int():
						pos_target = int(t)
						is_move = true # 直接写数字代表平滑移动
					else:
						emotion = t
						
			cmd_list.append({
				"type": "char_action",
				"char_id": char_id,
				"pos_target": pos_target,
				"is_move": is_move,
				"emotion": emotion,
				"text": dialogue_text,
				"is_remove": is_remove
			})
			continue
			
	return parsed_data
