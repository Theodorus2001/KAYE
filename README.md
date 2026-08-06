# KAYE

**A learning management system built for Haiti **

*Kaye* means "notebook" in Kreyòl. That's the idea: the notebook every Haitian student already carries, made digital, in the languages they actually speak.

---

## Why this exists

Education technology has transformed how schools work over the last decade. Canvas, Blackboard, Moodle and Google Classroom now run the daily rhythm of millions of classrooms — assignments posted and collected, grades tracked, parents kept informed, teachers freed from paperwork.

Haitian schools have largely been left out of that shift. Not because the need is smaller, but because these platforms were never designed with Haiti in mind:

- **Language.** Kreyòl is the language nearly every Haitian speaks. French is the language of school administration. Global platforms offer neither as a first-class experience — Kreyòl is usually absent entirely.
- **Connectivity.** These systems assume reliable broadband. They load heavy assets, expect a constant connection, and break down on intermittent mobile data.
- **Devices.** They're built desktop-first, assuming one student to one laptop. In Haiti, access is more often a shared phone.
- **Cost and complexity.** Enterprise licensing and administrative overhead put them out of reach for most schools here.

Meanwhile the fundamentals still run on paper and WhatsApp. Assignments are handed out as photocopies and collected by hand. Deadlines are announced out loud and forgotten. Grades live in a teacher's private notebook until report cards. Nobody — not the student, not the parent, not the school — can see how a term is actually going until it's over.

The technology to fix this isn't new. It just hasn't been built for here.

**KAYE is that: an LMS designed from the ground up around Haitian schools, in French and Kreyòl, for phones and patchy connections.**

---

## What we're trying to make easier

For **teachers**, the daily grind is collecting work, grading it, and recording marks. KAYE gives them assignments and quizzes that collect themselves, a grading view where they move through a whole class without opening files one at a time, and a gradebook that fills in as they go. Less admin, more teaching.

For **students**, the problem is knowing what's due and where they stand. KAYE puts every deadline across every course on one screen, keeps course material in one place, and shows grades and teacher feedback as soon as they're posted — not weeks later.

For **school administrators**, the problem is visibility. KAYE shows enrollment, attendance, submission rates and grade trends across the school, so problems surface while there's still time to act on them.

---

## The plan

We're deliberately starting small.

**Phase 1 — One classroom.**
The pilot is at Saint-François-Xavier (SFXO), with a single classroom. One teacher, one group of students, one term. The goal isn't scale — it's finding out what actually breaks when real people use this: where the connection fails, where the interface confuses, what teachers quietly stop bothering to do. A single classroom is small enough to fix things quickly and honestly.

**Phase 2 — The whole school.**
If the classroom works, we extend across SFXO. This is where the harder problems appear: many teachers with different habits, full enrollment management, parents wanting access, school-wide reporting.

**Phase 3 — More schools.**
Other institutions, each with their own roster and branding, on shared infrastructure.

**Long term — national reach.**
The ambition is for KAYE to become the platform Haitian schools use, potentially at a national level. We're clear-eyed that this is years away and depends on much more than software — institutional trust, funding, policy, infrastructure. We're not designing for that today. We're designing so it stays possible.

The reasoning throughout: an LMS that genuinely works for one Haitian classroom is worth more than one that theoretically works for a thousand.

---

## What's in this repository

A working interactive prototype of the platform — one self-contained HTML file. No build step, no dependencies, no backend. Open it and it runs.

It exists to make the concept tangible: something a teacher, a school director or a funder can click through and react to, rather than a document describing what we intend to build.

### Try it

Open `index.html` in any browser, or visit the live version if GitHub Pages is enabled:

```
https://<your-username>.github.io/kaye-lms/
```

**Any email and password logs you in** — there's no authentication behind it. Choose a role first:

| Role | You sign in as | What you see |
|---|---|---|
| **Étudiant** | Pam Doe | The student experience — 10 sections |
| **Enseignant** | Dr. Jean-Baptiste | The teaching workspace — 10 sections |
| **Admin** | Mme Étienne | The school console — 9 sections |

Every section is clickable and drills through to real detail pages. The FR / Kreyòl toggle in the header works throughout.

---

## What the prototype demonstrates

### Student

A dashboard pulling deadlines from every course into one to-do list, with progress and unread counts at a glance. Courses open into modules, video lessons, assignments, quizzes, discussion forums and classmates. Assignments accept a PDF upload or typed text, save drafts, and once graded show the teacher's written feedback alongside a rubric breakdown. Quizzes auto-grade — numeric and multiple choice — telling students immediately what they got wrong and why, with limited retries. Grades break down per course with a trend chart. A month calendar places every deadline on its due date. Plus messaging with teachers, forums, announcements, a file library, and account settings.

### Teacher

A dashboard leading with what needs doing: copies waiting to be graded, and students falling behind, flagged automatically by grade and attendance. The course workspace handles module publishing, assignment creation, a quiz builder with a randomized question bank, and a class roster. Grading is the centerpiece — pick a student, score against a rubric that auto-totals, save and advance straight to the next student, with marks written through to the gradebook as you go. Plus a gradebook with CSV export, a live-class view with polling and breakout rooms, an AI assistant that drafts a module outline from a plain description, and class analytics.

### Administrator

Pending account approvals and courses nearing capacity, surfaced on arrival. User management with role filters and per-user controls. Enrollment tracking, course management, reports with charts and exports, integrations (LTI, similarity detection, video, SMS to families, SIS export), and system settings covering grading scale, term dates, security policy and maintenance.

---

## Design

The visual identity comes from the KAYE mark — a notebook page and a mountain peak, in violet and orange.

| Colour | Hex | Used for |
|---|---|---|
| Violet | `#4C3C9C` | Primary actions, active navigation |
| Deep violet | `#241B54` | Login screen, gradients |
| Orange | `#FF6A45` | Accents, deadlines, urgency |

The interface is deliberately restrained — white space, clear type, no clutter. Many users will be meeting an LMS for the first time, on a small screen, and unfamiliar software shouldn't become another obstacle to learning.

Built with Tailwind CSS via CDN and inline SVG icons. The logo is embedded as base64 so the file has zero external dependencies.

---

## Honest limitations

This is a **UI prototype**, not a working product:

- No backend, database or real authentication — any credentials get you in
- All data lives in memory and resets when you refresh
- File uploads, downloads, video, live classes and the AI assistant are simulated
- Kreyòl covers navigation, dashboards and shared interface text; course content and longer body copy are still French-only. Full Kreyòl is a content task rather than a code task, and it matters enough that it shouldn't be machine-translated
- No accessibility audit yet
- Offline support — the real low-bandwidth requirement — isn't implemented

None of this is hidden. The prototype's job is to test whether the concept and the workflows are right before any of it gets built for real.

---

## Further reading

`KAYE-LMS-PRD.md` is the full product requirements document: personas, scope by role, technical requirements for low-bandwidth deployment, success metrics for the pilot, risks, and the phased roadmap.

## Files

```
index.html            The complete prototype (single file)
README.md             This document
KAYE-LMS-PRD.md       Product requirements document
kaye-logo-white.png   Transparent logo for dark backgrounds
PUSH-TO-GITHUB.md     Deployment instructions
LICENSE               MIT
```

---

*Built for Haitian schools, starting with one classroom at Saint-François-Xavier.*
