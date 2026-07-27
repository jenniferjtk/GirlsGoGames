Milestone 3
Hours Worked: 12 hours
Tasks Completed:
- Evaluated two proposed game concepts (Fill in the Blank vs. Tap the Word) for implementation feasibility against the existing codebase
- Built and iterated a full "Tap the Word" game: single-word MVP → 3-word round with scoring → kid-friendly redesign for pre-readers (hidden word, emoji-only audio button, non-sentence feedback)
- Restructured student navigation: renamed the "Practice" tab to "Games" and built a Games hub screen listing both Practice and Tap the Word (as "Sound Pop!"), designed to make adding future games a one-line change
- Created the self evlaution of our app
- Started the UI changes to improve the workflow
- Added Testing: at least 5 unit tests (pure Dart) and 3 widget tests, passing.
Contributions made:
-Found and reused existing flutter_tts infrastructure already in practice.dart instead of duplicating a new text-to-speech setup
-Cleaned up a pre-existing duplicate button bug in studentDashboard.dart while consolidating navigation
-Made several accessibility-minded UI calls for young/pre-literate readers (large tap targets, icon-based feedback over text, encouraging tone on incorrect answers)
- Created the self evlaution of our app
- Started the UI changes to improve the workflow
- Added Testing: at least 5 unit tests (pure Dart) and 3 widget tests, passing.
Challenges Encountered:
- Our database is hosted on Supabase, which the previous team is hosting. 
We have no access to supabase, and have to work around not being able to access the database.
- Our current format has the AI Story builder based on the student section, instead of the teacher section.
- Balancing "hide the target word for a true audio-only test" against making an MVP that's still easy to visually verify while testing
- No local Flutter/Dart toolchain available to run flutter analyze, so all changes had to be verified through manual code review and brace/paren balance checks instead of a compiler
- Reconciling scope creep risk — several small UX improvements (e.g., speaking the word again during feedback) weren't explicitly requested, so each had to be flagged as a judgment call rather than silently bundled in
Something learned:
Small MVPs benefit from explicitly separating "what's shown for testing convenience" from "what the final design actually calls for" — stating that distinction up front avoided confusion later when requirements got stricter (e.g., the request to hide the word)


Milestone 2 

Hours worked: 8

Tasks Completed/ Contributions Made:
- Leading the group, planning
- PRD
- Architecture Writeup
- Get Emulator to work
Challenhes Encountered:
- conflicting code from forked team for emulator

Something Learned:
Writing a PRD requires foresight into future problems, for example, asking "how" and "why" about each pillar.