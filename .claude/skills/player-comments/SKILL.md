---
name: player-comments
description: Use for Khutir Road's itch.io comments: reading them (the game's page, the jam pages), what players ask for and which of it goes into the next version, and answering them. "збери коментарі", "що пишуть гравці", "відповідай на коментарі", "read the comments", "reply to players".
---

# Player comments

The ledger is `media/comments.md`: its Sources table (the pages to read), the changelog
candidates, every comment with its status. Read it first; every step below ends in it.

## Collect

1. For each page in Sources, read every comment in Chrome (the owner is logged in there; WebFetch
   only summarises). On the page run JS that returns arrays, not objects: the browser tool blanks
   values under keys like `author`.
   ```js
   [...document.querySelectorAll('.community_post')].map(p => [p.id,
     (p.querySelector('.post_author') || {}).innerText, (p.querySelector('.post_date') || {}).title,
     (p.querySelector('.post_body') || {}).innerText, !!p.parentElement.closest('.community_post_replies')])
   ```
   The last field is "a reply". A post by Codirs is the owner's answer; the date is the post
   date's `title` (its text is relative, "2 days ago"). Some pages page their comments: follow
   "Next page" to the end. A new jam the game is in shows on the game's page as a link to
   `itch.io/jam/<jam>/rate/5228452`: add it to Sources.
2. Every comment not in the ledger goes into it, under its page, with its post id, author, date, a
   faithful summary (quote what is short) and status **new**.
   Done when every comment on every source page is in the ledger.

## Analyse

3. For each **new** comment: split it into its asks (a bug, a change, a feature, a question) and
   check each against the code and `CHANGELOG.md`: done already (say in which version), half done,
   or not there. A bug report gets reproduced before it is called a bug, the way it says (the web
   build for a web report; a headless script under `--fixed-fps 60` when the bug is in the
   game's own logic).
4. Each ask that is not done becomes a candidate under "Next release: candidates": `[ ]`, what to do
   in a player's words, who asked, and an honest size (an hour, a day, a release of its own).
   Mark the comment **open** (an answer is owed) or **answered**.
   Done when no comment is **new**.

## Pick

5. Show the owner the candidates as one numbered list (what, who, size, your recommendation) and
   ask which go into the next version. Their picks become `[x]`; nothing is built that is not
   picked. When a picked one ships, its CHANGELOG line names who asked ("asked for by Philip") and
   it leaves the list.

## Answer

6. For every **open** or **promised** comment whose answer is ready (what it asked for has shipped,
   or it needs no change): draft the reply in the owner's voice, as Codirs's earlier answers read
   (thanks first, then what changed and in which version, keys and buttons named, no promise the
   ledger does not hold); the owner's smiley is `:0)`. Show the owner every draft at once; post
   only the ones approved, word for word.
7. Posting, in Chrome on the comment's page: click that comment's **Reply** (the one under the
   comment being answered, `#post-<id>`). On the game's page a box opens under the comment; on a
   jam's page it goes to `itch.io/post/<id>/reply` ("Replying to a post by <author>"). The editor
   is a Redactor box over a hidden textarea: click inside the box (`[contenteditable="true"]`;
   screenshot coordinates are the page's CSS pixels times the screenshot's scale), type, then
   check that `textarea[name="post[body]"]` holds the text and the form's action is
   `.../post/<id>/reply` before **Post** / **Post reply**. The page comes back at `#post-<new id>`:
   that post is by Codirs, holds the text, and sits in the `.community_post_replies` right after
   `#post-<id>`.
8. Record each answer in the ledger: its post id and date, the status **answered** (or
   **promised**, with what was promised). Report the links.
   Done when every approved reply is on its page and in the ledger.

When the owner points at a comment by a link that is not in the conversation, ask for the link.
