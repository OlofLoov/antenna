import { t } from '#lib/strings.ts';

export type Link = { href: string; label: string };

/** The links on the right of the header, on every page. */
export const headerLinks: Link[] = [];

/** The links in the footer, on every page. */
export const footerLinks: Link[] = [
	{ href: '/terms/', label: t.nav.terms },
	{ href: '/privacy/', label: t.nav.privacy }
];
