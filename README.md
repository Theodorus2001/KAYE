# KAYE

A learning management system built for Haiti, not adapted to it.

Kaye means notebook in Kreyòl. That is the idea behind the name: the notebook every Haitian student already carries, made digital, in the languages they actually speak.

## Why this exists

Education technology has reshaped how schools operate over the last decade. Canvas, Blackboard, Moodle and Google Classroom now run the daily rhythm of millions of classrooms. Assignments are posted and collected online, grades are tracked continuously, parents stay informed, and teachers spend less time on paperwork.

Haitian schools have largely been left out of that shift. The need is not smaller here. The platforms were simply never designed with Haiti in mind.

Kreyòl is the language nearly every Haitian speaks, and French is the language of school administration. Global platforms treat neither as a first class experience, and Kreyòl is usually missing entirely. These systems also assume reliable broadband. They load heavy assets, expect a constant connection, and degrade badly on intermittent mobile data. They are built desktop first, on the assumption of one student to one laptop, while access in Haiti is more often a shared phone. On top of all that, enterprise licensing and administrative overhead put them out of reach for most schools here.

So the fundamentals still run on paper and WhatsApp. Assignments are handed out as photocopies and collected by hand. Deadlines are announced out loud and forgotten. Grades sit in a teacher's private notebook until report cards go out. Nobody, not the student, not the parent, not the school, can see how a term is actually going until it is already over.

The technology to solve this is not new. It just has not been built for here.

KAYE is that system: an LMS designed from the ground up around Haitian schools, in French and Kreyòl, for phones and unreliable connections.

## What KAYE is trying to make easier

For teachers, the daily grind is collecting work, grading it, and recording marks. KAYE gives them assignments and quizzes that collect themselves, a grading view that moves through an entire class without opening files one at a time, and a gradebook that fills in as they work. Less administration, more teaching.

For students, the difficulty is knowing what is due and where they stand. KAYE puts every deadline from every course on one screen, keeps course material in one place, and shows grades and teacher feedback the moment they are posted rather than weeks later.

For school administrators, the difficulty is visibility. KAYE surfaces enrollment, attendance, submission rates and grade trends across the school, so problems appear while there is still time to act on them.

## The prototype

This repository contains a complete, working interactive prototype of the platform. It is one self contained HTML file. There is no build step, nothing to install, and no server required. Open it and it runs.

Its purpose is to make the concept tangible. A teacher, a school director or a funder can click through the whole system and react to it, rather than reading a document describing what we intend to build.

### Signing in

Open `index.html` in any browser. If GitHub Pages is enabled on this repository, the live version is at:

```
https://<your-username>.github.io/KAYE/
```

The login screen has three role tabs. Pick one, then enter any email and any password. There is no authentication behind it, so anything you type will work.

| Role | Signs you in as | Sections |
| --- | --- | --- |
| Étudiant | Pam Doe | 10 |
| Enseignant | Dr. Jean-Baptiste | 10 |
| Admin | Mme Étienne | 9 |

Each role loads an entirely different application: its own navigation, its own pages, its own data. The language toggle in the header switches the interface between French and Kreyòl at any point, in any role.

### The student space

The dashboard opens on a violet banner showing the next class, the student's name, and four live figures: active courses, assignments outstanding, average progress and unread messages. Below it, a single to do list gathers every pending assignment across all four courses, sorted by due date, each one clickable straight through to its submission page. Beside that runs an activity feed of recent grades, deadline reminders and school announcements, each linking to the relevant screen.

Courses are shown as cards with a coloured header bar, a subject icon, the current letter grade and a progress bar. Opening a course reveals five tabs. Modules lists the units of the course with completion ticks, a locked module that cannot be opened until the previous one is finished, and individual items for readings, videos, quizzes and assignments. Devoirs lists the assignments. Quiz lists the assessments. Forums holds the class discussion threads. Participants shows the teacher, with a direct message shortcut, and the other students in the class.

An assignment page shows the instructions, a button to download the teacher's brief, and a submission panel that accepts either a PDF upload or typed text, with the option to save a draft before submitting. Once a piece of work has been graded, the submission panel is replaced by the teacher's written feedback and a rubric breakdown showing the score earned against each criterion.

Quizzes are genuinely interactive. Questions come in two forms, numeric entry and multiple choice. On submission the quiz grades itself, marks each question right or wrong, reveals the correct answer where the student got it wrong, and shows a total. Attempts are limited, and the retry button disappears once the limit is reached.

Notes gives the overall average and a per course breakdown. Opening a course from there lists every graded assessment with its date and score, followed by a bar chart of how the student's marks have moved across the term.

The calendar renders a real month grid with every assignment deadline placed on its due date, colour coded by course and clickable through to the assignment. Beneath it sits the weekly class schedule with times and room numbers.

Messagerie holds one conversation thread per teacher, with unread indicators that clear when a thread is opened and feed the counter on the dashboard. Messages can be typed and sent. Forums allow replies to class discussion threads. Annonces carries school wide notices. Bibliothèque lists course files with their sizes. Paramètres covers profile details, password and two factor settings, five notification preferences, and language, timezone and data saving options.

### The teacher space

The dashboard leads with the work that needs doing. It shows how many scripts are waiting to be graded and lists them individually, and separately flags students who are falling behind, identified automatically from their average grade and attendance record, with a button to contact them.

The course workspace has five tabs. Modules allows each unit to be published to students and each item within it to be edited. Devoirs lists assignments with their submission counts, showing how many of the class have handed in. Quiz is a full quiz builder with a title, a time limit, a toggle for drawing questions randomly from a bank so each student receives a different selection, and a checklist of questions tagged by type. Liste des élèves is the roster with each student's average, attendance percentage and risk status. Forums shows the class discussions.

Correction is the centrepiece of the teacher experience. The class roster runs down the left with a status marker against each student showing graded, awaiting grading, or nothing submitted. The centre pane holds the submitted document with annotation tools and a comment box. The right pane holds the grading rubric, where clicking a score against each criterion automatically totals the mark. Saving advances immediately to the next student in the roster, and the mark is written straight through into the gradebook.

Carnet de notes is the gradebook: a grid of every student against every assessment, with the student column pinned so it stays visible while scrolling sideways, colour coded averages, and CSV export.

Classe en direct provides a live teaching view with a broadcast area, participant count, microphone and camera controls, a live poll students can answer with results updating in real time, breakout room assignments, and file sharing with the class.

Assistant IA takes a plain description of a module and generates a draft outline: proposed lessons, a proposed quiz with question count and duration, and a discussion prompt, all clearly marked for review before publication.

Analytique reports the class average, average attendance, submission rate and number of at risk students, alongside a distribution of grades across bands and a chart of average performance on each assessment.

### The administrator space

The dashboard reports total students, teachers, active courses and the percentage of available places filled. It then surfaces the items requiring attention: accounts awaiting approval, which can be approved directly from the dashboard, and courses approaching capacity, which can be expanded. An activity log records recent administrative actions.

Utilisateurs lists everyone in the institution with filters by role. Each entry opens a full detail page with editable name, email and identifier, a role selector, toggles for account status, two factor authentication and SMS notifications, and actions to save, reset the password, or deactivate the account.

Inscriptions tracks enrollment against capacity for every course, with a bar showing how full each is, and lists the students enrolled in a given course with the option to remove them.

Cours manages the course catalogue with each course's code, teacher, schedule and room, and options to edit or archive.

Rapports offers four exportable reports covering grades, attendance, submission rates and login activity, along with institution wide statistics and charts of average performance by course and attendance by student.

Intégrations covers the external systems a school might connect: LTI 1.3 for third party tools, similarity detection for submitted work, video conferencing, SMS notifications to families, and CSV export to a school information system. Each has a working toggle. An API key panel sits below with copy and regenerate actions.

Système reports uptime, storage used, last backup and version number. It holds institution settings including name, code, grading scale and active term, security policies such as mandatory two factor authentication for staff, detailed audit logging and low bandwidth mode, maintenance actions for backups and cache clearing, and the full audit log.

### Throughout every role

A global search in the header finds courses, assignments, quizzes, forum threads, announcements and files, and jumps directly to whatever is selected. A notifications panel gives recent activity with deep links and a mark all read action. The French and Kreyòl toggle applies to navigation, dashboards, headings and shared interface text everywhere in the application.

## Design

The visual identity comes from the KAYE mark, a notebook page and a mountain peak rendered in violet and orange.

| Colour | Hex | Used for |
| --- | --- | --- |
| Violet | `#4C3C9C` | Primary actions and active navigation |
| Deep violet | `#241B54` | Login screen and gradients |
| Orange | `#FF6A45` | Accents, deadlines and urgency |

The interface is deliberately restrained: generous white space, clear typography, and no decoration for its own sake. Many users will be meeting a learning platform for the first time, on a small screen, and unfamiliar software should not become another obstacle to learning.

The prototype is built with Tailwind CSS loaded from a CDN and inline SVG icons. The logo is embedded directly in the file as a base64 image, so there are no external assets to host.

## Where the project stands today

Everything in this repository is a static front end. That is a deliberate stage, not an oversight. The interface, the navigation, the workflows and the screens are all complete and can be evaluated properly, which is exactly what a pilot needs before anyone commits to building infrastructure.

What that means in practice:

Authentication is not real. Any email and password will sign you in, and the role tab decides what you see.

All data lives in JavaScript objects inside the page. Grades, messages, submissions and approvals behave correctly while you use the application, so the workflows can be tested end to end, but everything resets when the page is refreshed. Nothing is stored.

File upload and download, video playback, the live classroom and the AI assistant are all simulated. They demonstrate the interaction and the place they occupy in the workflow without a service behind them.

Kreyòl currently covers navigation, dashboards, headings and shared interface text. Course content and longer passages of body copy remain in French. Completing this is a translation task rather than a programming one, and it matters enough that it should be done properly by a Kreyòl speaker rather than machine translated.

Offline capability, which is the real requirement for Haitian connectivity, is not yet implemented.

No accessibility audit has been carried out.

## What comes next

The next stage is the back end, which turns the prototype into a system a school can actually run on.

That work covers real authentication and session management with role based permissions enforced on the server rather than assumed by the interface. It covers a database holding institutions, users, courses, modules, assignments, submissions, grades, messages and announcements. It covers file storage for assignment briefs and student submissions, with access control so that work is visible only to its author and their teacher. It covers a notifications service capable of reaching families by SMS as well as in the application, since email is not universally practical here.

Alongside that sits the offline work, most likely as a progressive web application with a service worker, so that a student can open their course material and draft an assignment without a connection, and have their submission upload automatically once one returns. On Haitian mobile data this is closer to a requirement than a refinement.

The pilot will also need real data migration, meaning a way to bring an existing school register into the system without retyping it, and a backup and recovery process that a school can trust with the only copy of its academic records.

## Roadmap

The approach is deliberately incremental.

Phase one is a single classroom at Saint-François-Xavier. One teacher, one group of students, one term. The goal is not scale. It is finding out what genuinely breaks when real people use the system: where the connection fails, where the interface confuses, and which features teachers quietly stop bothering with. A single classroom is small enough to fix things quickly and honestly.

Phase two extends across the whole school, where the harder problems appear: many teachers with different working habits, full enrollment management, parents wanting access, and school wide reporting.

Phase three brings in other institutions, each with its own roster and branding, running on shared infrastructure.

Beyond that, the ambition is for KAYE to become the platform Haitian schools use, potentially at a national level. That is years away and depends on far more than software: institutional trust, funding, policy and infrastructure all have to align. We are not designing for that today. We are designing so that it remains possible.

The reasoning throughout is that a system which genuinely works for one Haitian classroom is worth more than one which theoretically works for a thousand.


