
# Attributes Effects API

`attributes_effects` is a general-purpose framework for managing temporary and permanent modifications to object attributes in Luanti/Minetest. It provides a flexible system for applying, combining, and removing effects on any object property (players, entities, etc.).

The system is **not limited to combat** - it can be used for any attribute modification such as:
- Movement speed, jump height, physics overrides
- Visual effects (fog, vision range, lighting)
- Entity behaviors (AI parameters, animation speeds)
- Custom game mechanics (resource regeneration, skill modifiers)

## Core Functions

### attributes_effects.register_value_effect(name, effect_def)

Registers a new value effect that can be applied to objects. This defines **what** can be modified and **how** to read/write the attribute.

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
  - `cb_on_apply(effect_def, object_data, object, calc_value)` - (Optional) Called after the effect value is applied
    - `effect_def` - Self reference
    - `object_data` - Internal object data structure
    - `object` - The object reference
    - `calc_value` - The calculated value that was applied

**Example:**
```lua
-- Example 1: Simple numeric attribute (player speed multiplier)
attributes_effects.register_value_effect("player:speed", {
    cb_is_available = function(effect_def, object)
        return object:is_player()
    end,
    cb_get_value = function(effect_def, object)
        return 1.0  -- Default speed multiplier
    end,
    cb_set_value = function(effect_def, object, value)
        local physics = object:get_physics_override()
        physics.speed = value
        object:set_physics_override(physics)
    end,
    cb_calculate_value = attributes_effects.default_calculate_value
})

-- Example 2: Entity attribute (mob walk velocity)
attributes_effects.register_value_effect("mob:walk_velocity", {
    cb_is_available = function(effect_def, object)
        local luaent = object:get_luaentity()
        return luaent and luaent.walk_velocity ~= nil
    end,
    cb_get_value = function(effect_def, object)
        return object:get_luaentity().walk_velocity
    end,
    cb_set_value = function(effect_def, object, value)
        local luaent = object:get_luaentity()
        if luaent then
            luaent.walk_velocity = value
        end
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
    - Use `cb_add_value(object, effect_name, value_table)` to add modifiers
      - `object` - The object reference
      - `effect_name` - Name of the effect to modify
      - `value_table` - Table with fields: `{value = X, rule = "...", priority = Y}`
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
            cb_add_value(object, "hp", {value = -1, rule = "post_sum", priority = 100})
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

### attributes_effects.set_object_verbose(object_guid)

Enables verbose/debug mode for an object. When enabled, detailed debug information about effects processing will be printed to the console/log.

**Parameters:**
- `object_guid` (string) - Object GUID

**Note:** Verbose mode is automatically disabled after one step.

---

### attributes_effects.get_object_verbose(object_guid)

Gets the verbose/debug mode status for an object.

**Parameters:**
- `object_guid` (string) - Object GUID

**Return value:**
- `verbose` (boolean) - `true` if verbose mode is enabled, `false` otherwise

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

### attributes_effects.gstep_data
Global step tracking data:
```lua
{
    gstep = number,  -- Current global step counter (resets at 2,000,000,000)
    gtime = number   -- Accumulated game time
}
```

---
