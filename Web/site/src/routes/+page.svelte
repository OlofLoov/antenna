<script lang="ts">
	import { areaPath, areas } from '#lib/areas.ts';
	import AppStoreLink from '#lib/components/AppStoreLink.svelte';
	import Meta from '#lib/components/Meta.svelte';
	import Screenshot from '#lib/components/Screenshot.svelte';
	import { t } from '#lib/strings.ts';
</script>

<Meta title={t.home.title} description={t.home.description} />

<section class="hero" id="hero">
	<div class="text">
		<h1>{t.home.hero}</h1>
		<p class="lead">{t.home.lead}</p>
		<div class="get">
			<AppStoreLink />
			<span class="muted">{t.home.platforms}</span>
		</div>
	</div>
	<div class="picture">
		<Screenshot name="apple-tv-live.jpg" alt={t.home.heroAlt} loading="eager" />
	</div>
</section>

{#each areas as area, index (area.slug)}
	<section class="area" class:flip={index % 2 === 1} id={area.slug}>
		<div class="text">
			<h2>{area.name}</h2>
			<p>{area.summary}</p>
			<p class="muted">{area.platforms}</p>
			<p><a href={areaPath(area)}>{area.more}</a></p>
		</div>
		{#if area.image && area.alt}
			<div class="picture">
				<Screenshot name={area.image} alt={area.alt} />
			</div>
		{/if}
	</section>
{/each}

<style>
	.hero,
	.area {
		display: flex;
		gap: 64px;
		align-items: center;
	}

	.hero {
		padding-block: 16px 48px;
	}

	.area {
		padding-block: 48px;
		border-block-start: 1px solid var(--rule);
	}

	.flip {
		flex-direction: row-reverse;
	}

	.text {
		flex: 1 1 0;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.picture {
		flex: 0 1 560px;
		min-inline-size: 0;
	}

	h1 {
		font-size: 52px;
		margin: 0;
	}

	.hero .lead {
		font-size: 20px;
		margin: 0;
	}

	.get {
		display: flex;
		flex-wrap: wrap;
		gap: 16px;
		align-items: center;
		font-size: 15px;
		margin-block-start: 8px;
	}

	h2 {
		font-size: 32px;
		margin: 0;
	}

	.area p {
		font-size: 18px;
		color: var(--secondary);
		margin: 0;
	}

	.area p.muted {
		font-size: 15px;
		color: var(--muted);
	}

	@media (max-width: 720px) {
		.hero,
		.area,
		.flip {
			flex-direction: column;
			align-items: stretch;
			gap: 20px;
		}

		.hero {
			padding-block: 0 32px;
		}

		.area {
			padding-block: 32px;
		}

		.picture {
			flex-basis: auto;
		}

		h1 {
			font-size: 34px;
		}

		.hero .lead {
			font-size: 17px;
		}

		.get {
			flex-direction: column-reverse;
			align-items: flex-start;
		}

		h2 {
			font-size: 24px;
		}

		.area p {
			font-size: 16px;
		}
	}
</style>
