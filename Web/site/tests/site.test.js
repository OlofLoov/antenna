import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { afterEach, describe, expect, test } from 'vitest';
import {
	BUILD,
	BUDGET,
	checkBudgets,
	checkEmails,
	checkLinks,
	checkPolicy,
	checkProviders,
	checkRoutes,
	checkStyleHashes,
	pages,
	providerNames,
	routeAddresses,
	scriptSizes,
	siteCsp,
	styleHash,
	textOf
} from '../scripts/check-site.js';
import { externalize, routeName } from '../scripts/externalize-start.js';

describe('the built site', () => {
	test('the build exists; run npm run build first', () => {
		expect(existsSync(join(BUILD, 'index.html'))).toBe(true);
	});

	// feature-website/every-page-reads-without-scripts
	test('every route has an HTML file with its heading and text in the markup', () => {
		expect(checkRoutes()).toEqual([]);
		expect(routeAddresses()).toContain('/404.html');
	});

	// feature-website/moving-between-pages-needs-no-reload
	test('every internal link and anchor resolves, and links to /setup/ reload', () => {
		expect(checkLinks()).toEqual([]);
	});

	// antuna-website/the-pages-read-on-a-phone-and-in-dark-mode
	test('no inline script or style, and nothing from another address', () => {
		expect(checkPolicy()).toEqual([]);
	});

	// hosting/pages-run-only-the-site-s-own-code
	test("the CSP allows exactly the route announcer's style attribute", () => {
		expect(siteCsp()).toContain("style-src-attr 'unsafe-hashes' 'sha256-");
		expect(checkStyleHashes()).toEqual([]);
	});

	// antuna-website/the-pages-read-on-a-phone-and-in-dark-mode
	test('images, scripts and the home page fit their budgets', () => {
		expect(checkBudgets()).toEqual([]);
		for (const size of Object.values(scriptSizes()))
			expect(size).toBeLessThan(BUDGET.scriptGzipBytes);
	});

	// feature-website/nothing-on-the-site-points-to-a-provider
	test('no page names a provider from the store listing check', () => {
		expect(providerNames()).toContain('tivimate');
		expect(checkProviders()).toEqual([]);
	});

	// feature-website/every-page-shares-one-header-and-footer
	test('every page has the header and footer, and the start script is a file', () => {
		for (const page of pages()) {
			expect(page.html, page.name).toContain('<header id="site-header"');
			expect(page.html, page.name).toContain('<footer id="site-footer"');
			expect(page.html, page.name).toMatch(
				/<script src="\/_app\/start\/[a-z0-9-]+\.[0-9a-f]{10}\.js">/
			);
		}
	});

	// antuna-website/the-legal-pages-are-dated-and-link-to-each-other
	test('the legal pages keep their text in the first answer', () => {
		const privacy = textOf(readFileSync(join(BUILD, 'privacy/index.html'), 'utf8'));
		expect(privacy).toContain('Antuna collects nothing about you.');
		expect(privacy).toMatch(/Last updated: [A-Z][a-z]+ \d{1,2}, \d{4}/);
		const terms = textOf(readFileSync(join(BUILD, 'terms/index.html'), 'utf8'));
		expect(terms).toContain('You are responsible for having the right to watch everything you add');
	});
});

describe('the pages', () => {
	/** @param {string} path */
	const html = (path) => readFileSync(join(BUILD, path), 'utf8');
	const areaSlugs = [
		'sources',
		'live-tv',
		'guide',
		'movies-and-series',
		'multi-view',
		'apple-tv',
		'setup-from-iphone',
		'sync-and-profiles',
		'privacy'
	];

	// feature-website/the-home-page-says-what-antuna-is
	test('the home page says what Antuna is before its first screenshot', () => {
		const home = html('index.html');
		const beforeImage = textOf(home.slice(0, home.indexOf('<img')));
		expect(beforeImage).toContain('Your TV sources, on every Apple screen.');
		expect(beforeImage).toContain('iPhone, iPad, Mac and Apple TV');
		expect(beforeImage).toContain('It includes no channels.');
		expect(beforeImage).toContain('A purchase unlocks it');
		expect(beforeImage).toContain('Coming soon to the App Store');
	});

	// feature-website/every-feature-area-has-a-section-and-a-page
	test('every area has a home section with a link, and a page that leads on', () => {
		const home = html('index.html');
		areaSlugs.forEach((slug, index) => {
			expect(home).toContain(`<section class="area`);
			expect(home).toMatch(new RegExp(`id="${slug}"`));
			expect(home).toContain(`href="/features/${slug}/"`);
			const page = html(`features/${slug}/index.html`);
			const next = areaSlugs[(index + 1) % areaSlugs.length];
			expect(page, slug).toContain(`href="/features/${next}/"`);
			expect(page, slug).toContain('href="/"');
			expect(textOf(page), slug).toMatch(/On (iPhone|Apple TV)/);
			expect(page.match(/<h2[^>]*>/g)?.length ?? 0, slug).toBeGreaterThan(2);
			for (const image of page.match(/<img[^>]*>/g) ?? []) expect(image).toMatch(/alt="[^"]{20,}"/);
		});
		const features = html('features/index.html');
		for (const slug of areaSlugs) expect(features).toContain(`href="/features/${slug}/"`);
	});

	// feature-website/every-feature-area-has-a-section-and-a-page
	test('multi-view says four channels, which one is heard, and not on iPhone', () => {
		const text = textOf(html('features/multi-view/index.html'));
		expect(text).toContain('up to four');
		expect(text).toContain('Only the highlighted tile plays its sound.');
		expect(text).toContain('On Apple TV, iPad and Mac. Not on iPhone.');
	});

	// feature-website/the-site-shows-only-what-the-app-does
	test('nothing from a change that has not shipped', () => {
		const movies = textOf(html('features/movies-and-series/index.html')).toLowerCase();
		for (const word of ['score', 'trending', 'tmdb']) expect(movies).not.toContain(word);
	});

	// feature-website/pricing-says-how-buying-works
	test('pricing names both purchases, Family Sharing and the region, and no amount', () => {
		const page = html('pricing/index.html');
		const text = textOf(page);
		for (const phrase of [
			'free to download',
			'Yearly',
			'Renews every year until you cancel.',
			'Lifetime',
			'Family Sharing',
			'One purchase covers the family',
			'The App Store shows the price for your region',
			"cancel in your Apple Account's subscription settings"
		])
			expect(text).toContain(phrase);
		expect(page).toContain('href="/terms/"');
		expect(text).not.toMatch(/[$€£¥]\s?\d|\d\s?(kr|sek|usd|eur)\b|\d+[.,]\d{2}/i);
	});

	// feature-website/support-answers-questions-and-points-to-the-app
	test('support answers the common questions and names Report a problem', () => {
		const page = html('support/index.html');
		for (const id of [
			'does-antuna-include-channels',
			'a-channel-will-not-play',
			'the-guide-is-empty-or-wrong',
			'unlocking-on-a-new-device',
			'family-sharing',
			'canceling-the-yearly-subscription',
			'deleting-your-data'
		])
			expect(page).toMatch(new RegExp(`<h2 id="${id}"`));
		const text = textOf(page);
		expect(text).toContain('Report a problem');
		expect(text).toContain('Restore purchase');
		expect(text).toContain('Format not supported');
	});

	// feature-website/support-answers-questions-and-points-to-the-app
	test('no page shows an email address, and the legal pages point to support', () => {
		expect(checkEmails()).toEqual([]);
		for (const page of ['terms/index.html', 'privacy/index.html'])
			expect(html(page)).toMatch(/see the <a href="\/support\/"/);
	});

	// feature-website/every-page-shares-one-header-and-footer
	test('the header links Features, Pricing and Support, the footer Support and the legal pages', () => {
		for (const page of pages()) {
			const header = page.html.match(/<header[\s\S]*?<\/header>/)?.[0] ?? '';
			for (const href of ['/', '/features/', '/pricing/', '/support/'])
				expect(header, page.name).toContain(`href="${href}"`);
			const footer = page.html.match(/<footer[\s\S]*?<\/footer>/)?.[0] ?? '';
			for (const href of ['/support/', '/terms/', '/privacy/'])
				expect(footer, page.name).toContain(`href="${href}"`);
		}
	});
});

describe('the checks catch what they look for', () => {
	/** @type {string[]} */
	const made = [];
	afterEach(() => {
		for (const dir of made.splice(0)) rmSync(dir, { recursive: true, force: true });
	});

	/** @param {Record<string, string>} tree */
	function build(tree) {
		const dir = mkdtempSync(join(tmpdir(), 'site-check-'));
		made.push(dir);
		for (const [name, body] of Object.entries(tree)) {
			mkdirSync(dirname(join(dir, name)), { recursive: true });
			writeFileSync(join(dir, name), body);
		}
		return dir;
	}

	const page = (body, head = '') =>
		`<html lang="en"><head>${head}</head><body><header id="site-header"></header><main>${body}</main><footer id="site-footer"></footer></body></html>`;

	test('an inline script, a style attribute and a handler', () => {
		const dir = build({
			'index.html': page('<h1 style="color:red" onclick="x()">Hi</h1><script>alert(1)</script>')
		});
		const problems = checkPolicy(dir).join('\n');
		expect(problems).toContain('an inline <script>');
		expect(problems).toContain('a style= attribute on <h1>');
		expect(problems).toContain('an onclick= attribute');
	});

	test('a style attribute the CSP does not hash, and a hash nothing uses', () => {
		const announcer = 'position: absolute; width: 1px';
		const dir = build({
			'_app/a.js': `const t = '<div id="svelte-announcer" style="${announcer}"></div>';`,
			'_app/b.js': 'const u = `<p style=\\"color: red\\">`;'
		});
		const csp = `style-src 'self'; style-src-attr 'unsafe-hashes' ${styleHash(announcer)} 'sha256-c3RhbGU='`;
		const problems = checkStyleHashes(dir, csp).join('\n');
		expect(problems).toContain(`_app/b.js: style="color: red" needs ${styleHash('color: red')}`);
		expect(problems).toContain("allows 'sha256-c3RhbGU=', which no built script writes");
		expect(problems).not.toContain('_app/a.js');
		expect(checkStyleHashes(dir, "style-src 'self' 'unsafe-inline'").join('\n')).toContain(
			"style-src-attr lacks 'unsafe-hashes'"
		);
		expect(checkStyleHashes(dir, "style-src 'unsafe-inline'")).toContain(
			"the CSP allows 'unsafe-inline' in style-src"
		);
	});

	test('a script, stylesheet or image from another address', () => {
		const dir = build({
			'index.html': page(
				'<img src="https://cdn.example.com/a.png">',
				'<script src="https://cdn.example.com/x.js"></script><link rel="stylesheet" href="//fonts.example.com/f.css">'
			)
		});
		const problems = checkPolicy(dir).join('\n');
		expect(problems).toContain('<script> loads https://cdn.example.com/x.js');
		expect(problems).toContain('<img> loads https://cdn.example.com/a.png');
		expect(problems).toContain('<link> loads //fonts.example.com/f.css');
	});

	test('a broken link, a missing anchor and a setup link that would not reload', () => {
		const statics = build({ 'setup/index.html': '<p>setup</p>' });
		const dir = build({
			'index.html': page('<a href="/nowhere/">x</a><a href="#gone">y</a><a href="/setup/">z</a>')
		});
		const problems = checkLinks(dir, statics).join('\n');
		expect(problems).toContain('href /nowhere/ resolves to no file');
		expect(problems).toContain('no element with id #gone');
		expect(problems).toContain('the link to /setup/ needs data-sveltekit-reload');
	});

	test('a provider name in the text or in alt text', () => {
		const dir = build({ 'index.html': page('<p>Watch the NBA here</p><img alt="TiviMate">') });
		const problems = checkProviders(dir).join('\n');
		expect(problems).toContain("names 'nba'");
		expect(problems).toContain("names 'tivimate'");
	});

	test('an image without its size or lazy loading', () => {
		const dir = build({
			'index.html': page('<img src="/a.jpg" alt="a" width="1" height="1"><img src="/b.jpg">'),
			'a.jpg': 'x',
			'b.jpg': 'x'
		});
		const problems = checkBudgets(dir).join('\n');
		expect(problems).toContain('an <img> without alt');
		expect(problems).toContain('/b.jpg is not loading="lazy"');
	});
});

describe('externalize-start', () => {
	const start = `<script>
		{
			__sveltekit_abc = { base: "" };
			const element = document.currentScript.parentElement;
		}
	</script>`;

	test('moves the start script into a file named after the route', () => {
		const result = externalize(`<div>${start}</div>`, 'features-guide');
		expect(result.path).toMatch(/^\/_app\/start\/features-guide\.[0-9a-f]{10}\.js$/);
		expect(result.html).toBe(`<div><script src="${result.path}"></script></div>`);
		expect(result.body).toContain('document.currentScript.parentElement');
	});

	test('fails on a page with no start script or with a second inline script', () => {
		expect(() => externalize('<div></div>', 'index')).toThrow(/found 0/);
		expect(() => externalize(`${start}<script>x()</script>`, 'index')).toThrow(/found 2/);
		expect(() => externalize('<script>x()</script>', 'index')).toThrow(/not SvelteKit/);
	});

	test('names each page by its address', () => {
		expect(routeName('/b', '/b/index.html')).toBe('index');
		expect(routeName('/b', '/b/terms/index.html')).toBe('terms');
		expect(routeName('/b', '/b/features/live-tv/index.html')).toBe('features-live-tv');
		expect(routeName('/b', '/b/404.html')).toBe('404');
	});
});
