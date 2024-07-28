local ElvSearch, Match, with, Found, Inject, Extra, Skip, laststring, ilvlcompare, ilvl, ilvl2
local Bind = {"unbound","bop","boe","",""}

function BSP_Search(text,I_link)
	if not(text) or not(I_link) then return false end
	if laststring ~= text then
		Match = {}
		Extra = 0
		ilvlcompare, ilvl, ilvl2 = nil, 0, 0
		for word in text:gmatch("%S+") do
			Skip = false
			if string.find(word, "+") and string.len(word) >= 3 then
				if ilvlcompare then
					ilvlcompare = "r"
					ilvl2 = tonumber(strmatch(word, "%d+"))
					Skip = true
				else
					ilvlcompare = "+"
					ilvl = tonumber(strmatch(word, "%d+"))
					Extra = Extra + 1
					Skip = true
				end
			end
			if string.find(word, "-") and string.len(word) >=3 then
				if ilvlcompare then
					ilvlcompare = "r"
					ilvl2 = tonumber(strmatch(word, "%d+"))
					Skip = true
				else
					ilvlcompare = "-"
					ilvl = tonumber(strmatch(word, "%d+"))
					Extra = Extra + 1
					Skip = true
				end
			end
			if not(Skip) then
				table.insert(Match, strlower(word))
			end
		end
		laststring = text
	end
	with = {}
	if I_link ~= "" and I_link ~= "[]" and I_link  then
		local I_stats = C_Item.GetItemStats(I_link)
		if I_stats then
			for k, _ in pairs(I_stats) do
				table.insert(with,strlower(k))
			end
		end
		local _,_,_,_,_,_,kind,_,place,_,_,_,_,bind = C_Item.GetItemInfo(I_link)
		if bind then tinsert(with,Bind[bind+1]) end

		local Ilvl = C_Item.GetDetailedItemLevelInfo(I_link)
		if kind then table.insert(with, strlower(kind)) end
		if Ilvl then table.insert(with, Ilvl) end
		if not(place == "") and place then table.insert(with, strlower(place)) end
		Found = 0
		if Ilvl and ilvlcompare == "+" then
			if Ilvl >= ilvl then Found = Found + 1 end
		end
		if Ilvl and ilvlcompare == "-" then
			if Ilvl <= ilvl then Found = Found + 1 end
		end
		if Ilvl and ilvlcompare == "r" then
			if (Ilvl <= ilvl and Ilvl >= ilvl2) or (Ilvl >= ilvl and Ilvl <= ilvl2) then Found = Found + 1 end
		end
		local comp = #Match + Extra
		for i = 1, #Match do
			for q = 1, #with do
				if string.find(with[q], Match[i]) then
					Found = Found + 1
					break
				end
			end
		end
		if Found == comp then
			return true
		else
			return false
		end
	else
		return false
	end
end
---------------------------------Standard UI
local function ItemOverlay(self)
	local SearchString = BagItemSearchBox:GetText()
	if SearchString then
		if self.ItemContextOverlay:IsShown() == true then
			if BSP_Search(SearchString,C_Container.GetContainerItemLink(self:GetBagID(), self:GetID())) then
				self.ItemContextOverlay:Hide()
			end
		end
	end
end

local function UpdateSearch(self)
	local SearchString = BagItemSearchBox:GetText()
	if SearchString then
		for _, itemButton in self:EnumerateValidItems() do
			if itemButton.ItemContextOverlay:IsShown() == true then
				if BSP_Search(SearchString,C_Container.GetContainerItemLink(itemButton:GetBagID(), itemButton:GetID())) then
					itemButton.ItemContextOverlay:Hide()
				end
			end
		end
	end
end

for i = 1, 13 do --Bags
	local containerFrame = _G["ContainerFrame"..i]
	hooksecurefunc(containerFrame,"UpdateSearchResults",UpdateSearch)
	hooksecurefunc(containerFrame,"UpdateItems",UpdateSearch)
end
hooksecurefunc(ContainerFrameCombinedBags,"UpdateItems",UpdateSearch)
hooksecurefunc(ContainerFrameCombinedBags,"UpdateSearchResults",UpdateSearch)
----------------------------------Elv UI---------------------------
local function BSP_Elv(B)
	function B:SetSearch(query)
		local keyword = ElvSearch.Filters.tipPhrases.keywords[query]
		local method = (keyword and ElvSearch.TooltipPhrase) or ElvSearch.Matches
		if keyword then query = keyword end

		local empty = strmatch(query, '^%s+$')
		for slot, link in next, B.SearchSlots do
			if empty then
				slot.searchOverlay:SetShown(false)
			else
				local success, result = pcall(method, ElvSearch, link, query)
				slot.searchOverlay:SetShown(not ( (success and result) or BSP_Search(query, link) ))
			end
		end
	end
end
----------------------------For ArkInventory---------------------

local function BSP_MatchesFilter( frame )

	if not ArkInventory.ValidFrame ( frame ) then return end

	local loc_id = frame.ARK_Data.loc_id
	--local matches = false

	local f = string.trim( string.lower( ArkInventory.Global.Location[loc_id].filter or "" ) )

	f = ArkInventory.Search.CleanText ( f )

	if f == "" then
		return true
	end

	local i = ArkInventory.Frame_Item_GetDB( frame )
	if not i or not i.h then
		return false
	end

	local txt = ArkInventory.Search.GetContent( i.h )

	if string.find( txt , f, nil, true) then
		return true
	end

	return BSP_Search(f, i.h)
end

--------------------------------------For Bagnon------------------------
local function BSP_Bagnon()
local ItemSearch = LibStub('LibItemSearch-1.2')
	function Bagnon.Item:UpdateSearch()
		local search = Bagnon.canSearch and Bagnon.search or ''
		local matches = search == '' or ItemSearch:Matches(self.info.link, search)

		matches = matches or BSP_Search(search,self.info.link)

		self:SetAlpha(matches and 1 or 0.3)
		self:SetLocked(not matches or self.info.locked)
	end
end

-----------------------------Add this search to other bag addons, but nicley I'm trying to keep an eye for when they update.-----------------

local eventframe = CreateFrame("FRAME", "BspEventframe");

function Inject()
	if C_AddOns.IsAddOnLoaded("ElvUI") then
		local E, _, _, _, _ = unpack(ElvUI); --Inport: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
		ElvSearch = LibStub('LibItemSearch-1.2-ElvUI')
		local B = E:GetModule('Bags')
		eventframe:UnregisterEvent("ADDON_LOADED")
		BSP_Elv(B)
	end
	if C_AddOns.IsAddOnLoaded("ArkInventory") then
		ArkInventory.Frame_Item_MatchesFilter = BSP_MatchesFilter
	end
	if C_AddOns.IsAddOnLoaded("Bagnon") then
		BSP_Bagnon()
	end
end

eventframe:RegisterEvent("ADDON_LOADED")


local function eventHandler(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "BagSearchPlus" or  arg1 == "ElvUI" or  arg1 == "ArkInventory" or arg1 == "Bagnon" then
			Inject()
		end
	end
end

eventframe:SetScript("OnEvent", eventHandler);
