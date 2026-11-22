<script lang="ts">
	import Meta from '#lib/components/Meta.svelte';
</script>

<Meta
	title="Privacy Policy"
	description="Antenna collects nothing about you. What it keeps stays on your devices and in your own iCloud."
/>

<article class="prose">
	<h1>Privacy Policy</h1>
	<p class="updated">Last updated: November 12, 2026</p>

	<p>
		This policy covers Antenna, the TV player for iPhone, iPad, Mac and Apple TV published by Code
		Crave. Antenna collects nothing about you. What you set up in the app stays on your devices and
		in your own iCloud account, and Code Crave runs no server that receives it.
	</p>

	<h2>What Antenna stores</h2>
	<p>
		Antenna keeps these in your private iCloud database and syncs them to your devices signed in to
		the same iCloud account:
	</p>
	<ul>
		<li>
			the sources you add, with their names and addresses, and the text of playlist files you import
		</li>
		<li>favorites, profiles, preferences and programme reminders</li>
		<li>
			channel groups, hidden groups, and a check value for the group passcode (never the passcode
			itself)
		</li>
		<li>watch progress, My List and recent searches</li>
	</ul>
	<p>
		Your private iCloud database belongs to your Apple Account. Code Crave cannot read it. Apple
		stores it under its own <a href="https://www.apple.com/legal/privacy/">privacy policy</a>. If a
		device is not signed in to iCloud, this data stays on that device.
	</p>
	<p>
		Some things stay on one device only: what you watched last there and other settings for that
		device, cached posters and guide data, and the notifications for your reminders.
	</p>

	<h2>Logins</h2>
	<p>
		Usernames, passwords and MAC addresses for your sources are kept in your iCloud Keychain, which
		Apple encrypts end to end, and sync to your devices from there. They are never written to the
		iCloud database or to logs.
	</p>
	<p>
		There is one exception. When you send a login from your iPhone to an Apple TV, the iPhone seals
		it with a key that exists only in that Apple TV's memory and places it in your private iCloud
		database. The Apple TV picks it up and deletes it. It stays there for at most ten minutes.
	</p>

	<h2>Network connections</h2>
	<p>Antenna connects only to:</p>
	<ul>
		<li>
			the sources and guide sources you add, and the addresses they list, such as streams, channel
			logos, posters and guide files
		</li>
		<li>Apple, for iCloud sync, the App Store and notifications</li>
	</ul>
	<p>
		Those servers see your IP address and what Antenna asks for, as with any connection, and their
		own privacy policies apply. If you tap Trailer on a movie, the trailer address your source gives
		opens outside Antenna.
	</p>
	<p>
		This website is hosted on GitHub Pages. When you open a page here, including the setup page your
		iPhone opens when Antenna is not installed, GitHub receives the request under its own <a
			href="https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement"
			>privacy statement</a
		>.
	</p>

	<h2>Analytics and tracking</h2>
	<p>
		Antenna has no analytics, crash reporting, advertising or tracking, and includes no third-party
		SDK. It does not track you across apps or websites, and Code Crave has no data about you to sell
		or share.
	</p>
	<p>
		If you have turned on sharing with app developers in your device's privacy settings, Apple may
		send Code Crave crash reports and usage statistics from Antenna. Apple controls that setting,
		and you can turn it off at any time.
	</p>

	<h2>Purchases</h2>
	<p>
		Apple handles every purchase. Antenna asks the App Store whether you have an active purchase and
		keeps the answer on the device so the app works offline. Code Crave never sees your name, your
		Apple Account or your payment details.
	</p>

	<h2>Deleting your data</h2>
	<p>
		Removing a source in Antenna's settings deletes it, its login, and its favorites, groups and
		reminders on every device signed in to your iCloud account. Remove your sources before you
		delete the app, since logins in your iCloud Keychain stay there when the app is deleted.
	</p>
	<p>
		To delete everything Antenna keeps in iCloud, open Settings on your iPhone, tap your name, then
		iCloud, then Manage Storage, and delete Antenna's data. Deleting the app removes what it kept on
		that device.
	</p>

	<h2>Children</h2>
	<p>Antenna is not aimed at children. It collects no data from anyone, children included.</p>

	<h2>Changes to this policy</h2>
	<p>
		Code Crave may change this policy. The date at the top says when it last changed, and the
		current version is always at this address.
	</p>

	<h2>Contact</h2>
	<p>
		Questions about this policy: <a href="mailto:support@code-crave.se">support@code-crave.se</a>.
	</p>

	<p class="across">Read the <a href="/terms/">Terms of Use</a>.</p>
</article>
