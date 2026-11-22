import adapter from '@sveltejs/adapter-static';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vitest/config';

export default defineConfig({
	plugins: [
		sveltekit({
			adapter: adapter({ pages: 'build', assets: 'build', strict: true }),
			paths: { relative: false },
			inlineStyleThreshold: 0,
			version: { pollInterval: 0 },
			prerender: {
				handleHttpError: 'fail',
				handleMissingId: 'fail',
				handleUnseenRoutes: 'fail',
				entries: ['*', '/404']
			}
		})
	],
	build: { assetsInlineLimit: 0 },
	test: { include: ['tests/**/*.test.js'], environment: 'node' }
});
