<script lang="ts">
	import AppStoreLink from '#lib/components/AppStoreLink.svelte';
	import Meta from '#lib/components/Meta.svelte';
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
</section>

<style>
	.hero {
		display: flex;
		gap: 64px;
		align-items: center;
		padding-block: 16px 24px;
	}

	.text {
		flex: 1 1 auto;
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	h1 {
		font-size: 52px;
		margin: 0;
	}

	.lead {
		font-size: 20px;
		margin: 0;
	}

	.get {
		display: flex;
		flex-wrap: wrap;
		gap: 16px;
		align-items: center;
		font-size: 15px;
	}

	@media (max-width: 720px) {
		.hero {
			flex-direction: column;
			align-items: stretch;
			gap: 24px;
		}

		h1 {
			font-size: 34px;
		}

		.lead {
			font-size: 17px;
		}

		.get {
			flex-direction: column-reverse;
			align-items: flex-start;
		}
	}
</style>
