<script lang="ts">
	// The home page's TV with an iPad and an iPhone in front of it
	// (antuna-website/the-home-page-tunes-in, the-tv-zaps-through-the-app and
	// the-hero-holds-still-with-reduce-motion). CSS plays the tune-in from the
	// first paint; the script zaps, drifts and loads the next channel, and only
	// while the stage is on screen, the tab is in front and motion is allowed.
	import { onMount } from 'svelte';
	import sizes from '#lib/screenshots.en.json';
	import { t } from '#lib/strings.ts';
	import {
		channels,
		devices,
		mayDrift,
		mayZap,
		nextChannel,
		pointerDrift,
		scrollDrift,
		timing
	} from '#lib/tuneIn.ts';

	let stage: HTMLDivElement;
	let channel = $state(0);
	let loaded = $state(channels.map((_, index) => index === 0));
	let tuning = $state(true);
	let zapping = $state(false);
	let paused = $state(false);
	let running = $state(false);

	const alts = t.home.tuneIn.channels;
	let reschedule = () => {};

	function togglePause() {
		paused = !paused;
		reschedule();
	}

	onMount(() => {
		const reduce = matchMedia('(prefers-reduced-motion: reduce)');
		const finePointer = matchMedia('(hover: hover) and (pointer: fine)');
		const state = {
			reducedMotion: reduce.matches,
			tuned: false,
			onScreen: true,
			tabVisible: document.visibilityState === 'visible'
		};
		const requested = channels.map(() => false);
		let zapTimer: ReturnType<typeof setTimeout> | undefined;
		let zapEnd: ReturnType<typeof setTimeout> | undefined;
		let waitingFor: number | undefined;
		let frame = 0;
		let pointer = { x: 0, y: 0 };

		const zapState = () => ({ ...state, paused });

		function load(index: number) {
			if (loaded[index] || requested[index]) return;
			requested[index] = true;
			const pictures = devices.map((device) => {
				const image = new Image();
				image.src = `/images/en/${channels[index][device]}`;
				return image.decode();
			});
			Promise.all(pictures).then(
				() => {
					loaded[index] = true;
					if (waitingFor === index) {
						waitingFor = undefined;
						zap();
					}
				},
				() => (requested[index] = false)
			);
		}

		function schedule() {
			clearTimeout(zapTimer);
			waitingFor = undefined;
			running = !state.reducedMotion;
			if (mayZap(zapState())) zapTimer = setTimeout(zap, timing.zapEvery);
		}

		function zap() {
			if (!mayZap(zapState())) return;
			const next = nextChannel(channel);
			if (!loaded[next]) {
				waitingFor = next;
				load(next);
				return;
			}
			channel = next;
			zapping = true;
			clearTimeout(zapEnd);
			zapEnd = setTimeout(() => (zapping = false), timing.zap);
			load(nextChannel(next));
			schedule();
		}

		function draw() {
			frame = 0;
			if (!mayDrift(state)) return;
			const box = stage.getBoundingClientRect();
			stage.style.setProperty('--drift-x', pointer.x.toFixed(3));
			stage.style.setProperty('--drift-y', pointer.y.toFixed(3));
			stage.style.setProperty('--drift-s', scrollDrift(box.top, box.height).toFixed(3));
		}

		function requestDraw() {
			if (frame === 0 && mayDrift(state)) frame = requestAnimationFrame(draw);
		}

		function onPointer(event: PointerEvent) {
			if (!finePointer.matches) return;
			pointer = pointerDrift(event.clientX, event.clientY, innerWidth, innerHeight);
			requestDraw();
		}

		function onVisibility() {
			state.tabVisible = document.visibilityState === 'visible';
			schedule();
		}

		function onReduce() {
			state.reducedMotion = reduce.matches;
			if (state.reducedMotion) {
				zapping = false;
				stage.style.removeProperty('--drift-x');
				stage.style.removeProperty('--drift-y');
				stage.style.removeProperty('--drift-s');
			} else {
				load(nextChannel(channel));
			}
			schedule();
		}

		const observer = new IntersectionObserver(([entry]) => {
			state.onScreen = entry.isIntersecting;
			schedule();
			requestDraw();
		});
		observer.observe(stage);

		const tuned = setTimeout(() => {
			tuning = false;
			state.tuned = true;
			if (!state.reducedMotion) load(1);
			schedule();
		}, timing.tuned);

		reschedule = schedule;
		running = !state.reducedMotion;
		addEventListener('pointermove', onPointer, { passive: true });
		addEventListener('scroll', requestDraw, { passive: true });
		document.addEventListener('visibilitychange', onVisibility);
		reduce.addEventListener('change', onReduce);

		return () => {
			clearTimeout(tuned);
			clearTimeout(zapTimer);
			clearTimeout(zapEnd);
			cancelAnimationFrame(frame);
			observer.disconnect();
			removeEventListener('pointermove', onPointer);
			removeEventListener('scroll', requestDraw);
			document.removeEventListener('visibilitychange', onVisibility);
			reduce.removeEventListener('change', onReduce);
		};
	});
</script>

<div class="stage" class:tuning class:zap={zapping} bind:this={stage}>
	{#each devices as device (device)}
		<div class="device {device}">
			<div class="screen">
				{#each channels as shots, index (index)}
					{#if loaded[index]}
						<img
							class:on={index === channel}
							src={`/images/en/${shots[device]}`}
							width={sizes[shots[device]].width}
							height={sizes[shots[device]].height}
							alt={alts[index][device]}
							aria-hidden={index === channel ? undefined : 'true'}
							loading={index === 0 && device === 'tv' ? 'eager' : 'lazy'}
							decoding="async"
						/>
					{/if}
				{/each}
				{#if device === 'tv'}
					<svg
						class="static"
						aria-hidden="true"
						focusable="false"
						viewBox="0 0 160 90"
						preserveAspectRatio="none"
						><filter id="tune-in-noise"
							><feTurbulence
								type="fractalNoise"
								baseFrequency="0.9"
								numOctaves="2"
								stitchTiles="stitch"
							/><feColorMatrix type="saturate" values="0" /></filter
						><rect
							class="grain"
							x="-40"
							y="-30"
							width="240"
							height="150"
							filter="url(#tune-in-noise)"
						/></svg
					>
					<div class="lines" aria-hidden="true"></div>
					<span class="number" aria-hidden="true">{channel + 1}</span>
				{/if}
			</div>
		</div>
	{/each}
</div>
<div class="controls">
	<button type="button" class="pause" hidden={!running} onclick={togglePause}
		>{paused ? t.home.tuneIn.play : t.home.tuneIn.pause}</button
	>
</div>

<style>
	.stage {
		position: relative;
		aspect-ratio: 100 / 66;
		container-type: inline-size;
		--drift-x: 0;
		--drift-y: 0;
		--drift-s: 0;
	}

	.device {
		position: absolute;
		background: #05070a;
		box-shadow:
			0 0 0 1px #1e2530,
			0 18px 40px rgb(0 0 0 / 0.45);
		transition: translate 0.3s ease-out;
	}

	.screen {
		position: relative;
		overflow: hidden;
		background: #000;
	}

	.tv {
		inset-block-start: 0;
		inset-inline-end: 0;
		inline-size: 88%;
		padding: 1.2%;
		border-radius: 14px;
		translate: calc(var(--drift-x) * -4px) calc(var(--drift-y) * -4px);
	}

	.tv .screen {
		aspect-ratio: 16 / 9;
		border-radius: 5px;
	}

	.ipad {
		inset-block-end: 0;
		inset-inline-start: 0;
		inline-size: 27%;
		padding: 1.1%;
		border-radius: 16px;
		translate: calc(var(--drift-x) * -10px) calc(var(--drift-y) * -10px - var(--drift-s) * 24px);
	}

	.ipad .screen {
		aspect-ratio: 3 / 4;
		border-radius: 9px;
	}

	.iphone {
		inset-block-end: 0;
		inset-inline-end: 4%;
		inline-size: 13%;
		padding: 0.6%;
		border-radius: 14px;
		translate: calc(var(--drift-x) * -16px) calc(var(--drift-y) * -16px - var(--drift-s) * 40px);
	}

	.iphone .screen {
		aspect-ratio: 600 / 1303;
		border-radius: 10px;
	}

	img {
		position: absolute;
		inset: 0;
		inline-size: 100%;
		block-size: 100%;
		max-inline-size: none;
		object-fit: cover;
		color: transparent;
		opacity: 0;
	}

	img.on {
		opacity: 1;
	}

	.ipad img,
	.iphone img {
		transition: opacity 0.2s ease-out;
	}

	.static,
	.lines {
		position: absolute;
		inset: 0;
		inline-size: 100%;
		block-size: 100%;
		opacity: 0;
		pointer-events: none;
	}

	.grain {
		fill: #fff;
	}

	.lines {
		background: repeating-linear-gradient(to bottom, rgb(0 0 0 / 0.4) 0 1px, transparent 1px 3px);
	}

	.number {
		position: absolute;
		inset-block-start: 4%;
		inset-inline-start: 2.5%;
		padding: 0.1em 0.5em;
		border-radius: 0.35em;
		background: rgb(11 14 19 / 0.72);
		color: #f2f4f8;
		font-size: max(10px, 2.4cqi);
		font-weight: 700;
		font-variant-numeric: tabular-nums;
		line-height: 1.3;
	}

	.controls {
		display: flex;
		justify-content: flex-end;
		min-block-size: 36px;
		margin-block-start: 8px;
	}

	.pause {
		padding: 6px 10px;
		border: 0;
		border-radius: 8px;
		background: none;
		color: var(--muted);
		font: inherit;
		font-size: 14px;
		font-weight: 600;
		cursor: pointer;
	}

	.pause[hidden] {
		display: none;
	}

	.pause:hover {
		color: var(--text);
	}

	.pause:focus-visible {
		outline: 2px solid var(--link);
		outline-offset: 2px;
	}

	@media (prefers-reduced-motion: no-preference) {
		.tuning .static {
			animation: tune-static 1.6s linear both;
		}

		.tuning .lines {
			animation:
				tune-static 1.6s linear both,
				roll 1.6s linear both;
		}

		.tuning .grain,
		.zap .grain {
			animation: drift 1.2s ease-in-out infinite alternate;
		}

		.tuning .tv img.on {
			animation:
				power 0s 1.6s both,
				snap 0.16s cubic-bezier(0.2, 0.8, 0.3, 1) 1.6s both;
		}

		.tuning .ipad img.on,
		.tuning .iphone img.on {
			animation: appear 0.3s ease-out 1.6s both;
		}

		.tuning .number {
			animation: appear 0.2s ease-out 1.7s both;
		}

		.zap .static,
		.zap .lines {
			animation: zap-static 0.36s ease-out both;
		}

		.zap .tv img.on {
			animation: snap 0.18s cubic-bezier(0.2, 0.8, 0.3, 1) 0.12s both;
		}

		.zap .number {
			animation: pop 0.3s ease-out both;
		}
	}

	@keyframes tune-static {
		0%,
		31% {
			opacity: 0;
		}
		44%,
		96% {
			opacity: 0.45;
		}
		100% {
			opacity: 0;
		}
	}

	@keyframes roll {
		from {
			background-position: 0 0;
		}
		to {
			background-position: 0 24px;
		}
	}

	@keyframes drift {
		from {
			transform: translate(0, 0);
		}
		to {
			transform: translate(-24px, -18px);
		}
	}

	@keyframes power {
		from {
			visibility: hidden;
		}
		to {
			visibility: visible;
		}
	}

	@keyframes snap {
		from {
			transform: scale(1.04, 0.01);
		}
		to {
			transform: none;
		}
	}

	@keyframes appear {
		from {
			opacity: 0;
		}
	}

	@keyframes zap-static {
		0%,
		100% {
			opacity: 0;
		}
		30% {
			opacity: 0.35;
		}
	}

	@keyframes pop {
		from {
			opacity: 0;
			transform: scale(0.6);
		}
	}

	@media (max-width: 720px) {
		.stage {
			aspect-ratio: 100 / 95;
		}

		.tv {
			inline-size: 100%;
		}

		.ipad {
			inline-size: 38%;
			inset-inline-start: 8%;
		}

		.iphone {
			inline-size: 21%;
			inset-inline-end: 10%;
		}
	}
</style>
