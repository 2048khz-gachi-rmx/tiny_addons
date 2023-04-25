Starlight.SetIncluded()

function math.RemapClamp(val, lo, hi, lo2, hi2)
	return lo2 + math.Clamp((val - lo) / (hi - lo), 0, 1) * (hi2 - lo2)
end

function math.TriWaveEx(t, upTime, hangTime, downTime, lo, hi, noPeriod)
	lo = lo or 0
	hi = hi or 1
	-- 1 for hang
	-- z/upTime is up wave
	-- rest is down wave

	local sum = upTime + hangTime + downTime
	if noPeriod and t > sum then return lo, 0 end

	t = t % sum
	local wv = math.min(1, t / upTime, (sum - t) / downTime)

	return math.Remap(wv, 0, 1, lo, hi), (t < upTime and 1) or (t < (upTime + hangTime) and 0) or -1
end