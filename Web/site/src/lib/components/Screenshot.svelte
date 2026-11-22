<script lang="ts">
	import sizes from '#lib/screenshots.en.json';

	let {
		name,
		alt,
		loading = 'lazy'
	}: { name: keyof typeof sizes; alt: string; loading?: 'lazy' | 'eager' } = $props();

	const size = $derived(sizes[name]);
</script>

<img
	class="shot"
	class:tall={size.height > size.width}
	src={`/images/en/${name}`}
	width={size.width}
	height={size.height}
	{alt}
	{loading}
	decoding="async"
/>

<style>
	img {
		inline-size: 100%;
		block-size: auto;
		border-radius: var(--radius-shot);
		background: var(--surface);
	}

	.tall {
		inline-size: auto;
		max-inline-size: 100%;
		max-block-size: 640px;
		margin-inline: auto;
	}
</style>
