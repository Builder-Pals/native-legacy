local timescale = {}

function timescale.scale_duration(duration: number, multiplier: number): number
	return duration * multiplier
end

function timescale.scale_delta_time(delta_time: number, multiplier: number): number
	return delta_time * multiplier
end

return timescale
