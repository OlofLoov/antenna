<script lang="ts">
	import AppStoreLink from '#lib/components/AppStoreLink.svelte';
	import Meta from '#lib/components/Meta.svelte';
	import { t } from '#lib/strings.ts';

	const p = t.pricing;
</script>

<Meta title={p.title} description={p.description} />

<h1>{p.title}</h1>
<p class="lead">{p.lead}</p>

<div class="plans">
	{#each p.plans as plan (plan.id)}
		<section class="card" id={plan.id}>
			<h2>{plan.name}</h2>
			{#each plan.lines as line (line)}
				<p>{line}</p>
			{/each}
		</section>
	{/each}
</div>

<div class="prose">
	{#each p.sections as section (section.id)}
		<section id={section.id}>
			<h2>{section.title}</h2>
			<p>{section.body}</p>
		</section>
	{/each}
	<p>
		{p.cancelBefore} <a href="/terms/">{t.nav.terms}</a>{p.cancelAfter}
	</p>
	<div class="get"><AppStoreLink /></div>
</div>

<style>
	.plans {
		display: flex;
		gap: 32px;
		margin-block: 32px 8px;
	}

	.card {
		flex: 1 1 0;
	}

	.card h2 {
		font-size: 26px;
		margin-block: 0 10px;
	}

	.card p {
		color: var(--secondary);
		margin-block-end: 8px;
	}

	.prose p {
		color: var(--secondary);
	}

	.get {
		margin-block-start: 24px;
	}

	@media (max-width: 720px) {
		.plans {
			flex-direction: column;
			gap: 16px;
		}
	}
</style>
