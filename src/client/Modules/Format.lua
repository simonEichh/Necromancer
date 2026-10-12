-- Number formatting helpers.

local function fmtGold(n)
	if n >= 1e15 then
		return string.format("%.1fQa", n / 1e15)
	elseif n >= 1e12 then
		return string.format("%.1fT", n / 1e12)
	elseif n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	else
		return tostring(math.floor(n))
	end
end

local function fmt(n)
	if n >= 1e15 then
		return string.format("%.1fQa", n / 1e15)
	elseif n >= 1e12 then
		return string.format("%.1fT", n / 1e12)
	elseif n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	elseif n >= 10 then
		return string.format("%.0f", n)
	else
		return string.format("%.1f", n)
	end
end

return {
	fmtGold = fmtGold,
	fmt = fmt,
}
