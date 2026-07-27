export type Creator = {
	name: string,
	id: number,
	type: "user" | "group",
}


export type Snapshot = {
	label: string,
}

export type GameEntry = {
	name: string,
	original_description: string,
	notes: string,
	place_id: number,
	thumbnails: { string },
	creator: Creator,
	best_version: Snapshot,
	versions: { Snapshot }
}

return nil