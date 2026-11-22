import type sizes from '#lib/screenshots.en.json';
import { t } from '#lib/strings.ts';

export type Feature = { id: string; title: string; body: string; platforms: string };

export type Area = {
	slug: string;
	name: string;
	summary: string;
	line: string;
	platforms: string;
	more: string;
	image?: keyof typeof sizes;
	alt?: string;
	features: Feature[];
};

/** The nine feature areas in the order the home page and the menu show them. */
export const areas: Area[] = t.areas as Area[];

/** The address of an area's page. */
export function areaPath(area: Area): string {
	return `/features/${area.slug}/`;
}

/** The area after this one, wrapping to the first. */
export function nextArea(area: Area): Area {
	return areas[(areas.indexOf(area) + 1) % areas.length];
}
