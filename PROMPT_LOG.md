## ENTRY 1: Candidate 2 Main Code Analysis (June 23, 2026, ChatGPT)

Context: 
Needed a full scale evaluation of the codebase of Candidate 2, team_3_f25_project. Needed to 
focus on overall strengths, weaknesses, architechure, and feasibility for ReadRight2.0.

Prompt Excerpt: 
Analyze this Flutter codebase and identify potential strengths, weaknesses, architecture, user expereince,
educational effectiveness, and code quality. Provide examples from the codebase to support the claims.

AI Summary: 
The AI response included an exerpt for every category requested, inlcuding details about the codebase
to ensure no information was fabricated. 

Human Evaluation: 
The analysis was sound, with code examples from the codebase to supoort all points and claims about 
strengths, weaknesses, and otherwise details.

Final Decision: 
This analysis was extremely helpful for deciding which applciation to use as a basis for ReadRight2.0


## Entry 2 - Analyzing Architecture of Candidate 1 (tool:Claude) (June 21, 2026)

Context

We were analyzing the architecture of the WitherTigher/Capstone-Project-RW codebase to evaluate whether it was a sound foundation to build a semester project on.

Prompt Excerpt

"Analyze this Flutter codebase across six dimensions: strengths, weaknesses, architecture, UX for young users, educational effectiveness, and code quality. Be specific and cite actual file names and code patterns"

AI Summary

Claude identified the Azure pronunciation pipeline in practice.dart as the strongest asset, flagged feedback.dart as entirely hardcoded placeholder content disconnected from real data, noted the 871-line practice screen as the biggest architectural risk, and flagged the Supabase credential hardcoded in config.dart as an immediate security issue.

Human Evaluation

The architectural assessment was accurate and matched what we found when we opened the files ourselves. The security findings were confirmed in config.dart and pubspec.yaml. The claim about feedback.dart was verified by opening the file and finding the hardcoded word "cat", a score of 0.88, and a "Next word feature coming soon" snackbar.

Final Decision

Accepted with modification. We used Claude's analysis as a starting framework but rewrote the evaluation in our own words and added observations Claude missed, including the flutter_dotenv misconfiguration and the 2000+ linter warnings visible on import.

Testing and Verification

We opened practice.dart and confirmed the feedback field is hardcoded to "Good job" regardless of score. We opened feedback.dart and confirmed the hardcoded word, score, and phoneme chips. We opened pubspec.yaml and confirmed mockito under dependencies and three unused Firebase packages listed despite Firebase never being used.

## Entry 3 Educational Effectiveness of Candiadte 1 ([06/22/26],tool:ChatGPT) 

Context
We were evaluating the educational effectiveness of the WitherTigher codebase to determine whether it actually teaches children to read or just drills them on words.

Prompt Excerpt

"Given that this app uses Azure Pronunciation Assessment and Dolch word lists, does it meet the criteria for an educationally effective tool for early readers? What is missing from a learning standpoint?"

AI Summary

ChatGPT noted that the app functions as a drill tool rather than a teaching tool. It presents words and records pass or fail but has no spaced repetition, no session structure, no phoneme level feedback shown to students, and no adaptive difficulty. It suggested adding spaced repetition and session stopping points as high priority improvements.

Human Evaluation

The assessment was accurate but somewhat generic. ChatGPT described what a good literacy app should have without specifically tying it to what was present or absent in this codebase. We had to verify each claim against the actual code to confirm which gaps were real.

Final Decision

Modified. We accepted the general framework of what was missing but replaced the generic recommendations with specific observations tied to actual files, such as the fact that Azure returns per-phoneme data that never reaches the student, and that the feedback field in every attempt row is hardcoded to "Good job" regardless of score.

Testing and Verification

We confirmed no spaced repetition logic exists anywhere in the codebase by searching for relevant terms across all service files. We confirmed the always "Good job" feedback string in practice.dart. We confirmed Azure returns phoneme level data by reviewing the AssessmentResult model and noting it is never passed to feedback.dart.

## ENTRY 4: Candidate 2 Pronounciation Question (June 23, 2026, ChatGPT)

Context: 
Determining whether speech-to-text is a sufficent way to gauge student pronunciation for the 
dolch words.

Prompt:
"Is using speech to text alone a good way to evaluate pronunciation? Explain the advantages and 
disadvantages compared to a dedicated pronunciation assessment."

AI Summary:
The AI explained that speech to text can determine when a word is said correctly, but does not 
accurately determine pronunciation quality. The AI also explained that a poorly pronounced word 
could be marked correctly because of context or the pronunciation being "close enough", which could
stunt learning. It reccomended using a service such as Azure Pronunciation Assessment for a more 
accurate learning experience.

Human Evaluation:
This response alligned with the project and provided useful information in the decision making 
process for which candidate to choose. 

Final Decision: 
We decided that because of this important limitation, candidate 2 was not a great choice to use for 
ReadRight2.0. 


# Entry 5: Understanding Architecure Candidate 5 (tool: ChatGPT. 6/23/26) [Karina]
Context:
Understand the architecture, structure, and quality of a Flutter app  and assess whether it is scalable or would require major refactoring.

Prompt Excerpt:
Based on this code, give me the rough architecture of this project. what are strengths? what can be improved? non-goal = writing new code or trying to fix it

AI Summary:
The AI described the app as a Provider-based Flutter architecture with global state management (Session, Users, Recording), centralized routing, and dotenv configuration. It identified strengths like simplicity, clean separation of domains, and consistent state patterns, but flagged weaknesses such as likely fat providers, missing service/repository layers, and potential scalability issues in speech/recording logic.

Human Evaluation:
Accurate high-level architectural breakdown. The identification of domain separation and global state usage matches the code structure. 

Final Decision:
The response aligned with the project's overview and provided observations without trying to fix the code. Decided to go back and ask for clarification and line numbers.

Testing / Verification — how you confirmed the conclusion.
Cross-checked the main() file: confirmed MultiProvider setup, presence of SessionProvider, RecordingProvider, and AllUsersProvider, and centralized routing via MaterialApp.

# Entry 6: Candidate 5 Review (tool: Gemini. 6/23/26) [Karina]
Context:
Understand the architecture, structure, and quality of a Flutter app  and assess whether it is scalable or would require major refactoring.

Prompt Excerpt: 
Asked the AI to impersonate a master flutter engineer with the goal to grade the code 1-5 based on it's quality, strengths, weaknesses, efficitivness, etc.

AI Summary:
Rated the code a 3.5/5.Suggested transitioning to a service-repository pattern to maintain scalability. Considered the providers bloated.

Human Evalution:
The feedback accurately identifies the trade-off between current simplicity and future technical debt.Feedback also pointed out some missed items like losing the benefits of lazy loading.

Verification:
Verfied by reviewing main.dart against Flutter's best practices. Suggested were cross referenced against other candidates.



# Entry 7: Backend Proxy Creation (tool: ChatGPT 7/11/26) [Kathleen]
Context:
Build a secure backend proxy for the AI Story Builder that keeps the OpenAI API key out of the Flutter app and follows the project requirements.

Prompt Excerpt:
I need to build the backend proxy for my part of the project, but I've never done this before. Can you explain what a backend proxy is, what files I need to create, and help me build an Express server that stores the OpenAI key in a local .env file and exposes a /generate-story endpoint that my Flutter app can call?

AI Summary:
The AI explained how a backend proxy works, suggested using Express with a .env file, and provided the basic server structure with a /generate-story endpoint that forwards requests to OpenAI.

Human Evaluation:
The overall setup matched what our professor wanted, but the AI included a temperature parameter that the required model didn't support. After removing it, everything worked correctly.

Final Decision:
Accepted with a small change. We kept the backend setup but removed the unsupported parameter.

Testing / Verification:
Started the backend, tested the /health endpoint, then sent a test prompt to /generate-story and confirmed it returned a story.



# Entry #8: Flutter Connection to Backend Proxy (tool: ChatGPT, 7/11/26) [Kathleen]
Context:
Create a Flutter page that connects to the backend proxy and displays the generated story without repeatedly calling the API.

Prompt Excerpt:
Help me build a simple AI Story Builder page in Flutter that has a text box, a Generate Story button, and displays the returned story. I also want to make sure it only sends one request when the button is pressed and doesn't accidentally make repeated API calls every time the screen refreshes.

AI Summary:
The AI suggested creating a new screen with a text field, a button, and an HTTP POST request to the backend. It also recommended only calling the backend inside the button's onPressed function so requests would only be made intentionally.

Human Evaluation:
The design was simple, which was fine since Milestone 2 only requires proving the AI path works. It also only sends a request when the button is pressed, so it won't accidentally make repeated API calls.

Final Decision:
Accepted. The page was added with only small changes to match the existing app.

Testing / Verification:
Opened the Story Builder page, submitted a Dolch word prompt, and confirmed the generated story was returned and displayed correctly.

# Entry 9: Migrating Credentials to Environment Variables (tool: Claude, 6/24/26) [Jennifer]
Context:
The inherited codebase had the Supabase URL and anon key hardcoded in plaintext in config/config.dart. The goal was to move these credentials into a .env file loaded at runtime using flutter_dotenv so they would never be committed to the repository.

Prompt Excerpt:
Asked Claude to rewrite config.dart to read the Supabase URL, anon key, and Azure key from flutter_dotenv environment variables instead of hardcoded strings, and to update main.dart accordingly.

AI Summary:
Claude rewrote config.dart as a getter-based class reading from dotenv.env for all three credentials, updated main.dart to use final instead of const when assigning the Supabase values since getters cannot be used with const, and flagged that flutter_dotenv needed to be moved from dev_dependencies to dependencies in pubspec.yaml so it would be available in release builds.

Human Evaluation:
The credential migration was correct and the final vs const distinction was accurate. However, Claude's rewrite removed the color constants and appName that other files in the app depended on, causing red squiggle errors across multiple screens. These had to be added back manually by checking what AppConfig values were referenced elsewhere in the codebase.

Final Decision:
Accepted with modification. The getter-based credential loading was kept, and the missing constants (primaryColor, secondaryColor, appName) were restored using the original app colors found in pubspec.yaml's splash screen configuration.

Testing and Verification:
Ran flutter run -d chrome after the fix and confirmed the app connected to Supabase successfully. The signup screen no longer showed "Failed to fetch." Also ran flutter analyze and confirmed warnings dropped from 49 to 37 info-level only issues with no remaining warnings.

# Entry 10: Fixing Teacher Add Student Feature (tool: Claude, 7/5/26) [Jennifer]

Context:
The teacher dashboard's "Add New Student" button was failing with the error "Failed to fetch, uri=https://fdqfxkddijsbbhwgmfeu.supabase.co/functions/v1/create_student." The original team had built this feature using a Supabase Edge Function that no longer existed in our migrated project. The goal was to fix the feature so teachers could add students without depending on the missing edge function.

Prompt Excerpt:
Asked Claude to find where the create_student edge function call was made in the codebase and replace it with a direct Supabase database insert that matched the pattern already used in signup.dart, without creating any new edge functions.

AI Summary:
Claude located the edge function call in the teacher dashboard files, identified that the bulk upload feature used the same broken call, and proposed replacing both with direct Supabase auth signup calls followed by a database insert into the users table. Claude flagged that using supabase.auth.signUp() client-side would automatically log the teacher out and replace their session with the new student's session, and recommended capturing and restoring the teacher's session afterward to prevent this.

Human Evaluation:
The diagnosis was accurate — both the single student add and bulk upload were broken for the same reason. The session replacement issue was a real problem that Claude correctly identified before making the fix, which was not something that would have been obvious without understanding how Supabase client-side auth works. The recommended fix of restoring the teacher session was the right approach.

Final Decision:
Accepted. Chose the session restore option so the teacher stays logged in after adding a student, and also chose to fix the bulk upload at the same time since it had the identical problem.

Testing and Verification:
Ran the app after the fix, logged in as a teacher, and used the Add New Student form to create a test student account. Confirmed the teacher remained on the dashboard after submission rather than being redirected to the student view. Then logged out and logged in with the new student credentials to confirm the account was created correctly in Supabase.

# Entry 11: Tradeoffs and Emulator Error fixes (tool: ChatGPT &Claude, 7/12/26) [Karina]

Context:
Flutter Project succesffully runs on chrome and across all member's local devices, but was not working on emulators.

Prompt Excerpt:
Told AI what device, program, emulator information, and scope of the project. Asked AI where could the error be preventing android emulator from running the project.

AI Summary:
Claude located the problem as well of what code to fix.

Human Evaluation:
ChatGPT was unable to locate the exact issue. Switched to

Final Decision:
Went over code and redownloaded android simulator to create another device

Testing and Verification:
Ran the app after the fix, logged in as a student and tested features.

# Entry 12: Wiring Real Data into the Feedback Screen (tool: Claude, 7/26/26) [Jennifer]

Context:
feedback.dart was a fully hardcoded placeholder screen, always showing the word "cat," a score of 88%, and fake phoneme chips regardless of what the student actually practiced. The goal was to make it show the real word and real AssessmentResult from the student's most recent attempt.

Prompt Excerpt:
Asked Claude to look at the AssessmentResult model and how practice.dart already displays assessment results, then rebuild feedback.dart to accept the practiced word and AssessmentResult and replace every hardcoded value with real data, and to confirm whether real phoneme-level data was available.

AI Summary:
Claude found that AssessmentResult only contains word-level accuracy, not phoneme-level data, so it removed the fake phoneme chip section entirely and replaced it with an accuracy/fluency/completeness breakdown using the real Azure scores. It also added a "View Feedback" button to practice.dart alongside the existing Next Word/Try Again buttons, and updated the /feedback route in main.dart to pass the word and result as arguments.

Human Evaluation:
Confirmed directly in assessment_result.dart that phoneme-level data genuinely does not exist, so removing that section instead of faking it was the right call. The new accuracy breakdown card reuses the same visual style as the old phoneme chips, so the screen didn't lose its look.

Final Decision:
Accepted.

Testing and Verification:
Ran flutter analyze with no new warnings. Full end-to-end verification (recording a real attempt and viewing the resulting feedback screen) was deferred until the microphone permission bug below was fixed, since practice couldn't produce a real attempt until then.

# Entry 13: iOS Microphone Permission Root-Cause Investigation (tool: Claude, 7/26/26) [Jennifer]

Context:
The Practice screen showed "You need to enable permissions in the app settings" on both iOS Simulator and a real iPhone, even after granting microphone access. This blocked all real testing of the pronunciation pillar.

Prompt Excerpt:
Asked Claude to figure out why iOS never even showed a permission dialog, despite the Info.plist usage description being present and the app running fine on web after a simple kIsWeb bypass.

AI Summary:
Claude ruled out several causes with direct evidence before finding the real one: confirmed the simulator's TCC database had no cached denial, confirmed no MDM/Screen Time restrictions were blocking it, confirmed the audio input device was correctly configured, and confirmed a misconfigured xcode-select path wasn't the cause. Added temporary debug logging that showed Permission.microphone.request() was returning "denied" immediately, before any dialog could appear, even on a freshly erased simulator. That led to finding that the permission_handler iOS plugin silently hardcodes every permission check to "denied" unless a PERMISSION_MICROPHONE=1 preprocessor macro is added to the Podfile, which was missing. Separately found that _initRecording() never called setState() after the async permission result came back, so the UI wouldn't refresh even once permission was actually granted.

Human Evaluation:
This took many iterations because several plausible causes had to be eliminated with real evidence (TCC database queries, system logs, temporary debug prints) rather than guessed at. The methodical process of ruling things out was slow but avoided chasing the wrong fix, and the Podfile macro issue would have been very hard to find without that process.

Final Decision:
Accepted all four fixes together: the Info.plist usage description, the Podfile macro, the missing setState(), and the earlier kIsWeb bypass (kept as a legitimate separate fix for web, not a workaround for the same bug).

Testing and Verification:
Verified with temporary debug logging showing the exact permission status at each stage, then confirmed the real iOS system permission dialog appeared and microphone access worked, tested on both iOS Simulator and a real physical iPhone.

# Entry 14: Removing media_kit After an iOS Crash (tool: Claude, 7/26/26) [Jennifer]

Context:
media_kit and its native backend packages were crashing the app on iOS with "Cannot find Mpv.framework." The assumption going in was that media_kit was unused dead weight.

Prompt Excerpt:
Asked Claude to remove media_kit from main.dart and pubspec.yaml, since audio recording and TTS use separate packages (record and flutter_tts).

AI Summary:
Claude found that media_kit was not unused — the teacher's student-attempts screen used it to let a teacher play back a student's recorded audio, a real working feature. Instead of just deleting it and breaking that feature, Claude proposed and implemented a replacement using just_audio, which doesn't depend on the crashing native framework.

Human Evaluation:
Catching that the feature was actually in use before removing the dependency was important; deleting it outright would have silently broken audio playback for teachers.

Final Decision:
Accepted the just_audio replacement over the two other options considered (leaving media_kit installed just for that one screen, or removing the feature entirely).

Testing and Verification:
flutter analyze clean, no media_kit references remaining anywhere in the codebase. A teammate had independently patched the same crash with a partial fix (commenting out the initialization call) in a separate commit; this was reconciled during a git rebase, keeping the full removal.

# Entry 15: Azure Key Diagnosis and Backend Proxy (tool: Claude, 7/26/26) [Jennifer]

Context:
The pronunciation feature failed with "Network Error retries failed" after every attempt. Separately, the course rubric requires every API call to route through a backend proxy with no key embedded in the Flutter app, but the Azure Speech key was being called directly from the app via a bundled .env file.

Prompt Excerpt:
First asked Claude to diagnose the network error. After confirming it was a real backend, asked Claude to move the Azure call behind our existing Node backend so the key is never shipped inside the app.

AI Summary:
Claude tested the Azure endpoint directly with curl using the existing key and got a 401 Unauthorized, proving it was an invalid/stale key rather than a network problem. After the key was replaced with a valid one from the Azure Portal, Claude added a /assess-pronunciation route to the existing backend/server.js that mirrors the exact same Azure request shape, moved the key into backend/.env, and removed it from the app's .env entirely, since .env is bundled as an asset into the compiled app regardless of whether the Dart code still reads it.

Human Evaluation:
Testing the key directly with curl instead of guessing saved a lot of time. Catching that the key was still physically bundled into the app via the .env asset, even after the Dart code stopped reading it, was a detail that would have been easy to miss.

Final Decision:
Accepted. Also added a configurable BACKEND_BASE_URL override in .env so a real device (which can't reach "localhost") can be pointed at the Mac's LAN IP during testing.

Testing and Verification:
Verified the backend route directly with curl (health check, missing-parameter validation, and a real call that returned a genuine Azure response), then verified the full app flow on both iOS Simulator and a real iPhone.

# Entry 16: Pronunciation Service Extraction and Recording Cap (tool: Claude, 7/26/26) [Jennifer]

Context:
The PRD commits to two things for Pillar 1 that weren't implemented: capping recordings at 3 seconds, and extracting audio capture/assessment logic out of the practice screen into a dedicated, swappable PronunciationAssessor interface.

Prompt Excerpt:
Asked Claude to check the PRD against the current implementation, identify what was still outstanding for Pillar 1, and implement it.

AI Summary:
Claude found the 3-second cap was never implemented (a countdown existed in the code but was commented out and never wired to anything), and that all Azure networking, retry, and parsing logic lived inline inside the 800+ line practice screen instead of behind an interface. Claude added a Timer-based auto-stop matching the manual Stop button's behavior, and extracted the Azure logic into services/pronunciation_assessor.dart behind a PronunciationAssessor interface with AzurePronunciationAssessor as the implementation, so a different provider could be swapped in later without touching the practice screen.

Human Evaluation:
The extraction preserved the exact same retry count and error messages, so no user-facing behavior changed, only where the code lives. This directly matches what the PRD committed to for this pillar's architecture.

Final Decision:
Accepted.

Testing and Verification:
flutter analyze clean. Confirmed recording auto-stops at 3 seconds and the practice flow works identically through the new service on a real device.

# Entry 17: Tap the Word Game — Feasibility Comparison and MVP (tool: Claude, 7/26/26) [Karina]

Context:
Comparing two candidate sight-word game concepts (Fill in the Blank vs. Tap the Word) for
feasibility on top of the existing ReadRight codebase, then building a testable single-screen
MVP of Tap the Word as a new addition to the app.

Prompt Excerpt:
Asked Claude which of two proposed game ideas (Fill in the Blank vs. Tap the Word) was easier
to implement given the existing codebase. After Claude flagged Tap the Word as needing a new
TTS/audio pipeline, reminded AI the app already has word-pronunciation software in practice.dart
and asked to locate it. Then asked Claude to build a basic MVP — show a word, speak it aloud,
show 3 answer buttons, let the student pick one, and end with feedback — following
practice.dart's existing patterns.

AI Summary:
Claude initially assessed Fill in the Blank as easier since it reuses the existing sentences
data, while flagging Tap the Word as needing a new TTS or audio-asset pipeline it assumed
didn't exist yet. After being told practice.dart already speaks words aloud, Claude searched
the repo and located the existing flutter_tts integration and wordSpeech() method, which
reversed that assessment — Tap the Word turned out to be just as simple once the existing TTS
call was reused instead of built from scratch. Claude then created
lib/screen/tap_the_word.dart following practice.dart's FlutterTts/Supabase/StudentBaseScaffold
patterns, wired a /tapTheWord route into main.dart, and added a dashboard button in
studentDashboard.dart so the screen could be reached and tested.

Human Evaluation:
Game was accpectable as an MVP, but needed changes to actually form a a game round and make it engaging for a child.

Final Decision:
Accpected with changes needing to be done later on.

Testing and Verification:
ran flutter pub get / flutter run, opened the dashboard, tapped "Tap the Word
(MVP)", confirmed the word is spoken, confirmed tapping the correct/incorrect button shows the
right feedback screen

# Entry 18: Tap the Word Game — Expansion (tool: Claude, 7/26/26) [Karina]

Context:
Expanding the Tap the Word game into an actual game with rounds. Non-goa: changing the anything besides the game, changing the format of the game

Prompt Excerpt:
Asked AI to expand the game to include 3 rounds, with visual feedback between each round. Asked AI to change buttons and UI to better reflect emojis and the intended audience.

AI Summary:
Claude finazlized

Human Evaluation:
The game works as intended with 3 rounds. The UI of the game needs to be better adjusted to fit the intended audience as it uses too large of words.

Final Decision:
Accpected from a game presppective - UI changes will be made

Testing and Verification:
ran flutter pub get / flutter run, opened the dashboard, tapped "Tap the Word
(MVP)", confirmed the word is spoken, confirmed tapping the correct/incorrect button shows the
right feedback screen

# Entry 17: Game Screen (tool: Claude, 7/26/26) [Karina]

Context:
Rearranging the dashboard screen to better fit the addition of the new game. goal: change nav bar non-goal: rearrangign every scene

Prompt Excerpt:
Using the same flutter app we are already working on, in the bottom nav bar, can we replace "practice" with "games" and the games screen showcases "practice", a fun name for tap the word, and potential to expand if we add another game. keep the nav bar child friendly

AI Summary:
Gave new and editted files. Gave a list of everything built as wells as flags noticed. Removed another UI feature without asking.

Human Evaluation:
Reviewed the new nav bar changes and the non-prompted UI feature removal. Found the UI feature removal was a left over duplicate practice button from the orginial team.

Final Decision:
Accpected all changes with no revision. Will continue to push UI changes to the next milestone.

Testing and Verification:
ran flutter pub get / flutter run, opened the dashboard, tested all screens and all nav bar buttons