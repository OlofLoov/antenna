<script lang="ts">
	import { page } from '$app/state';
	import { headerLinks } from '#lib/nav.ts';
	import { t } from '#lib/strings.ts';
</script>

<header id="site-header">
	<a class="skip" href="#content">{t.site.skip}</a>
	<div class="bar">
		<!-- The Antuna wordmark (antuna-website/the-header-shows-the-wordmark): the triangle and the mouth are cut by a mask, so the page shows through. -->
		<a class="name" href="/" aria-label={t.site.name}
			><svg
				class="wordmark"
				aria-hidden="true"
				focusable="false"
				width="131"
				height="34"
				viewBox="-6 -192 760 198"
				><path
					d="M99.0 -59.0A40.0 40.0 0 1 0 19.0 -59.0A40.0 40.0 0 1 0 99.0 -59.0M99.0 -99.0V-19.0M147.0 -19.0V-99.0M147.0 -59.0A40.0 40.0 0 0 1 227.0 -59.0V-19.0M289.0 -139.0V-59.0A40.0 40.0 0 0 0 329.0 -19.0M275.0 -99.0H323.0M377.0 -99.0V-59.0A40.0 40.0 0 0 0 457.0 -59.0M457.0 -99.0V-19.0M505.0 -19.0V-99.0M505.0 -59.0A40.0 40.0 0 0 1 585.0 -59.0V-19.0"
					fill="none"
					stroke="currentColor"
					stroke-width="38"
					stroke-linecap="round"
					stroke-linejoin="round"
				/><mask
					id="wordmark-cut"
					maskUnits="userSpaceOnUse"
					x="560"
					y="-200"
					width="220"
					height="230"
					><rect x="560" y="-200" width="220" height="230" fill="#fff" /><path
						d="M659 -81L695 -59L659 -37Z"
						fill="#000"
						stroke="#000"
						stroke-width="6"
						stroke-linejoin="round"
					/><path d="M641 -60L605 -56.3L606 -68Z" fill="#000" /></mask
				><g mask="url(#wordmark-cut)"
					><path
						d="M673 -118A59 59 0 0 1 673 0C640 0 616 -20 606 -46Q604 -54 611 -57L609 -61L612 -66Q610 -67 612 -72C624 -100 646 -118 673 -118Z"
						fill="currentColor"
					/><path
						d="M694 -99C694 -111 700 -119 711 -120L733 -122Q740 -122 738 -116Q726 -90 727 -59Q726 -28 738 -2Q740 4 733 4L711 2C700 1 694 -7 694 -19Z"
						fill="currentColor"
					/></g
				><g
					><path
						d="M656 -112L640 -140"
						stroke="currentColor"
						stroke-width="11"
						stroke-linecap="round"
					/><circle cx="635.0" cy="-148.7" r="10" class="tip" /></g
				><g
					><path
						d="M690 -112L704 -141"
						stroke="currentColor"
						stroke-width="11"
						stroke-linecap="round"
					/><circle cx="708.3" cy="-150.0" r="10" class="tip" /></g
				></svg
			></a
		>
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
		display: flex;
		color: var(--text);
	}

	.wordmark {
		display: block;
		block-size: 34px;
		inline-size: auto;
	}

	.tip {
		fill: var(--tip);
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

		.wordmark {
			block-size: 30px;
		}

		ul {
			gap: 20px;
		}

		nav a {
			font-size: 15px;
		}
	}
</style>
