<script lang="ts">
	import { pageTitle } from '#lib/strings.ts';

	let { title, description }: { title: string; description: string } = $props();
</script>

<svelte:head>
	<title>{pageTitle(title)}</title>
	<meta name="description" content={description} />
	<meta property="og:title" content={pageTitle(title)} />
	<meta property="og:description" content={description} />
</svelte:head>
