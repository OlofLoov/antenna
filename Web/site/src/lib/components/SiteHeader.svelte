<script lang="ts">
	import { page } from '$app/state';
	import { headerLinks } from '#lib/nav.ts';
	import { t } from '#lib/strings.ts';
</script>

<header id="site-header">
	<a class="skip" href="#content">{t.site.skip}</a>
	<div class="bar">
		<a class="name" href="/">{t.site.name}</a>
		{#if headerLinks.length > 0}
			<nav aria-label={t.site.navLabel}>
				<ul>
					{#each headerLinks as link (link.href)}
						<li>
							<a
								href={link.href}
								aria-current={page.url.pathname.startsWith(link.href) ? 'page' : undefined}
								>{link.label}</a
							>
						</li>
					{/each}
				</ul>
			</nav>
		{/if}
	</div>
</header>

<style>
	header {
		border-block-end: 1px solid var(--rule);
	}

	.bar {
		max-inline-size: var(--wide);
		margin-inline: auto;
		min-block-size: 64px;
		padding-inline: var(--gutter);
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		justify-content: space-between;
		gap: 8px 32px;
	}

	.name {
		font-size: 22px;
		font-weight: 700;
		color: var(--text);
	}

	ul {
		display: flex;
		gap: 32px;
		list-style: none;
		margin: 0;
		padding: 0;
	}

	li {
		margin: 0;
	}

	nav a {
		font-size: 16px;
		font-weight: 400;
		color: var(--secondary);
	}

	nav a:hover,
	nav a[aria-current='page'] {
		color: var(--text);
	}

	@media (max-width: 720px) {
		.bar {
			flex-direction: column;
			align-items: flex-start;
			padding-block: 16px 8px;
		}

		.name {
			font-size: 20px;
		}

		ul {
			gap: 20px;
		}

		nav a {
			font-size: 15px;
		}
	}
</style>
