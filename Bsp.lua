-- Version 9.0.2
local ElvSearch, Match, with, Found, Inject, Extra, Skip, laststring, ilvlcompare, ilvl, ilvl2
local Bind = {"unbound","bop","boe","",""}

function BSP_Search(text,I_link)
	if not(text) then return false end
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
		local I_stats = GetItemStats(I_link)
		if I_stats then
			for k, _ in pairs(I_stats) do
				table.insert(with,strlower(k))
			end
		end
		local _,_,_,_,_,_,kind,_,place,_,_,_,_,bind = GetItemInfo(I_link)
		if bind then tinsert(with,Bind[bind+1]) end

		local Ilvl = GetDetailedItemLevelInfo(I_link)
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

local function UpdateBlizzResults(frame)
	local id = frame:GetID();
	local name = frame:GetName().."Item";
	local itemButton, Box, iD
	local _, isFiltered;
	Box=strlower(BagItemSearchBox:GetText())
	for i=1, frame.size, 1 do
		itemButton = _G[name..i] or frame["Item"..i];
		iD = itemButton:GetID()
		_, _, _, _, _, _, _, isFiltered = GetContainerItemInfo(id, iD);
		if ( isFiltered ) then
			if not(BSP_Search(Box,GetContainerItemLink(id,iD))) then
				itemButton:SetMatchesSearch(false)
			else
			itemButton:SetMatchesSearch(true)
			end
		else
			itemButton:SetMatchesSearch(true)
		end
	end
end
hooksecurefunc("ContainerFrame_UpdateSearchResults",UpdateBlizzResults)
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
	if IsAddOnLoaded("ElvUI") then
		local E, _, _, _, _ = unpack(ElvUI); --Inport: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
		ElvSearch = LibStub('LibItemSearch-1.2-ElvUI')
		local B = E:GetModule('Bags')
		eventframe:UnregisterEvent("ADDON_LOADED")
		BSP_Elv(B)
	end
	if IsAddOnLoaded("ArkInventory") then
		ArkInventory.Frame_Item_MatchesFilter = BSP_MatchesFilter
	end
	if IsAddOnLoaded("Bagnon") then
		BSP_Bagnon()
	end
end

eventframe:RegisterEvent("ADDON_LOADED")


local function eventHandler(_, _, name)
	if name == "BagSearchPlus" or  name == "ElvUI" or  name == "ArkInventory" or name == "Bagnon" then
		Inject()
	end
end

eventframe:SetScript("OnEvent", eventHandler);
