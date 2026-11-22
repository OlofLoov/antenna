import { t } from '#lib/strings.ts';

export type Link = { href: string; label: string };

/** The links on the right of the header, on every page. */
export const headerLinks: Link[] = [
	{ href: '/features/', label: t.nav.features },
	{ href: '/pricing/', label: t.nav.pricing },
	{ href: '/support/', label: t.nav.support }
];

/** The links in the footer, on every page. */
export const footerLinks: Link[] = [
	{ href: '/support/', label: t.nav.support },
	{ href: '/terms/', label: t.nav.terms },
	{ href: '/privacy/', label: t.nav.privacy }
];
