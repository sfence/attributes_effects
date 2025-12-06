
local gstep_data = {
	gstep = 0,
	gtime = nil,
}

attributes_effects.gstep_data = gstep_data

core.register_globalstep(function(dtime)
	gstep_data.gstep = gstep_data.gstep + 1
	if gstep_data.gstep > 2000000000 then
		gstep_data.gstep = 0
	end
	if not gstep_data.gtime then
		gstep_data.gtime = core.get_gametime()
	end
	gstep_data.gtime = gstep_data.gtime + dtime

	-- Iterate through all objects with effects
	for object_guid, object_data in pairs(attributes_effects.objects_list) do
		if object_data.need_step_update > 0 
				and object_data.need_step_update <= dtime then
			object_data.need_step_update = 0

			local verbose = object_data.verbose

			if verbose then
				print("=== Processing object "..object_guid.." (verbose mode) ===")
				print("  dtime: "..dtime)
			end

			local apply_effects = {}
			local cb_add_value = function(obj, effect_name, value)
				if type(value) ~= "table" then
					core.log("error", "[attributes_effects] Value must be a table!")
					return
				end
				local effect_def = attributes_effects.effects[effect_name]
				if not effect_def then
					core.log("warning", "[attributes_effects] Unknown effect '"..tostring(effect_name).."' in cb_add_value!")
					return
				end
				if not effect_def.cb_is_available(effect_def, obj) then
					core.log("info", "[attributes_effects] Effect '"..effect_name.."' is not available for object "..obj:get_guid().."!")
					return
				end
				if not apply_effects[effect_name] then
					apply_effects[effect_name] = {}
				end
				table.insert(apply_effects[effect_name], value)
				if verbose then
					print("  cb_add_value: effect="..effect_name..", value="..dump(value))
				end
			end

			local object = core.objects_by_guid[object_guid]
			if object and object:is_valid() then
				if verbose then
					print("  Processing effects groups:")
				end

				local have_effects_group = false
				for effects_group_id, effects_group in pairs(object_data.effects_groups) do
					if verbose then
						print("    Group ID: "..effects_group_id)
					end
					if not effects_group:cb_update(object, dtime, cb_add_value) then
						if verbose then
							print("    Removing effects group "..effects_group_id)
						end
						attributes_effects.remove_effects_group(effects_group_id)
					else
						have_effects_group = true
					end
				end

				if verbose then
					print("  Applying effects:")
				end

				for effect_name, values in pairs(apply_effects) do
					local effect_def = attributes_effects.effects[effect_name]

					if object_data.stored[effect_name] == nil then
						object_data.stored[effect_name] = effect_def:cb_get_value(object)
						if verbose then
							print("    Stored original value for "..effect_name..": "..object_data.stored[effect_name])
						end
					end
					local orig_value = object_data.stored[effect_name]
					local calc_value = effect_def:cb_calculate_value(orig_value, values)
					effect_def:cb_set_value(object, calc_value)

					if verbose then
						print("    Effect "..effect_name..": orig="..orig_value..", calc="..calc_value)
					end

					if effect_def.cb_on_apply then
						effect_def:cb_on_apply(object_data, object, calc_value)
					end
				end

				-- check stored values, and apply restore if there is no effect added
				for effect_name, stored_value in pairs(object_data.stored) do
					if not apply_effects[effect_name] then
						if verbose then
							print("  Restoring effect "..effect_name)
						end
						local effect_def = attributes_effects.effects[effect_name]
						effect_def.cb_set_value(effect_def, object, stored_value)
						object_data.stored[effect_name] = nil
					end
				end

				-- if no active effects groups, remove object data
				if not have_effects_group then
					if verbose then
						print("  No more effects groups, removing object data")
					end
					attributes_effects.remove_object(object_guid)
				end

				-- Disable verbose after one step
				if verbose then
					print("=== End of verbose step ===")
					object_data.verbose = false
				end
			else
				if verbose then
					print("  Object not found, removing object data")
				end
				attributes_effects.remove_object(object_guid)
			end
		elseif object_data.need_step_update > dtime then
			object_data.need_step_update = object_data.need_step_update - dtime
		end
	end
end)