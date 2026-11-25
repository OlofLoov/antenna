<script lang="ts">
	// The wordmark above the home page's headline, playing Hello once as the
	// page opens and sending one Tuning ring from each tip as the TV's picture
	// snaps in (antuna-website/the-home-page-tunes-in). The shapes are the
	// header's; the times are tune-in-home-hero design.md decision 1. The
	// still mark is the default, and the motion only runs when the device does
	// not ask for reduced motion.
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
	><mask id="tune-in-cut" maskUnits="userSpaceOnUse" x="560" y="-200" width="220" height="230"
		><rect x="560" y="-200" width="220" height="230" fill="#fff" /><path
			class="hole"
			d="M659 -81L695 -59L659 -37Z"
			fill="#000"
			stroke="#000"
			stroke-width="6"
			stroke-linejoin="round"
		/><path class="mouth" d="M641 -60L605 -56.3L606 -68Z" fill="#000" /><g class="eye"
			><circle class="eye-in" cx="650" cy="-80" r="10" fill="#000" /></g
		></mask
	><g mask="url(#tune-in-cut)"
		><g class="body"
			><path
				d="M673 -118A59 59 0 0 1 673 0C640 0 616 -20 606 -46Q604 -54 611 -57L609 -61L612 -66Q610 -67 612 -72C624 -100 646 -118 673 -118Z"
				fill="currentColor"
			/><path
				d="M694 -99C694 -111 700 -119 711 -120L733 -122Q740 -122 738 -116Q726 -90 727 -59Q726 -28 738 -2Q740 4 733 4L711 2C700 1 694 -7 694 -19Z"
				fill="currentColor"
			/></g
		></g
	><g class="left"
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
	><g class="right"
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

	.mouth {
		transform-box: fill-box;
		transform-origin: 100% 64%;
	}

	.eye-in {
		transform: scale(0);
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

		.hole {
			animation: hole 3.2s ease-in-out both;
		}

		.eye-in {
			animation: eye 3.2s ease-in-out both;
		}

		.eye {
			animation: blink 0.24s ease-in-out 2.45s;
		}

		.mouth {
			animation: say 0.5s ease-in-out 1.55s both;
		}

		.left .stick {
			animation: draw 0.25s ease-out 1.05s both;
		}

		.right .stick {
			animation: draw 0.25s ease-out 1.12s both;
		}

		.tip {
			transform: scale(0);
			animation: grow 0.35s cubic-bezier(0.3, 1.8, 0.5, 1) 1.25s forwards;
		}

		.right .tip {
			animation-delay: 1.32s;
		}

		.left .ring {
			animation: ring 1.2s ease-out 1.6s forwards;
		}

		.right .ring {
			animation: ring 1.2s ease-out 1.9s forwards;
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

	@keyframes hole {
		0%,
		26% {
			transform: translate(0, 0) scale(0);
		}
		32% {
			transform: translate(0, 0) scale(1.15);
		}
		36%,
		62% {
			transform: translate(0, 0) scale(1);
		}
		70%,
		86% {
			transform: translate(-21px, -21px) scale(0);
		}
		95%,
		100% {
			transform: translate(0, 0) scale(1);
		}
	}

	@keyframes eye {
		0%,
		66% {
			transform: scale(0);
		}
		72% {
			transform: scale(1.15);
		}
		75%,
		86% {
			transform: scale(1);
		}
		90%,
		100% {
			transform: scale(0);
		}
	}

	@keyframes blink {
		0%,
		100% {
			transform: scale(1, 1);
		}
		50% {
			transform: scale(1, 0.1);
		}
	}

	@keyframes say {
		0%,
		100% {
			transform: scaleY(1);
		}
		40% {
			transform: scaleY(3);
		}
		70% {
			transform: scaleY(1.5);
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

	@keyframes fade {
		from {
			opacity: 0;
		}
	}
</style>
