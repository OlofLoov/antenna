# Tasks

## 1. Fix

- [ ] 1.1 A film on the demuxer asks for `bytes=0-`; a 206 marks it as able to skip, with the length from Content-Range
- [ ] 1.2 A skip during a skip uses the last start of the film
- [ ] 1.3 A reopening skip closes the old connection before the new one opens
- [ ] 1.4 Apple's player skips in a ready film whose seekable ranges are briefly empty
- [ ] 1.5 Positions carry `canSkip`; the transport shows "This stream can't skip" with the controls and ignores skips when it is false
- [ ] 1.6 The fixture server can take ranges without saying so, and can redirect
- [ ] 1.7 Tests: a quiet server skips, a redirect skips, a skip during a skip lands, a server without ranges reports it up front, the transport names it before a press

## 2. Verify

- [ ] 2.1 Each requirement has a test citing `<capability>/<requirement-slug>`
- [ ] 2.2 `/opsx:verify` passes
