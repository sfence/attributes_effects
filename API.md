
# Attributes Effects API

## Core Functions

### attributes_effects.register_value_effect(name, effect_def)

Registers a new value effect that can be applied to objects.

**Parameters:**
- `name` (string) - Unique effect name
- `effect_def` (table) - Effect definition with the following callbacks:
  - `cb_is_available(effect_def, object)` - Returns `true` if the effect is available for the given object
  - `cb_get_value(effect_def, object)` - Gets the current value from the object
  - `cb_set_value(effect_def, object, value)` - Sets a new value to the object
  - `cb_calculate_value(effect_def, orig_value, values)` - Calculates the resulting value from modifiers
    - `effect_def` - Self reference
    - `orig_value` - Original value
    - `values` - Array of modifier tables `{value = X, rule = "...", priority = Y}`

**Example:**
```lua
attributes_effects.register_value_effect("hp", {
    cb_is_available = function(effect_def, object)
        return object:is_player() or object:get_luaentity()
    end,
    cb_get_value = function(effect_def, object)
        return object:get_hp()
    end,
    cb_set_value = function(effect_def, object, value)
        object:set_hp(value)
    end,
    cb_calculate_value = attributes_effects.default_calculate_value
})
```

---

### attributes_effects.add_effects_group_to_object(object_guid, label, effects_group)

Adds an effects group to an object (player or entity).

**Parameters:**
- `object_guid` (string) - GUID of the object to apply effects to
- `label` (string or nil) - Optional label for easy group identification
- `effects_group` (table) - Effects group definition:
  - `cb_update(effects_group, object, dtime, cb_add_value)` - Callback called every step
    - Must return `true` to continue or `false` to terminate the group
    - Use `cb_add_value(effect_name, value, rule, priority)` to add modifiers
  - `cb_remove(effects_group, object_guid)` - (Optional) Callback when removing the group

**Return value:**
- `effects_group_id` (number) - ID of the created effects group, or `0` on failure

**Example:**
```lua
local group_id = attributes_effects.add_effects_group_to_object(
    player:get_guid(),
    "poison",
    {
        duration = 10,
        cb_update = function(self, object, dtime, cb_add_value)
            self.duration = self.duration - dtime
            if self.duration <= 0 then
                return false
            end
            cb_add_value("hp", -1, "post_sum", 100)
            attributes_effects.request_object_on_step_update(object:get_guid())
            return true
        end
    }
)
```

---

### attributes_effects.request_object_on_step_update(object_guid, after_time)

Requests an update of the object's effects in the next step.

**Parameters:**
- `object_guid` (string) - Object GUID
- `after_time` (number or nil) - Minimum time until next update (default: dedicated_server_step/2)

---

### attributes_effects.get_effects_group(effects_group_id)

Gets an effects group by ID.

**Parameters:**
- `effects_group_id` (number) - Effects group ID

**Return value:**
- `effects_group` (table or nil) - Effects group table

---

### attributes_effects.get_effects_group_object_guid(effects_group_id)

Gets the GUID of the object to which the effects group belongs.

**Parameters:**
- `effects_group_id` (number) - Effects group ID

**Return value:**
- `object_guid` (string or nil) - Object GUID

---

### attributes_effects.get_effects_group_id(object_guid, label)

Gets the effects group ID by object label.

**Parameters:**
- `object_guid` (string) - Object GUID
- `label` (string) - Effects group label

**Return value:**
- `effects_group_id` (number or nil) - Effects group ID

---

### attributes_effects.remove_effects_group(effects_group_id)

Removes an effects group from an object.

**Parameters:**
- `effects_group_id` (number) - ID of the effects group to remove

**Note:** Automatically calls the `cb_remove` callback if defined.

---

### attributes_effects.remove_object(object_guid)

Removes all effects groups from an object.

**Parameters:**
- `object_guid` (string) - Object GUID

**Note:** Calls `cb_remove` on all groups if the callback is defined.

---

### attributes_effects.object_effects_groups_callback(object_guid, callback_name, ...)

Calls a named callback on all effects groups of an object.

**Parameters:**
- `object_guid` (string) - Object GUID
- `callback_name` (string) - Name of the callback to call
- `...` - Additional parameters passed to the callback

---

### attributes_effects.default_calculate_value(effect_def, orig_value, value_list)

Default function for calculating the final value from modifiers with priority support.

**Parameters:**
- `effect_def` (table) - Effect definition
- `orig_value` (number) - Original value
- `value_list` (table) - Array of modifiers `{value = X, rule = "...", priority = Y}`

**Supported rules:**

#### Priority-based rules (processed by priority):
- `"pre_set"` - Sets value before other modifications (respects priority)
- `"pre_sum"` - Adds value before multiplication
- `"multiply"` - Multiplies the value
- `"post_sum"` - Adds value after multiplication
- `"post_set"` - Sets value after other modifications (respects priority)

#### Final rules (applied at the end regardless of priority):
- `"final_pre_sum"` - Adds before final multiplication
- `"final_pre_sum_min"` - Adds the minimum of all `final_pre_sum_min` values
- `"final_pre_sum_max"` - Adds the maximum of all `final_pre_sum_max` values
- `"final_multiply"` - Multiplies by final value
- `"final_multiply_min"` - Multiplies by the minimum of all `final_multiply_min` values
- `"final_multiply_max"` - Multiplies by the maximum of all `final_multiply_max` values
- `"final_post_sum"` - Adds after final multiplication
- `"final_post_sum_min"` - Adds the minimum of all `final_post_sum_min` values
- `"final_post_sum_max"` - Adds the maximum of all `final_post_sum_max` values
- `"final_clamp_min"` - Clamps result to minimum value
- `"final_clamp_max"` - Clamps result to maximum value

**Calculation order:**
1. Process rules by priority (from lowest to highest)
   - For each priority: pre_set → pre_sum → multiply → post_sum → post_set
2. Apply final rules:
   - final_pre_sum* → final_multiply* → final_post_sum* → final_clamp*

**Return value:**
- `result` (number) - Calculated final value

---

## Data Structures

### attributes_effects.effects
Table of all registered effects, indexed by their names.

### attributes_effects.objects_list
Table of objects with active effects, indexed by GUID:
```lua
{
    [object_guid] = {
        effects_groups = {},           -- Table of effects groups by ID
        effects_groups_by_label = {},  -- Mapping of labels to group IDs
        stored = {},                   -- Stored values for effects
        need_step_update = number,     -- Time until next update
        verbose = boolean              -- Debug mode
    }
}
```

### attributes_effects.effects_groups_list
Reverse mapping of effects group ID to object GUID.