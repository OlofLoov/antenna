// Moves the inline start script SvelteKit writes into each prerendered page
// into a file of its own, so the site runs under a Content-Security-Policy of
// script-src 'self' with no inline scripts allowed.
//
// For each HTML file under the build folder it cuts the one inline <script>
// that starts the app, writes it unchanged to /_app/start/<route>.<hash>.js,
// and puts <script src> in its place. The script reads document.currentScript,
// which a classic external script sets the same way. It exits non-zero when a
// page has no start script, more than one inline script, or an inline script
// that is not SvelteKit's, so a SvelteKit update that changes the start script
// fails the build instead of shipping a page the CSP blocks.
//
// Usage: node scripts/externalize-start.js <build folder>

import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { pathToFileURL } from 'node:url';

const INLINE = /<script>([\s\S]*?)<\/script>/g;

/** @param {string} dir @returns {string[]} */
export function htmlFiles(dir) {
	return readdirSync(dir, { recursive: true, encoding: 'utf8' })
		.filter((name) => name.endsWith('.html'))
		.map((name) => join(dir, name))
		.sort();
}

/** The start file's base name for a page: index, terms, features-guide, 404. */
export function routeName(build, file) {
	const path = relative(build, file).split(sep).join('/');
	const name = path.replace(/(^|\/)index\.html$/, '').replace(/\.html$/, '');
	return name === '' ? 'index' : name.replaceAll('/', '-');
}

/**
 * Rewrites one page. Returns the new HTML and the start script, or throws.
 * @param {string} html
 * @param {string} name
 */
export function externalize(html, name) {
	const scripts = [...html.matchAll(INLINE)];
	if (scripts.length !== 1) {
		throw new Error(`${name}: expected one inline start script, found ${scripts.length}`);
	}
	const [whole, body] = scripts[0];
	if (!body.includes('__sveltekit_') || !body.includes('document.currentScript')) {
		throw new Error(`${name}: the inline script is not SvelteKit's start script`);
	}
	const hash = createHash('sha256').update(body).digest('hex').slice(0, 10);
	const path = `/_app/start/${name}.${hash}.js`;
	return { html: html.replace(whole, `<script src="${path}"></script>`), path, body };
}

function main() {
	const build = process.argv[2];
	if (!build) {
		console.error('usage: node scripts/externalize-start.js <build folder>');
		process.exit(2);
	}
	mkdirSync(join(build, '_app', 'start'), { recursive: true });
	let count = 0;
	for (const file of htmlFiles(build)) {
		const name = routeName(build, file);
		const page = externalize(readFileSync(file, 'utf8'), name);
		writeFileSync(join(build, page.path), page.body.trim() + '\n');
		writeFileSync(file, page.html);
		count += 1;
	}
	console.log(`externalized the start script of ${count} pages`);
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
	try {
		main();
	} catch (error) {
		console.error(error instanceof Error ? error.message : error);
		process.exit(1);
	}
}
