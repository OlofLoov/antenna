import { error } from '@sveltejs/kit';
import { areas } from '#lib/areas.ts';
import type { EntryGenerator, PageLoad } from './$types';

export const entries: EntryGenerator = () => areas.map((area) => ({ area: area.slug }));

export const load: PageLoad = ({ params }) => {
	const area = areas.find((candidate) => candidate.slug === params.area);
	if (!area) error(404, 'Page not found');
	return { area };
};
