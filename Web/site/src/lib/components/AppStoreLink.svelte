<script lang="ts">
	import { appStoreURL, t } from '#lib/strings.ts';
</script>

{#if appStoreURL}
	<a class="store" href={appStoreURL}>{t.appStore.get}</a>
{:else}
	<p class="soon">{t.appStore.comingSoon}</p>
{/if}

<style>
	.store,
	.soon {
		display: inline-flex;
		align-items: center;
		min-block-size: 48px;
		padding-inline: 20px;
		border-radius: 10px;
		border: 1px solid var(--text);
		font-size: 15px;
		font-weight: 600;
		margin: 0;
	}

	.store {
		color: var(--text);
	}
</style>
