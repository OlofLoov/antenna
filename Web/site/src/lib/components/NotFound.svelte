<script lang="ts">
	import Meta from '#lib/components/Meta.svelte';
	import { t } from '#lib/strings.ts';
</script>

<Meta title={t.notFound.title} description={t.notFound.description} />

<h1>{t.notFound.title}</h1>
<p class="lead">{t.notFound.body}</p>
<p><a href="/">{t.notFound.home}</a></p>
