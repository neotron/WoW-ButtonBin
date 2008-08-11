--[[
**********************************************************************
ButtonBin - A displayer for LibDataBroker compatible addons
**********************************************************************
Code inspired by and copied from Fortress by Borlox
**********************************************************************
]]
ButtonBin = LibStub("AceAddon-3.0"):NewAddon("ButtonBin", "AceConsole-3.0") -- , "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")

-- Silently fail embedding if it doesn't exist
local LibStub = LibStub
LDB = LibStub:GetLibrary("LibDataBroker-1.1")

local BB_DEBUG = false

local C = LibStub("AceConfigDialog-3.0")
local DBOpt = LibStub("AceDBOptions-3.0")
local mod = ButtonBin

local fmt = string.format
local tinsert = table.insert
local tsort   = table.sort
local tconcat = table.concat
local tremove = table.remove
local type = type
local pairs = pairs
local ipairs = ipairs
local tostring = tostring 
local unpack = unpack
local lower = string.lower

local bins = {}
local ldbObjects = {}
local buttonFrames = {}
local options
local db

local unlockButtons = false
local unlockFrames = false

function mod.clear(tbl)
   if type(tbl) == "table" then
      for id,data in pairs(tbl) do
	 if type(data) == "table" then mod.del(data) end
	 tbl[id] = nil
      end
   end
end   
   

function mod.get()
   return tremove(tableStore) or {}
end

function mod.del(tbl, index)
   local todel = tbl
   if index then todel = tbl[index] end
   if type(todel) ~= "table" then return end
   mod.clear(todel)
   tinsert(tableStore, todel)
   if index then tbl[index] = nil end
end

local defaults = {
   profile = {
      -- TBD
      enabledDataObjects = {
	 ['*'] = {
	    enabled = true
	 },
      },
      bins = {
	 ['*'] = {
	    collapsed = false,
	    size = 24,
	    scale = 1.0,
	    width  = 10,
	    flipx = false,
	    flipy = false,
	    hideEmpty = true,
	    hpadding = 0.5,
	    vpadding = 0.5,
	    sortedButtons = {},
	    newlyAdded = true,
	    hidden = true
	 }
      },
   }
}


local GameTooltip = GameTooltip
local function GT_OnLeave(self)
   self:SetScript("OnLeave", self.oldOnLeave)
   self.oldOnLeave = nil
   self:Hide()
   GameTooltip:EnableMouse(false)
end

local function getAnchors(frame)
   local x, y = frame:GetCenter()
   local leftRight
   if x < GetScreenWidth() / 2 then
      leftRight = "LEFT"
   else
      leftRight = "RIGHT"
   end
   if y < GetScreenHeight() / 2 then
      return "BOTTOM", "TOP"
   else
      return "TOP", "BOTTOM"
   end
end

local function PrepareTooltip(frame, anchorFrame, isGameTooltip)
   if frame == GameTooltip then
      frame.oldOnLeave = frame:GetScript("OnLeave")
      frame:EnableMouse(true)
      frame:SetScript("OnLeave", GT_OnLeave)
   end
   frame:SetOwner(anchorFrame, "ANCHOR_NONE")
   frame:ClearAllPoints()
   local a1, a2 = getAnchors(anchorFrame)
   frame:SetPoint(a1, anchorFrame, a2)	
end

local function BB_OnClick(clickedFrame, button)
   if button == "LeftButton" then
      if IsAltKeyDown() then
	 mod:ToggleButtonLock()
      else
	 mod:ToggleCollapsed(clickedFrame)
      end
   elseif button == "MiddleButton" then
      mod:ToggleLocked()
   elseif button == "RightButton" then
      mod:ToggleConfigDialog()
   end
end

local function LDB_OnEnter(self, now)
   local obj = self.obj
   if obj.tooltip then
      PrepareTooltip(obj.tooltip, self)
      obj.tooltip:Show()
      if obj.tooltiptext then
	 obj.tooltip:SetText(obj.tooltiptext)
      end
   elseif obj.OnTooltipShow then
      PrepareTooltip(GameTooltip, self, true)
      obj.OnTooltipShow(GameTooltip)
      GameTooltip:Show()
   elseif obj.tooltiptext then
      PrepareTooltip(GameTooltip, self, true)
      GameTooltip:SetText(obj.tooltiptext)
      GameTooltip:Show()
   elseif self.buttonBinText and not obj.OnEnter then
      PrepareTooltip(GameTooltip, self, true)
      GameTooltip:SetText(self.buttonBinText)
      GameTooltip:Show()
      self.hideTooltipOnLeave = true
   end
   if obj.OnEnter then
      obj.OnEnter(self)
   end
--   resizeBin(buttonBin)
end

local function LDB_OnLeave(self)
   local obj = self.obj
   if not obj then return end
   if MouseIsOver(GameTooltip) and (obj.tooltiptext or obj.OnTooltipShow) then return end	

   if self.hideTooltipOnLeave or obj.tooltiptext or obj.OnTooltipShow then
      GT_OnLeave(GameTooltip)
      self.hideTooltipOnLeave = nil
   end
   if obj.OnLeave then
      obj.OnLeave(self)
   end
end

function mod:OnInitialize()
   self.db = LibStub("AceDB-3.0"):New("ButtonBinDB", defaults, "Default")
   self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
   self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
   self.db.RegisterCallback(self, "OnProfileDeleted","OnProfileChanged")
   self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
   db = self.db.profile

   options.profile = DBOpt:GetOptionsTable(self.db)

   if db.size or db.scale or db.posx then
      -- Create a new bin based on the old stored data
      for id,name in pairs(db.sortedButtons) do
	 if name == "ButtonBin" then
	    tremove(db.sortedButtons, id)
	    break
	 end
      end
      db.bins[1] =  {
	 collapsed = db.collapsed,
	 size = db.size, 
	 scale = db.scale,
	 posx = db.posx,
	 posy = db.posy,
	 anchor = db.anchor,
	 width = db.width, 
	 flipx = db.flipx, 
	 flipy = db.flipy, 
	 hideEmpty = db.hideEmpty, 
	 hpadding = db.hpadding, 
	 vpadding = db.vpadding, 
	 sortedButtons = db.sortedButtons,
      }
      -- Reset old data
      db.posx = nil db.posy = nil db.anchor = nil
      db.collapsed = nil db.size = nil
      db.scale = nil     db.width = nil
      db.flipx = nil     db.flipy = nil
      db.hideEmpty = nil db.hpadding = nil
      db.vpadding = nil  db.sortedButtons = nil
   end

   -- Initialize 5 bins, hiding all but the first
   for id=1,5 do
      local bin = db.bins[id]
      if bin.newlyAdded then
	 if id == 1 then bin.hidden = false end
	 bin.newlyAdded = false
      end
   end

   local bgFrame = {
      bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 6,
      insets = {left = 1, right = 1, top = 1, bottom = 1}
   }
   local tooltip = "Button Bin %d\n"..
      "|cffffff00Left click|r to collapse/uncollapse all other icons.\n"..
      "|cffffff00Alt-Left click|r to toggle the button lock.\n"..
      "|cffffff00Middle click|r to toggle the Button Bin window lock.\n"..
      "|cffffff00Right click|r to open the Button Bin configuration.\n"

   for id,bdb in pairs(db.bins) do
      local f = CreateFrame("Frame", "ButtonBinParent", UIParent)
      local bdb = db.bins[id]
      bins[id] = f
      f.binId = id
      f:EnableMouse(true)
      f:SetClampedToScreen(true)
      f:SetWidth(300)
      f:SetHeight(bdb.size)
      f:SetScale(bdb.scale)
      f.mover = CreateFrame("Button", "ButtonBinMover", UIParent)
      f.mover:EnableMouse(true)
      f.mover:SetMovable(true)
      f.mover:SetBackdrop(bgFrame)
      f.mover:SetBackdropColor(0, 1, 0);
      f.mover:SetClampedToScreen(true)
      f.mover:RegisterForClicks("AnyUp")
      f.mover:SetFrameStrata("HIGH")
      f.mover:SetFrameLevel(5)
      f.mover:SetAlpha(0.5)
      f.mover:SetScript("OnDragStart",
			       function() f.mover:StartMoving() end)
      f.mover:SetScript("OnDragStop",
			       function()
				  mod:SavePosition(f)
				  f.mover:StopMovingOrSizing() end)
      f.mover:SetScript("OnClick",
			       function(frame,button)
				  mod:ToggleLocked()
			       end)
      f.mover.text = CreateFrame("Frame")
      f.mover.text:SetPoint("BOTTOMLEFT", f.mover, "TOPLEFT")   
      f.mover.text:SetPoint("BOTTOMRIGHT", f.mover, "TOPRIGHT")
      f.mover.text:SetHeight(30)
      f.mover.text:SetFrameStrata("DIALOG")
      f.mover.text:SetFrameLevel(10)
      
      f.mover.text.label = f.mover.text:CreateFontString(nil, nil, "GameFontNormal")
      f.mover.text.label:SetJustifyH("CENTER")
      f.mover.text.label:SetPoint("BOTTOM")
      f.mover.text.label:SetText("Click to stop moving")
      f.mover.text.label:SetNonSpaceWrap(true)
      f.mover.text:SetAlpha(1)

      f.button = self:GetFrame()
      f.button:SetParent(f)
      f.button:SetScript("OnClick", BB_OnClick)
      f.button:SetScript("OnEnter", LDB_OnEnter)
      f.button:SetScript("OnLeave", LDB_OnLeave)
      f.button.icon:SetTexture("Interface\\AddOns\\ButtonBin\\bin.tga")
      f.button.db = { bin = id, tooltiptext = tooltip:format(id) }
      f.button.obj = f.button.db
      f.button.name = "ButtonBin"
      if bdb.hidden then f:Hide() else f:Show() end
      f.mover:Hide()
      f.mover.text:Hide()
   end
   
   mod:SetupOptions()
   
   
   if BB_DEBUG then
      -- Just for easy access while debugging
      bbdb = db
      bns = bins
      bf = buttonFrames
   end
end

function mod:LibDataBroker_DataObjectCreated(event, name, obj)
   ldbObjects[name] = obj
   if db.enabledDataObjects[name].enabled then
      mod:EnableDataObject(name, obj)
      local bdb = db.bins[buttonFrames[name].db.bin]
      for _,bname in ipairs(bdb.sortedButtons) do
	 if name == bname then
	    return
	 end
      end
      bdb.sortedButtons[#bdb.sortedButtons+1] = name
   end
end

local updaters = {
   text = function(frame, value, name, object)
	     local text
	     if type(object.label) == "string" then
		if object.value and (type(object.value) == "string" or type(object.value) == "number") then
		   text = fmt("|cffffffff%s:|r %s|cffffffff%s|r", object.label, object.value, ((type(object.suffix) == "string" or type(object.suffix) == "number") and object.suffix) or "")
		elseif object.text and object.text ~= object.label and string.find(object.text, "%S") then
		   text = fmt("|cffffffff%s:|r %s", object.label, object.text)
		else
		   text = fmt("|cffffffff%s|r", object.label)
		end
	     elseif object.value and (type(object.value) == "string" or type(object.value) == "number") then
		text = fmt("%s|cffffffff%s|r", object.value, ((type(object.suffix) == "string" or type(object.suffix) == "number") and object.suffix) or "")
	     elseif object.text then
		text = object.text
	     elseif object.type and object.type == "launcher" then
		local addonName, title = GetAddOnInfo(object.tocname or name)
		text = fmt("|cffffffff%s|r", title or addonName or name)
	     end
	     frame.buttonBinText = text
--	     if text then
--		frame.label:SetText(text)
--		frame.label:Show()
--	     else
		frame.label:Hide()
--	     end
	  end,	
   icon = function(frame, value, name)
	     frame.icon:SetTexture(value)
	     local has_texture = not not value
	     if has_texture ~= frame._has_texture then
		frame._has_texture = has_texture
		mod:SortFrames(frame:GetParent())
	     end
	  end,
   OnClick = function(frame, value)
		frame:SetScript("OnClick", value)
	     end,
   tooltiptext = function(frame, value, name, object)
		    local tt = object.tooltip or GameTooltip
		    if tt:GetOwner() == frame then
		       tt:SetText(object.tooltiptext)
		    end
		 end,
}

function mod:AttributeChanged(event, name, key, value)
   if not db.enabledDataObjects[name].enabled then return end
   local f = buttonFrames[name]
   local obj = ldbObjects[name]
   obj[key] = value
   if f and obj and updaters[key] then
      updaters[key](f, value, name, obj)     
   end   
end

function mod:EnableDataObject(name, obj)
   db.enabledDataObjects[name].enabled = true
   -- create frame for object
   local frame = buttonFrames[name] or mod:GetFrame()
   buttonFrames[name] = frame
   frame.db = db.enabledDataObjects[name]
   frame.name = name
   frame.obj = obj
   if not frame.db.bin then
      frame.db.bin = 1
   end
   frame:SetParent(bins[frame.db.bin])
   frame:SetScript("OnEnter", LDB_OnEnter)
   frame:SetScript("OnLeave", LDB_OnLeave)
   
   for key, func in pairs(updaters) do
      func(frame, obj[key], name, obj) 
   end	

   LDB.RegisterCallback(self, "LibDataBroker_AttributeChanged_"..name, "AttributeChanged")

   mod:SortFrames(frame:GetParent())
end

function mod:DisableDataObject(name, obj)
   db.enabledDataObjects[name].enabled = false
   LDB.UnregisterCallback(self, "LibDataBroker_AttributeChanged_"..name)
   if buttonFrames[name] then
      self:ReleaseFrame(buttonFrames[name])
   end
end

function mod:OnEnable()
   self:ApplyProfile()
   if self.SetLogLevel then
      self:SetLogLevel(self.logLevels.TRACE)
   end
   for name, obj in LDB:DataObjectIterator() do
      self:LibDataBroker_DataObjectCreated(nil, name, obj)
   end
   LDB.RegisterCallback(self, "LibDataBroker_DataObjectCreated")
   for _,bin in ipairs(bins) do
      self:SortFrames(bin)
   end
end

function mod:OnDisable()
   LDB.UnregisterAllCallbacks(self)

   for _,bin in ipairs(bins) do
      bin:Hide()
   end
end

function mod:PLAYER_REGEN_ENABLED()
end

function mod:PLAYER_REGEN_DISABLED()
end

function mod:ApplyProfile()
   for _,bin in ipairs(bins) do
      if bin.mover:IsVisible() then
	 mod:ToggleLocked()
      end
      bin:ClearAllPoints()
      self:SortFrames(bin) -- will handle any size changes etc
      mod:LoadPosition(bin)
   end
end

function mod:SavePosition(bin)
   local s = bin:GetEffectiveScale()
   local bdb = db.bins[bin.binId]
   if bdb.flipy then
      bdb.posy = bin:GetBottom() * s
      bdb.anchor = "BOTTOM"
   else
      bdb.posy =  bin:GetTop() * s - UIParent:GetHeight()*UIParent:GetEffectiveScale() 
      bdb.anchor = "TOP"
   end
   if bdb.flipx then
      bdb.anchor = bdb.anchor .. "RIGHT"
      bdb.posx = bin:GetRight() * s - UIParent:GetWidth()*UIParent:GetEffectiveScale() 
   else
      bdb.anchor = bdb.anchor .. "LEFT"
      bdb.posx = bin:GetLeft() * s
   end
end

function mod:LoadPosition(bin)
   local bdb = db.bins[bin.binId]
   local posx = bdb.posx 
   local posy = bdb.posy

   local anchor = bdb.anchor
   bin:ClearAllPoints()
   if not anchor then  anchor = "TOPLEFT" end
   local s = bin:GetEffectiveScale()
   if posx and posy then
      bin:SetPoint(anchor, posx/s, posy/s)
   else
      bin:SetPoint(anchor, UIParent, "CENTER")
   end
end

function mod:OnProfileChanged(event, newdb)
   if event ~= "OnProfileDeleted" then
      db = self.db.profile
      if not db.colors then db.colors = colors end -- set default if needed
      self:ApplyProfile()
   end
end

function mod:ToggleLocked()
   for id,bin in ipairs(bins) do 
      if unlockFrames then
	 local s = bin:GetEffectiveScale()
	 bin.mover:RegisterForDrag()
	 bin.mover:Hide()
	 bin.mover.text:Hide()
	 mod:LoadPosition(bin)
	 if db.bins[id].hidden then
	    bin:Hide()
	 end
      else
	 bin.mover:ClearAllPoints()
	 bin.mover:SetWidth(bin:GetWidth())
	 bin.mover:SetHeight(bin:GetHeight())
	 bin.mover:SetScale(bin:GetScale())
	 bin.mover:SetPoint(bin:GetPoint())
	 bin.mover:RegisterForDrag("LeftButton")
	 bin:ClearAllPoints()
	 bin:SetPoint("TOPLEFT", bin.mover)
	 bin.mover:Show()
	 bin.mover.text:Show()
	 bin:Show()
      end
   end
   unlockFrames = not unlockFrames
end

function mod:ToggleButtonLock()
   unlockButtons = not unlockButtons
   
   local dragButton
   if unlockButtons then dragButton = "LeftButton" end
      if unlockButtons then
	 mod:Print("Button positions are now unlocked.")
      else
	 mod:Print("Locking button positions.")
      end
   for name,frame in pairs(buttonFrames) do
      frame:RegisterForDrag(dragButton)
      frame:SetMovable(unlockButtons)
      if unlockButtons then
	 frame._onenter = frame:GetScript("OnEnter")
	 frame._onleave = frame:GetScript("OnLeave")
	 frame:SetScript("OnEnter", nil)
	 frame:SetScript("OnLeave", nil)
      else
	 frame:SetScript("OnEnter", frame._onenter or LDB_OnEnter)
	 frame:SetScript("OnLeave", frame._onleave or LDB_OnLeave)
	 frame._onenter = nil frame._onleave = nil
      end

   end
end
   
function mod:ReloadFrame(bin)
   mod:SortFrames(bin)
   mod:SavePosition(bin)
   mod:LoadPosition(bin)
end

options = { 
   global = {
      type = "group",
      name = "Global Settings",
      order = 4,
      childGroups = "tab",
      args = {
	 toggle ={ 
	    type = "toggle",
	    name = "Lock the button bin frame",
	    width = "full",
	    get = function() return not unlockFrames end,
	    set = function() mod:ToggleLocked() end,
	 },
--	 toggleButton = {
--	    type = "toggle",
--	    name = "Lock data broker button positions",
--	    desc = "When unlocked, you can move buttons into a new position on the bar.",
--	    width = "full",
--	    get = function() return not unlockButtons end,
--	    set = function() mod:ToggleButtonLock() end
--	 },
      }
   },
   binConfig = {
      type = "group",
      name = "Bin #",
      order = 4,
      childGroups = "tab",
      get = "GetOption", 
      set = "SetOption", 
      args = {
	 orientation = {
	    type = "group",
	    name = "Orientation",
	    args = {
	       flipx = {
		  type = "toggle",
		  name = "Flip x-axis",
		  desc = "If toggled, the buttons will expand to the left instead of to the right.",
	       },
	       flipy = {
		  type = "toggle",
		  name = "Flip y-axis",
		  desc = "If toggled, the buttons will expand upwards instead of downwards.",
	       },
	    }
	 },
	 hideEmpty = {
	    type = "toggle",
	    name = "Hide blocks without icons",
	    desc = "This will hide all addons that lack icons instead of showing an empty space.",
	    width = "full",
	 },
	 hidden = {
	    type = "toggle",
	    name = "Hide button bin",
	    desc = "Hidw or show this bin.",
	    width = "full",
	 },
	 spacing = {
	    type = "group",
	    name = "Padding",
	    args = { 
	       hpadding = {
		  type = "range",
		  name = "Horizontal Button Padding",
		  width = "full",
		  min = 0, max = 50, step = 0.1,
	       }, 
	       vpadding = {
		  type = "range",
		  name = "Vertical Button Padding",
		  width = "full",
		  min = 0, max = 50, step = 0.1,
	       },
	    }
	 },
	 sizing = {
	    type = "group",
	    name = "Sizing",
	    args = {
	       size = {
		  type = "range",
		  name = "Button Size",
		  width = "full",
		  min = 5, max = 50, step = 1,
	       },
	       scale = {
		  type = "range",
		  name = "Bin Scale",
		  width = "full",
		  min = 0.01, max = 5, step = 0.05,
	       },
	       width = {
		  type = "range",
		  name = "Bin Width",
		  width = "full",
		  min = 1, max = 100, step = 1, 
	       },
	    }
	 },
      }
   },
   objects = {
      name = "Enabled Data Objects",
      type = "group",
      args = {
	 objs = {
	    name = "",
	    type = "multiselect",
	    values = function()
			local tbl = {}
			for name in pairs(db.enabledDataObjects) do
			   if LDB:GetDataObjectByName(name) then
			      tbl[name] = name
			   end
			end
			return tbl
		     end,
	    get = function(_,key)  return db.enabledDataObjects[key].enabled end,
	    set = function(_,key,state)
		     db.enabledDataObjects[key].enabled = state
		     if state then
			mod:LibDataBroker_DataObjectCreated("config", key,
							    LDB:GetDataObjectByName(key))
		     else
			mod:DisableDataObject(key)
		     end
		  end
	       }
      }
   },
   cmdline = {
      name = "Command Line",
      type = "group",
      args = {
	 config = {
	    type = "execute",
	    name = "Show configuration dialog",
	    func = function() mod:ToggleConfigDialog() end,
	    dialogHidden = true
	 },
	 toggle = {
	    type = "execute",
	    name = "Toggle the frame lock",
	    func = function() mod:ToggleLocked() end,
	    dialogHidden = true
	 },
      }
   }
}


function mod:OptReg(optname, tbl, dispname, cmd)
   if dispname then
      optname = "ButtonBin"..optname
      LibStub("AceConfig-3.0"):RegisterOptionsTable(optname, tbl, cmd)
      if not cmd then
	 return LibStub("AceConfigDialog-3.0"):AddToBlizOptions(optname, dispname, "Button Bin")
      end
   else
      LibStub("AceConfig-3.0"):RegisterOptionsTable(optname, tbl, cmd)
      if not cmd then
	 return LibStub("AceConfigDialog-3.0"):AddToBlizOptions(optname, "Button Bin")
      end
   end
end

function mod:GetBinOption(info)
   local bdb = db.bins[self.binId]
   local var = info[#info]
   return bdb[var]
end

function mod:SetBinOption(info, val)
   local bdb = db.bins[self.binId]
   local var = info[#info]

--   mod:Print(fmt("SetOption(%d,%s) = %s",
--		 self.binId, var, tostring(val)))
   
   bdb[var] = val
   if var == "scale" then
      self:SetScale(val)
      self.mover:SetScale(self:GetScale())
   elseif var == "hidden" then
      if bdb.hidden then self:Hide() else self:Show() end
   end
   
   mod:ReloadFrame(self) 
end


function mod:AddBinOptions(id)
   local bin = {}
   for key,val in pairs(options.binConfig) do
      bin[key] = val
   end
   bin.name = bin.name .. id
   bin.handler = bins[id]
   if not bins[id].GetOption then
      bins[id].GetOption = mod.GetBinOption
      bins[id].SetOption = mod.SetBinOption
   end
   mod.profile = mod:OptReg(": "..bin.name, bin, bin.name)
   
end

function mod:SetupOptions()
   mod.main = mod:OptReg("Button Bin", options.global)
   mod:OptReg(": Data Blocks", options.objects, "Data Blocks")
   mod.profile = mod:OptReg(": Profiles", options.profile, "Profiles")
   for id, bin in ipairs(db.bins) do
      mod:AddBinOptions(id)
   end
   mod:OptReg("Button Bin CmdLine", options.cmdline, nil,  { "buttonbin", "bin" })
end

function mod:ToggleConfigDialog()
   InterfaceOptionsFrame_OpenToFrame(mod.profile)
   InterfaceOptionsFrame_OpenToFrame(mod.main)
end

function mod:ToggleCollapsed(frame)
   local bdb
   bin = frame:GetParent()
--   mod:Print("bin id = "..tostring(bin.binId))
   bdb = db.bins[bin.binId]
   bdb.collapsed = not bdb.collapsed
   mod:SortFrames(bin)
end


function mod:SortFrames(bin)
   local bdb = db.bins[bin.binId]
   local xoffset = 0
   local width = 0
   local height = 0
   local sorted = bdb.sortedButtons
   local frame
   local addBin = false
   if bdb.collapsed then
      for id,name in pairs(sorted) do
--	 mod:Print("Hiding frame "..name.." in bin "..bin.binId)
	 if buttonFrames[name] then
	    buttonFrames[name]:Hide()
	 end
      end 
      sorted = {}
  end   
   
   local count = 1
   local previousFrame

   local anchor, xmulti, ymulti

   if bdb.flipy then ymulti = 1 anchor = "BOTTOM"
   else ymulti = -1 anchor = "TOP" end
   if bdb.flipx then anchor = anchor .. "RIGHT"  xmulti = -1
   else anchor = anchor .. "LEFT" xmulti = 1 end

   local hpadding = bdb.hpadding or 0
   local vpadding = (bdb.size + (bdb.vpadding or 0))

   previousFrame = bin.button
   if previousFrame then
      previousFrame:resizeWindow()
      previousFrame:ClearAllPoints()
      previousFrame:SetPoint(anchor, bin, anchor, 0, 0)
      width = previousFrame:GetWidth()
      height = vpadding
      if bdb.width > 1 then
	 xoffset = hpadding + width
	 count = 2
      else
	 previousFrame = nil
      end
   end
   
   for _,name in ipairs(sorted) do
      frame = buttonFrames[name]
      if frame and (not bdb.hideEmpty or frame._has_texture) then
	 if count == 1 then height = height + vpadding end
	 frame:resizeWindow()
	 frame:ClearAllPoints()
	 local frameWidth = hpadding + frame:GetWidth()
	 if previousFrame then
	    frame:SetPoint(anchor, previousFrame, anchor, xmulti*frameWidth, 0)
	 else
	    frame:SetPoint(anchor, bin, anchor, 0, ymulti*(height-vpadding))
	 end
	 count = count + 1
	 xoffset = xoffset + frameWidth
	 if xoffset > width then
	    width =  xoffset
	 end
	 if count > bdb.width then
	    previousFrame = nil
	    xoffset = 0
	    count = 1
	 else
	    previousFrame = frame
	 end
      end
   end
   bin:SetWidth(width)
   bin:SetHeight(height)
   bin.mover:SetWidth(bin:GetWidth())
   bin.mover:SetHeight(bin:GetHeight())
   if bdb.hidden then bin:Hide() else bin:Show() end
end


local unusedFrames = {}
local oldSorted

local function Button_OnDragStart()
   local toRemove
   local bin = this:GetParent()
   local bdb = db.bins[bin.binId]
   local newSorted = {}
   for id, name in pairs(bdb.sortedButtons) do
      if name ~= this.name then
	 newSorted[#newSorted+1] = name
      end
   end
   oldSorted = bdb.sortedButtons
   bdb.sortedButtons = newSorted
   mod:SortFrames(bin)
   this:ClearAllPoints()
   this:StartMoving()
   this:SetAlpha(0.75)
   this:SetFrameLevel(100)
end

local function Button_OnDragStop()
   local bin = this:GetParent()
   local bdb = db.bins[bin.binId]
   local destFrame, destParent
   this:StopMovingOrSizing()
   this:SetFrameLevel(98)
   this:SetAlpha(1.0)
   for id,frame in ipairs(bins) do
      if MouseIsOver(frame.button) then
	 destFrame = frame.button
	 destParent = frame
      end
   end

   if not destFrame then
      for name,frame in pairs(buttonFrames) do
	 if MouseIsOver(frame) and frame ~= this then
	    destFrame = frame
	    destParent = frame:GetParent()
	    break
	 end
      end
   end
   if destFrame and destParent then
      if destParent ~= bin then
--	 mod:Print("Changing parent from "..bin.binId.." to "..destParent.binId)
	 this.db.bin = destParent.binId
	 this:SetParent(destParent)
	 bdb = db.bins[destParent.binId]
      end
      local inserted 
      if destParent.button == destFrame then
	 tinsert(bdb.sortedButtons, 1, this.name)
	 inserted = true
      else
	 local x, midpoint
	 local add = 0
	 if bdb.width > 1 then
	    x = GetCursorPosition()
	    midpoint = (destFrame:GetLeft() + destFrame:GetWidth()/2)*destParent:GetEffectiveScale()
	    if bdb.flipx then
	       if x < midpoint then add = 1 end
	    else
	       if x > midpoint then add = 1 end
	    end
	 else
	    _,x = GetCursorPosition()
	    midpoint = (destFrame:GetBottom() + destFrame:GetHeight()/2)*destParent:GetEffectiveScale()
	    if bdb.flipy then
	       if x > midpoint then add = 1 end
	    else
	       if x < midpoint then add = 1 end
	    end
	 end

--	 mod:Print("x = "..x..", mid = "..midpoint.."...")
	 for id,n in pairs(bdb.sortedButtons) do
	    if destFrame.name == n then
	       id = id + add 
	       if id < 1 then id = 1 end
	       if id > (#bdb.sortedButtons+1) then id = id - 1 end
	       tinsert(bdb.sortedButtons, id, this.name)
	       inserted = true
	       break
	    end
	 end
      end
      if inserted then
	 oldSorted = nil
	 mod:SortFrames(destParent)
	 return
      end
   end
   -- no valid destination, roll state back
   bdb.sortedButtons = oldSorted
   this:SetParent(bin)
   mod:SortFrames(bin)
end

function mod:GetFrame()
   local frame
   if #unusedFrames > 0 then
      frame = unusedFrames[#unusedFrames]
      unusedFrames[#unusedFrames] = nil
   else
      frame = CreateFrame("Button", nil)
      frame:EnableMouse(true)
      frame:RegisterForClicks("AnyUp")
      frame.icon = frame:CreateTexture()
      frame.icon:SetPoint("TOPLEFT", frame)
      frame.icon:SetPoint("BOTTOMLEFT", frame)
      frame.label = frame:CreateFontString(nil, nil, "GameFontNormal")
      frame.label:SetPoint("LEFT", frame.icon, "RIGHT", 4, 0)
      frame.resizeWindow = function(self)
			      local bdb = db.bins[self.db.bin]
			      self.icon:SetWidth(bdb.size)
			      self.icon:SetHeight(bdb.size)
			      if self.label:IsVisible() then
				 local width = self.label:GetStringWidth()
				 self.label:SetWidth(width)
				 self:SetWidth(bdb.size + width)
			      else
				 self:SetWidth(bdb.size)
			      end
			      self:SetHeight(bdb.size)
			      self:Show()
			   end
      frame:SetScript("OnDragStart", Button_OnDragStart)
      frame:SetScript("OnDragStop", Button_OnDragStop)
      
   end
   return frame
end

function mod:ReleaseFrame(frame)
   local bin = frame:GetParent()
   buttonFrames[frame.name] = nil
   unusedFrames[#unusedFrames+1] = frame
   frame:Hide()
   frame:SetParent(nil)
   frame.buttonBinText = nil
   frame.db = nil
   frame.name = nil
   frame.obj = nil
   frame._has_texture = nil
   frame:SetScript("OnEnter", nil)
   frame:SetScript("OnLeave", nil)
   frame:SetScript("OnClick", nil)
   if bin then self:SortFrames(bin) end
end
   
