<script lang="ts">
	import { areaPath, nextArea } from '#lib/areas.ts';
	import Meta from '#lib/components/Meta.svelte';
	import Screenshot from '#lib/components/Screenshot.svelte';
	import { t } from '#lib/strings.ts';

	let { data } = $props();

	const area = $derived(data.area);
	const next = $derived(nextArea(area));
</script>

<Meta title={area.name} description={area.line} />

<div class="intro">
	<p class="muted eyebrow"><a href="/features/">{t.features.title}</a></p>
	<h1>{area.name}</h1>
	<p class="lead">{area.line}</p>
	<p class="muted">{area.platforms}</p>
</div>

{#if area.image && area.alt}
	<div class="picture">
		<Screenshot name={area.image} alt={area.alt} loading="eager" />
	</div>
{/if}

<div class="features">
	{#each area.features as feature (feature.id)}
		<section id={feature.id}>
			<h2>{feature.title}</h2>
			<p>{feature.body}</p>
			<p class="muted on">{feature.platforms}</p>
		</section>
	{/each}
</div>

<nav class="next" aria-label={t.features.moreLabel}>
	<a href="/features/">{t.features.all}</a>
	<a href="/">{t.features.home}</a>
	<a href={areaPath(next)}>{t.features.next} {next.name}</a>
</nav>

<style>
	.intro {
		max-inline-size: var(--measure);
	}

	.eyebrow {
		font-size: 15px;
		margin-block-end: 8px;
	}

	.eyebrow a {
		color: var(--muted);
		font-weight: 400;
	}

	.picture {
		margin-block: 32px;
	}

	.features {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 8px 48px;
	}

	section h2 {
		font-size: 22px;
		margin-block: 24px 8px;
	}

	section p {
		color: var(--secondary);
		margin-block-end: 4px;
	}

	section .on {
		color: var(--muted);
		font-size: 15px;
	}

	.next {
		display: flex;
		flex-wrap: wrap;
		gap: 12px 32px;
		margin-block-start: 48px;
		font-size: 17px;
	}

	.next a:last-child {
		margin-inline-start: auto;
	}

	@media (max-width: 720px) {
		.features {
			grid-template-columns: 1fr;
		}

		.next a:last-child {
			margin-inline-start: 0;
		}
	}
</style>
