
attributes_effects.default_calculate_value = function(effect_def, orig_value, value_list)
	local act_value = orig_value
	local highest_set = 0
	local highest_priority = 0
	local final_pre_sum = 0
	local final_pre_sum_min = nil
	local final_pre_sum_max = nil
	local final_post_sum = 0
	local final_post_sum_min = nil
	local final_post_sum_max = nil
	local final_multiply = 1
	local final_multiply_min = nil
	local final_multiply_max = nil
	local final_clamp_min = nil
	local final_clamp_max = nil
	local priorities = {}
	for _, value in ipairs(value_list) do
		local priority = value.priority or 100
		if not priorities[priority] then
			priorities[priority] = {
				pre_set = {},
				pre_sum = {},
				multiply = {},
				post_sum = {},
				post_set = {}
			}
		end
		if value.rule == "pre_set" then
			highest_set = math.max(highest_set, priority)
			table.insert(priorities[priority].pre_set, value)
		elseif value.rule == "pre_sum" then
			table.insert(priorities[priority].pre_sum, value)
		elseif value.rule == "multiply" then
			table.insert(priorities[priority].multiply, value)
		elseif value.rule == "post_sum" then
			table.insert(priorities[priority].post_sum, value)
		elseif value.rule == "post_set" then
			highest_set = math.max(highest_set, priority)
			table.insert(priorities[priority].post_set, value)
		elseif value.rule == "final_pre_sum" then
			final_pre_sum = final_pre_sum + value.value
		elseif value.rule == "final_pre_sum_min" then
			final_pre_sum_min = math.min(final_pre_sum_min or value.value, value.value)
		elseif value.rule == "final_pre_sum_max" then
			final_pre_sum_max = math.max(final_pre_sum_max or value.value, value.value)
		elseif value.rule == "final_post_sum" then
			final_post_sum = final_post_sum + value.value
		elseif value.rule == "final_post_sum_min" then
			final_post_sum_min = math.min(final_post_sum_min or value.value, value.value)
		elseif value.rule == "final_post_sum_max" then
			final_post_sum_max = math.max(final_post_sum_max or value.value, value.value)
		elseif value.rule == "final_multiply" then
			final_multiply = final_multiply * value.value
		elseif value.rule == "final_multiply_min" then
			final_multiply_min = math.min(final_multiply_min or value.value, value.value)
		elseif value.rule == "final_multiply_max" then
			final_multiply_max = math.max(final_multiply_max or value.value, value.value)
		elseif value.rule == "final_clamp_min" then
			final_clamp_min = value.value
		elseif value.rule == "final_clamp_max" then
			final_clamp_max = value.value
		else
			core.log("error", "[attributes_effects] Unknown rule '"..tostring(value.rule).."' in effect calculation!")
		end
		highest_priority = math.max(highest_priority, priority)
	end

	for priority = highest_set, highest_priority do
		local data = priorities[priority]
		if data then
			for _, v in ipairs(data.pre_set) do
				act_value = v.value
			end
			for _, v in ipairs(data.pre_sum) do
				act_value = act_value + v.value
			end
			for _, v in ipairs(data.multiply) do
				act_value = act_value * v.value
			end
			for _, v in ipairs(data.post_sum) do
				act_value = act_value + v.value
			end
			for _, v in ipairs(data.post_set) do
				act_value = v.value
			end
		end
	end

	act_value = act_value + final_pre_sum
	if final_pre_sum_min then
		act_value = act_value + final_pre_sum_min
	end
	if final_pre_sum_max then
		act_value = act_value + final_pre_sum_max
	end
	act_value = act_value * final_multiply
	if final_multiply_min then
		act_value = act_value * final_multiply_min
	end
	if final_multiply_max then
		act_value = act_value * final_multiply_max
	end
	act_value = act_value + final_post_sum
	if final_post_sum_min then
		act_value = act_value + final_post_sum_min
	end
	if final_post_sum_max then
		act_value = act_value + final_post_sum_max
	end
	act_value = math.max(act_value, final_clamp_min or act_value)
	act_value = math.min(act_value, final_clamp_max or act_value)

	return act_value
end