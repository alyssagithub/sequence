--!strict
const Sift = require(script.Parent.Parent.Packages.sift)
const Easing = require(script.Parent.Easing)

export type Key = {
	Time: number,
	Value: CFrame,
	EasingStyle: Easing.Style,
	EasingDirection: Easing.Direction,
}

export type Track = {Keys: {Key}}

export type Marker = {
	Time: number,
	Name: string,
	Value: string,
}

export type Clip = {
	Name: string,
	Length: number,
	Looping: boolean,
	Priority: string,
	Tracks: {[string]: Track},
	Markers: {Marker},
}

const Clip = {}

Clip.Priorities = {
	"Core",
	"Idle",
	"Movement",
	"Action",
	"Action2",
	"Action3",
	"Action4",
}

function Clip.New(Name: string): Clip
	return {
		Name = Name,
		Length = 1,
		Looping = false,
		Priority = "Action",
		Tracks = {},
		Markers = {},
	}
end

const function ByTime(A: {Time: number}, B: {Time: number}): boolean
	return A.Time < B.Time
end

function Clip.FindKey(Current: Clip, JointName: string, Time: number): (Key?, number?)
	const Track = Current.Tracks[JointName]

	if not Track then
		return nil, nil
	end

	for Index, Key in Track.Keys do
		if math.abs(Key.Time - Time) < 0.0005 then
			return Key, Index
		end
	end

	return nil, nil
end

function Clip.SetKey(Current: Clip, JointName: string, Key: Key): Clip
	const Track = Current.Tracks[JointName] or {Keys = {}}
	const Existing, Index = Clip.FindKey(Current, JointName, Key.Time)
	const Keys = if Index then Sift.Array.set(Track.Keys, Index, Sift.Dictionary.merge(Existing, Key)) else Sift.Array.sort(Sift.Array.push(Track.Keys, Key), ByTime)

	return Sift.Dictionary.merge(Current, {
		Tracks = Sift.Dictionary.set(Current.Tracks, JointName, {Keys = Keys}),
		Length = math.max(Current.Length, Key.Time),
	})
end

function Clip.RemoveKey(Current: Clip, JointName: string, Time: number): Clip
	const _, Index = Clip.FindKey(Current, JointName, Time)

	if not Index then
		return Current
	end

	const Keys = Sift.Array.removeIndex(Current.Tracks[JointName].Keys, Index)

	return Sift.Dictionary.merge(Current, {
		Tracks = if #Keys == 0 then Sift.Dictionary.removeKey(Current.Tracks, JointName) else Sift.Dictionary.set(Current.Tracks, JointName, {Keys = Keys}),
	})
end

function Clip.MoveKey(Current: Clip, JointName: string, Time: number, NewTime: number): Clip
	const Key = Clip.FindKey(Current, JointName, Time)

	if not Key or Time == NewTime then
		return Current
	end

	return Clip.SetKey(Clip.RemoveKey(Current, JointName, Time), JointName, Sift.Dictionary.merge(Key, {Time = NewTime}))
end

function Clip.KeyTimes(Current: Clip): {number}
	const Seen: {[number]: boolean} = {}
	const Times = {}

	for _, Track in Current.Tracks do
		for _, Key in Track.Keys do
			const Rounded = math.round(Key.Time * 10000) / 10000

			if Seen[Rounded] then
				continue
			end

			Seen[Rounded] = true
			table.insert(Times, Rounded)
		end
	end

	table.sort(Times)

	return Times
end

function Clip.SetMarker(Current: Clip, Marker: Marker): Clip
	const Kept = Sift.Array.filter(Current.Markers, function(Other: Marker)
		return math.abs(Other.Time - Marker.Time) >= 0.0005 or Other.Name ~= Marker.Name
	end)

	return Sift.Dictionary.merge(Current, {Markers = Sift.Array.sort(Sift.Array.push(Kept, Marker), ByTime)})
end

function Clip.RemoveMarker(Current: Clip, Marker: Marker): Clip
	return Sift.Dictionary.merge(Current, {
		Markers = Sift.Array.filter(Current.Markers, function(Other: Marker)
			return Other ~= Marker
		end),
	})
end

function Clip.SetLength(Current: Clip, Length: number): Clip
	const Tracks = {}

	for Name, Track in Current.Tracks do
		const Keys = Sift.Array.filter(Track.Keys, function(Key: Key)
			return Key.Time <= Length + 0.0005
		end)

		if #Keys > 0 then
			Tracks[Name] = {Keys = Keys}
		end
	end

	return Sift.Dictionary.merge(Current, {
		Length = Length,
		Tracks = Tracks,
		Markers = Sift.Array.filter(Current.Markers, function(Marker: Marker)
			return Marker.Time <= Length + 0.0005
		end),
	})
end

return Clip