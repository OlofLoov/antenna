import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { afterEach, describe, expect, test } from 'vitest';
import {
	BUILD,
	BUDGET,
	checkBudgets,
	checkLinks,
	checkPolicy,
	checkProviders,
	checkRoutes,
	pages,
	providerNames,
	routeAddresses,
	scriptSizes,
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

	// antenna-website/the-pages-read-on-a-phone-and-in-dark-mode
	test('no inline script or style, and nothing from another address', () => {
		expect(checkPolicy()).toEqual([]);
	});

	// antenna-website/the-pages-read-on-a-phone-and-in-dark-mode
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

	// antenna-website/the-legal-pages-are-dated-and-link-to-each-other
	test('the legal pages keep their text in the first answer', () => {
		const privacy = textOf(readFileSync(join(BUILD, 'privacy/index.html'), 'utf8'));
		expect(privacy).toContain('Antenna collects nothing about you.');
		expect(privacy).toMatch(/Last updated: [A-Z][a-z]+ \d{1,2}, \d{4}/);
		const terms = textOf(readFileSync(join(BUILD, 'terms/index.html'), 'utf8'));
		expect(terms).toContain('You are responsible for having the right to watch everything you add');
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
