// The home page hero's channels and timeline (tune-in-home-hero design.md
// decisions 4 and 5, tuning-on-the-home-hero design.md decisions 1 and 6).
// The CSS in TuneInWordmark.svelte and TuneInStage.svelte plays the same
// times; the tests read them here.

import type sizes from '#lib/screenshots.en.json';

type Shot = keyof typeof sizes;

/** One channel: the screenshot each device shows while it is on. */
export interface Channel {
	tv: Shot;
	ipad: Shot;
	iphone: Shot;
}

/** The devices in the order the stage draws them. */
export const devices = ['tv', 'ipad', 'iphone'] as const;

/** Live, the guide, Movies and the player, in the order the TV zaps through them. */
export const channels: Channel[] = [
	{ tv: 'apple-tv-live.jpg', ipad: 'live-tv-ipad.jpg', iphone: 'live-iphone.jpg' },
	{ tv: 'guide-apple-tv.jpg', ipad: 'guide-ipad.jpg', iphone: 'guide-iphone.jpg' },
	{ tv: 'movies-apple-tv.jpg', ipad: 'movies-ipad.jpg', iphone: 'movies-iphone.jpg' },
	{ tv: 'player-apple-tv.jpg', ipad: 'player-ipad.jpg', iphone: 'player-iphone.jpg' }
];

/** Milliseconds from the first paint, as the CSS animations count them. */
export const timing = {
	/** The static fades in. */
	staticFrom: 500,
	/** The wordmark has drawn on and starts one loop of Tuning. */
	tuningFrom: 1600,
	/** One loop of Tuning, as in the app. */
	tuningLoop: 2400,
	/** The static goes, the picture opens and the wordmark plays Got it. */
	picture: 4000,
	/** The picture opening from a line. */
	snap: 160,
	/** Got it, from the picture to the still mark. */
	gotIt: 1200,
	/** One ring, from the tip to gone. */
	ring: 1200,
	/** The right tip's rings follow the left's by this much. */
	secondRing: 600,
	/** From one zap to the next, and from the tune-in to the first. */
	zapEvery: 4000,
	/** One zap, from the picture going to the next one fully open. */
	zap: 360
} as const;

/** The channel after `index`, back to the first after the last. */
export function nextChannel(index: number, count = channels.length): number {
	return (index + 1) % count;
}

/** What decides whether the TV may zap right now. */
export interface ZapState {
	/** The device asks for reduced motion. */
	reducedMotion: boolean;
	/** The tune-in's animations have finished. */
	tuned: boolean;
	/** Some of the stage is inside the window. */
	onScreen: boolean;
	/** The tab is in front. */
	tabVisible: boolean;
	/** The visitor pressed Pause channels. */
	paused: boolean;
}

/** True when nothing holds the channels back. */
export function mayZap(state: ZapState): boolean {
	return !state.reducedMotion && state.tuned && mayAnimate(state);
}

/**
 * True when the tune-in, the wordmark and the zaps may move: the hero is
 * on screen, the tab is in front and Pause channels is off.
 */
export function mayAnimate(state: Pick<ZapState, 'onScreen' | 'tabVisible' | 'paused'>) {
	return state.onScreen && state.tabVisible && !state.paused;
}

/** True when the devices may follow the pointer and the scroll. */
export function mayDrift(state: Pick<ZapState, 'reducedMotion' | 'onScreen' | 'tabVisible'>) {
	return !state.reducedMotion && state.onScreen && state.tabVisible;
}

/**
 * How far the devices drift, from -1 to 1 on each axis, for a pointer at
 * (x, y) in a window of the given size.
 */
export function pointerDrift(x: number, y: number, width: number, height: number) {
	const clamp = (value: number) => Math.max(-1, Math.min(1, value));
	return {
		x: width > 0 ? clamp((x / width) * 2 - 1) : 0,
		y: height > 0 ? clamp((y / height) * 2 - 1) : 0
	};
}

/**
 * How far the hero has scrolled out of the window's top, from 0 while its
 * top is in view to 1 once it is gone.
 */
export function scrollDrift(top: number, height: number) {
	if (height <= 0) return 0;
	return Math.max(0, Math.min(1, -top / height));
}
