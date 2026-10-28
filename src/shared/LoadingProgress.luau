--!strict
local LoadingProgress = {}

function LoadingProgress.new(weights: { [string]: number })
	local stages: { [string]: number } = {}
	local highWater = 0
	local copiedWeights = table.clone(weights)
	local progress = {}
	function progress:setStage(name: string, fraction: number)
		if copiedWeights[name] then stages[name] = math.clamp(fraction, 0, 1) end
	end
	function progress:total(): number
		local total = 0
		for name, weight in copiedWeights do total += weight * (stages[name] or 0) end
		if total >= 1 - 1e-9 then total = 1 end
		highWater = math.max(highWater, math.clamp(total, 0, 1))
		return highWater
	end
	return progress
end

function LoadingProgress.ease(display: number, target: number, dt: number): number
	target = math.max(display, target)
	if dt <= 0 then return display end
	local value = display + (target - display) * (1 - math.exp(-dt * 6))
	return if target - value < .001 then target else math.min(value, target)
end

function LoadingProgress.status(percent: number, thresholds: { { Percent: number, Text: string } }?): string
	local rows = thresholds or {
		{ Percent = 0, Text = "Waking up the crater..." },
		{ Percent = 15, Text = "Polishing the pickaxes..." },
		{ Percent = 55, Text = "Counting your ore..." },
		{ Percent = 85, Text = "Firing up the foundry..." },
		{ Percent = 100, Text = "Ready!" },
	}
	local text = rows[1].Text
	for _, row in rows do
		if percent >= row.Percent then text = row.Text end
	end
	return text
end

-- Explicit returned seed makes replay deterministic without global RNG state.
function LoadingProgress.nextTip(count: number, previous: number?, seed: number?): (number, number)
	local nextSeed = ((seed or 73) * 48271) % 2147483647
	if count <= 1 then return math.max(0, count), nextSeed end
	local validPrevious = previous ~= nil and previous >= 1 and previous <= count
	local index = 1 + nextSeed % (if validPrevious then count - 1 else count)
	if validPrevious and index >= (previous :: number) then index += 1 end
	return index, nextSeed
end

function LoadingProgress.shouldFinish(elapsed: number, total: number, minShow: number, maxShow: number): boolean
	return (total >= 1 and elapsed >= minShow) or elapsed >= maxShow
end

return LoadingProgress
