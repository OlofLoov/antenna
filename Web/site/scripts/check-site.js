// The link, route and policy check over the built site. Each check returns a
// list of problems, empty when the build passes; tests/site.test.js runs them
// with Vitest, and `node scripts/check-site.js` prints them.
//
// What it holds the build to (design.md decisions 2 and 3 of
// add-feature-website):
// - every route in src/routes has an HTML file, with its <h1> in the markup
// - every internal href and src resolves, links to /setup/ reload the page,
//   and every #anchor exists
// - no inline <script>, <style>, on*= or style= attribute, and nothing loaded
//   from another address
// - the image and script budgets

import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { gzipSync } from 'node:zlib';
import { dirname, join, relative, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

export const SITE = join(dirname(fileURLToPath(import.meta.url)), '..');
export const BUILD = join(SITE, 'build');
/** The plain files that publish-web.sh copies next to the build. */
export const STATIC = join(SITE, '..');
export const REPO = join(SITE, '..', '..');

/** Hosts a page may link to with a plain <a href>. Nothing is loaded from them. */
export const LINK_HOSTS = [
	'apps.apple.com',
	'www.apple.com',
	'reportaproblem.apple.com',
	'support.apple.com',
	'docs.github.com'
];

/** Folders of Web/ that publish-web.sh copies as they are. */
export const STATIC_FOLDERS = ['setup', 'review', '.well-known'];

export const BUDGET = {
	imageBytes: 250 * 1024,
	scriptGzipBytes: 60 * 1024,
	homeBytes: 500 * 1024
};

/** @param {string} dir */
function files(dir) {
	return readdirSync(dir, { recursive: true, encoding: 'utf8' })
		.filter((name) => statSync(join(dir, name)).isFile())
		.map((name) => name.split(sep).join('/'))
		.sort();
}

/** @param {string} build */
export function pages(build = BUILD) {
	return files(build)
		.filter((name) => name.endsWith('.html'))
		.map((name) => ({ name, html: readFileSync(join(build, name), 'utf8') }));
}

/** The address a built file answers, such as /terms/ for terms/index.html. */
export function addressOf(name) {
	if (name === 'index.html') return '/';
	if (name.endsWith('/index.html')) return '/' + name.slice(0, -'index.html'.length);
	return '/' + name;
}

/** The text a reader sees: tags, comments and scripts removed, spaces collapsed. */
export function textOf(html) {
	return html
		.replace(/<script[\s\S]*?<\/script>/gi, ' ')
		.replace(/<style[\s\S]*?<\/style>/gi, ' ')
		.replace(/<!--[\s\S]*?-->/g, '')
		.replace(/<[^>]+>/g, ' ')
		.replace(/&nbsp;/g, ' ')
		.replace(/&amp;/g, '&')
		.replace(/&#39;|&apos;/g, "'")
		.replace(/&quot;/g, '"')
		.replace(/\s+/g, ' ')
		.trim();
}

/** @param {string} html */
function bodyOf(html) {
	return html.match(/<body[^>]*>([\s\S]*)<\/body>/i)?.[1] ?? '';
}

/** Every opening tag with its name and attributes. */
export function tags(html) {
	const found = [];
	const tag =
		/<([a-zA-Z][a-zA-Z0-9-]*)((?:\s+[^\s=>/]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+))?)*)\s*\/?>/g;
	for (const match of html.matchAll(tag)) {
		const attributes = {};
		const attribute = /([^\s=>/]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g;
		for (const a of match[2].matchAll(attribute)) {
			attributes[a[1].toLowerCase()] = a[2] ?? a[3] ?? a[4] ?? '';
		}
		found.push({ name: match[1].toLowerCase(), attributes, source: match[0] });
	}
	return found;
}

/** The addresses each route in src/routes is built at. */
export function routeAddresses(routes = join(SITE, 'src', 'routes')) {
	return files(routes)
		.filter((name) => name.endsWith('+page.svelte'))
		.map((name) => name.slice(0, -'+page.svelte'.length).replace(/\/$/, ''))
		.map((route) =>
			route
				.split('/')
				.filter((part) => !/^\(.*\)$/.test(part))
				.join('/')
		)
		.map((route) => (route === '' ? '/' : route === '404' ? '/404.html' : `/${route}/`));
}

/** Resolves a site path to a built or static file, or null. */
export function resolvePath(path, build = BUILD, statics = STATIC) {
	const clean = decodeURI(path.split('#')[0].split('?')[0]);
	const candidates = clean.endsWith('/') ? [clean + 'index.html'] : [clean, clean + '.html'];
	for (const candidate of candidates) {
		const inBuild = join(build, candidate);
		if (existsSync(inBuild) && statSync(inBuild).isFile()) return { root: 'build', file: inBuild };
		const top = candidate.split('/')[1];
		if (STATIC_FOLDERS.includes(top)) {
			const inStatic = join(statics, candidate);
			if (existsSync(inStatic) && statSync(inStatic).isFile())
				return { root: 'static', file: inStatic };
		}
	}
	return null;
}

/** Each route has its page, with one <h1>, a title, a description and its text in the markup. */
export function checkRoutes(build = BUILD) {
	const problems = [];
	const built = new Map(pages(build).map((page) => [addressOf(page.name), page.html]));
	for (const address of routeAddresses()) {
		if (address.includes('[')) continue;
		if (!built.has(address)) problems.push(`${address}: no HTML file in the build`);
	}
	for (const [address, html] of built) {
		const h1 = [...bodyOf(html).matchAll(/<h1[^>]*>([\s\S]*?)<\/h1>/g)];
		if (h1.length !== 1) problems.push(`${address}: ${h1.length} <h1> elements, expected one`);
		else if (textOf(h1[0][1]) === '') problems.push(`${address}: the <h1> is empty`);
		if (!/<html lang="en"/.test(html)) problems.push(`${address}: no lang on <html>`);
		if (!/<title>[^<]+<\/title>/.test(html)) problems.push(`${address}: no <title>`);
		if (!/<meta name="description" content="[^"]+"/.test(html))
			problems.push(`${address}: no description`);
		if (!html.includes('<meta name="viewport" content="width=device-width, initial-scale=1"'))
			problems.push(`${address}: no viewport meta`);
		if (!html.includes('<meta name="referrer" content="no-referrer"'))
			problems.push(`${address}: no referrer policy`);
		if (!html.includes('id="site-header"')) problems.push(`${address}: no site header`);
		if (!html.includes('id="site-footer"')) problems.push(`${address}: no site footer`);
		if (textOf(bodyOf(html)).length < 40) problems.push(`${address}: almost no text in the markup`);
	}
	return problems;
}

/** Internal links resolve, /setup/ links reload, and every #anchor exists. */
export function checkLinks(build = BUILD, statics = STATIC) {
	const problems = [];
	const ids = new Map(
		pages(build).map((page) => [
			addressOf(page.name),
			new Set(tags(page.html).flatMap((t) => (t.attributes.id ? [t.attributes.id] : [])))
		])
	);
	for (const page of pages(build)) {
		const address = addressOf(page.name);
		for (const tag of tags(page.html)) {
			for (const key of ['href', 'src']) {
				const value = tag.attributes[key];
				if (value === undefined || /^[a-z]+:/i.test(value) || value.startsWith('//')) continue;
				if (value.startsWith('#')) {
					if (value.length > 1 && !ids.get(address)?.has(value.slice(1)))
						problems.push(`${address}: no element with id ${value}`);
					continue;
				}
				if (!value.startsWith('/')) {
					problems.push(`${address}: relative ${key} ${value}`);
					continue;
				}
				const target = resolvePath(value, build, statics);
				if (!target) {
					problems.push(`${address}: ${key} ${value} resolves to no file`);
					continue;
				}
				const hash = value.split('#')[1];
				if (hash && target.root === 'build') {
					const other = addressOf(relative(build, target.file).split(sep).join('/'));
					if (!ids.get(other)?.has(hash)) problems.push(`${address}: ${value} has no anchor`);
				}
				if (
					tag.name === 'a' &&
					target.root === 'static' &&
					!('data-sveltekit-reload' in tag.attributes)
				) {
					problems.push(`${address}: the link to ${value} needs data-sveltekit-reload`);
				}
			}
		}
	}
	return problems;
}

/** Nothing inline, nothing from another address, no cookies or forms. */
export function checkPolicy(build = BUILD) {
	const problems = [];
	for (const page of pages(build)) {
		const address = addressOf(page.name);
		for (const tag of tags(page.html)) {
			const { name, attributes } = tag;
			if (name === 'script' && !attributes.src) problems.push(`${address}: an inline <script>`);
			if (name === 'style') problems.push(`${address}: a <style> element`);
			if (['iframe', 'form', 'object', 'embed', 'base'].includes(name))
				problems.push(`${address}: a <${name}> element`);
			for (const key of Object.keys(attributes)) {
				if (key.startsWith('on')) problems.push(`${address}: an ${key}= attribute on <${name}>`);
				if (key === 'style') problems.push(`${address}: a style= attribute on <${name}>`);
			}
			const loads =
				(name === 'script' && attributes.src) ||
				(name === 'img' && attributes.src) ||
				(name === 'link' && attributes.href) ||
				(name === 'source' && (attributes.src || attributes.srcset));
			if (loads && !(loads.startsWith('/') && !loads.startsWith('//')))
				problems.push(`${address}: <${name}> loads ${loads} from outside the site`);
			if (name === 'img' && attributes.srcset)
				for (const candidate of attributes.srcset.split(',')) {
					const url = candidate.trim().split(/\s+/)[0];
					if (!url.startsWith('/') || url.startsWith('//'))
						problems.push(`${address}: srcset loads ${url} from outside the site`);
				}
			if (name === 'a' && attributes.href && /^(https?:)?\/\//i.test(attributes.href)) {
				const host = new URL(attributes.href, 'https://site.invalid').host;
				if (!LINK_HOSTS.includes(host)) problems.push(`${address}: a link to ${host}`);
			}
		}
		const outside = page.html
			.replace(/<a\s[^>]*>/gi, '')
			.match(/(https?:)?\/\/[a-z0-9.-]+\.[a-z]{2,}/gi);
		for (const url of outside ?? []) {
			if (url === 'http://www.w3.org' || url === '//www.w3.org') continue;
			problems.push(`${address}: names ${url} outside a link`);
		}
		if (/document\.cookie|localStorage|sessionStorage/.test(page.html))
			problems.push(`${address}: touches cookies or storage`);
	}
	for (const name of files(build).filter((file) => file.endsWith('.css'))) {
		const css = readFileSync(join(build, name), 'utf8');
		if (/@import/.test(css)) problems.push(`${name}: @import`);
		for (const match of css.matchAll(/url\(\s*['"]?([^'")]+)/g)) {
			if (!match[1].startsWith('/') || match[1].startsWith('//'))
				problems.push(`${name}: url(${match[1]}) is not a path on the site`);
		}
		if (/@font-face/.test(css)) problems.push(`${name}: a web font`);
	}
	// SvelteKit's router keeps scroll positions in sessionStorage so the back
	// button returns to the same place; the site's own code stores nothing.
	const src = join(SITE, 'src');
	for (const name of files(src).filter((file) => /\.(svelte|ts|js)$/.test(file))) {
		const code = readFileSync(join(src, name), 'utf8');
		if (/document\.cookie|localStorage|sessionStorage|indexedDB/.test(code))
			problems.push(`src/${name}: touches cookies or storage`);
		if (/\bfetch\(\s*['"`]https?:/.test(code))
			problems.push(`src/${name}: fetches another address`);
		if (/\{@html\b/.test(code)) problems.push(`src/${name}: uses {@html}`);
		if (
			/\s(transition|in|out|animate|style):[a-z]/.test(code.replace(/<style[\s\S]*?<\/style>/g, ''))
		)
			problems.push(`src/${name}: a Svelte transition, animation or style directive`);
	}
	return problems;
}

/** The scripts a page loads before it is interactive: its start file and preloads. */
export function pageScripts(html) {
	const paths = new Set();
	for (const tag of tags(html)) {
		if (tag.name === 'script' && tag.attributes.src) paths.add(tag.attributes.src);
		if (tag.name === 'link' && tag.attributes.rel === 'modulepreload' && tag.attributes.href)
			paths.add(tag.attributes.href);
	}
	return [...paths];
}

/** @param {string} build @param {string[]} paths */
function gzipBytes(build, paths) {
	return paths.reduce((sum, path) => sum + gzipSync(readFileSync(join(build, path))).length, 0);
}

/** The compressed script each page loads, by address. */
export function scriptSizes(build = BUILD) {
	return Object.fromEntries(
		pages(build).map((page) => [addressOf(page.name), gzipBytes(build, pageScripts(page.html))])
	);
}

/** The image, script and home page budgets from design.md decision 3. */
export function checkBudgets(build = BUILD) {
	const problems = [];
	for (const name of files(build).filter((file) => /\.(jpe?g|png|webp|avif|svg)$/i.test(file))) {
		const size = statSync(join(build, name)).size;
		if (size > BUDGET.imageBytes) problems.push(`${name}: ${size} bytes, over the image budget`);
	}
	for (const [address, size] of Object.entries(scriptSizes(build))) {
		if (size > BUDGET.scriptGzipBytes)
			problems.push(`${address}: ${size} bytes of compressed script, over the budget`);
	}
	for (const page of pages(build)) {
		const address = addressOf(page.name);
		const images = tags(bodyOf(page.html)).filter((tag) => tag.name === 'img');
		images.forEach((image, index) => {
			for (const key of ['width', 'height', 'alt']) {
				if (!image.attributes[key]) problems.push(`${address}: an <img> without ${key}`);
			}
			if (index > 0 && image.attributes.loading !== 'lazy')
				problems.push(`${address}: ${image.attributes.src} is not loading="lazy"`);
		});
	}
	const home = pages(build).find((page) => page.name === 'index.html');
	if (home) {
		const styles = tags(home.html)
			.filter((tag) => tag.name === 'link' && tag.attributes.rel === 'stylesheet')
			.map((tag) => tag.attributes.href);
		const firstImage = tags(bodyOf(home.html)).find((tag) => tag.name === 'img')?.attributes.src;
		const paths = [...pageScripts(home.html), ...styles, ...(firstImage ? [firstImage] : [])];
		const total =
			Buffer.byteLength(home.html) +
			paths.reduce((sum, path) => sum + statSync(join(build, path)).size, 0);
		if (total > BUDGET.homeBytes)
			problems.push(`/: ${total} bytes with its scripts, styles and first image`);
	}
	return problems;
}

/** The provider, broadcaster and service names the store listing check refuses. */
export function providerNames(repo = REPO) {
	const source = readFileSync(join(repo, 'scripts', 'store_metadata.py'), 'utf8');
	const list = source.match(/^NAMES = \[([\s\S]*?)\]/m)?.[1];
	if (!list) throw new Error('NAMES not found in scripts/store_metadata.py');
	return [...list.matchAll(/"([^"]+)"/g)].map((match) => match[1]);
}

/** No page names a provider, broadcaster, league or streaming service. */
export function checkProviders(build = BUILD) {
	const problems = [];
	const names = providerNames();
	for (const page of pages(build)) {
		const text = textOf(page.html).toLowerCase();
		const alts = tags(page.html)
			.map((tag) => tag.attributes.alt ?? '')
			.join(' ')
			.toLowerCase();
		for (const name of names) {
			const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
			if (new RegExp(`(?<!\\w)${escaped}(?!\\w)`).test(`${text} ${alts}`))
				problems.push(`${addressOf(page.name)}: names '${name}'`);
		}
	}
	return problems;
}

/** No page shows an email address or links to one. */
export function checkEmails(build = BUILD) {
	const problems = [];
	for (const page of pages(build)) {
		const address = addressOf(page.name);
		if (/mailto:/i.test(page.html)) problems.push(`${address}: a mailto: link`);
		for (const match of textOf(page.html).matchAll(/[\w.+-]+@[\w-]+\.[\w.-]+/g))
			problems.push(`${address}: shows the email address ${match[0]}`);
	}
	return problems;
}

export const checks = {
	checkRoutes,
	checkLinks,
	checkPolicy,
	checkBudgets,
	checkProviders,
	checkEmails
};

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
	const build = process.argv[2] ?? BUILD;
	let failed = false;
	for (const [name, check] of Object.entries(checks)) {
		const problems = check(build);
		for (const problem of problems) console.error(`${name}: ${problem}`);
		failed ||= problems.length > 0;
	}
	for (const [address, size] of Object.entries(scriptSizes(build)))
		console.log(`${address} loads ${(size / 1024).toFixed(1)} KB of compressed script`);
	process.exit(failed ? 1 : 0);
}
