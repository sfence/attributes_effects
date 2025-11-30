-- Debug tool for viewing attributes_effects state

core.register_tool("attributes_effects:debug_tool", {
	description = "Attributes Effects Debug Tool",
	inventory_image = "attributes_effects_debug_tool.png",
	
	on_secondary_use = function(itemstack, user, pointed_thing)
		if not pointed_thing or pointed_thing.type ~= "object" then
			return
		end
		
		local object = pointed_thing.ref
		if not object then
			return
		end
		
		local object_guid = object:get_guid()
		if not object_guid then
			core.chat_send_player(user:get_player_name(), "Object has no GUID")
			return
		end
		
		local object_data = attributes_effects.objects_list[object_guid]
		
		if not object_data then
			core.chat_send_player(user:get_player_name(), "No effects on this object")
			return
		end
		
		-- Enable verbose mode
		object_data.verbose = true
		core.chat_send_player(user:get_player_name(), "Verbose mode enabled for object "..object_guid)
		print("=== Verbose mode enabled for object "..object_guid.." ===")
	end,
	
	on_use = function(itemstack, user, pointed_thing)
		if not pointed_thing or pointed_thing.type ~= "object" then
			return
		end
		
		local object = pointed_thing.ref
		if not object then
			return
		end
		
		local object_guid = object:get_guid()
		if not object_guid then
			core.chat_send_player(user:get_player_name(), "Object has no GUID")
			return
		end
		
		print("=== Attributes Effects Debug for object "..object_guid.." ===")
		
		local object_data = attributes_effects.objects_list[object_guid]
		
		if not object_data then
			print("No effects data for this object")
			core.chat_send_player(user:get_player_name(), "No effects on this object")
			return
		end
		
		-- Print effects groups
		print("Effects groups:")
		for effects_group_id, effects_group in pairs(object_data.effects_groups) do
			print("  Group ID: "..effects_group_id)
		end
		
		-- Print labels
		if next(object_data.effects_groups_by_label) then
			print("Labels:")
			for label, eg_id in pairs(object_data.effects_groups_by_label) do
				print("  "..label.." -> "..eg_id)
			end
		end
		
		-- Print stored and current values for each effect
		if next(object_data.stored) then
			print("Effects:")
			for effect_name, stored_value in pairs(object_data.stored) do
				local effect_def = attributes_effects.effects[effect_name]
				if effect_def then
					local current_value = effect_def:cb_get_value(object)
					print("  Effect: "..effect_name)
					print("    Stored value:  "..tostring(stored_value))
					print("    Current value: "..tostring(current_value))
				else
					print("  Effect: "..effect_name.." (UNKNOWN)")
					print("    Stored value: "..tostring(stored_value))
				end
			end
		else
			core.log("action", "No effects stored")
			print("No effects stored")
		end
		
		print("===========================================")
		
		core.chat_send_player(user:get_player_name(), "Debug info printed to terminal and debug.txt")
	end,
})
