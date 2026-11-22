<script lang="ts">
	import { footerLinks } from '#lib/nav.ts';
	import { t } from '#lib/strings.ts';
</script>

<footer id="site-footer">
	<div class="bar">
		<nav aria-label={t.site.footerLabel}>
			<ul>
				{#each footerLinks as link (link.href)}
					<li><a href={link.href}>{link.label}</a></li>
				{/each}
			</ul>
		</nav>
		<p>{t.site.publisher}</p>
	</div>
</footer>

<style>
	footer {
		border-block-start: 1px solid var(--rule);
		color: var(--muted);
		font-size: 14px;
	}

	.bar {
		max-inline-size: var(--wide);
		margin-inline: auto;
		padding-block: 24px;
		padding-inline: var(--gutter);
		display: flex;
		flex-wrap: wrap;
		gap: 16px 24px;
	}

	ul {
		display: flex;
		flex-wrap: wrap;
		gap: 16px 24px;
		list-style: none;
		margin: 0;
		padding: 0;
	}

	li,
	p {
		margin: 0;
	}

	a {
		color: var(--muted);
		font-weight: 400;
	}

	a:hover {
		color: var(--text);
	}
</style>
