---@meta

---@class storage
storage = {}

---@class data
---@field extend function
---@field raw table
data = {}

---@class game
---@field players table
---@field set_game_state function
game = {}

---@alias TargetType
---| "entity"
---| "position"
---| "direction"

---@class AmmoType
---@field target_type TargetType

---@class itemPrototype
---@field name? string
---@field type? string
---@field ammo_category table
---@field stack_size? number
---@field fuel_category? string
---@field fuel_value? number
---@field get_ammo_type? function
---@field order? string

itemPrototype = {}

---@class entityPrototype
---@field type? string
---@field indexed_guns? itemPrototype[]
---@field attack_parameters? table

entityPrototype = {}

---@return AmmoType
function itemPrototype.get_ammo_type() end

---@class prototypes
---@field item table<string, itemPrototype>
---@field entity table<string, entityPrototype>

---@class script
script = {}
function script.on_event(event, fn) end
