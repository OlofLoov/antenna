import en from './strings/en.json';

/** The site's English text. Other languages add a file with the same keys. */
export const t = en;

/** The App Store page, or null until Antuna has one. */
export const appStoreURL: string | null = null;

/** A page title as the browser tab and link previews show it. */
export function pageTitle(page: string): string {
	return page === t.site.name ? t.site.name : `${page} · ${t.site.name}`;
}
