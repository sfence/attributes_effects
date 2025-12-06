
attributes_effects.effects = {}

attributes_effects.objects_list = {}
attributes_effects.effects_groups_list = {}

local dedicated_server_step = tonumber(core.settings:get("dedicated_server_step") or "0.09")/2

local next_effects_group_id = 1

attributes_effects.register_value_effect = function(name, effect_def)
	attributes_effects.effects[name] = effect_def
end

--[[ effect example
{

	cb_select_value = function(value_list) return math.min(unpack(value_list)) end,
	cb_calculate = function(obj, effect_data)
		return effect_data.value
	end,
	cb_apply = function(obj, selected_value)
		-- apply effect on each step
	end,
	cb_restore = function(obj, stored_value)
		-- restore effect on removal
	end,

}
--]]

attributes_effects.add_effects_group_to_object = function(object_guid, label, effects_group)
	local object = core.objects_by_guid[object_guid]
	if not object then
		return 0
	end
	if label then
		local object_data = attributes_effects.objects_list[object_guid]
		if object_data and object_data.effects_groups_by_label[label] then
			core.log("error", "[attributes_effects] Effects group with label "..label.." already exists on object "..object_guid)
			return 0
		end
	end
	if not attributes_effects.objects_list[object_guid] then
		attributes_effects.objects_list[object_guid] = {
			effects_groups = {
			},
			effects_groups_by_label = {
			},
			stored = {
			},
			need_step_update = dedicated_server_step,
			verbose = false,
		}
	end
	local effects_group_id = next_effects_group_id
	next_effects_group_id = next_effects_group_id + 1

	attributes_effects.objects_list[object_guid].effects_groups[effects_group_id] = effects_group
	attributes_effects.objects_list[object_guid].need_step_update = dedicated_server_step
	if label then
		attributes_effects.objects_list[object_guid].effects_groups_by_label[label] = effects_group_id
	end
	attributes_effects.effects_groups_list[effects_group_id] = object_guid

	core.log("action", "[attributes_effects] Added effects group "..effects_group_id.." with label "..tostring(label).." to object "..object_guid)

	return effects_group_id
end

function attributes_effects.request_object_on_step_update(object_guid, after_time)
	after_time = after_time or dedicated_server_step
	local object_data = attributes_effects.objects_list[object_guid]
	if object_data then
		if object_data.need_step_update == 0 or after_time < object_data.need_step_update then
			object_data.need_step_update = after_time
		end
	end
end

function attributes_effects.get_effects_group(effects_group_id)
	local object_guid = attributes_effects.effects_groups_list[effects_group_id]
	if not object_guid then
		return nil
	end
	return attributes_effects.objects_list[object_guid].effects_groups[effects_group_id]
end

function attributes_effects.get_effects_group_object_guid(effects_group_id)
	return attributes_effects.effects_groups_list[effects_group_id]
end

function attributes_effects.get_effects_group_id(object_guid, label)
	local object_data = attributes_effects.objects_list[object_guid]
	if not object_data then
		return nil
	end
	return object_data.effects_groups_by_label[label]
end

attributes_effects.remove_effects_group = function(effects_group_id)
	local object_guid = attributes_effects.effects_groups_list[effects_group_id]
	if not object_guid then
		return
	end
	attributes_effects.effects_groups_list[effects_group_id] = nil

	local object_data = attributes_effects.objects_list[object_guid]
	if not object_data then
		return
	end
	if object_data.effects_groups[effects_group_id] then
		if object_data.effects_groups[effects_group_id].cb_remove then
			object_data.effects_groups[effects_group_id]:cb_remove(object_guid)
		end
	end
	object_data.effects_groups[effects_group_id] = nil
	local log_label
	for label, eg_id in pairs(object_data.effects_groups_by_label) do
		if eg_id == effects_group_id then
			log_label = label
			object_data.effects_groups_by_label[label] = nil
			break
		end
	end
	core.log("action", "[attributes_effects] Removed effects group "..effects_group_id.." with label "..tostring(log_label).." from object "..object_guid)
	--error("Effects group removal failed")
end

attributes_effects.remove_object = function(object_guid)
	local object_data = attributes_effects.objects_list[object_guid]
	if not object_data then
		return
	end
	for effects_group_id, effects_group in pairs(object_data.effects_groups) do
		if effects_group.cb_remove then
			effects_group:cb_remove(object_guid)
		end
		attributes_effects.effects_groups_list[effects_group_id] = nil
	end
	attributes_effects.objects_list[object_guid] = nil
	core.log("action", "[attributes_effects] Removed all effects groups from object "..object_guid)
end

function attributes_effects.set_object_verbose(object_guid)
	local object_data = attributes_effects.objects_list[object_guid]
	if not object_data then
		return
	end
	object_data.verbose = true
end

function attributes_effects.get_object_verbose(object_guid)
	local object_data = attributes_effects.objects_list[object_guid]
	if not object_data then
		return false
	end
	return object_data.verbose
end

attributes_effects.object_effects_groups_callback = function(object_guid, callback_name, ...)
	local object_data = attributes_effects.objects_list[object_guid]
	if not object_data then
		return
	end
	for effects_group_id, effects_group in pairs(object_data.effects_groups) do
		local cb = effects_group[callback_name]
		if cb then
			cb(effects_group, ...)
		end
	end
end