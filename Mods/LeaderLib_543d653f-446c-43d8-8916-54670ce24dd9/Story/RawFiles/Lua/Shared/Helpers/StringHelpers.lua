if StringHelpers == nil then 
	StringHelpers = {} 
end

---Check if a string is equal to another. Case-insenstive.
---@param a string
---@param b string
---@param insensitive boolean
---@return boolean
local function Equals(a,b, insensitive)
	if insensitive == nil then insensitive = true end
	if a ~= nil and b ~= nil then
		if insensitive then
			return string.upper(a) == string.upper(b)
		else
			return a == b
		end
	end
	return false
end

StringHelpers.Equals = Equals

---Checks if a string is null or empty.
---@type x string
---@return boolean
local function IsNullOrEmpty(x)
	return x == nil or x == "" or type(x) ~= "string"
end

StringHelpers.IsNullOrEmpty = IsNullOrEmpty

---Capitalize a string.
---@type s string
---@return string
local function Capitalize(s)
	return s:sub(1,1):upper()..s:sub(2)
end

StringHelpers.Capitalize = Capitalize

---Join a table of string into one string.
---Source: http://www.wellho.net/resources/ex.php4?item=u105/spjo
---@param delimiter string
---@param list table
local function Join(delimiter, list)
	local len = #list
	if len == 0 then
		return ""
	end
	local string = list[1]
	for i = 2, len do
		string = string .. delimiter .. list[i]
	end
	return string
end

StringHelpers.Join = Join

---Split a string into a table.
---Source: http://www.wellho.net/resources/ex.php4?item=u105/spjo
---@param delimiter string
---@param str string
local function Split(delimiter, str)
	local list = {}; local pos = 1
	if string.find("", delimiter, 1) then
		return list
	end
	while 1 do
		local first, last = string.find(str, delimiter, pos)
		if first then
			table.insert(list, string.sub(str, pos, first-1))
			pos = last+1
		else
			table.insert(list, string.sub(str, pos))
			break
		end
	end
	return list
end

StringHelpers.Split = Split