# Drop workflows: what stays built in

The drop experience can absorb an unlimited number of file actions, and most of them
would make it worse. This document is the verdict on which workflows FlowDock ships
itself and which belong to the extension surface described in section 7 of
[ROADMAP.md](ROADMAP.md). It is written once, here, so the answer to "can we add just
one more action" is a reference rather than an argument.

## The test

A workflow stays built in when it passes all four:

1. **It is the drop, not a use of the drop.** Holding, moving, and handing off content is
   what the shelf is. An action that only happens to start from a file is a use of it.
2. **It works with no account, no network, and no configuration.** Anything needing
   credentials or a service URL has an owner, and that owner is not FlowDock.
3. **The system already carries the weight.** Quick Look, the sharing services, Vision,
   Image I/O, and the archive tools are on every Mac. A workflow that would ship a
   library or a binary is not built in.
4. **It applies to what people actually drop.** Files, images, links, and text. Not one
   file format's ecosystem.

An action that fails any of these is not rejected — it is an extension.

## Built in

| Workflow | Why it stays |
|---|---|
| Hold, select, reorder by drag-out, clear | This is the shelf itself (1) |
| Drag out to any app, with copy or move | The point of holding anything (1) |
| AirDrop and the system share services | The system's own handoff, no account of ours (1, 2, 3) |
| Quick Look preview | The system preview, one keystroke from any selection (2, 3) |
| Compress to a zip archive | Universal, offline, and the most common thing done to several files at once (2, 3, 4) |
| Convert an image's format and size | Image I/O, offline, and the most common thing done to one image (2, 3, 4) |
| Remove an image background | Vision does it offline; nothing else on the Mac offers it in one click (2, 3, 4) |
| Images to a PDF | Offline, and the only way most people combine screenshots (2, 3, 4) |
| Rename, reveal, copy path, open, open with | Finder verbs people expect wherever a file is shown (1, 2, 3) |

## Extensions

| Workflow | Which test it fails |
|---|---|
| Upload to Dropbox, Drive, S3, or any host | 2 — an account and a network |
| Post to Slack, Discord, or a chat service | 2 — an account, and the share services already cover the polite version |
| OCR, transcription, translation, summarizing | 4, and each is a product rather than an action |
| Video and audio conversion | 3 — that is ffmpeg, and shipping it is a decision about FlowDock's size |
| Watermarking, resizing presets, batch renaming rules | 4 — a photographer's workflow, not everyone's |
| Signing, encrypting, redacting | 2 — key material belongs to a tool that manages key material |
| Sending to a specific app's inbox: Things, Obsidian, Bear | 4 — the app that benefits should ship the extension |
| Git, deploy, and other developer verbs | 4 — an audience, not a default |

## Consequences

- The built-in list above is closed. A new built-in workflow requires this document to
  change first, with the test it passes named.
- Every extension workflow gets the same room the built-in ones have: the action row,
  the overflow menu, and the shelf's selection. Section 7 is what makes that true; until
  it lands, the list above is also the list of what FlowDock can do to a file.
- Nothing in the built-in list may grow a setting to configure a service. The moment a
  workflow needs a field, it has failed test 2 and belongs on the other side.
