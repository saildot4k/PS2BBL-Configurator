---@meta
---@file intellisense metadata corresponding to the `Pads` library inside `src/lua/controls.cpp`
---@diagnostic disable

---@class Pads
Pads = {}

---@type padbuttons
PAD_LEFT = 0x0080;
---@type padbuttons
PAD_DOWN = 0x0040;
---@type padbuttons
PAD_RIGHT = 0x0020;
---@type padbuttons
PAD_UP = 0x0010;
---@type padbuttons
PAD_START = 0x0008;
---@type padbuttons
PAD_R3 = 0x0004;
---@type padbuttons
PAD_L3 = 0x0002;
---@type padbuttons
PAD_SELECT = 0x0001;
---@type padbuttons
PAD_SQUARE = 0x8000;
---@type padbuttons
PAD_CROSS = 0x4000;
---@type padbuttons
PAD_CIRCLE = 0x2000;
---@type padbuttons
PAD_TRIANGLE = 0x1000;
---@type padbuttons
PAD_R1 = 0x0800;
---@type padbuttons
PAD_L1 = 0x0400;
---@type padbuttons
PAD_R2 = 0x0200;
---@type padbuttons
PAD_L2 = 0x0100;

---@type padtypes
PAD_TYPE_NEJICON = 0x2;
---@type padtypes
PAD_TYPE_KONAMIGUN = 0x3;
---@type padtypes
PAD_TYPE_DIGITAL = 0x4;
---@type padtypes
PAD_TYPE_ANALOG = 0x5;
---@type padtypes
PAD_TYPE_NAMCOGUN = 0x6;
---@type padtypes
PAD_TYPE_DUALSHOCK = 0x7;
---@type padtypes
PAD_TYPE_JOGCON = 0xE;
---@type padtypes
PAD_TYPE_EX_TSURICON = 0x100;
---@type padtypes
PAD_TYPE_EX_JOGCON = 0x300;

--- Gets the currently pressed buttons for a specific port
---@param port integer which port to check
---@return integer ret currently pressed buttons
---@see Pads.check
--- if no parameter passed, port 0 is assumed
---@overload fun():integer
function Pads.get(port) end

---gets the position of the left stick as coordinates
---@param port integer which port to check
---@return integer X the X axis value
---@return integer Y the Y axis value
--- if no parameter passed, port 0 is assumed
---@overload fun(): integer:X, integer:Y
function Pads.getLeftStick() end

---gets the position of the Right stick as coordinates
---@param port integer which port to check
---@return integer X the X axis value
---@return integer Y the Y axis value
--- if no parameter passed, port 0 is assumed
---@overload fun(): integer:X, integer:Y
function Pads.getRightStick() end

---gets what kind of controller is plugged into this port
---@param port integer which port to check
---@return padtypes T
---@see padtypes
--- if no parameter passed, port 0 is assumed
---@overload fun(): padtypes:T
function Pads.getType(port) end

--- checks if the following button(s) is/are pressed
---@param port integer which port to check
---@param pad padbuttons wich buttons to check, you can combine with like this: `PAD_START|PAD_R1`
function Pads.check(port, pad) end
