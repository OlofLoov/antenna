<script lang="ts">
	import Meta from '#lib/components/Meta.svelte';
	import { t } from '#lib/strings.ts';

	const s = t.support;
</script>

<Meta title={s.title} description={s.description} />

<div class="prose">
	<h1>{s.title}</h1>

	<section class="card" id="contact">
		<h2>{s.contactTitle}</h2>
		<p>
			{s.contactBefore}<a href="mailto:{s.contactEmail}">{s.contactEmail}</a>{s.contactAfter}
		</p>
		<p>{s.contactWarning}</p>
	</section>

	<h2 class="questions">{s.questionsTitle}</h2>
	{#each s.faq as item (item.id)}
		<section class="question">
			<h2 id={item.id}>{item.question}</h2>
			{#each item.answer as paragraph (paragraph)}
				<p>{paragraph}</p>
			{/each}
		</section>
	{/each}
</div>

<style>
	.card {
		margin-block: 24px 16px;
	}

	.card h2 {
		font-size: 22px;
		margin-block: 0 8px;
	}

	.card p,
	.question p {
		color: var(--secondary);
		margin-block-end: 8px;
	}

	.questions {
		font-size: 26px;
		margin-block: 40px 8px;
	}

	.question {
		border-block-start: 1px solid var(--rule);
		padding-block: 18px 10px;
	}

	.question h2 {
		font-size: 19px;
		margin-block: 0 6px;
	}
</style>
