--!strict
const Sift = require(script.Parent.Parent.Packages.sift)
const Easing = require(script.Parent.Easing)

export type Key = {
	Time: number,
	Value: any,
	EasingStyle: Easing.Style,
	EasingDirection: Easing.Direction,
}

export type Track = {
	Keys: {Key},
	Object: Instance?,
	Property: string?,
}

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

function Clip.IsProperty(Name: string): boolean
	return Name:sub(1, 1) == "@"
end

function Clip.PropertyTrackName(Object: Instance, Property: string): string
	return `@{Object:GetDebugId()}.{Property}`
end

function Clip.FindKey(Current: Clip, TrackName: string, Time: number): (Key?, number?)
	const Track = Current.Tracks[TrackName]

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

function Clip.SetKey(Current: Clip, TrackName: string, Key: Key, Object: Instance?, Property: string?): Clip
	const Track = Current.Tracks[TrackName] or {
		Keys = {},
		Object = Object,
		Property = Property,
	}
	const Existing, Index = Clip.FindKey(Current, TrackName, Key.Time)
	const Keys = if Index then Sift.Array.set(Track.Keys, Index, Sift.Dictionary.merge(Existing, Key)) else Sift.Array.sort(Sift.Array.push(Track.Keys, Key), ByTime)

	return Sift.Dictionary.merge(Current, {
		Tracks = Sift.Dictionary.set(Current.Tracks, TrackName, Sift.Dictionary.merge(Track, {Keys = Keys})),
		Length = math.max(Current.Length, Key.Time),
	})
end

function Clip.RemoveKey(Current: Clip, TrackName: string, Time: number): Clip
	const _, Index = Clip.FindKey(Current, TrackName, Time)

	if not Index then
		return Current
	end

	const Track = Current.Tracks[TrackName]
	const Keys = Sift.Array.removeIndex(Track.Keys, Index)

	return Sift.Dictionary.merge(Current, {
		Tracks = if #Keys == 0 then Sift.Dictionary.removeKey(Current.Tracks, TrackName) else Sift.Dictionary.set(Current.Tracks, TrackName, Sift.Dictionary.merge(Track, {Keys = Keys})),
	})
end

function Clip.RemoveTrack(Current: Clip, TrackName: string): Clip
	return Sift.Dictionary.merge(Current, {Tracks = Sift.Dictionary.removeKey(Current.Tracks, TrackName)})
end

function Clip.MoveKey(Current: Clip, TrackName: string, Time: number, NewTime: number): Clip
	const Key = Clip.FindKey(Current, TrackName, Time)

	if not Key or Time == NewTime or Clip.FindKey(Current, TrackName, NewTime) then
		return Current
	end

	const Track = Current.Tracks[TrackName]

	return Clip.SetKey(Clip.RemoveKey(Current, TrackName, Time), TrackName, Sift.Dictionary.merge(Key, {Time = NewTime}), Track.Object, Track.Property)
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

function Clip.FindMarker(Current: Clip, Time: number, Name: string): Marker?
	for _, Marker in Current.Markers do
		if math.abs(Marker.Time - Time) < 0.0005 and Marker.Name == Name then
			return Marker
		end
	end

	return nil
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

function Clip.LastTime(Current: Clip): number
	local Last = 0

	for _, Track in Current.Tracks do
		for _, Key in Track.Keys do
			Last = math.max(Last, Key.Time)
		end
	end

	for _, Marker in Current.Markers do
		Last = math.max(Last, Marker.Time)
	end

	return Last
end

function Clip.SetLength(Current: Clip, Length: number): Clip
	return Sift.Dictionary.merge(Current, {Length = math.max(Length, Clip.LastTime(Current))})
end

function Clip.Scale(Current: Clip, Factor: number): Clip
	const Tracks = {}

	for Name, Track in Current.Tracks do
		Tracks[Name] = Sift.Dictionary.merge(Track, {
			Keys = Sift.Array.map(Track.Keys, function(Key: Key)
				return Sift.Dictionary.merge(Key, {Time = Key.Time * Factor})
			end),
		})
	end

	return Sift.Dictionary.merge(Current, {
		Length = Current.Length * Factor,
		Tracks = Tracks,
		Markers = Sift.Array.map(Current.Markers, function(Marker: Marker)
			return Sift.Dictionary.merge(Marker, {Time = Marker.Time * Factor})
		end),
	})
end

function Clip.JointTracks(Current: Clip): {[string]: Track}
	const Found = {}

	for Name, Track in Current.Tracks do
		if not Clip.IsProperty(Name) then
			Found[Name] = Track
		end
	end

	return Found
end

return Clip