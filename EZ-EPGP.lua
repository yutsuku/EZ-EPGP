local _G = getfenv()
local tinsert = tinsert
local getn = getn
local strupper = strupper
local ceil = ceil
local strfind = strfind
local gmatch = string.gfind

local debug_level = 0

local SORT_ASC = 0
local SORT_DESC = 1
local SORT_BY_NAME = 0
local SORT_BY_CLASS = 1
local SORT_BY_RATIO = 2
local USE_GUILD_NOTE = 0
local USE_OFFICER_NOTE = 1
local USE_NOTE = USE_OFFICER_NOTE

local addon = CreateFrame('Frame')

addon:SetScript('OnEvent', function()
	this[event](this)
end)

addon:RegisterEvent('ADDON_LOADED')
addon:RegisterEvent('GUILD_ROSTER_UPDATE')
addon:RegisterEvent('RAID_ROSTER_UPDATE')
addon:RegisterEvent('PARTY_MEMBERS_CHANGED')

function addon:print(message, level, headless)
	if not message or message == '' then return end
	if level then
		if level <= debug_level then
			if headless then
				ChatFrame1:AddMessage(message, 0.53, 0.69, 0.19)
			else
				ChatFrame1:AddMessage('[EZ EP/GP]: ' .. message, 0.53, 0.69, 0.19)
			end
		end
	else
		if headless then
			ChatFrame1:AddMessage(message)
		else
			ChatFrame1:AddMessage('[EZ EP/GP]: ' .. message, 1.0, 0.61, 0)
		end
	end
end


do
	local id = 1
	function addon:GetUniqueName()
		id = id + 1
		return 'EZEPGP'..id
	end
end

function addon:RAID_ROSTER_UPDATE()
	self:HandlePlayerChange()
end

function addon:PARTY_MEMBERS_CHANGED()
	self:HandlePlayerChange()
end

function addon:HandlePlayerChange()
	if self:IsInGroup(UnitName('player')) then
		self.main_frame.raidframe.button:Enable()
	else
		self.main_frame.raidframe.button:SetChecked(false)
		self.main_frame.raidframe.button:Disable()
	end
	
	self:UpdateData()
	self:Sort(self.sort_by)
end

function addon:IsInGroup(name)
	local playersRaid = GetNumRaidMembers()
	local playersParty = GetNumPartyMembers()
	
	if playersRaid > 0 then
		for i=1, playersRaid do
			if UnitName('raid'..i) == name then
				return true
			end
		end
	elseif playersParty > 0 then
		if UnitName('player') == name then
			return true
		end
		for i=1, playersParty do
			if UnitName('party'..i) == name then
				return true
			end
		end
	end
	
	return false
end

function addon:UpdateData()
	if not IsInGuild() then return end
	if self.manualUpdate and self.manualUpdate == 2 then
		self.manualUpdate = nil
		return
	end
	
	local userdata = {}
	local showOffline = GetGuildRosterShowOffline()
	
	if not showOffline then
		self.manualUpdate = 1
		self.manualShowOffline = false
		SetGuildRosterShowOffline(true)
		return
	end

	if USE_NOTE == USE_GUILD_NOTE then
		for i=1, GetNumGuildMembers(), 1 do
			local name, _, _, _, class, _, note, officernote, online = GetGuildRosterInfo(i)
			local ratio = 0
			
			if not name or not class then break end
			
			local _,_, ep, gp = string.find(note, '(%d+)/(%d+)')
			if ep and gp then
				ratio = ep/gp
			end
			if ratio > 0 then
				if self.main_frame.raidframe.button:IsChecked() then
					if self:IsInGroup(name) then
						table.insert(userdata, {name, class, ratio, online})
					end
				else
					table.insert(userdata, {name, class, ratio, online})
				end
			end
		end
	elseif USE_NOTE == USE_OFFICER_NOTE and CanViewOfficerNote() then
		for i=1, GetNumGuildMembers(), 1 do
			local name, _, _, _, class, _, note, officernote, online = GetGuildRosterInfo(i)
			local ratio = 0
			
			if not name or not class then break end
			
			local _,_, ep, gp = string.find(officernote, '(%d+)/(%d+)')
			if ep and gp then
				ratio = ep/gp
			end
			if ratio > 0 then
				if self.main_frame.raidframe.button:GetChecked() then
					if self:IsInGroup(name) then
						table.insert(userdata, {name, class, ratio, online})
					end
				else
					table.insert(userdata, {name, class, ratio, online})
				end
			end
		end
	end
	
	self.data = userdata
	self:UpdateScrollFrame()
	
	if self.manualUpdate then
		self.manualUpdate = 2
		SetGuildRosterShowOffline(self.manualShowOffline)
		return
	end
end

function addon:GetDataRange()
	return getn(self.data)
end

function addon:GetData(index)
	local name, class, ratio, online
	
	if self.data[index] then
		name = self.data[index][1]
		class = self.data[index][2]
		ratio = self.data[index][3]
		online = self.data[index][4]
	end
	
	return name, class, ratio, online
end

function addon:SetSelection(index)
	self.selected = index
	self:UpdateScrollFrame()
end

function addon:GetSelection()
	return self.selected
end

function addon:UpdateScrollFrame()
	local offset = FauxScrollFrame_GetOffset(addon.main_frame.scrollframe)

	for i=1, 13, 1 do
		local name, class, ratio, index, button
		
		index = offset + i
		button = addon.main_frame.buttons[i]
		button.index = index
		
		if index > addon:GetDataRange() then
			button:Hide()
		else		
			name, class, ratio, online = addon:GetData(index)
			addon.main_frame.buttons[i].name:SetText(name)
			addon.main_frame.buttons[i].class:SetText(class)
			addon.main_frame.buttons[i].ratio:SetText(string.format('%.4f',ratio))
			
			if ( not online ) then
				addon.main_frame.buttons[i].name:SetTextColor(0.5, 0.5, 0.5)
				addon.main_frame.buttons[i].class:SetTextColor(0.5, 0.5, 0.5)
				addon.main_frame.buttons[i].ratio:SetTextColor(0.5, 0.5, 0.5)
			else
				addon.main_frame.buttons[i].name:SetTextColor(1.0, 0.82, 0.0)
				addon.main_frame.buttons[i].class:SetTextColor(1.0, 1.0, 1.0)
				addon.main_frame.buttons[i].ratio:SetTextColor(1.0, 1.0, 1.0)
			end
			
			if ( addon:GetSelection() == name ) then
				button:LockHighlight()
			else
				button:UnlockHighlight()
			end
			
			button:Show()
		end

	end
	
	FauxScrollFrame_Update(addon.main_frame.scrollframe, addon:GetDataRange(), 13, 14)
end

function addon:Sort(by, toggle)
	if toggle then
		if self.sort_order == SORT_DESC then
			self.sort_order = SORT_ASC
		else
			self.sort_order = SORT_DESC
		end
	end

	if by == SORT_BY_NAME then
		if self.main_frame.header1.sort_order == SORT_DESC then
			sort(self.data, function(x,y) return x[1] > y[1] end)
		else
			sort(self.data, function(x,y) return x[1] < y[1] end)
		end
	elseif by == SORT_BY_CLASS then
		if self.main_frame.header2.sort_order == SORT_DESC then
			sort(self.data, function(x,y)
				if x[2] == y[2] then
					-- same class, sort by ratio
					if self.main_frame.header3.sort_order == SORT_DESC then
						return x[3] > y[3]
					else
						return x[3] < y[3]
					end
				else
					return x[2] > y[2]
				end
			end)
		else
			sort(self.data, function(x,y)
				if x[2] == y[2] then
					-- same class, sort by ratio
					if self.main_frame.header3.sort_order == SORT_DESC then
						return x[3] > y[3]
					else
						return x[3] < y[3]
					end
				else
					return x[2] < y[2]
				end
			end)
		end
	elseif by == SORT_BY_RATIO then
		if self.main_frame.header3.sort_order == SORT_DESC then
			sort(self.data, function(x,y) return x[3] > y[3] end)
		else
			sort(self.data, function(x,y) return x[3] < y[3] end)
		end
	end
	
	self:UpdateScrollFrame()
end

function addon:CreateGUI()
	self.sort_order = SORT_DESC
	
	local main_frame = CreateFrame('Frame', nil, _G['GuildFrame'])
	self.main_frame = main_frame

	main_frame:SetPoint('TOPLEFT', _G['GuildFrame'], 'TOPRIGHT', -34, -10)
	main_frame:SetWidth(300)
	main_frame:SetHeight(337)
	main_frame:SetBackdrop({
		bgFile=[[Interface\DialogFrame\UI-DialogBox-Background]],
		edgeFile=[[Interface\DialogFrame\UI-DialogBox-Border]],
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 }
	})
	main_frame:SetMovable(true)
	main_frame:SetClampedToScreen(true)
	main_frame:SetToplevel(true)
	main_frame:EnableMouse(true)
	main_frame:RegisterForDrag('LeftButton')
	main_frame:SetScript('OnDragStart', function()
		this:StartMoving()
	end)
	main_frame:SetScript('OnDragStop', function()
		this:StopMovingOrSizing()
	end)
	main_frame:SetScript('OnShow', function()
		self:UpdateScrollFrame()
	end)
	main_frame:Hide()
	
	do
		local button_ez = CreateFrame('Button', nil, _G['GuildFrame'])
		self.button_ez = button_ez
		button_ez:SetWidth(60)
		button_ez:SetHeight(60)
		button_ez:SetPoint('TOPLEFT', _G['FriendsFrame'], 'TOPLEFT', 7, -6)
		
		button_ez:SetNormalTexture([[Interface\Addons\EZ-EPGP\icons\ez-button]])
		button_ez:SetHighlightTexture([[Interface\Addons\EZ-EPGP\icons\ez-button-highlight]], 'ADD')
		button_ez:SetPushedTexture([[Interface\Addons\EZ-EPGP\icons\ez-button-pushed]])
		
		button_ez:SetScript('OnClick', function()
			if self.main_frame:IsVisible() then
				self.main_frame:Hide()
			else
				self.main_frame:Show()
			end
		end)
		
	end
	
	do 
		local header = main_frame:CreateTexture(nil, 'ARTWORK')
		main_frame.header = header
		header:SetTexture([[Interface\DialogFrame\UI-DialogBox-Header]])
		header:SetWidth(256)
		header:SetHeight(64)
		header:SetPoint('TOP', main_frame, 0, 12)
	end
	
	do
		local text = main_frame:CreateFontString()
		main_frame.text = text
		text:SetFontObject(GameFontNormal)
		text:SetPoint('TOP', main_frame.header, 0, -14)
		text:SetText('EZ EP/GP')
	end
	
	do
		local raidframe = CreateFrame('Frame', nil, main_frame)
		main_frame.raidframe = raidframe
		raidframe:SetWidth(210)
		raidframe:SetHeight(23)
		raidframe:SetPoint('TOPRIGHT', main_frame, -16, -28)

		do
			local bg_left = raidframe:CreateTexture(nil, 'BACKGROUND')
			raidframe.bg_left = bg_left
			bg_left:SetTexture([[Interface\ClassTrainerFrame\UI-ClassTrainer-FilterBorder]])
			bg_left:SetWidth(12)
			bg_left:SetHeight(28)
			bg_left:SetPoint('TOPLEFT', raidframe, 0, 0)
			bg_left:SetTexCoord(0, 0.09375, 0, 1.0)
			
			local bg_middle = raidframe:CreateTexture(nil, 'BACKGROUND')
			raidframe.bg_middle = bg_middle
			bg_middle:SetTexture([[Interface\ClassTrainerFrame\UI-ClassTrainer-FilterBorder]])
			bg_middle:SetWidth(186)
			bg_middle:SetHeight(28)
			bg_middle:SetPoint('LEFT', bg_left, 'RIGHT', 0, 0)
			bg_middle:SetTexCoord(0.09375, 0.90625, 0, 1.0)
			
			local bg_right = raidframe:CreateTexture(nil, 'BACKGROUND')
			raidframe.bg_right = bg_right
			bg_right:SetTexture([[Interface\ClassTrainerFrame\UI-ClassTrainer-FilterBorder]])
			bg_right:SetWidth(12)
			bg_right:SetHeight(28)
			bg_right:SetPoint('LEFT', bg_middle, 'RIGHT', 0, 0)
			bg_right:SetTexCoord(0.90625, 1.0, 0, 1.0)
		end
		
		local button = CreateFrame('CheckButton', nil, raidframe)
		raidframe.button = button
		button:SetWidth(20)
		button:SetHeight(20)
		button:SetPoint('RIGHT', raidframe, -8, 0)
		button:SetNormalTexture([[Interface\Buttons\UI-CheckBox-Up]])
		button:SetHighlightTexture([[Interface\Buttons\UI-CheckBox-Highlight]], 'ADD')
		button:SetPushedTexture([[Interface\Buttons\UI-CheckBox-Down]])
		button:SetCheckedTexture([[Interface\Buttons\UI-CheckBox-Check]])
		--button:SetDisabledCheckedTexture([[Interface\Buttons\UI-CheckBox-Check-Disabled]])
		
		button:SetScript('OnClick', function()
			self:UpdateData()
			self:Sort(self.sort_by)
		end)
		
		local label = button:CreateFontString()
		raidframe.label = label
		label:SetFontObject(GameFontHighlightSmall)
		label:SetPoint('RIGHT', button, 'LEFT', -10, 1)
		label:SetText('Show Raid members')
	end
	
	do
		local header1 = CreateFrame('Button', self:GetUniqueName(), main_frame, 'GuildFrameColumnHeaderTemplate')
		main_frame.header1 = header1
		header1:SetPoint('TOPLEFT', 16, -62)
		WhoFrameColumn_SetWidth(83, header1)
		header1:SetText('Name')
		header1.sort_order = SORT_ASC
		
		header1:SetScript('OnClick', function()
			if this.sort_order == SORT_DESC then
				this.sort_order = SORT_ASC
			else
				this.sort_order = SORT_DESC
			end
			
			self.sort_by = SORT_BY_NAME
			self:Sort(self.sort_by)
		end)
		
		local header2 = CreateFrame('Button', self:GetUniqueName(), main_frame, 'GuildFrameColumnHeaderTemplate')
		main_frame.header2 = header2
		header2:SetPoint('LEFT', header1, 'RIGHT', -2, 0)
		WhoFrameColumn_SetWidth(92, header2)
		header2:SetText('Class')
		header2.sort_order = SORT_ASC
		
		header2:SetScript('OnClick', function()			
			if this.sort_order == SORT_DESC then
				this.sort_order = SORT_ASC
			else
				this.sort_order = SORT_DESC
			end
			
			self.sort_by = SORT_BY_CLASS
			self:Sort(self.sort_by)
		end)
		
		local header3 = CreateFrame('Button', self:GetUniqueName(), main_frame, 'GuildFrameColumnHeaderTemplate')
		main_frame.header3 = header3
		header3:SetPoint('LEFT', header2, 'RIGHT', -2, 0)
		WhoFrameColumn_SetWidth(72, header3)
		header3:SetText('Ratio')
		header3.sort_order = SORT_DESC
		
		header3:SetScript('OnClick', function()
			if this.sort_order == SORT_DESC then
				this.sort_order = SORT_ASC
			else
				this.sort_order = SORT_DESC
			end
			
			self.sort_by = SORT_BY_RATIO
			self:Sort(self.sort_by)
		end)
	end
	
	do
		main_frame.buttons = {}
		local lastButton
		for i=1, 13, 1 do
			local button = CreateFrame('Button', nil, main_frame)
			button:SetID(i)
			button:SetWidth(240)
			button:SetHeight(16)
			button:SetHighlightTexture([[Interface\FriendsFrame\UI-FriendsFrame-HighlightBar]], 'ADD')
			button:SetScript('OnClick', function()
				self:SetSelection(this.name:GetText())
				this:LockHighlight()
			end)
			
			do
				local name = button:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
				button.name = name
				name:SetWidth(88)
				name:SetHeight(14)
				name:SetPoint('TOPLEFT', button, 8, 0)
				name:SetJustifyH('LEFT')
			end
			
			do
				local class = button:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
				button.class = class
				class:SetWidth(100)
				class:SetHeight(14)
				class:SetPoint('LEFT', button.name, 'RIGHT', -10, 0)
				class:SetJustifyH('LEFT')
			end
			
			do
				local ratio = button:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
				button.ratio = ratio
				ratio:SetWidth(100)
				ratio:SetHeight(14)
				ratio:SetPoint('LEFT', button.class, 'RIGHT', -10, 0)
				ratio:SetJustifyH('LEFT')
			end
			
			if i == 1 then
				button:SetPoint('TOPLEFT', main_frame, 18, -86)
			else
				button:SetPoint('TOPLEFT', lastButton, 'BOTTOMLEFT', 0, 0)
			end
			
			main_frame.buttons[i] = button
			lastButton = button
		end
	end
	
	do
		local scrollframe = CreateFrame('ScrollFrame', self:GetUniqueName(), main_frame, 'FauxScrollFrameTemplate')
		main_frame.scrollframe = scrollframe
		scrollframe:SetWidth(240)
		scrollframe:SetHeight(237)
		scrollframe:SetPoint('TOPLEFT', main_frame, 18, -86)
		scrollframe:EnableMouse(true)
		
		local t1 = scrollframe:CreateTexture(nil, 'BACKGROUND')
		scrollframe.t1 = t1
		t1:SetTexture([[Interface\PaperDollInfoFrame\UI-Character-ScrollBar]])
		t1:SetWidth(31)
		t1:SetHeight(226)
		t1:SetPoint('TOPLEFT', scrollframe, 'TOPRIGHT', -2, 5)
		t1:SetTexCoord(0, 0.484375, 0, 0.8828125)
		
		local t2 = scrollframe:CreateTexture(nil, 'BACKGROUND')
		scrollframe.t2 = t2
		t2:SetTexture([[Interface\PaperDollInfoFrame\UI-Character-ScrollBar]])
		t2:SetWidth(31)
		t2:SetHeight(106)
		t2:SetPoint('BOTTOMLEFT', scrollframe, 'BOTTOMRIGHT', -2, -2)
		t2:SetTexCoord(0.515625, 1.0, 0, 0.4140625)
		
		scrollframe:SetScript('OnVerticalScroll', function()
			FauxScrollFrame_OnVerticalScroll(14, self.UpdateScrollFrame)
		end)
		scrollframe:SetScript('OnShow', function()
			self:UpdateScrollFrame()
		end)
	end

end

function addon:ADDON_LOADED()
	if arg1 ~= 'EZ-EPGP' then
		return
	end
	
	self.enabled = true
	self.inGroup = false
	self.version = GetAddOnMetadata('EZ-EPGP', 'Version')
	self.data = {}
	self.sort_by = SORT_BY_RATIO
	
	self:CreateGUI()
	self:HandlePlayerChange()
end

function addon:GUILD_ROSTER_UPDATE()
	self:UpdateData()
	self:Sort(self.sort_by)
end