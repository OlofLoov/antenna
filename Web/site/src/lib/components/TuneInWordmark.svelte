<script lang="ts">
	// The wordmark above the home page's headline (antuna-website/the-home-page-tunes-in).
	// It draws on, plays one loop of Tuning while the TV searches for a
	// signal and Got it as the picture snaps in, then stands still
	// (tuning-on-the-home-hero design.md decision 1, with the app's
	// MarkMotion keyframes). The triangle, the mouth and the eye are shapes
	// in the ground color over the head, so they move the same in every
	// browser. `held` stops it where it is (the-tv-zaps-through-the-app).
	let { held = false }: { held?: boolean } = $props();

	const letters = [
		'M99.0 -59.0A40.0 40.0 0 1 0 19.0 -59.0A40.0 40.0 0 1 0 99.0 -59.0M99.0 -99.0V-19.0',
		'M147.0 -19.0V-99.0M147.0 -59.0A40.0 40.0 0 0 1 227.0 -59.0V-19.0',
		'M289.0 -139.0V-59.0A40.0 40.0 0 0 0 329.0 -19.0M275.0 -99.0H323.0',
		'M377.0 -99.0V-59.0A40.0 40.0 0 0 0 457.0 -59.0M457.0 -99.0V-19.0',
		'M505.0 -19.0V-99.0M505.0 -59.0A40.0 40.0 0 0 1 585.0 -59.0V-19.0'
	];
</script>

<svg
	class="mark"
	class:held
	aria-hidden="true"
	focusable="false"
	width="300"
	height="78"
	viewBox="-6 -192 760 198"
	><g
		fill="none"
		stroke="currentColor"
		stroke-width="38"
		stroke-linecap="round"
		stroke-linejoin="round"
		>{#each letters as d (d)}<path class="letter" {d} pathLength="1" />{/each}</g
	><g class="body"
		><path
			d="M673 -118A59 59 0 0 1 673 0C640 0 616 -20 606 -46Q604 -54 611 -57L609 -61L612 -66Q610 -67 612 -72C624 -100 646 -118 673 -118Z"
			fill="currentColor"
		/><path
			class="tail"
			d="M694 -99C694 -111 700 -119 711 -120L733 -122Q740 -122 738 -116Q726 -90 727 -59Q726 -28 738 -2Q740 4 733 4L711 2C700 1 694 -7 694 -19Z"
			fill="currentColor"
		/><path class="mouth cut" d="M641 -60L605 -56.3L606 -68Z" /><path
			class="hole cut"
			d="M659 -81L695 -59L659 -37Z"
			stroke-width="6"
			stroke-linejoin="round"
		/><g class="eye"><g class="look"><circle class="eye-in cut" cx="650" cy="-80" r="10" /></g></g
		></g
	><g class="antenna left"
		><path
			class="stick"
			d="M656 -112L640 -140"
			stroke="currentColor"
			stroke-width="11"
			stroke-linecap="round"
			pathLength="1"
		/><circle class="ring" cx="635.0" cy="-148.7" r="10" /><circle
			class="tip"
			cx="635.0"
			cy="-148.7"
			r="10"
		/></g
	><g class="antenna right"
		><path
			class="stick"
			d="M690 -112L704 -141"
			stroke="currentColor"
			stroke-width="11"
			stroke-linecap="round"
			pathLength="1"
		/><circle class="ring" cx="708.3" cy="-150.0" r="10" /><circle
			class="tip"
			cx="708.3"
			cy="-150.0"
			r="10"
		/></g
	></svg
>

<style>
	.mark {
		display: block;
		inline-size: min(300px, 70%);
		block-size: auto;
		color: var(--text);
		overflow: visible;
	}

	.cut {
		fill: var(--bg);
		stroke: var(--bg);
	}

	.mouth,
	.eye-in {
		stroke: none;
	}

	.tip {
		fill: var(--tip);
	}

	.ring {
		fill: none;
		stroke: var(--tip);
		stroke-width: 3;
		opacity: 0;
	}

	.body,
	.hole,
	.eye,
	.eye-in,
	.tip,
	.ring {
		transform-box: fill-box;
		transform-origin: center;
	}

	.tail {
		transform-box: fill-box;
		transform-origin: 0% 50%;
	}

	.mouth {
		transform-box: fill-box;
		transform-origin: 100% 64%;
	}

	.antenna {
		transform-box: view-box;
	}

	.left {
		transform-origin: 656px -112px;
	}

	.right {
		transform-origin: 690px -112px;
	}

	.eye-in {
		transform: scale(0);
	}

	/* Important, since each animation shorthand below sets the play state too. */
	.held,
	.held :global(*) {
		animation-play-state: paused !important;
	}

	@media (prefers-reduced-motion: no-preference) {
		.letter,
		.stick {
			stroke-dasharray: 1;
			animation: draw 0.55s cubic-bezier(0.5, 0, 0.3, 1) both;
		}

		.letter:nth-child(2) {
			animation-delay: 0.09s;
		}

		.letter:nth-child(3) {
			animation-delay: 0.18s;
		}

		.letter:nth-child(4) {
			animation-delay: 0.27s;
		}

		.letter:nth-child(5) {
			animation-delay: 0.36s;
		}

		.body {
			transform: scale(0);
			animation: grow 0.45s cubic-bezier(0.3, 1.5, 0.5, 1) 0.5s forwards;
		}

		.left .stick {
			animation: draw 0.25s ease-out 1.05s both;
		}

		.right .stick {
			animation: draw 0.25s ease-out 1.12s both;
		}

		.tip {
			transform: scale(0);
			animation:
				grow 0.35s cubic-bezier(0.3, 1.8, 0.5, 1) 1.25s forwards,
				hop 0.45s cubic-bezier(0.3, 0, 0.4, 1) 4.3s;
		}

		.right .tip {
			animation:
				grow 0.35s cubic-bezier(0.3, 1.8, 0.5, 1) 1.32s forwards,
				hop 0.45s cubic-bezier(0.3, 0, 0.4, 1) 4.38s;
		}

		.left {
			animation: lean-left 2.4s ease-in-out 1.6s;
		}

		.right {
			animation: lean-right 2.4s ease-in-out 1.6s;
		}

		.left .ring {
			animation: ring 1.2s ease-out 1.6s 2;
		}

		.right .ring {
			animation: ring 1.2s ease-out 2.2s 2;
		}

		.look {
			animation: look 2.4s ease-in-out 1.6s;
		}

		.hole {
			transform: scale(0);
			animation:
				open 0.3s cubic-bezier(0.3, 1.4, 0.5, 1) 0.83s forwards,
				to-eye 0.35s ease-in 1.6s forwards,
				back 1.2s ease-in-out 4s forwards;
		}

		.eye-in {
			animation:
				grow 0.3s cubic-bezier(0.3, 1.6, 0.5, 1) 1.85s forwards,
				shrink 1.2s ease-in-out 4s forwards;
		}

		.eye {
			animation:
				blink 2.4s ease-in-out 1.6s,
				squint 1.2s ease-in-out 4s;
		}

		.mouth {
			animation:
				breathe 2.4s ease-in-out 1.6s,
				gulp 0.6s ease-out 4.1s;
		}

		.tail {
			animation: flick 0.7s ease-out 4.15s;
		}
	}

	@media (prefers-reduced-motion: reduce) {
		.mark {
			animation: fade 0.4s ease-out both;
		}
	}

	@keyframes draw {
		from {
			stroke-dashoffset: 1;
			opacity: 0;
		}
		4% {
			opacity: 1;
		}
		to {
			stroke-dashoffset: 0;
			opacity: 1;
		}
	}

	@keyframes grow {
		to {
			transform: scale(1);
		}
	}

	@keyframes open {
		from {
			transform: translate(0, 0) scale(0);
		}
		to {
			transform: translate(0, 0) scale(1);
		}
	}

	@keyframes to-eye {
		from {
			transform: translate(0, 0) scale(1);
		}
		to {
			transform: translate(-21px, -21px) scale(0);
		}
	}

	@keyframes back {
		0%,
		52% {
			transform: translate(-21px, -21px) scale(0);
		}
		80% {
			transform: translate(0, 0) scale(1.12);
		}
		90%,
		100% {
			transform: translate(0, 0) scale(1);
		}
	}

	@keyframes shrink {
		0%,
		50% {
			transform: scale(1);
		}
		60%,
		100% {
			transform: scale(0);
		}
	}

	@keyframes lean-left {
		0%,
		100% {
			transform: rotate(0);
		}
		30% {
			transform: rotate(-14deg);
		}
		65% {
			transform: rotate(9deg);
		}
	}

	@keyframes lean-right {
		0%,
		100% {
			transform: rotate(0);
		}
		30% {
			transform: rotate(-9deg);
		}
		65% {
			transform: rotate(14deg);
		}
	}

	@keyframes ring {
		from {
			opacity: 0.7;
			transform: scale(1);
		}
		to {
			opacity: 0;
			transform: scale(2.6);
		}
	}

	@keyframes look {
		0%,
		100% {
			transform: translate(0, 0);
		}
		30% {
			transform: translate(-3px, -1px);
		}
		60% {
			transform: translate(3px, -1px);
		}
	}

	@keyframes blink {
		0%,
		80%,
		92%,
		100% {
			transform: scale(1, 1);
		}
		86% {
			transform: scale(1, 0.1);
		}
	}

	@keyframes squint {
		0%,
		100% {
			transform: scale(1, 1);
		}
		12%,
		40% {
			transform: scale(1.15, 0.4);
		}
	}

	@keyframes breathe {
		0%,
		100% {
			transform: scaleY(1);
		}
		50% {
			transform: scaleY(2.1);
		}
	}

	@keyframes gulp {
		0%,
		100% {
			transform: scaleY(1);
		}
		30% {
			transform: scaleY(3.4);
		}
		55% {
			transform: scaleY(1);
		}
		75% {
			transform: scaleY(1.8);
		}
	}

	@keyframes flick {
		0%,
		100% {
			transform: skewY(0);
		}
		25% {
			transform: skewY(-20deg);
		}
		55% {
			transform: skewY(12deg);
		}
		80% {
			transform: skewY(-3deg);
		}
	}

	@keyframes hop {
		0%,
		100% {
			transform: translateY(0);
		}
		45% {
			transform: translateY(-9px);
		}
	}

	@keyframes fade {
		from {
			opacity: 0;
		}
	}
</style>
