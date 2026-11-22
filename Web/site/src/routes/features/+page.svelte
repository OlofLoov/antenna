<script lang="ts">
	import { areaPath, areas } from '#lib/areas.ts';
	import Meta from '#lib/components/Meta.svelte';
	import { t } from '#lib/strings.ts';
</script>

<Meta title={t.features.title} description={t.features.description} />

<h1>{t.features.title}</h1>
<p class="lead">{t.features.lead}</p>

<ul class="areas">
	{#each areas as area (area.slug)}
		<li id={area.slug}>
			<h2><a href={areaPath(area)}>{area.name}</a></h2>
			<p>{area.summary}</p>
			<p class="muted">{area.platforms}</p>
		</li>
	{/each}
</ul>

<style>
	.areas {
		list-style: none;
		padding: 0;
		margin-block-start: 32px;
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
		gap: 24px;
	}

	li {
		background: var(--surface);
		border-radius: var(--radius-card);
		padding: 24px;
		margin: 0;
	}

	h2 {
		font-size: 22px;
		margin-block: 0 8px;
	}

	p {
		color: var(--secondary);
		margin-block-end: 8px;
	}

	p.muted {
		color: var(--muted);
		font-size: 15px;
		margin: 0;
	}
</style>
