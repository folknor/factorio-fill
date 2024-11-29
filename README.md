# Automated Fuel & Ammo

Automatically inserts your most powerful fuel and ammunition into items placed by the player. \o/

The main feature of the mod is that it works without configuration for both AAI Vehicles (tested with Flame Tumbler and Hauler), all Tankwerkz tanks, and most likely all other mods you can think of.

The second advantage is that it doesn't lag the game when you spam-drop turrets.

The third advantage is that it automatically fills in all ammunition slots (Tankwerkz Goliath tank has 3x weapons), if you have enough ammunition.

The fourth advantage is that if the car/turret/tank/whatever has 2x weapons of type rocket or cannon, it will insert different ammunition in them.

It's made to work automatically with all vehicles, trains, and turrets added by mods.

Personally, I use the mod along with [Just GO!](https://mods.factorio.com/mods/folk/folk-justgo) and [Shuttle Train Lite](https://mods.factorio.com/mod/folk-shuttle).

Please check out [my other addons](https://mods.factorio.com/user/folk) as well!

## How it behaves

The mod exclusively takes from the players main inventory.

For fuel, it will add a full stack of whatever is the most powerful fuel in your inventory. This includes "Small electric pole".

For ammunition, it will add 10% of a stack of ammunition (usually 10 for normal magazines), if it can. If not, it will add 25% of however many you currently have in your inventory (minimum 1). It uses the "best" ammunition from your inventory, according to the order the items are presented in the games normal interface.

## Settings

In the mod settings, there's a few settings per player.

These settings are per-player, and also per-save. You can change them mid-game.

### 1. Ignore ammo and ignore fuel

This is a comma-separated list of items that the mod will ignore. `Ignore ammo` defaults to "capture-robot-rocket, atomic-bomb".

If you want to change this setting, please look up the item identifier for the relevant item - for example "piercing-rounds-magazine" or "rocket-fuel". Don't input quotation marks into the text field.

### 2. Prefer ammo and prefer fuel

Same kind of comma-separated list as `Ignore ammo` and `Ignore fuel`, but item types presented here will be used regardless of whether more powerful items are in your inventory. So for example if you have uranium ammo for yourself in your inventory but want to use piercing rounds in placed turrets, write "piercing-rounds-magazine" here without the quotes.

Items should be listed in prioritized order.

### 3. Ammo stack size %

Tells the mod how many % of a normal stack size you want to insert when you build something.

A standard bullet magazine has a stack size of 100, and the default is 10%, which means the mod will try to insert 10 clips.

If you have one stack or less in your inventory, the mod will insert 25% of whatever you have. So if you have 4 firearm magazines, the mod will insert 1.

### 4. Fuel stack size %

Tells the mod how many % of a normal stack size you want to insert when you build something.

Fuel default is 100%, so a full stack.

If you have one stack or less in your inventory, the mod will insert 50% of whatever you have. So if you have 20 coals, the mod will insert 10.

## Planned features/considerations

Please let me know in the comments section if you have any questions or comments. Thank you!

## Changelog

See changelog.txt or the changelog tab on the factorio mod portal.
