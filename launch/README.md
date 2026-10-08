# Launch kit

Drafts for announcing ATT. These are not part of the template itself, so you
can delete this folder once they're posted.

| file | where | length |
|---|---|---|
| `medium-1-launch.md` | Medium: the story and the numbers | ~1,300 words |
| `medium-2-deep-dive.md` | Medium: the technical mechanisms | ~1,100 words |
| `linkedin-post.md` | LinkedIn feed post | ~200 words |
| `linkedin-article.md` | LinkedIn article: what it teaches about managing teams | ~650 words |
| `../paper/att.pdf` (+ `att.tex`, `refs.bib`) | arXiv | 7 pages |

## Facts every piece must keep straight

All numbers come from one private project, run locally, over 2026-09-30 →
2026-10-08, computed by `paper/analyze_git_history.py` from git history:

- about 432 rows filed; 365 claimed; **344 claimed rows merged** (94%); 373 recorded as merged in total
- claim → merge: **median 1.27 h**, IQR 0.63–3.19 h, p90 6.1 h; 66% within 2 h, 91% within 8 h; 19 over 24 h
- by level (median): L1 1.21 h, L2 1.25 h, L3 1.41 h
- 21 merge trains carried 177 rows; the largest had 37
- 2 reverts on the integration branch
- lessons: 56 for the tech leads and 27 for the PM (83 in total)
- before vs after the supervisor: 10.7 h (n=30) → 1.2 h (n=314). This is confounded; never present it as caused by the supervisor alone.
- It is a **field study, not a benchmark**. Keep that caveat in every piece.

## arXiv checklist

1. Replace `<email>` in `paper/att.tex` with a contact address.
2. Primary category **cs.SE** (Software Engineering); cross-list **cs.AI**
   and **cs.MA** (Multiagent Systems).
3. A first-time submitter needs an **endorsement** for cs.SE: ask someone who
   has published there, or use arXiv's endorsement request flow.
4. Upload the source rather than the PDF: `att.tex`, `refs.bib` and the
   generated `att.bbl` (arXiv does not run BibTeX). Build locally with
   `pdflatex att && bibtex att && pdflatex att && pdflatex att`.
5. Licence: CC BY 4.0 is the usual choice for wide reuse.

## Suggested order

1. Make the repo public, add a LICENSE, and check that the README badges render.
2. Submit to arXiv. Listing takes 1–2 working days; then add the arXiv badge
   and link to the README.
3. Publish Medium post 1 and link the repo and the paper.
4. Post on LinkedIn the same day, linking the repo. Post the LinkedIn article a
   few days later.
5. Publish Medium post 2 about a week later. Cross-post to dev.to, Hacker News
   ("Show HN"), r/ClaudeAI and r/programming.
