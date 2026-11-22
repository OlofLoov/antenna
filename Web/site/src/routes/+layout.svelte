<script lang="ts">
	import '#lib/site.css';
	import SiteFooter from '#lib/components/SiteFooter.svelte';
	import SiteHeader from '#lib/components/SiteHeader.svelte';

	let { children } = $props();
</script>

<SiteHeader />
<main id="content" tabindex="-1">
	{@render children()}
</main>
<SiteFooter />
